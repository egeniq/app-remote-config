import AppRemoteConfig
import Crypto

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public import ServiceLifecycle
public import Logging
public import Metrics
import AsyncAlgorithms
import Synchronization
public import Configuration

/// A configuration provider that reads configuration from an URL with automatic resolving and reloading capability.
///
/// `AppRemoteConfigProvider` is a generic URL-based configuration provider that monitors
/// a configuration URL for changes and automatically reloads the data periodically and when
/// changes are scheduled. This provider works with different file formats by using
/// different snapshot types that conform to ``FileRemoteConfigSnapshot``.
///
/// ## Swift-Configuration Integration
///
/// `AppRemoteConfigProvider` conforms to swift-configuration's `ConfigProvider` protocol, allowing
/// it to be used directly with `ConfigReader`. It provides access to configuration values through
/// the snapshot's raw data.
///
/// ```swift
/// // Create the remote config provider with resolution context
/// let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
///     platform: .iOS,
///     platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
///     appVersion: try Version("1.2.0"),
///     buildVariant: .debug
/// )
/// 
/// let configProvider = try await AppRemoteConfigProvider<JSONSnapshot>(
///     url: URL(string: "https://example.com/config.json")!,
///     resolutionContext: context
/// )
///
/// // Use with ConfigReader
/// let reader = ConfigReader(provider: configProvider)
/// let featureEnabled = reader.bool(forKey: "features.newUI", default: false)
/// ```
///
/// ## Usage
///
/// Create a remote config provider by specifying the snapshot type and URL:
///
/// ```swift
/// // Using with a JSON snapshot and a custom poll interval
/// let jsonProvider = try await AppRemoteConfigProvider<JSONSnapshot>(
///     url: URL(string: "https://www.example.com/config.json")!,
///     pollInterval: .seconds(30)
/// )
///
/// // Using with a YAML snapshot
/// let yamlProvider = try await AppRemoteConfigProvider<YAMLSnapshot>(
///     url: URL(string: "https://www.example.com/config.yaml")!,
///     pollInterval: .seconds(30)
/// )
/// ```
///
/// ## Service integration
///
/// This provider implements the `Service` protocol and must be run within a `ServiceGroup`
/// to enable automatic reloading:
///
/// ```swift
/// let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
///     platform: .iOS,
///     platformVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 1, patchVersion: 0),
///     appVersion: try Version("1.0"),
///     variant: "custom1",
///     buildVariant: .debug,
///     language: "en"
/// )
/// let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
///     url: URL(string: "https://www.example.com/config.json")!,
///     resolutionContext: context
/// )
/// let serviceGroup = ServiceGroup(services: [provider], logger: logger)
/// try await serviceGroup.run()
/// ```
///
/// The provider monitors the URL by polling at the specified interval (default: 15 seconds)
/// and notifies any active watchers when changes are detected or when they are scheduled.
///
/// ## Configuration from a reader
///
/// You can also initialize the provider using a configuration reader:
///
/// ```swift
/// let envConfig = ConfigReader(provider: EnvironmentVariablesProvider())
/// let provider = try await AppRemoteConfigProvider<JSONSnapshot>(config: envConfig)
/// ```
///
/// This expects a `url` key in the configuration that specifies the URL to the file.
/// For a full list of configuration keys, check out ``RemoteFileProvider/init(snapshotType:parsingOptions:config:)``.
///
public final class AppRemoteConfigProvider<Snapshot: FileConfigSnapshot>: Sendable {

    /// The internal storage structure for the provider state.
    private struct Storage {

        /// The current configuration snapshot.
        var snapshot: Snapshot

        /// The raw data bytes used to create the snapshot and parse into Config.
        var rawData: Data

        /// Last modified timestamp of the resolved file.
        var lastModifiedTimestamp: Date
        
        /// Last refresh attempt timestamp for minimum refresh interval enforcement.
        var lastRefreshTimestamp: Date

        /// The URL of the configuration file.
        var url: URL

        /// Active watchers for individual configuration values, keyed by encoded key.
        var valueWatchers: [AbsoluteConfigKey: [UUID: AsyncStream<Result<LookupResult, any Error>>.Continuation]]

        /// Active watchers for configuration snapshots.
        var snapshotWatchers: [UUID: AsyncStream<Snapshot>.Continuation]

        /// Cache of resolved settings keyed by resolution context hash.
        /// Stores [String: Sendable] to avoid re-resolution on every access.
        var resolvedSettingsCache: [String: [String: Sendable]] = [:]

