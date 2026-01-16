//#if ReloadingSupport
import AppRemoteConfig

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public import SystemPackage
public import ServiceLifecycle
public import Logging
public import Metrics
import AsyncAlgorithms
import Synchronization
import Configuration

/// A configuration provider that reads configuration from an URL with automatic resolving and reloading capability.
///
/// `AppRemoteConfigProvider` is a generic URL-based configuration provider that monitors
/// a configuration URL for changes and automatically reloads the data periodically and when
/// changes are scheduled. This provider works with different file formats by using
/// different snapshot types that conform to ``FileRemoteConfigSnapshot``.
///
/// ## Swift-Configuration Integration
///
/// `AppRemoteConfigProvider` conforms to swift-configuration's `Provider` protocol, allowing
/// it to be used directly with `ConfigReader`. It resolves configuration values based on
/// context provided by another `Provider` (platform, version, variant, language).
///
/// ```swift
/// // Create a context provider with environment values
/// let contextProvider = InMemoryProvider(values: [
///     "platform.name": "iOS",
///     "platform.version": "17.0.0",
///     "app.version": "1.2.0",
///     "app.buildVariant": "debug",
/// ])
///
/// // Create the remote config provider with context support
/// let configProvider = try await AppRemoteConfigProvider<JSONSnapshot>(
///     url: URL(string: "https://example.com/config.json")!,
///     contextProvider: contextProvider
/// )
///
/// // Use with ConfigReader
/// let reader = ConfigReader(provider: configProvider)
/// let featureEnabled = reader.bool(forKey: "settings.features.newUI", default: false)
/// ```
///
/// ## Key Path Format
///
/// Configuration keys use dot-separated nested paths:
/// - `"settings.feature.enabled"` maps to `config.settings["feature"]["enabled"]`
/// - Intermediate keys must be dictionaries for the path to resolve
/// - Missing intermediate keys return nil, falling back to cached values
///
/// ## Usage
///
/// Create a remote config provider by specifying the snapshot type and URL:
///
/// ```swift
/// // Using with a JSON snapshot and a custom poll interval
/// let jsonProvider = try await AppRemoteConfigProvider<JSONSnapshot>(
///     url: "https://www.example.com/config.json",
///     minimumRefreshInterval: .seconds(30)
/// )
///
/// // Using with a YAML snapshot
/// let yamlProvider = try await AppRemoteConfigProvider<YAMLSnapshot>(
///     url: "https://www.example.com/config.yaml",
///     minimumRefreshInterval: .seconds(30)
/// )
/// ```
///
/// ## Service integration
///
/// This provider implements the `Service` protocol and must be run within a `ServiceGroup`
/// to enable automatic reloading:
///
/// ```swift
/// let environmentProvider = InMemoryProvider(values: [
///     "app.version": "1.0",
///     "app.variant": "custom1",
///     "app.buildVariant": "debug",
///     "app.language": "en",
///     "platform.name": "iOS",
///     "platform.version": "26.1",
/// ])
/// let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
///     url: "https://www.example.com/config.json",
///     contextProvider: environmentProvider
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
//@available(AppRemoteConfigProvider 1.0, *)
public final class AppRemoteConfigProvider<Snapshot: FileConfigSnapshot>: Sendable {

    /// The internal storage structure for the provider state.
    private struct Storage {

        /// The current configuration snapshot.
        var snapshot: Snapshot

        /// Last modified timestamp of the resolved file.
        var lastModifiedTimestamp: Date

//        /// The resolved real file path.
//        var realFilePath: FilePath
        var url: URL

        /// Active watchers for individual configuration values, keyed by encoded key.
        var valueWatchers: [AbsoluteConfigKey: [UUID: AsyncStream<Result<LookupResult, any Error>>.Continuation]]

        /// Active watchers for configuration snapshots.
        var snapshotWatchers: [UUID: AsyncStream<Snapshot>.Continuation]

        /// Cache of last-known-good resolved values per key.
        var valueCache: [String: Sendable] = [:]

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

//    /// The file system interface for reading files and timestamps.
//    private let fileSystem: any CommonProviderFileSystem

