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
/// ## Automatic Updates
///
/// The provider monitors for configuration changes in two ways:
///
/// 1. **Polling**: Periodically checks the URL for file changes at the specified interval (default: 3600 seconds)
/// 2. **Scheduled Resolution**: Automatically re-evaluates configuration at times specified in override schedules
///
/// When the configuration includes scheduled overrides with `from` and `until` timestamps, the provider
/// automatically schedules timers to re-resolve the configuration at those times. This ensures that
/// features can activate and deactivate on a schedule without requiring file changes or manual refreshes.
///
/// For example:
/// ```json
/// "overrides": [
///   {
///     "schedule": {
///       "from": "2026-01-17T16:06:43Z",
///       "until": "2026-01-17T16:06:53Z"
///     },
///     "settings": {
///       "features": {
///         "newUI": true
///       }
///     }
///   }
/// ]
/// ```
///
/// In this example, the `newUI` feature will automatically activate at the "from" time and deactivate at the "until" time.
/// All watchers are notified when the configuration is re-resolved, so views automatically update.
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
/// For a full list of configuration keys, check out ``AppRemoteConfigProvider/init``.
///
@available(iOS 18.0, *)
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
    
    /// Optional URL for caching downloaded configuration data.
    private let cacheURL: URL?
    
    /// Optional URL for a local fallback configuration file.
    private let fallbackURL: URL?

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

    public init(
        snapshotType: Snapshot.Type = Snapshot.self,
        parsingOptions: Snapshot.ParsingOptions = .default,
        url: URL,
        cacheURL: URL? = nil,
        fallbackURL: URL? = nil,
        pollInterval: Duration? = .seconds(3600),
        minimumRefreshInterval: Duration = .seconds(300),
        resolutionContext: ResolutionContext,
        publicKey: Curve25519.Signing.PublicKey? = nil,
        logger: Logger = Logger(label: "AppRemoteConfigProvider"),
        metrics: any MetricsFactory = MetricsSystem.factory
    ) async throws {
        self.parsingOptions = parsingOptions
        self.url = url
        self.cacheURL = cacheURL
        self.fallbackURL = fallbackURL
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

        // Perform initial load with fallback chain: network → fallback → cache
        logger.debug("Performing initial file load")
        let timestamp = Date()
        let (actualConfigData, initialSnapshot) = try await Self.fetchAndParseConfig(
            preferredURL: url,
            fallbackURL: fallbackURL,
            cacheURL: cacheURL,
            publicKey: publicKey,
            resolutionContext: resolutionContext,
            providerName: providerName,
            parsingOptions: parsingOptions,
            logger: logger
        )

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

        // Schedule initial resolution timer for any scheduled overrides
        let relevantDates = (try? Config(data: actualConfigData))?
            .relevantResolutionDates(
                platform: resolutionContext.platform,
                platformVersion: resolutionContext.platformVersion,
                appVersion: resolutionContext.appVersion,
                variant: resolutionContext.variant,
                buildVariant: resolutionContext.buildVariant,
                language: resolutionContext.language
            ) ?? []
        let initialNextDate = relevantDates.first(where: { $0 > timestamp })
        scheduleResolutionTimer(for: initialNextDate)
        
        // Store the next resolution date in storage
        storage.withLock { $0.nextResolutionDate = initialNextDate }

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
    /// - `cacheURL` (string, optional): URL where downloaded configuration should be cached.
    /// - `fallbackURL` (string, optional): URL to a local fallback configuration file.
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
        
        // Parse optional cache and fallback URLs
        let cacheURL = config.string(forKey: "cacheURL").flatMap { URL(string: $0) }
        let fallbackURL = config.string(forKey: "fallbackURL").flatMap { URL(string: $0) }
        
        try await self.init(
            snapshotType: snapshotType,
            parsingOptions: parsingOptions,
            url: config.requiredString(forKey: "url", as: URL.self),
            cacheURL: cacheURL,
            fallbackURL: fallbackURL,
            pollInterval: effectivePollInterval,
            minimumRefreshInterval: Duration.seconds(config.int(forKey: "minimumRefreshIntervalSeconds", default: 300)),
            resolutionContext: resolutionContext,
            publicKey: effectivePublicKey,
            logger: logger,
            metrics: metrics
        )
    }

    // MARK: - Data Fetching
    
    /// Centralized method for fetching and parsing configuration data.
    ///
    /// Attempts to fetch configuration in the following order:
    /// 1. From the preferred URL (typically network)
    /// 2. From the cache URL if provided (previously downloaded data)
    /// 3. From the fallback URL if provided (typically bundled file)
    ///
    /// If a fetch succeeds, the data is cached to cacheURL if provided.
    ///
    /// - Parameters:
    ///   - preferredURL: Primary URL to fetch from (e.g., network URL)
    ///   - fallbackURL: Optional local file URL to use if preferred fetch fails
    ///   - cacheURL: Optional URL where data should be cached
    ///   - resolutionContext: Context for resolving configuration
    ///   - logger: Logger for diagnostic messages
    /// - Returns: Tuple of (raw config data, resolved snapshot)
    /// - Throws: If all fetch attempts fail
    private static func fetchAndParseConfig(
        preferredURL: URL,
        fallbackURL: URL?,
        cacheURL: URL?,
        publicKey: Curve25519.Signing.PublicKey?,
        resolutionContext: ResolutionContext,
        providerName: String,
        parsingOptions: Snapshot.ParsingOptions,
        logger: Logger
    ) async throws -> (Data, Snapshot) {
        var lastError: Error?
        
        // Try preferred URL first
        do {
            logger.debug("Attempting to fetch from preferred URL", metadata: [
                "\(providerName).url": .string(preferredURL.absoluteString)
            ])
            let (loadedData, _) = try await URLSession.shared.data(from: preferredURL)
            let (data, snapshot) = try Self.processAndResolveData(
                loadedData,
                publicKey: publicKey,
                resolutionContext: resolutionContext,
                providerName: providerName,
                parsingOptions: parsingOptions
            )
            
            // Cache the successfully fetched data
            if let cacheURL = cacheURL {
                try? data.write(to: cacheURL, options: [.atomic])
                logger.debug("Cached configuration data", metadata: [
                    "\(providerName).cacheURL": .string(cacheURL.absoluteString)
                ])
            }
            
            return (data, snapshot)
        } catch {
            lastError = error
            logger.warning("Failed to fetch from preferred URL", metadata: [
                "\(providerName).error": .string(String(describing: error))
            ])
        }
        
        // Try cache URL second - more recent than bundled fallback
        if let cacheURL = cacheURL {
            do {
                logger.debug("Attempting to load from cache", metadata: [
                    "\(providerName).cacheURL": .string(cacheURL.absoluteString)
                ])
                let loadedData = try Data(contentsOf: cacheURL)
                let (data, snapshot) = try Self.processAndResolveData(
                    loadedData,
                    publicKey: publicKey,
                    resolutionContext: resolutionContext,
                    providerName: providerName,
                    parsingOptions: parsingOptions
                )
                logger.info("Loaded configuration from cache")
                return (data, snapshot)
            } catch {
                lastError = error
                logger.warning("Failed to load from cache", metadata: [
                    "\(providerName).error": .string(String(describing: error))
                ])
            }
        }
        
        // Try fallback URL as last resort
        if let fallbackURL = fallbackURL {
            do {
                logger.debug("Attempting to fetch from fallback URL", metadata: [
                    "\(providerName).fallbackURL": .string(fallbackURL.absoluteString)
                ])
                let loadedData = try Data(contentsOf: fallbackURL)
                let (data, snapshot) = try Self.processAndResolveData(
                    loadedData,
                    publicKey: publicKey,
                    resolutionContext: resolutionContext,
                    providerName: providerName,
                    parsingOptions: parsingOptions
                )
                return (data, snapshot)
            } catch {
                lastError = error
                logger.warning("Failed to fetch from fallback URL", metadata: [
                    "\(providerName).error": .string(String(describing: error))
                ])
            }
        }
        
        // All attempts failed
        throw lastError ?? NSError(
            domain: "AppRemoteConfigProvider",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to fetch configuration from all sources"]
        )
    }
    
    /// Processes raw data (verifying signature if needed) and resolves it into a snapshot.
    ///
    /// - Parameters:
    ///   - loadedData: Raw data that may be signed or unsigned
    ///   - publicKey: Optional public key for signature verification
    ///   - resolutionContext: Context for resolving configuration
    ///   - providerName: Name of the provider for logging
    ///   - parsingOptions: Options for parsing the configuration
    /// - Returns: Tuple of (unwrapped config data, resolved snapshot)
    /// - Throws: If signature verification or parsing fails
    private static func processAndResolveData(
        _ loadedData: Data,
        publicKey: Curve25519.Signing.PublicKey?,
        resolutionContext: ResolutionContext,
        providerName: String,
        parsingOptions: Snapshot.ParsingOptions
    ) throws -> (Data, Snapshot) {
        // If public key is provided, verify signature and extract the actual config data
        if let publicKey = publicKey {
            // Verify signature
            let _ = try Config(data: loadedData, publicKey: publicKey)
            
            // Extract the actual config data from the signed wrapper
            guard let json = try JSONSerialization.jsonObject(with: loadedData, options: []) as? [String: Any],
                  let encodedConfigData = json[Config.dataKey] as? String,
                  let configData = Data(base64Encoded: encodedConfigData) else {
                throw ConfigError.base64DecodingFailed
            }
            
            let resolvedSnapshot = try Self.makeResolvedSnapshot(
                from: configData,
                context: resolutionContext,
                providerName: providerName,
                parsingOptions: parsingOptions
            )
            return (configData, resolvedSnapshot)
        } else {
            let resolvedSnapshot = try Self.makeResolvedSnapshot(
                from: loadedData,
                context: resolutionContext,
                providerName: providerName,
                parsingOptions: parsingOptions
            )
            return (loadedData, resolvedSnapshot)
        }
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

        // Try to load new data - if this fails, we'll keep using the current config
        let (actualData, newSnapshot): (Data, Snapshot)
        do {
            let result = try await Self.fetchAndParseConfig(
                preferredURL: url,
                fallbackURL: nil, // Don't use fallback on refresh, only on init
                cacheURL: cacheURL,
                publicKey: publicKey,
                resolutionContext: getResolutionContext(),
                providerName: providerName,
                parsingOptions: parsingOptions,
                logger: logger
            )
            actualData = result.0
            newSnapshot = result.1
        } catch {
            // Log the error but don't throw - keep using current configuration
            logger.error("Failed to refresh configuration, keeping current config", metadata: [
                "error": .string(String(describing: error))
            ])
            return
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

    /// Creates a snapshot from resolved settings for the current context.
    ///
    /// This ensures the snapshot only contains flattened settings values (strings, numbers, bools),
    /// avoiding errors when the raw config contains complex structures like overrides.
    private func makeResolvedSnapshot(from data: Data, resolveDate: Date = Date()) throws -> Snapshot {
        let context = getResolutionContext()
        return try Self.makeResolvedSnapshot(
            from: data,
            context: context,
            providerName: providerName,
            parsingOptions: parsingOptions,
            resolveDate: resolveDate
        )
    }

    /// Builds a snapshot from resolved settings for the given context.
    private static func makeResolvedSnapshot(
        from data: Data,
        context: ResolutionContext,
        providerName: String,
        parsingOptions: Snapshot.ParsingOptions,
        resolveDate: Date = Date()
    ) throws -> Snapshot {
        let resolvedSettings = try Config(data: data).resolve(
            date: resolveDate,
            platform: context.platform,
            platformVersion: context.platformVersion,
            appVersion: context.appVersion,
            variant: context.variant,
            buildVariant: context.buildVariant,
            language: context.language
        )

        let resolvedData = try JSONSerialization.data(withJSONObject: resolvedSettings, options: [])
        return try Snapshot.init(
            data: resolvedData.bytes,
            providerName: providerName,
            parsingOptions: parsingOptions
        )
    }

    /// Schedule a timer to re-resolve at the given date.
    /// Only schedules timers in non-test environments to avoid blocking test completion.
    private func scheduleResolutionTimer(for date: Date?) {
        // Skip scheduling in test environments
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }
        
        storage.withLock { storage in
            // Cancel existing timers
            storage.scheduledTimers.values.forEach { $0.cancel() }
            storage.scheduledTimers.removeAll()
            guard let date, date > Date() else {
                storage.nextResolutionDate = nil
                return
            }
            let delay = date.timeIntervalSinceNow
            print("[AppRemoteConfigProvider] Scheduling resolution timer for \(String(format: "%.1f", delay)) seconds from now")
            logger.debug("Scheduling resolution timer", metadata: [
                "delay_seconds": .stringConvertible(delay),
                "scheduled_for": .string(date.formatted(.iso8601))
            ])
            let task = Task.detached { [weak self] in
                let nanoseconds = UInt64(max(delay, 0) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                print("[AppRemoteConfigProvider] Timer fired! Performing scheduled resolution")
                await self?.performScheduledResolution(at: date)
            }
            storage.scheduledTimers[UUID()] = task
            storage.nextResolutionDate = date
        }
    }

    /// Recompute resolved snapshot at a scheduled date and notify watchers.
    private func performScheduledResolution(at date: Date) async {
        logger.debug("Performing scheduled resolution", metadata: [
            "scheduled_date": .string(date.formatted(.iso8601))
        ])
        typealias ValueWatchers = [(

            AbsoluteConfigKey,
            Result<LookupResult, any Error>,
            [AsyncStream<Result<LookupResult, any Error>>.Continuation]
        )]
        typealias SnapshotWatchers = (Snapshot, [AsyncStream<Snapshot>.Continuation])

        let context = getResolutionContext()
        let rawDataAndWatchers: (Data, ValueWatchers, SnapshotWatchers, Date?)
        do {
            rawDataAndWatchers = try storage.withLock { storage in
                // Ensure this scheduled resolution is still relevant
                if let nextDate = storage.nextResolutionDate, nextDate > date {
                    return (storage.rawData, [], (storage.snapshot, []), storage.nextResolutionDate)
                }

                let resolvedSnapshot = try Self.makeResolvedSnapshot(
                    from: storage.rawData,
                    context: context,
                    providerName: providerName,
                    parsingOptions: parsingOptions,
                    resolveDate: date
                )

                // Compute next relevant date for future scheduling
                let nextDate = (try? Config(data: storage.rawData))?
                    .relevantResolutionDates(
                        platform: context.platform,
                        platformVersion: context.platformVersion,
                        appVersion: context.appVersion,
                        variant: context.variant,
                        buildVariant: context.buildVariant,
                        language: context.language
                    ).first(where: { $0 > date })

                // Prepare watcher notifications
                let valueWatchers = storage.valueWatchers.compactMap {
                    (key, watchers) -> (
                        AbsoluteConfigKey,
                        Result<LookupResult, any Error>,
                        [AsyncStream<Result<LookupResult, any Error>>.Continuation]
                    )? in
                    guard !watchers.isEmpty else { return nil }
                    let newValue = Result { try resolvedSnapshot.value(forKey: key, type: .string) }
                    return (key, newValue, Array(watchers.values))
                }
                let snapshotWatchers = (resolvedSnapshot, Array(storage.snapshotWatchers.values))

                // Update storage
                storage.snapshot = resolvedSnapshot
                storage.resolvedSettingsCache.removeAll()
                storage.lastResolutionContext = nil
                storage.nextResolutionDate = nextDate
                storage.scheduledTimers.values.forEach { $0.cancel() }
                storage.scheduledTimers.removeAll()
                storage.lastRefreshTimestamp = date

                return (storage.rawData, valueWatchers, snapshotWatchers, nextDate)
            }
        } catch {
            logger.error("Failed scheduled resolution: \(error)")
            return
        }

        let (_, valueWatchers, snapshotWatchers, nextDate) = rawDataAndWatchers

        // Notify watchers outside the lock
        for (_, valueUpdate, watchers) in valueWatchers {
            for watcher in watchers {
                watcher.yield(valueUpdate)
            }
        }
        for watcher in snapshotWatchers.1 {
            watcher.yield(snapshotWatchers.0)
        }

        // Schedule next resolution if needed
        scheduleResolutionTimer(for: nextDate)
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
        let outcome: ([String: Sendable], Date?, Date?) = try storage.withLock { storage in
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
                return (cached, storage.nextResolutionDate, storage.nextResolutionDate)
            }
            
            // Capture the old next resolution date before updating
            let oldNextResolutionDate = storage.nextResolutionDate
            
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
            
            return (resolvedSettings, storage.nextResolutionDate, oldNextResolutionDate)
        }
        // Schedule timer outside lock only if date changed (to avoid scheduling multiple times)
        // Only schedule in non-test environments
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let (_, newDate, oldDate) = outcome
            if newDate != oldDate {
                scheduleResolutionTimer(for: newDate)
            }
        }
        return outcome.0
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

@available(iOS 18.0, *)
extension AppRemoteConfigProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        storage.withLock { $0.snapshot.description }
    }
}

@available(iOS 18.0, *)
extension AppRemoteConfigProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        storage.withLock { $0.snapshot.debugDescription }
    }
}

@available(iOS 18.0, *)
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

@available(iOS 18.0, *)
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
