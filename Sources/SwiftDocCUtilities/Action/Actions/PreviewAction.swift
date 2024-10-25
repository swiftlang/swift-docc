/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

#if canImport(NIOHTTP1)
/// A preview server instance.
var servers: [String: PreviewServer] = [:]

fileprivate func trapSignals() {
    // When the user stops docc - stop the preview server first before exiting.
    Signal.on(Signal.all) { _ in
        // This C function wrapper can't capture context so we print to the standard output.
        print("Stopping preview...")
        do {
            // This will unblock the execution at `server.start()`.
            for server in servers.values {
                try server.stop()
            }
        } catch {
            print(error.localizedDescription)
            exit(1)
        }
    }
}

/// An action that monitors a documentation bundle for changes and runs a live web-preview.
public final class PreviewAction: AsyncAction {
    /// A test configuration allowing running multiple previews for concurrent testing.
    static var allowConcurrentPreviews = false

    private let printHTMLTemplatePath: Bool

    var logHandle = LogHandle.standardOutput
    
    let port: Int
    
    var convertAction: ConvertAction

    private var previewPaths: [String] = []
    
    // Use for testing to override binding to a system port
    var bindServerToSocketPath: String?
    
    /// This closure is used to create a new convert action to generate a new version of the docs
    /// whenever the user changes a file in the watched directory.
    private let createConvertAction: () throws -> ConvertAction
    
    /// A unique ID to access the action's preview server.
    let serverIdentifier = ProcessInfo.processInfo.globallyUniqueString
    
    /// Creates a new preview action from the given parameters.
    ///
    /// - Parameters:
    ///   - port: The port number used by the preview server.
    ///   - createConvertAction: A closure that returns the action used to convert the documentation before preview.
    ///
    ///     On macOS, this action will be recreated each time the source is modified to rebuild the documentation.
    ///   - printTemplatePath: Whether or not the HTML template used by the convert action should be printed when the action
    ///     is performed.
    /// - Throws: If an error is encountered while initializing the documentation context.
    public init(
        port: Int,
        createConvertAction: @escaping () throws -> ConvertAction,
        printTemplatePath: Bool = true
    ) throws {
        if !Self.allowConcurrentPreviews && !servers.isEmpty {
            assertionFailure("Running multiple preview actions is not allowed.")
        }
        
        // Initialize the action context.
        self.port = port
        self.createConvertAction = createConvertAction
        self.convertAction = try createConvertAction()
        self.printHTMLTemplatePath = printTemplatePath
    }
    
    /// Converts a documentation bundle and starts a preview server to render the result of that conversion.
    ///
    /// > Important: On macOS, the bundle will be converted each time the source is modified.
    ///
    /// - Parameter logHandle: The file handle that the convert and preview actions will print debug messages to.
    public func perform(logHandle: inout LogHandle) async throws -> ActionResult {
        self.logHandle = logHandle

        if let rootURL = convertAction.rootURL {
            print("Input: \(rootURL.path)", to: &self.logHandle)
        }
        // TODO: This never did output human readable string; rdar://74324255
        // print("Input: \(convertAction.documentationCoverageOptions)", to: &self.logHandle)

        // In case a developer is using a custom template log its path.
        if printHTMLTemplatePath, let htmlTemplateDirectory = convertAction.htmlTemplateDirectory {
            print("Template: \(htmlTemplateDirectory.path)", to: &self.logHandle)
        }
        
        let previewResult = try await preview()
        return ActionResult(didEncounterError: previewResult.didEncounterError, outputs: [convertAction.targetDirectory])
    }

    /// Stops a currently running preview session.
    func stop() throws {
        monitoredConvertTask?.cancel()
        
        try servers[serverIdentifier]?.stop()
        servers.removeValue(forKey: serverIdentifier)
    }
    