    /// The original unresolved file path provided by the user, may contain symlinks.
    private let url: URL

    /// The interval between polling checks.
    private let pollInterval: Duration

    /// The human-readable name of the provider.
    public let providerName: String

    /// The optional context provider for reading resolution context (platform, version, variant, language).
    private let contextProvider: (any Provider)?
/*
//    environmentProvider
    public let platform: Platform //{
//    public private(set) var platform: Platform //{
//        didSet {
//            reloadIfNeeded(logger: logger)
//        }
//    }
    public let platformVersion: OperatingSystemVersion //{
//    public private(set) var platformVersion: OperatingSystemVersion //{
//        didSet {
//            reloadIfNeeded(logger: logger)
//        }
//    }
    public let appVersion: Version //{
//    public private(set) var appVersion: Version //{
//        didSet {
//            reloadIfNeeded(logger: logger)
//        }
//    }
    public let variant: String? = nil //{
//    public private(set) var variant: String? = nil //{
//        didSet {
//            reloadIfNeeded(logger: logger)
//        }
//    }
    public let buildVariant: BuildVariant // {
//    public private(set) var buildVariant: BuildVariant // {
//        didSet {
//            reloadIfNeeded(logger: logger)
//        }
//    }
    public let language: String? = nil //{
//    public private(set) var language: String? = nil //{
//        didSet {
//            reloadIfNeeded(logger: logger)
//        }
//    }
    
    public func update(
        platform: Platform,
        platformVersion: OperatingSystemVersion,
        appVersion: Version,
        variant: String? = nil,
        buildVariant: BuildVariant,
        language: String? = nil
    ) {
        // Not Sendable...
//        self.platform = platform
//        self.platformVersion = platformVersion
//        self.appVersion = appVersion
//        self.variant = variant
//        self.buildVariant = buildVariant
//        self.language = language
        
        Task {
            try? await reloadIfNeeded(logger: logger)
        }
    }
  */
    
    /// The logger for this provider instance.
    private let logger: Logger

    /// The metrics collector for this provider instance.
    private let metrics: AppRemoteConfigProviderMetrics

    internal init(
        snapshotType: Snapshot.Type = Snapshot.self,
        parsingOptions: Snapshot.ParsingOptions,
        url: URL,
        pollInterval: Duration,
        contextProvider: (any Provider)? = nil,
//        fileSystem: any CommonProviderFileSystem,
        logger: Logger,
        metrics: any MetricsFactory
    ) async throws {
        self.parsingOptions = parsingOptions
        self.url = url
        self.pollInterval = pollInterval
        self.contextProvider = contextProvider
        self.providerName = "AppRemoteConfigProvider<\(Snapshot.self)>"
//        self.fileSystem = fileSystem

        // Set up the logger with metadata
        var logger = logger
        logger[metadataKey: "\(providerName).url"] = .string(url.absoluteString)
        logger[metadataKey: "\(providerName).pollInterval.seconds"] = .string(
            pollInterval.components.seconds.description
        )
        self.logger = logger

        // Set up metrics
        self.metrics = AppRemoteConfigProviderMetrics(
            factory: metrics,
            providerName: providerName
        )

        // Perform initial load
        logger.debug("Performing initial file load")
//        let realPath = try await fileSystem.resolveSymlinks(atPath: filePath)
//        let timestamp = try await fileSystem.lastModifiedTimestamp(atPath: realPath)
//        let data = try await fileSystem.fileContents(atPath: realPath)
        let timestamp = Date()
        let data = try Data(contentsOf: url)
        let initialSnapshot = try snapshotType.init(
            data: data.bytes,
            providerName: providerName,
            parsingOptions: parsingOptions
        )

        // Initialize storage
        self.storage = .init(
            .init(
                snapshot: initialSnapshot,
                lastModifiedTimestamp: timestamp,
                url: url,
//                realFilePath: realPath,
                valueWatchers: [:],
                snapshotWatchers: [:]
            )
        )

        // Update initial metrics
        self.metrics.fileSize.record(data.count)

        logger.debug(
            "Successfully initialized reloading app remote config provider",
            metadata: [
                "\(providerName).url": .string(url.absoluteString),
                "\(providerName).initialTimestamp": .stringConvertible(timestamp.formatted(.iso8601)),
                "\(providerName).fileSize": .stringConvertible(data.count),
            ]
        )
    }