        /// The last resolution context used for caching.
        var lastResolutionContext: (
            platform: Platform,
            platformVersion: OperatingSystemVersion,
            appVersion: Version,
            variant: String?,
            buildVariant: BuildVariant,
            language: String?
        )? = nil

        /// The next date at which resolution should be re-evaluated.
        var nextResolutionDate: Date? = nil

        /// Scheduled timers for resolution date changes, keyed by UUID.
        var scheduledTimers: [UUID: Task<Void, Never>] = [:]

        /// Returns the total number of active watchers.
        var totalWatcherCount: Int {
            let valueWatcherCount = valueWatchers.values.map(\.count).reduce(0, +)
            let snapshotWatcherCount = snapshotWatchers.count
            return valueWatcherCount + snapshotWatcherCount
        }
    }

    /// Internal provider storage.
    private let storage: Mutex<Storage>

    /// The options used for parsing the data.
    private let parsingOptions: Snapshot.ParsingOptions

    /// The URL of the configuration file to monitor.
    private let url: URL

    /// The interval between polling checks. If nil, automatic polling is disabled.
    private let pollInterval: Duration?
    
    /// Minimum interval between refresh attempts to prevent excessive network requests.
    private let minimumRefreshInterval: Duration

    /// The human-readable name of the provider.
    public let providerName: String

    /// Resolution context for configuration. These values are used to resolve overrides and conditions.
    private let resolutionContext: Mutex<ResolutionContext>
    
    /// Optional public key for verifying signed configurations.
    private let publicKey: Curve25519.Signing.PublicKey?
    
    /// Resolution context structure containing platform, version, and variant information.
    public struct ResolutionContext: Sendable {
        public let platform: Platform
        public let platformVersion: OperatingSystemVersion
        public let appVersion: Version
        public let variant: String?
        public let buildVariant: BuildVariant
        public let language: String?
        
        public init(
            platform: Platform,
            platformVersion: OperatingSystemVersion,
            appVersion: Version,
            variant: String? = nil,
            buildVariant: BuildVariant,
            language: String? = nil
        ) {
            self.platform = platform
            self.platformVersion = platformVersion
            self.appVersion = appVersion
            self.variant = variant
            self.buildVariant = buildVariant
            self.language = language
        }
    }
    
    /// The logger for this provider instance.
    private let logger: Logger

    /// The metrics collector for this provider instance.
    private let metrics: AppRemoteConfigProviderMetrics

    internal init(
        snapshotType: Snapshot.Type = Snapshot.self,
        parsingOptions: Snapshot.ParsingOptions = .default,
        url: URL,
        pollInterval: Duration? = .seconds(3600),
        minimumRefreshInterval: Duration = .seconds(300),
        resolutionContext: ResolutionContext,
        publicKey: Curve25519.Signing.PublicKey? = nil,
        logger: Logger = Logger(label: "AppRemoteConfigProvider"),
        metrics: any MetricsFactory = MetricsSystem.factory
    ) async throws {
        self.parsingOptions = parsingOptions
        self.url = url
        self.pollInterval = pollInterval
        self.minimumRefreshInterval = minimumRefreshInterval
        self.resolutionContext = .init(resolutionContext)
        self.publicKey = publicKey
        self.providerName = "AppRemoteConfigProvider<\(Snapshot.self)>"

        // Set up the logger with metadata
        var logger = logger
        logger[metadataKey: "\(providerName).url"] = .string(url.absoluteString)
        if let pollInterval = pollInterval {
            logger[metadataKey: "\(providerName).pollInterval.seconds"] = .string(
                pollInterval.components.seconds.description
            )
        } else {
            logger[metadataKey: "\(providerName).pollInterval"] = "disabled"
        }
        logger[metadataKey: "\(providerName).minimumRefreshInterval.seconds"] = .string(
            minimumRefreshInterval.components.seconds.description
        )
        self.logger = logger

        // Set up metrics
        self.metrics = AppRemoteConfigProviderMetrics(
            factory: metrics,
            providerName: providerName
        )

        // Perform initial load
        logger.debug("Performing initial file load")
        let timestamp = Date()
        let (loadedData, _) = try await URLSession.shared.data(from: url)
        
        // If public key is provided, verify signature and extract the actual config data
        let (actualConfigData, initialSnapshot): (Data, Snapshot)
        if let publicKey = publicKey {
            // Verify and extract signed config
            let _ = try Config(data: loadedData, publicKey: publicKey) // Verify signature
            
            // Extract the actual config data from the signed wrapper
            guard let json = try JSONSerialization.jsonObject(with: loadedData, options: []) as? [String: Any],
                  let encodedConfigData = json[Config.dataKey] as? String,
                  let configData = Data(base64Encoded: encodedConfigData) else {
                throw ConfigError.base64DecodingFailed
            }
            let snapshot = try snapshotType.init(
                data: configData.bytes,
                providerName: providerName,
                parsingOptions: parsingOptions
            )
            actualConfigData = configData
            initialSnapshot = snapshot
        } else {
            let snapshot = try snapshotType.init(
                data: loadedData.bytes,
                providerName: providerName,
                parsingOptions: parsingOptions
            )
            actualConfigData = loadedData
            initialSnapshot = snapshot
        }

        // Initialize storage with the actual config data (unwrapped if signed)
        self.storage = .init(
            .init(
                snapshot: initialSnapshot,
                rawData: actualConfigData,
                lastModifiedTimestamp: timestamp,
                lastRefreshTimestamp: timestamp,
                url: url,
                valueWatchers: [:],
                snapshotWatchers: [:]
            )
        )

        // Update initial metrics
        self.metrics.fileSize.record(actualConfigData.count)

        logger.debug(
            "Successfully initialized reloading app remote config provider",
            metadata: [
                "\(providerName).url": .string(url.absoluteString),
                "\(providerName).initialTimestamp": .stringConvertible(timestamp.formatted(.iso8601)),
                "\(providerName).fileSize": .stringConvertible(actualConfigData.count),
            ]
        )
    }

