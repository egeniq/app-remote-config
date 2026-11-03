import ArgumentParser
import Foundation

#if !Crypto
#error("care requires the Crypto trait")
#endif

@main
struct Care: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Configure apps remotely.",
        discussion: """
        A simple but effective way to manage apps remotely.
        
        Create a simple configuration file that is easy to maintain and host, yet provides important flexibility to specify settings based on your needs.
        """,
        version: "0.8.3",
        subcommands: [Init.self, CreateKeyPair.self, Verify.self, Resolve.self, Prepare.self])
}