    /// Creates a reloading file provider that monitors the specified URL.
    ///
    /// - Parameters:
    ///   - snapshotType: The type of snapshot to create from the file contents.
    ///   - parsingOptions: Options used by the snapshot to parse the file data.
    ///   - url: The URL to the configuration file to monitor.
    ///   - pollInterval: How often to check for file changes.
    ///   - contextProvider: An optional provider for reading resolution context values (platform, version, variant, language).
    ///   - logger: The logger instance to use for this provider.
    ///   - metrics: The metrics factory to use for monitoring provider performance.
    /// - Throws: If the file cannot be read or if snapshot creation fails.
    public convenience init(
        snapshotType: Snapshot.Type = Snapshot.self,
        parsingOptions: Snapshot.ParsingOptions = .default,
        url: URL,
        pollInterval: Duration = .seconds(15),
        contextProvider: (any Provider)? = nil,
        logger: Logger = Logger(label: "AppRemoteConfigProvider"),
        metrics: any MetricsFactory = MetricsSystem.factory
    ) async throws {
        try await self.init(
            snapshotType: snapshotType,
            parsingOptions: parsingOptions,
            url: url,
            pollInterval: pollInterval,
            contextProvider: contextProvider,
            logger: logger,
            metrics: metrics
        )
    }

    /// Creates a reloading file provider using configuration from a reader.
    ///
    /// ## Configuration keys
    /// - `url` (string, required): The URL to the configuration file to monitor.
    /// - `publicKey` (string, optional): The public key with which the configuration file is signed.
    /// - `minimumRefreshIntervalSeconds` (int, optional, default: 15): How often to check for file changes in seconds.
    /// - `automaticRefreshIntervalSeconds` (int, optional, default: 15): How often to check for file changes in seconds.
    ///
    /// - Parameters:
    ///   - snapshotType: The type of snapshot to create from the file contents.
    ///   - parsingOptions: Options used by the snapshot to parse the file data.
    ///   - config: A configuration reader that contains the required configuration keys.
    ///   - contextProvider: An optional provider for reading resolution context values (platform, version, variant, language).
    ///   - logger: The logger instance to use for this provider.
    ///   - metrics: The metrics factory to use for monitoring provider performance.
    /// - Throws: If required configuration keys are missing, if the file cannot be read, or if snapshot creation fails.
    public convenience init(
        snapshotType: Snapshot.Type = Snapshot.self,
        parsingOptions: Snapshot.ParsingOptions = .default,
        config: ConfigReader,
        contextProvider: (any Provider)? = nil,
        logger: Logger = Logger(label: "AppRemoteConfigProvider"),
        metrics: any MetricsFactory = MetricsSystem.factory
    ) async throws {
        try await self.init(
            snapshotType: snapshotType,
            parsingOptions: parsingOptions,
            url: config.requiredString(forKey: "url", as: URL.self),
            pollInterval: .seconds(config.int(forKey: "pollIntervalSeconds", default: 15)),
            contextProvider: contextProvider,
//            fileSystem: LocalCommonProviderFileSystem(),
            logger: logger,
            metrics: metrics
        )
    }

    /// Checks if the file has changed and reloads it if necessary.
    ///
    /// This method performs the core file monitoring logic by checking both the file's
    /// last modified timestamp and its resolved path (in case of symlinks). If changes
    /// are detected, it reloads the file contents, creates a new snapshot, and notifies
    /// any active watchers of the changes.
    ///
    /// - Parameter logger: The logger to use during the reload operation.
    /// - Throws: File system errors or snapshot creation errors.
    
    // MARK: - Context Reading Methods
    