    /// Creates a reloading file provider using configuration from a reader.
    ///
    /// ## Configuration keys
    /// - `url` (string, required): The URL to the configuration file to monitor.
    /// - `publicKey` (string, optional): Base64-encoded Curve25519 public key for verifying signed configurations.
    /// - `pollIntervalSeconds` (int, optional, default: 3600): Automatic polling interval in seconds. Set to 0 to disable polling.
    /// - `minimumRefreshIntervalSeconds` (int, optional, default: 300): Minimum interval between refresh attempts in seconds.
    ///
    /// - Parameters:
    ///   - snapshotType: The type of snapshot to create from the file contents.
    ///   - parsingOptions: Options used by the snapshot to parse the file data.
    ///   - config: A configuration reader that contains the required configuration keys.
    ///   - resolutionContext: The context for resolving configuration based on platform, version, variant, language.
    ///   - publicKey: Optional Curve25519 public key for verifying signed configurations. If provided via config reader, this parameter takes precedence.
    ///   - logger: The logger instance to use for this provider.
    ///   - metrics: The metrics factory to use for monitoring provider performance.
    /// - Throws: If required configuration keys are missing, if the file cannot be read, or if snapshot creation fails.
    public convenience init(
        snapshotType: Snapshot.Type = Snapshot.self,
        parsingOptions: Snapshot.ParsingOptions = .default,
        config: ConfigReader,
        resolutionContext: ResolutionContext,
        publicKey: Curve25519.Signing.PublicKey? = nil,
        logger: Logger = Logger(label: "AppRemoteConfigProvider"),
        metrics: any MetricsFactory = MetricsSystem.factory
    ) async throws {
        // Try to load public key from config if not provided directly
        let effectivePublicKey: Curve25519.Signing.PublicKey?
        if let publicKey = publicKey {
            effectivePublicKey = publicKey
        } else if let publicKeyString = config.string(forKey: "publicKey"),
                  let publicKeyData = Data(base64Encoded: publicKeyString) {
            effectivePublicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        } else {
            effectivePublicKey = nil
        }
        
        // Parse poll interval (0 or negative means disabled)
        let pollIntervalSeconds = config.int(forKey: "pollIntervalSeconds", default: 3600)
        let effectivePollInterval = pollIntervalSeconds > 0 ? Duration.seconds(pollIntervalSeconds) : nil
        
        try await self.init(
            snapshotType: snapshotType,
            parsingOptions: parsingOptions,
            url: config.requiredString(forKey: "url", as: URL.self),
            pollInterval: effectivePollInterval,
            minimumRefreshInterval: Duration.seconds(config.int(forKey: "minimumRefreshIntervalSeconds", default: 300)),
            resolutionContext: resolutionContext,
            publicKey: effectivePublicKey,
            logger: logger,
            metrics: metrics
        )
    }

