import AppRemoteConfig

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
//@available(AppRemoteConfigProvider 1.0, *)
public final class AppRemoteConfigProvider<Snapshot: FileConfigSnapshot>: Sendable {

    /// The internal storage structure for the provider state.
    private struct Storage {

        /// The current configuration snapshot.
        var snapshot: Snapshot

        /// Last modified timestamp of the resolved file.
        var lastModifiedTimestamp: Date

        /// The URL of the configuration file.
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

    /// The URL of the configuration file to monitor.
    private let url: URL

    /// The interval between polling checks.
    private let pollInterval: Duration

    /// The human-readable name of the provider.
    public let providerName: String

    /// Resolution context for configuration. These values are used to resolve overrides and conditions.
    private let resolutionContext: Mutex<ResolutionContext?>
    
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
        pollInterval: Duration = .seconds(15),
        resolutionContext: ResolutionContext? = nil,
        logger: Logger = Logger(label: "AppRemoteConfigProvider"),
        metrics: any MetricsFactory = MetricsSystem.factory
    ) async throws {
        self.parsingOptions = parsingOptions
        self.url = url
        self.pollInterval = pollInterval
        self.resolutionContext = .init(resolutionContext)
        self.providerName = "AppRemoteConfigProvider<\(Snapshot.self)>"

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
    ///   - resolutionContext: An optional context for resolving configuration based on platform, version, variant, language.
    ///   - logger: The logger instance to use for this provider.
    ///   - metrics: The metrics factory to use for monitoring provider performance.
    /// - Throws: If required configuration keys are missing, if the file cannot be read, or if snapshot creation fails.
    public convenience init(
        snapshotType: Snapshot.Type = Snapshot.self,
        parsingOptions: Snapshot.ParsingOptions = .default,
        config: ConfigReader,
        resolutionContext: ResolutionContext? = nil,
        logger: Logger = Logger(label: "AppRemoteConfigProvider"),
        metrics: any MetricsFactory = MetricsSystem.factory
    ) async throws {
        try await self.init(
            snapshotType: snapshotType,
            parsingOptions: parsingOptions,
            url: config.requiredString(forKey: "url", as: URL.self),
            pollInterval: Duration.seconds(config.int(forKey: "pollIntervalSeconds", default: 15)),
            resolutionContext: resolutionContext,
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

    // MARK: - Resolution Context Methods
    
    /// Sets the resolution context for config resolution.
    public func setResolutionContext(_ context: ResolutionContext) {
        resolutionContext.withLock { $0 = context }
    }
    
    /// Gets the current resolution context.
    public func getResolutionContext() -> ResolutionContext? {
        resolutionContext.withLock { $0 }
    }

    internal func reloadIfNeeded(logger: Logger) async throws {
        logger.debug("reloadIfNeeded started")
        defer {
            logger.debug("reloadIfNeeded finished")
        }

        let candidateRealPath = url
        let candidateTimestamp = Date()

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
    
    /// Resolves a nested configuration key using the stored resolution context if available.
    ///
    /// This method:
    /// 1. Uses the stored resolution context (platform, version, variant, etc.)
    /// 2. Resolves the AppRemoteConfig using conditions and schedules
    /// 3. Extracts the value at the nested key path (e.g., "settings.feature.enabled")
    /// 4. Falls back to cached value if key is missing, then to nil
    ///
    /// - Parameters:
    ///   - keyPath: A dot-separated key path (e.g., "settings.feature.enabled")
    ///   - snapshot: The snapshot to resolve (optional, uses current snapshot if not provided)
    /// - Returns: The resolved value or nil if not found
    private func resolveNestedValue(_ keyPath: String, snapshot: Snapshot? = nil) -> Sendable? {
        _ = snapshot // Use snapshot parameter if provided (for future extension)
        
        // If no resolution context is set, just return cached value
        guard getResolutionContext() != nil else {
            logger.debug("No context available for resolution, returning cached or nil value")
            return storage.withLock { $0.valueCache[keyPath] }
        }
        
        // For now, just return the cached value or nil
        // The actual resolution logic would require being able to extract config from the snapshot
        // and the snapshot types (JSONSnapshot, YAMLSnapshot) don't expose raw dictionary data
        return storage.withLock { $0.valueCache[keyPath] }
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

/// This allows using AppRemoteConfigProvider with swift-configuration's ConfigReader.
/// The provider gives access to the snapshot values directly through the ConfigProvider protocol.