    /// Reads the current resolution context from the context provider.
    ///
    /// - Returns: A tuple containing (platform, platformVersion, appVersion, variant, buildVariant, language), or nil if contextProvider is not set.
    /// - Throws: If reading from the context provider fails.
    private func readResolutionContext() async throws -> (platform: Platform, platformVersion: OperatingSystemVersion, appVersion: Version, variant: String?, buildVariant: BuildVariant, language: String?)? {
        guard let contextProvider = contextProvider else {
            return nil
        }
        
        do {
            let platformStr = try contextProvider.value(forKey: "platform.name") as? String
            let platformVersionStr = try contextProvider.value(forKey: "platform.version") as? String
            let appVersionStr = try contextProvider.value(forKey: "app.version") as? String
            let variant = try contextProvider.value(forKey: "app.variant") as? String
            let buildVariantStr = try contextProvider.value(forKey: "app.buildVariant") as? String
            let language = try contextProvider.value(forKey: "app.language") as? String
            
            guard let platformStr = platformStr,
                  let platform = Platform(rawValue: platformStr),
                  let platformVersionStr = platformVersionStr,
                  let appVersionStr = appVersionStr,
                  let appVersion = try? Version(appVersionStr),
                  let buildVariantStr = buildVariantStr,
                  let buildVariant = BuildVariant(rawValue: buildVariantStr) else {
                logger.warning("Failed to parse resolution context from provider")
                return nil
            }
            
            let platformVersion = parseOperatingSystemVersion(platformVersionStr)
            
            return (platform, platformVersion, appVersion, variant, buildVariant, language)
        } catch {
            logger.warning("Failed to read resolution context from provider", metadata: ["error": "\(error)"])
            return nil
        }
    }
    
    /// Parses a version string into an OperatingSystemVersion.
    ///
    /// - Parameter versionString: A version string in format "major.minor.patch"
    /// - Returns: The parsed OperatingSystemVersion
    private func parseOperatingSystemVersion(_ versionString: String) -> OperatingSystemVersion {
        let components = versionString.split(separator: ".").compactMap { Int($0) }
        if components.count >= 3 {
            return OperatingSystemVersion(majorVersion: components[0], minorVersion: components[1], patchVersion: components[2])
        } else if components.count >= 2 {
            return OperatingSystemVersion(majorVersion: components[0], minorVersion: components[1], patchVersion: 0)
        } else if components.count >= 1 {
            return OperatingSystemVersion(majorVersion: components[0], minorVersion: 0, patchVersion: 0)
        }
        return OperatingSystemVersion(majorVersion: 0, minorVersion: 0, patchVersion: 0)
    }
    
    /// Extracts a value from a nested dictionary using a dot-separated key path.
    ///
    /// - Parameters:
    ///   - keyPath: A dot-separated key path (e.g., "settings.feature.enabled")
    ///   - dictionary: The dictionary to search
    /// - Returns: The value at the key path, or nil if not found
    private func extractNestedValue(_ keyPath: String, from dictionary: [String: Sendable]) -> Sendable? {
        let components = keyPath.split(separator: ".", omittingEmptySubsequences: true).map(String.init)
        
        var current: Sendable? = dictionary
        for component in components {
            guard let dict = current as? [String: Sendable] else {
                return nil
            }
            current = dict[component]
        }
        return current
    }