    // MARK: - Refresh Methods
    
    /// Manually triggers a refresh of the configuration data.
    ///
    /// This method respects the `minimumRefreshInterval` to prevent excessive network requests.
    /// Use this method when your app comes to the foreground or when you want to ensure
    /// fresh configuration data.
    ///
    /// - Throws: Network errors, parsing errors, or if minimum refresh interval has not elapsed.
    public func refresh() async throws {
        try await refreshIfNeeded(logger: logger, force: true)
    }
    
    /// Checks if the file should be refreshed and reloads it if necessary.
    ///
    /// This method performs the core file monitoring logic. It checks the minimum refresh
    /// interval to prevent excessive network requests, then fetches new data, creates a
    /// new snapshot, and notifies any active watchers of changes.
    ///
    /// - Parameters:
    ///   - logger: The logger to use during the reload operation.
    ///   - force: If true, bypasses timestamp comparison but still respects minimum refresh interval.
    /// - Throws: File system errors or snapshot creation errors.
    internal func refreshIfNeeded(logger: Logger, force: Bool = false) async throws {
        logger.debug("refreshIfNeeded started")
        defer {
            logger.debug("refreshIfNeeded finished")
        }

        let candidateRealPath = url
        let candidateTimestamp = Date()
        
        // Check minimum refresh interval
        let shouldSkipDueToMinimumInterval = storage.withLock { storage -> Bool in
            let timeSinceLastRefresh = candidateTimestamp.timeIntervalSince(storage.lastRefreshTimestamp)
            let minimumInterval = minimumRefreshInterval.components.seconds
            return timeSinceLastRefresh < Double(minimumInterval)
        }
        
        if shouldSkipDueToMinimumInterval {
            logger.debug(
                "Skipping refresh due to minimum refresh interval",
                metadata: [
                    "\(providerName).minimumRefreshInterval.seconds": .stringConvertible(minimumRefreshInterval.components.seconds)
                ]
            )
            return
        }

        guard
            let (originalTimestamp, originalRealPath) =
                storage
                .withLock({ storage -> (Date, URL)? in
                    let originalTimestamp = storage.lastModifiedTimestamp
                    let originalRealPath = storage.url

                    // Check if either the real path or timestamp has changed (or force refresh)
                    guard force || originalRealPath != candidateRealPath || originalTimestamp != candidateTimestamp else {
                        logger.debug(
                            "File path and timestamp unchanged, no reload needed",
                            metadata: [
                                "\(providerName).timestamp": .stringConvertible(originalTimestamp.formatted(.iso8601)),
                                "\(providerName).realPath": .string(originalRealPath.absoluteString),
                            ]
                        )
                        return nil
                    }
                    return (originalTimestamp, originalRealPath)
                })
        else {
            // No changes detected.
            return
        }

        logger.debug(
            "File path or timestamp changed, reloading...",
            metadata: [
                "\(providerName).originalTimestamp": .stringConvertible(originalTimestamp.formatted(.iso8601)),
                "\(providerName).candidateTimestamp": .stringConvertible(candidateTimestamp.formatted(.iso8601)),
                "\(providerName).originalRealPath": .string(originalRealPath.absoluteString),
                "\(providerName).candidateRealPath": .string(candidateRealPath.absoluteString),
            ]
        )

        // Load new data outside the lock
        let (loadedData, _) = try await URLSession.shared.data(from: url)
        
        // If public key is provided, verify and extract signed config
        let (actualData, newSnapshot): (Data, Snapshot)
        if let publicKey = self.publicKey {
            // Verify signed config
            let _ = try Config(data: loadedData, publicKey: publicKey)
            
            // Extract actual config data
            guard let json = try JSONSerialization.jsonObject(with: loadedData, options: []) as? [String: Any],
                  let encodedConfigData = json[Config.dataKey] as? String,
                  let configData = Data(base64Encoded: encodedConfigData) else {
                throw ConfigError.base64DecodingFailed
            }
            let snapshot = try Snapshot.init(
                data: configData.bytes,
                providerName: providerName,
                parsingOptions: parsingOptions
            )
            actualData = configData
            newSnapshot = snapshot
        } else {
            let snapshot = try Snapshot.init(
                data: loadedData.bytes,
                providerName: providerName,
                parsingOptions: parsingOptions
            )
            actualData = loadedData
            newSnapshot = snapshot
        }

        typealias ValueWatchers = [(
            AbsoluteConfigKey,
            Result<LookupResult, any Error>,
            [AsyncStream<Result<LookupResult, any Error>>.Continuation]
        )]
        typealias SnapshotWatchers = (Snapshot, [AsyncStream<Snapshot>.Continuation])
        guard
            let (valueWatchersToNotify, snapshotWatchersToNotify) =
                storage
                .withLock({ storage -> (ValueWatchers, SnapshotWatchers)? in

                    // Check if we lost the race with another caller
                    if storage.lastModifiedTimestamp != originalTimestamp || storage.url != originalRealPath {
                        return nil
                    }

                    // Update storage with new data
                    storage.snapshot = newSnapshot
                    storage.rawData = actualData
                    storage.lastModifiedTimestamp = candidateTimestamp
                    storage.lastRefreshTimestamp = candidateTimestamp
                    storage.url = candidateRealPath

                    logger.debug(
                        "Successfully reloaded file",
                        metadata: [
                            "\(providerName).timestamp": .stringConvertible(candidateTimestamp.formatted(.iso8601)),
                            "\(providerName).fileSize": .stringConvertible(actualData.count),
                            "\(providerName).realPath": .string(candidateRealPath.absoluteString),
                        ]
                    )

                    // Update metrics
                    metrics.reloadCounter.increment(by: 1)
                    metrics.fileSize.record(actualData.count)
                    metrics.watcherCount.record(storage.totalWatcherCount)

                    // Collect watchers to potentially notify outside the lock
                    let valueWatchers = storage.valueWatchers.compactMap {
                        (key, watchers) -> (
                            AbsoluteConfigKey,
                            Result<LookupResult, any Error>,
                            [AsyncStream<Result<LookupResult, any Error>>.Continuation]
                        )? in
                        guard !watchers.isEmpty else { return nil }

                        // Get new values using the new snapshot
                        let newValue = Result { try newSnapshot.value(forKey: key, type: .string) }

                        // Only notify watchers of new value
                        return (key, newValue, Array(watchers.values))
                    }

                    let snapshotWatchers = (newSnapshot, Array(storage.snapshotWatchers.values))
                    return (valueWatchers, snapshotWatchers)
                })
        else {
            logger.debug("Lost race with another caller, not modifying internal state")
            return
        }

        // Notify watchers outside the lock
        let totalWatchers = valueWatchersToNotify.map { $0.2.count }.reduce(0, +) + snapshotWatchersToNotify.1.count
        guard totalWatchers > 0 else {
            logger.debug("No watchers to notify")
            return
        }

        // Notify value watchers
        for (_, valueUpdate, watchers) in valueWatchersToNotify {
            for watcher in watchers {
                watcher.yield(valueUpdate)
            }
        }

        // Notify snapshot watchers
        for watcher in snapshotWatchersToNotify.1 {
            watcher.yield(snapshotWatchersToNotify.0)
        }

        logger.debug(
            "Notified watchers of file changes",
            metadata: [
                "\(providerName).valueWatcherKeys": .array(valueWatchersToNotify.map { .string($0.0.description) }),
                "\(providerName).snapshotWatcherCount": .stringConvertible(snapshotWatchersToNotify.1.count),
                "\(providerName).totalWatcherCount": .stringConvertible(totalWatchers),
            ]
        )
    }