    func preview() async throws -> ActionResult {
        // Convert the documentation source for previewing.
        let result = try await convert()
        guard !result.didEncounterError else {
            return result
        }

        let previewResult: ActionResult
        // Preview the output and monitor the source bundle for changes.
        do {
            print(String(repeating: "=", count: 40), to: &logHandle)
            if let previewURL = URL(string: "http://localhost:\(port)") {
                print("Starting Local Preview Server", to: &logHandle)
                printPreviewAddresses(base: previewURL)
                print(String(repeating: "=", count: 40), to: &logHandle)
            }

            let to: PreviewServer.Bind = bindServerToSocketPath.map { .socket(path: $0) } ?? .localhost(port: port)
            servers[serverIdentifier] = try PreviewServer(contentURL: convertAction.targetDirectory, bindTo: to, logHandle: &logHandle)
            
            // When the user stops docc - stop the preview server first before exiting.
            trapSignals()

            // Monitor the source folder if possible.
            #if !os(Linux) && !os(Android)
            try watch()
            #endif
            // This will wait until the server is manually killed.
            try servers[serverIdentifier]!.start()
            previewResult = ActionResult(didEncounterError: false)
        } catch {
            let diagnosticEngine = convertAction.diagnosticEngine
            diagnosticEngine.emit(.init(description: error.localizedDescription, source: nil))
            diagnosticEngine.flush()
            
            // Stale server entry, remove it from the list
            servers.removeValue(forKey: serverIdentifier)
            previewResult = ActionResult(didEncounterError: true)
        }

        return previewResult
    }
    
    func convert() async throws -> ActionResult {
        convertAction = try createConvertAction()
        let (result, context) = try await convertAction.perform(logHandle: &logHandle)
        
        previewPaths = try context.previewPaths()
        return result
    }
    
    private func printPreviewAddresses(base: URL) {
        // If the preview paths are empty, just print the base.
        let firstPath = previewPaths.first ?? ""
        print("\t Address: \(base.appendingPathComponent(firstPath).absoluteString)", to: &logHandle)
            
        let spacing = String(repeating: " ", count: "Address:".count)
        for previewPath in previewPaths.dropFirst() {
            print("\t \(spacing) \(base.appendingPathComponent(previewPath).absoluteString)", to: &logHandle)
        }
    }
    
    var monitoredConvertTask: Task<Void, Never>?
}

// Monitoring a source folder: Asynchronous output reading and file system events are supported only on macOS.

#if !os(Linux) && !os(Android)
/// If needed, a retained directory monitor.
fileprivate var monitor: DirectoryMonitor! = nil

extension PreviewAction {
    private func watch() throws {
        guard let rootURL = convertAction.rootURL else {
            return
        }

        monitor = try DirectoryMonitor(root: rootURL) { _, _ in
            print("Source bundle was modified, converting... ", terminator: "", to: &self.logHandle)
            self.monitoredConvertTask?.cancel()
            self.monitoredConvertTask = Task {
                defer {
                    // Reload the directory contents and start to monitor for changes.
                    do {
                        try monitor.restart()
                    } catch {
                        // The file watching system API has thrown, stop watching.
                        print("Watching for changes has failed. To continue preview with watching restart docc.", to: &self.logHandle)
                        print(error.localizedDescription, to: &self.logHandle)
                    }
                }
                
                do {
                    let result = try await self.convert()
                    if result.didEncounterError {
                        throw ErrorsEncountered()
                    }
                    print("Done.", to: &self.logHandle)
                } catch DocumentationContext.ContextError.registrationDisabled {
                    // The context cancelled loading the bundles and threw to yield execution early.
                    print("\nConversion cancelled...", to: &self.logHandle)
                } catch is CancellationError {
                    print("\nConversion cancelled...", to: &self.logHandle)
                } catch {
                    print("\n\(error.localizedDescription)\nCompilation failed", to: &self.logHandle)
                }
            }
        }
        try monitor.start()
        print("Monitoring \(rootURL.path) for changes...", to: &self.logHandle)
    }
}
#endif // !os(Linux) && !os(Android)
#endif // canImport(NIOHTTP1)

extension DocumentationContext {
    
    /// A collection of non-implicit root modules
    var renderRootModules: [ResolvedTopicReference] {
        get throws {
            try rootModules.filter({ try !entity(with: $0).isVirtual })
        }
    }
    
    /// Finds the module and tutorial table-of-contents pages in the context and returns their paths.
    func previewPaths() throws -> [String] {
        let urlGenerator = PresentationURLGenerator(context: self, baseURL: URL(string: "/")!)
        
        let rootModules = try renderRootModules
        
        return (rootModules + tutorialTableOfContentsReferences).map { page in
            urlGenerator.presentationURLForReference(page).absoluteString
        }
    }
}
