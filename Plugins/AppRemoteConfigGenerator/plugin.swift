import PackagePlugin
import Foundation

@main struct AppRemoteConfigGeneratorPlugin {
    func createBuildCommands(
        pluginWorkDirectory: Path,
        tool: (String) throws -> PluginContext.Tool,
        sourceFiles: FileList,
        targetName: String
    ) throws -> [Command] {
        let inputs = try PluginUtils.validateInputs(
            workingDirectory: pluginWorkDirectory,
            tool: tool,
            sourceFiles: sourceFiles,
            targetName: targetName,
            pluginSource: .build
        )

        let outputFiles: [Path] = GeneratorMode.allCases.map { inputs.genSourcesDir.appending($0.outputFileName) }
        return [
            .buildCommand(
                displayName: "Running app-remote-config-generator",
                executable: inputs.tool.path,
                arguments: inputs.arguments,
                environment: [:],
                inputFiles: [inputs.config, inputs.doc],
                outputFiles: outputFiles
            )
        ]
    }
}

extension AppRemoteConfigGeneratorPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let swiftTarget = target as? SwiftSourceModuleTarget else {
            throw PluginError.incompatibleTarget(name: target.name)
        }
        return try createBuildCommands(
            pluginWorkDirectory: context.pluginWorkDirectory,
            tool: context.tool,
            sourceFiles: swiftTarget.sourceFiles,
            targetName: target.name
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension AppRemoteConfigGeneratorPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        try createBuildCommands(
            pluginWorkDirectory: context.pluginWorkDirectory,
            tool: context.tool,
            sourceFiles: target.inputFiles,
            targetName: target.displayName
        )
    }
}
#endif