    // MARK: - Resolution Context Methods
    
    /// Sets the resolution context for config resolution.
    ///
    /// Use this to update the platform, app version, build variant, or other contextual
    /// information that affects which configuration overrides are applied. The next time
    /// values are accessed, they will be resolved using the new context.
    ///
    /// - Parameter context: The new resolution context to use for config resolution.
    public func setResolutionContext(_ context: ResolutionContext) {
        resolutionContext.withLock { $0 = context }
    }
    
    /// Gets the current resolution context.
    ///
    /// - Returns: The currently active resolution context used for config resolution.
    public func getResolutionContext() -> ResolutionContext {
        resolutionContext.withLock { $0 }
    }
    
    /// Creates a hash key for the resolution context to cache resolved settings.
    private func contextCacheKey(
        platform: Platform,
        platformVersion: OperatingSystemVersion,
        appVersion: Version,
        variant: String?,
        buildVariant: BuildVariant,
        language: String?
    ) -> String {
        "\(platform)_\(platformVersion.majorVersion).\(platformVersion.minorVersion).\(platformVersion.patchVersion)_\(appVersion)_\(variant ?? "nil")_\(buildVariant)_\(language ?? "nil")"
    }
    
    /// Compare two OperatingSystemVersions for equality.
    private func versionsEqual(_ lhs: OperatingSystemVersion, _ rhs: OperatingSystemVersion) -> Bool {
        lhs.majorVersion == rhs.majorVersion &&
        lhs.minorVersion == rhs.minorVersion &&
        lhs.patchVersion == rhs.patchVersion
    }
    
