import ArgumentParser
import Foundation

@main
struct Care: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Configure apps remotely.",
        discussion: """
        A simple but effective way to manage apps remotely.
        
        Create a simple configuration file that is easy to maintain and host, yet provides important flexibility to specify settings based on your needs.
        """,
        version: "0.6.0",
        subcommands: [Init.self, CreateKeyPair.self, Verify.self, Resolve.self, Prepare.self])
}