    internal func reloadIfNeeded(logger: Logger) async throws {
        logger.debug("reloadIfNeeded started")
        defer {
            logger.debug("reloadIfNeeded finished")
        }

        let candidateRealPath = url // try await fileSystem.resolveSymlinks(atPath: filePath)
        let candidateTimestamp = Date() // fileSystem.lastModifiedTimestamp(atPath: candidateRealPath)

        guard
            let (originalTimestamp, originalRealPath) =
                storage
                .withLock({ storage -> (Date, URL)? in
                    let originalTimestamp = storage.lastModifiedTimestamp
                    let originalRealPath = storage.url

                    // Check if either the real path or timestamp has changed
                    guard originalRealPath != candidateRealPath || originalTimestamp != candidateTimestamp else {
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
        let data = try Data(contentsOf: url) // fileSystem.fileContents(atPath: candidateRealPath)
        let newSnapshot = try Snapshot.init(
            data: data.bytes,
            providerName: providerName,
            parsingOptions: parsingOptions
        )

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
                    let oldSnapshot = storage.snapshot
                    storage.snapshot = newSnapshot
                    storage.lastModifiedTimestamp = candidateTimestamp
                    storage.url = candidateRealPath

                    logger.debug(
                        "Successfully reloaded file",
                        metadata: [
                            "\(providerName).timestamp": .stringConvertible(candidateTimestamp.formatted(.iso8601)),
                            "\(providerName).fileSize": .stringConvertible(data.count),
                            "\(providerName).realPath": .string(candidateRealPath.absoluteString),
                        ]
                    )

                    // Update metrics
                    metrics.reloadCounter.increment(by: 1)
                    metrics.fileSize.record(data.count)
                    metrics.watcherCount.record(storage.totalWatcherCount)

                    // Collect watchers to potentially notify outside the lock
                    let valueWatchers = storage.valueWatchers.compactMap {
                        (key, watchers) -> (
                            AbsoluteConfigKey,
                            Result<LookupResult, any Error>,
                            [AsyncStream<Result<LookupResult, any Error>>.Continuation]
                        )? in
                        guard !watchers.isEmpty else { return nil }

                        // Get old and new values for this key
                        let oldValue = Result { try oldSnapshot.value(forKey: key, type: .string) }
                        let newValue = Result { try newSnapshot.value(forKey: key, type: .string) }

                        let didChange =
                            switch (oldValue, newValue) {
                            case (.success(let lhs), .success(let rhs)):
                                lhs != rhs
                            case (.failure, .failure):
                                false
                            default:
                                true
                            }

                        // Only notify if the value changed
                        guard didChange else {
                            return nil
                        }
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
}

//@available(AppRemoteConfigProvider 1.0, *)
extension AppRemoteConfigProvider: CustomStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var description: String {
        storage.withLock { $0.snapshot.description }
    }
}

//@available(AppRemoteConfigProvider 1.0, *)
extension AppRemoteConfigProvider: CustomDebugStringConvertible {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public var debugDescription: String {
        storage.withLock { $0.snapshot.debugDescription }
    }
}

//@available(AppRemoteConfigProvider 1.0, *)
extension AppRemoteConfigProvider: ConfigProvider {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    
    /// Resolves a nested configuration key using the context provider if available.
    ///
    /// This method:
    /// 1. Reads the current resolution context from the context provider (if set)
    /// 2. Resolves the AppRemoteConfig using conditions and schedules
    /// 3. Extracts the value at the nested key path (e.g., "settings.feature.enabled")
    /// 4. Falls back to cached value if key is missing, then to nil
    ///
    /// - Parameters:
    ///   - keyPath: A dot-separated key path (e.g., "settings.feature.enabled")
    ///   - snapshot: The snapshot to resolve (optional, uses current snapshot if not provided)
    /// - Returns: The resolved value or nil if not found
    private func resolveNestedValue(_ keyPath: String, snapshot: Snapshot? = nil) async -> Sendable? {
        let targetSnapshot = snapshot ?? storage.withLock { $0.snapshot }
        
        guard let context = try? await readResolutionContext() else {
            logger.debug("No context available for resolution, returning cached or nil value")
            return storage.withLock { $0.valueCache[keyPath] }
        }
        
        do {
            // Get the raw config from snapshot
            let rawConfig = try targetSnapshot.value(forKey: AbsoluteConfigKey(""), type: .dictionary) as? [String: Sendable] ?? [:]
            
            // Parse config to resolve overrides
            guard let configData = try targetSnapshot.value(forKey: AbsoluteConfigKey(""), type: .dictionary) as? [String: Sendable] else {
                return storage.withLock { $0.valueCache[keyPath] }
            }
            
            // For now, we need to create a Config from the snapshot data
            // This is a simplified approach - you may need to extract this differently
            let appConfig = try Config(json: configData)
            let resolvedSettings = appConfig.resolve(
                date: Date(),
                platform: context.platform,
                platformVersion: context.platformVersion,
                appVersion: context.appVersion,
                variant: context.variant,
                buildVariant: context.buildVariant,
                language: context.language
            )
            
            if let value = extractNestedValue(keyPath, from: resolvedSettings) {
                storage.withLock { storage in
                    storage.valueCache[keyPath] = value
                }
                return value
            }
            
            // Fall back to cache
            return storage.withLock { $0.valueCache[keyPath] }
        } catch {
            logger.warning("Failed to resolve nested value", metadata: ["keyPath": "\(keyPath)", "error": "\(error)"])
            return storage.withLock { $0.valueCache[keyPath] }
        }
    }
    
    public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
        try storage.withLock { storage in
            try storage.snapshot.value(forKey: key, type: type)
        }
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func fetchValue(
        forKey key: AbsoluteConfigKey,
        type: ConfigType
    ) async throws -> LookupResult {
        try await reloadIfNeeded(logger: logger)
        return try value(forKey: key, type: type)
    }

    public func watchValue<Return>(
        forKey key: Configuration.AbsoluteConfigKey,
        type: Configuration.ConfigType,
        updatesHandler: nonisolated(nonsending) (Configuration.ConfigUpdatesAsyncSequence<Result<Configuration.LookupResult, any Error>, Never>) async throws -> Return
    ) async throws -> Return where Return : ~Copyable {
        //        code
//    }
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
//    public func watchValue<Return>(
//        forKey key: AbsoluteConfigKey,
//        type: ConfigType,
//        updatesHandler: (ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>) async throws -> Return
//    ) async throws -> Return {
        let (stream, continuation) = AsyncStream<Result<LookupResult, any Error>>
            .makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()

        // Add watcher and get initial value
        let initialValue: Result<LookupResult, any Error> = storage.withLock { storage in
            storage.valueWatchers[key, default: [:]][id] = continuation
            metrics.watcherCount.record(storage.totalWatcherCount)
            return .init {
                try storage.snapshot.value(forKey: key, type: type)
            }
        }
        defer {
            storage.withLock { storage in
                storage.valueWatchers[key, default: [:]][id] = nil
                metrics.watcherCount.record(storage.totalWatcherCount)
            }
        }

        // Send initial value
        continuation.yield(initialValue)
        return try await updatesHandler(.init(stream))
    }

    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func snapshot() -> any ConfigSnapshot {
        storage.withLock { $0.snapshot }
    }

    public func watchSnapshot<Return>(updatesHandler: nonisolated(nonsending) (Configuration.ConfigUpdatesAsyncSequence<any Configuration.ConfigSnapshot, Never>) async throws -> Return) async throws -> Return where Return : ~Copyable {
        
//    }
//    
//    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
//    public func watchSnapshot<Return>(
//        updatesHandler: (ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return
//    ) async throws -> Return {
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

//@available(AppRemoteConfigProvider 1.0, *)
extension AppRemoteConfigProvider: Service {
    // swift-format-ignore: AllPublicDeclarationsHaveDocumentation
    public func run() async throws {
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
                try await reloadIfNeeded(logger: tickLogger)
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

// MARK: - Configuration Provider Conformance

/// Extension that makes AppRemoteConfigProvider conform to swift-configuration's Provider protocol.
/// This allows using AppRemoteConfigProvider with swift-configuration's ConfigReader.
extension AppRemoteConfigProvider: Provider {
    /// Retrieves a configuration value using nested key path resolution.
    ///
    /// The key should be a dot-separated path (e.g., "settings.feature.enabled").
    /// If a context provider is available, resolves the config based on platform, version, and variant.
    /// Falls back to cached values if the key is not found in the resolved config.
    ///
    /// - Parameter key: The configuration key using dot-separated nested path format
    /// - Returns: The configuration value, or nil if not found
    public func value(forKey key: String) -> Any? {
        Task {
            await resolveNestedValue(key)
        }
        
        // For synchronous access, return cached value
        return storage.withLock { $0.valueCache[key] }
    }
    
    /// Watches a configuration value for changes with support for scheduled resolution updates.
    ///
    /// This method sets up a watcher that:
    /// 1. Returns the current resolved value immediately
    /// 2. Re-resolves when the remote config snapshot changes
    /// 3. Re-resolves when context values change (platform, version, etc.)
    /// 4. Automatically re-resolves at scheduled times when overrides activate/deactivate
    ///
    /// - Parameters:
    ///   - key: The configuration key using dot-separated nested path format
    ///   - updatesHandler: Async closure called with an async sequence of value updates
    /// - Returns: The result of the updatesHandler
    /// - Throws: If reading from the provider fails or the updatesHandler throws
    public func watch<Return>(
        forKey key: String,
        updatesHandler: (AsyncStream<Any?>) async throws -> Return
    ) async throws -> Return where Return: ~Copyable {
        let (stream, continuation) = AsyncStream<Any?>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let watcherId = UUID()
        
        // Send initial value
        let initialValue = await resolveNestedValue(key)
        continuation.yield(initialValue)
        
        // Set up watchers to monitor both snapshot and context changes
        // We'll use the existing snapshot watcher infrastructure and add a scheduled timer handler
        
        let scheduleTimerTaskId = UUID()
        
        // Create an async task that handles scheduled updates
        let timerTask = Task {
            while !Task.isCancelled {
                do {
                    // Get current context to determine next resolution date
                    guard let context = try? await readResolutionContext() else {
                        try await Task.sleep(for: .seconds(60)) // Check again in a minute if no context
                        continue
                    }
                    
                    let appConfig = try storage.withLock { storage in
                        let configDict = try storage.snapshot.value(forKey: AbsoluteConfigKey(""), type: .dictionary) as? [String: Sendable] ?? [:]
                        return try Config(json: configDict)
                    }
                    
                    let relevantDates = appConfig.relevantResolutionDates(
                        platform: context.platform,
                        platformVersion: context.platformVersion,
                        appVersion: context.appVersion,
                        variant: context.variant,
                        buildVariant: context.buildVariant,
                        language: context.language
                    )
                    
                    // Find the next relevant date
                    let now = Date()
                    if let nextDate = relevantDates.first(where: { $0 > now }) {
                        let timeUntilNext = nextDate.timeIntervalSince(now)
                        logger.debug("Scheduling resolution update", metadata: [
                            "\(providerName).nextResolutionDate": .stringConvertible(nextDate.formatted(.iso8601)),
                            "\(providerName).secondsUntilNext": .stringConvertible(Int(timeUntilNext))
                        ])
                        
                        try await Task.sleep(for: .seconds(Int(timeUntilNext)))
                        
                        // Re-resolve and notify if value changed
                        let newValue = await resolveNestedValue(key)
                        continuation.yield(newValue)
                    } else {
                        // No more relevant dates, sleep for a while and check again
                        try await Task.sleep(for: .minutes(5))
                    }
                } catch {
                    if !Task.isCancelled {
                        logger.warning("Error in scheduled resolution watcher", metadata: ["error": "\(error)"])
                        try? await Task.sleep(for: .seconds(10))
                    }
                }
            }
        }
        
        // Store the timer task so it can be cleaned up later
        storage.withLock { storage in
            storage.scheduledTimers[scheduleTimerTaskId] = timerTask
        }
        
        defer {
            // Clean up timer task
            timerTask.cancel()
            storage.withLock { storage in
                storage.scheduledTimers.removeValue(forKey: scheduleTimerTaskId)
            }
        }
        
        // Watch snapshot changes
        do {
            return try await watchSnapshot { updates in
                // For each snapshot update, re-resolve the value
                var lastValue = initialValue
                
                for await _ in updates {
                    let newValue = await resolveNestedValue(key)
                    if !valuesEqual(lastValue, newValue) {
                        continuation.yield(newValue)
                        lastValue = newValue
                    }
                }
                
                return try await updatesHandler(stream)
            }
        } catch {
            logger.warning("Snapshot watcher failed", metadata: ["error": "\(error)"])
            return try await updatesHandler(stream)
        }
    }
    
    /// Compares two Any? values for equality (used for change detection in watchers).
    private func valuesEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (lhs as String, rhs as String):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as [String: Sendable], rhs as [String: Sendable]):
            return NSDictionary(dictionary: lhs) == NSDictionary(dictionary: rhs)
        default:
            return false
        }
    }
}

//@available(AppRemoteConfigProvider 1.0, *)
extension AppRemoteConfigProvider: Service {

//#endif