    /// Resolves configuration values once and caches them.
    ///
    /// This method:
    /// 1. Checks if we've already resolved with the same context
    /// 2. If context hasn't changed and no scheduled resolution date has passed, returns cached values
    /// 3. If context changed or scheduled resolution date passed, re-resolves using raw data
    /// 4. Updates scheduled timers based on `relevantResolutionDates`
    ///
    /// - Parameters:
    ///   - platform: The platform context
    ///   - platformVersion: The platform version context
    ///   - appVersion: The app version context
    ///   - variant: The variant context (optional)
    ///   - buildVariant: The build variant context
    ///   - language: The language context (optional)
    /// - Returns: Resolved settings dictionary, or raw settings if no context available
    private func resolveOnce(
        platform: Platform,
        platformVersion: OperatingSystemVersion,
        appVersion: Version,
        variant: String?,
        buildVariant: BuildVariant,
        language: String?
    ) throws -> [String: Sendable] {
        return try storage.withLock { storage in
            let cacheKey = contextCacheKey(
                platform: platform,
                platformVersion: platformVersion,
                appVersion: appVersion,
                variant: variant,
                buildVariant: buildVariant,
                language: language
            )
            let now = Date()
            
            // Check if context hasn't changed and no scheduled resolution date has passed
            let contextUnchanged = storage.lastResolutionContext.map { ctx in
                ctx.platform == platform &&
                versionsEqual(ctx.platformVersion, platformVersion) &&
                ctx.appVersion == appVersion &&
                ctx.variant == variant &&
                ctx.buildVariant == buildVariant &&
                ctx.language == language
            } ?? false
            
            let noScheduledDatePassed = storage.nextResolutionDate.map { now < $0 } ?? true
            
            // If context unchanged and no scheduled date has passed, return cached values
            if contextUnchanged && noScheduledDatePassed, let cached = storage.resolvedSettingsCache[cacheKey] {
                return cached
            }
            
            // Create Config from raw data
            let config = try Config(data: storage.rawData)
            let resolvedSettings = config.resolve(
                date: now,
                platform: platform,
                platformVersion: platformVersion,
                appVersion: appVersion,
                variant: variant,
                buildVariant: buildVariant,
                language: language
            )
            
            // Cache the resolved settings
            storage.resolvedSettingsCache[cacheKey] = resolvedSettings
            
            // Update resolution context tracking
            storage.lastResolutionContext = (
                platform: platform,
                platformVersion: platformVersion,
                appVersion: appVersion,
                variant: variant,
                buildVariant: buildVariant,
                language: language
            )
            
            // Calculate next resolution date based on scheduled changes
            let relevantDates = config.relevantResolutionDates(
                platform: platform,
                platformVersion: platformVersion,
                appVersion: appVersion,
                variant: variant,
                buildVariant: buildVariant,
                language: language
            )
            
            // Find the next date after now
            storage.nextResolutionDate = relevantDates.first { $0 > now }
            
            return resolvedSettings
        }
    }
    
    /// Extracts a value from resolved settings using a dot-separated key path.
    ///
    /// Example: "settings.features.betaMode" navigates through nested dictionaries.
    ///
    /// - Parameters:
    ///   - settings: The resolved settings dictionary
    ///   - keyPath: The dot-separated path to the value
    /// - Returns: The value at the path, or nil if not found
    private func extractValue(from settings: [String: Sendable], keyPath: String) -> Sendable? {
        let components = keyPath.split(separator: ".").map(String.init)
        var current: Sendable? = settings
        
        for component in components {
            guard let dict = current as? [String: Sendable] else {
                return nil
            }
            current = dict[component]
        }
        
        return current
    }
}

extension AppRemoteConfigProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        storage.withLock { $0.snapshot.description }
    }
}

extension AppRemoteConfigProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        storage.withLock { $0.snapshot.debugDescription }
    }
}

extension AppRemoteConfigProvider: ConfigProvider {
    
