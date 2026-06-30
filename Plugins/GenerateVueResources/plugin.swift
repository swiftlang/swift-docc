/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackagePlugin

/// A build tool plugin that generates `VueApp.generated.swift` from the compiled
/// Vue assets in `Sources/DocCHTMLVue/dist/`.
///
/// The generated file is placed in the plugin's work directory (inside `.build/`)
/// and is never committed to source control. If the `dist/` folder is absent,
/// the `GenerateVueResourcesTool` executable will exit with a clear error asking
/// the developer to run `bin/build-vue-app` first.
@main
struct GenerateVueResources: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let distDir = context.package.directory
            .appending(subpath: "Sources/DocCHTMLVue/dist")

        let jsInput  = distDir.appending(subpath: "app.js")
        let cssInput = distDir.appending(subpath: "app.css")

        // Use a build command to generate Swift source files from the Vue dist assets.
        // buildCommand can use executable targets built from source, unlike prebuildCommand.
        // All Swift files written into pluginWorkDirectory are automatically
        // picked up as generated sources for the target.
        let outputFile = context.pluginWorkDirectory.appending(subpath: "VueApp.generated.swift")
        
        return [
            .buildCommand(
                displayName: "Generating Vue app Swift resources",
                executable: try context.tool(named: "GenerateVueResourcesTool").path,
                arguments: [
                    jsInput,
                    cssInput,
                    outputFile,
                ],
                inputFiles: [
                    jsInput,
                    cssInput,
                ],
                outputFiles: [
                    outputFile
                ]
            )
        ]
    }
}
