import AppRemoteConfig
import Dependencies
import DependenciesAdditions
import DependenciesMacros
import Foundation
import Perception

@DependencyClient
public struct AppRemoteConfigClient {
    public var update: () async throws -> Void
    public var values: () -> Values = { Values() }
}

@Perceptible
public class Values {
    public private(set) var updateRequired: Bool = false
    
    func apply(settings: [String: Any]) {
        if let newValue = settings["updateRequired"] as? Bool {
            updateRequired = newValue
        }
    }
}

extension DependencyValues {
    public var configClient: AppRemoteConfigClient {
        get { self[AppRemoteConfigClient.self] }
        set { self[AppRemoteConfigClient.self] = newValue }
    }
}

extension AppRemoteConfigClient: TestDependencyKey {
    public static let testValue = Self()
}

extension AppRemoteConfigClient: DependencyKey {
    public static let liveValue = {
        @Dependency(\.logger["AppRemoteConfigClient"]) var logger
        
        let url = URL(string: "https://www.example.com/config.json")!
        let service = ConfigurationService(url: url)
        logger.debug("Preparing")
        service.prepare()

        let values = Values()
        @Dependency(\.date.now) var now
        resolveAndApply(date: now)
        
        func resolveAndApply(date: Date) {
            logger.debug("Resolving settings for date \(date, privacy: .public)")
            let settings = service.resolve(date: date)
            logger.debug("Applying settings \(settings)")
            values.apply(settings: settings)
            if let nextDate = service.nextResolutionDate(after: date) {
                logger.debug("Next resolve on date \(nextDate, privacy: .public)")
                DispatchQueue.main.asyncAfter(deadline: .now() + nextDate.timeIntervalSinceNow) {
                    resolveAndApply(date: nextDate)
                }
            } else {
                logger.debug("No next resolve needed")
            }
        }
        
        return Self(
            update: {
                logger.debug("Updating")
                do {
                    try await service.update()
                } catch {
                    logger.error("Updating failed \(error)")
                    throw error
                }
                resolveAndApply(date: now)
            },
            values: {
                values
            }
        )
    }()
}