    /// Retrieves a configuration value for the specified key.
    ///
    /// This method uses the current resolution context to resolve config overrides and
    /// extract the value at the specified key path. It performs type-directed casting
    /// based on the requested ConfigType.
    ///
    /// - Parameters:
    ///   - key: The absolute configuration key path (dot-separated for nested values)
    ///   - type: The expected type of the configuration value
    /// - Returns: A LookupResult containing the value if found and type-compatible, nil otherwise
    /// - Throws: Configuration resolution errors
    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        let keyString = key.description
        
        // Use resolution context to get resolved settings directly
        let context = getResolutionContext()
        let settings = try resolveOnce(
            platform: context.platform,
            platformVersion: context.platformVersion,
            appVersion: context.appVersion,
            variant: context.variant,
            buildVariant: context.buildVariant,
            language: context.language
        )
        
        guard let rawValue = extractValue(from: settings, keyPath: keyString) else {
            return LookupResult(encodedKey: keyString, value: nil)
        }
        
        // Use the requested type to cast and create ConfigValue
        let configValue: ConfigValue? = switch type {
        case .bool:
            // Handle both Bool and NSNumber (which JSON uses for booleans)
            if let bool = rawValue as? Bool {
                .some(ConfigValue(.bool(bool), isSecret: false))
            } else if let number = rawValue as? NSNumber {
                // NSNumber from JSON might represent a boolean as 0/1
                .some(ConfigValue(.bool(number.boolValue), isSecret: false))
            } else {
                .none
            }
        case .int:
            (rawValue as? Int).map { ConfigValue(.int($0), isSecret: false) }
        case .double:
            (rawValue as? Double).map { ConfigValue(.double($0), isSecret: false) }
        case .string:
            (rawValue as? String).map { ConfigValue(.string($0), isSecret: false) }
        case .stringArray:
            (rawValue as? [String]).map { ConfigValue(.stringArray($0), isSecret: false) }
        case .intArray:
            (rawValue as? [Int]).map { ConfigValue(.intArray($0), isSecret: false) }
        case .doubleArray:
            (rawValue as? [Double]).map { ConfigValue(.doubleArray($0), isSecret: false) }
        case .bytes:
            // Handle both Data and byte arrays
            if let data = rawValue as? Data {
                .some(ConfigValue(.bytes([UInt8](data)), isSecret: false))
            } else if let array = rawValue as? [UInt8] {
                .some(ConfigValue(.bytes(array), isSecret: false))
            } else {
                .none
            }
        case .boolArray:
            // Handle arrays of booleans or NSNumbers
            if let boolArray = rawValue as? [Bool] {
                .some(ConfigValue(.boolArray(boolArray), isSecret: false))
            } else if let numberArray = rawValue as? [NSNumber] {
                .some(ConfigValue(.boolArray(numberArray.map { $0.boolValue }), isSecret: false))
            } else {
                .none
            }
        case .byteChunkArray:
            // Handle arrays of byte chunks (Data objects)
            if let dataArray = rawValue as? [Data] {
                .some(ConfigValue(.byteChunkArray(dataArray.map { [UInt8]($0) }), isSecret: false))
            } else if let byteArrays = rawValue as? [[UInt8]] {
                .some(ConfigValue(.byteChunkArray(byteArrays), isSecret: false))
            } else {
                .none
            }
        @unknown default:
            // For any unknown types, attempt string conversion
            (rawValue as? String).map { ConfigValue(.string($0), isSecret: false) }
        }
        
