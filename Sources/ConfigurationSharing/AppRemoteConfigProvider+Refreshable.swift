import AppRemoteConfigProvider

/// Extend AppRemoteConfigProvider to conform to the Refreshable protocol,
/// allowing it to be explicitly refreshed when requested.
extension AppRemoteConfigProvider: Refreshable {
    // Already has a public refresh() async throws method,
    // so it automatically conforms to the Refreshable protocol
}