        return LookupResult(encodedKey: keyString, value: configValue)
    }

    /// Fetches a configuration value after first refreshing the configuration if needed.
    ///
    /// This async variant of `value(forKey:type:)` ensures the configuration is up-to-date
    /// before returning the value by calling `refreshIfNeeded()` first.
    ///
    /// - Parameters:
    ///   - key: The absolute configuration key path
    ///   - type: The expected type of the configuration value
    /// - Returns: A LookupResult containing the value if found
    /// - Throws: Network errors, configuration resolution errors
    public func fetchValue(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) async throws -> LookupResult {
        try await refreshIfNeeded(logger: logger)
        return try value(forKey: key, type: type)
    }

    /// Watches a configuration value for changes over time.
    ///
    /// Creates a stream that yields the initial value and subsequently yields whenever
    /// the configuration file changes. The stream remains active until the handler returns.
    ///
    /// - Parameters:
    ///   - key: The absolute configuration key path to watch
    ///   - type: The expected type of the configuration value
    ///   - updatesHandler: Handler that receives the async sequence of value updates
    /// - Returns: The value returned by the updates handler
    /// - Throws: Configuration resolution errors or errors thrown by the handler
    public func watchValue<Return>(
        forKey key: Configuration.AbsoluteConfigKey,
        type: Configuration.ConfigType,
        updatesHandler: nonisolated(nonsending) (Configuration.ConfigUpdatesAsyncSequence<Result<Configuration.LookupResult, any Error>, Never>) async throws -> Return
    ) async throws -> Return where Return : ~Copyable {
        // Use original key for resolved values (always have resolution context now)
        let watchKey = key
        
        let (stream, continuation) = AsyncStream<Result<LookupResult, any Error>>
            .makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()

        // Add watcher and get initial value
        let initialValue: Result<LookupResult, any Error> = .init {
            try value(forKey: key, type: type)
        }
        
        storage.withLock { storage in
            storage.valueWatchers[watchKey, default: [:]][id] = continuation
            metrics.watcherCount.record(storage.totalWatcherCount)
        }
        
        defer {
            storage.withLock { storage in
                storage.valueWatchers[watchKey, default: [:]][id] = nil
                metrics.watcherCount.record(storage.totalWatcherCount)
            }
        }

        // Send initial value
        continuation.yield(initialValue)
        return try await updatesHandler(.init(stream))
    }

    /// Returns the current configuration snapshot.
    ///
    /// - Returns: The current immutable configuration snapshot
    public func snapshot() -> any ConfigSnapshot {
        storage.withLock { $0.snapshot }
    }

    /// Watches the configuration snapshot for changes over time.
    ///
    /// Creates a stream that yields the initial snapshot and subsequently yields whenever
    /// the configuration file changes. Useful for observing all configuration changes
    /// rather than individual values.
    ///
    /// - Parameter updatesHandler: Handler that receives the async sequence of snapshots
    /// - Returns: The value returned by the updates handler
    /// - Throws: Errors thrown by the handler
    public func watchSnapshot<Return>(updatesHandler: nonisolated(nonsending) (Configuration.ConfigUpdatesAsyncSequence<any Configuration.ConfigSnapshot, Never>) async throws -> Return) async throws -> Return where Return : ~Copyable {
        let (stream, continuation) = AsyncStream<Snapshot>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()

        // Add watcher and get initial snapshot
        let initialSnapshot = storage.withLock { storage in
            storage.snapshotWatchers[id] = continuation
            metrics.watcherCount.record(storage.totalWatcherCount)
            return storage.snapshot
        }
        defer {
            // Clean up watcher
            storage.withLock { storage in
                storage.snapshotWatchers[id] = nil
                metrics.watcherCount.record(storage.totalWatcherCount)
            }
        }

        // Send initial snapshot
        continuation.yield(initialSnapshot)
        return try await updatesHandler(.init(stream.map { $0 }))
    }
}

extension AppRemoteConfigProvider: Service {
    
    /// Runs the service's main polling loop.
    ///
    /// This method implements the `Service` protocol and should be run within a `ServiceGroup`.
    /// It polls the configuration URL at the specified `pollInterval`, checking for changes
    /// and notifying watchers when updates are detected. If `pollInterval` is nil, polling
    /// is disabled and the service waits indefinitely for graceful shutdown.
    ///
    /// - Throws: Network errors or configuration parsing errors during polling
    public func run() async throws {
        // If polling is disabled, just wait for graceful shutdown
        guard let pollInterval = pollInterval else {
            logger.debug("Automatic polling disabled, waiting for graceful shutdown")
            try await gracefulShutdown()
            return
        }
        
        logger.debug("URL polling starting")
        defer {
            logger.debug("URL polling stopping")
        }

        var counter = 1
        for try await _ in AsyncTimerSequence(interval: pollInterval, clock: .continuous).cancelOnGracefulShutdown() {
            defer {
                counter += 1
                metrics.pollTickCounter.increment(by: 1)
            }

            var tickLogger = logger
            tickLogger[metadataKey: "\(providerName).poll.tick.number"] = .stringConvertible(counter)
            tickLogger.debug("Poll tick starting")
            defer {
                tickLogger.debug("Poll tick stopping")
            }

            do {
                try await refreshIfNeeded(logger: tickLogger)
            } catch {
                tickLogger.debug(
                    "Poll tick failed, will retry on next tick",
                    metadata: [
                        "error": "\(error)"
                    ]
                )
                metrics.pollTickErrorCounter.increment(by: 1)
            }
        }
    }
}
