/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

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
public final class PreviewAction: Action, RecreatingContext {
    /// A test configuration allowing running multiple previews for concurrent testing.
    static var allowConcurrentPreviews = false

    enum Error: DescribedError {
        case technologyNotFound, cannotConvert
        var errorDescription: String {
            switch self {
                case .technologyNotFound: return "A technology page not found in context."
                case .cannotConvert: return "Unable to run documentation conversion."
            }
        }
    }

    private let context: DocumentationContext
    private let workspace: DocumentationWorkspace    
    private let printHTMLTemplatePath: Bool

    var logHandle = LogHandle.standardOutput
    
    let tlsCertificateKey: URL?
    let tlsCertificateChain: URL?
    let serverUsername: String?
    let serverPassword: String?
    let port: Int
    
    var convertAction: ConvertAction
    
    public var setupContext: ((inout DocumentationContext) -> Void)?
    private var previewPaths: [String] = []
    private var runSecure: Bool {
        return tlsCertificateKey != nil && tlsCertificateChain != nil
    }
    
    // Use for testing to override binding to a system port
    var bindServerToSocketPath: String?
    
    /// This closure is used to create a new convert action to generate a new version of the docs
    /// whenever the user changes a file in the watched directory.
    private let createConvertAction: () throws -> ConvertAction
    
    /// A unique ID to access the action's preview server.
    let serverIdentifier = ProcessInfo.processInfo.globallyUniqueString

    private let diagnosticEngine: DiagnosticEngine
    
    /// Creates a new preview action from the given parameters.
    ///
    /// The `tlsCertificateKey`, `tlsCertificateChain`, `serverUsername`,  and `serverPassword`
    /// parameters are optional, but if you provide one, all four are expected. They are used by the preview server
    /// to serve content on the local network over SSL.
    ///
    /// - Parameters:
    ///   - tlsCertificateKey: The path to the TLS certificate key used by the preview server for SSL configuration.
    ///   - tlsCertificateChain: The path to the TLS certificate chain used by the preview server for SSL configuration.
    ///   - serverUsername: The username used by the preview server for HTTP authentication.
    ///   - serverPassword: The password used by the preview server for HTTP authentication.
    ///   - port: The port number used by the preview server.
    ///   - convertAction: The action used to convert the documentation bundle before preview.
    ///   On macOS, this action will be reused to convert documentation each time the source is modified.
    ///   - workspace: The documentation workspace used by the the action's documentation context.
    ///   - context: The documentation context for the action.
    ///   - printTemplatePath: Whether or not the HTML template used by the convert action should be printed when the action
    ///     is performed.
    /// - Throws: If an error is encountered while initializing the documentation context.
    public init(
        tlsCertificateKey: URL?, tlsCertificateChain: URL?, serverUsername: String?,
        serverPassword: String?, port: Int,
        createConvertAction: @escaping () throws -> ConvertAction,
        workspace: DocumentationWorkspace = DocumentationWorkspace(),
        context: DocumentationContext? = nil,
        printTemplatePath: Bool = true) throws
    {
        if !Self.allowConcurrentPreviews && !servers.isEmpty {
            assertionFailure("Running multiple preview actions is not allowed.")
        }
        
        // Initialize the action context.
        self.tlsCertificateKey = tlsCertificateKey
        self.tlsCertificateChain = tlsCertificateChain
        self.serverUsername = serverUsername
        self.serverPassword = serverPassword
        self.port = port
        self.createConvertAction = createConvertAction
        self.convertAction = try createConvertAction()
        self.workspace = workspace
        let engine = self.convertAction.diagnosticEngine
        self.diagnosticEngine = engine
        self.context = try context ?? DocumentationContext(dataProvider: workspace, diagnosticEngine: engine)
        self.printHTMLTemplatePath = printTemplatePath
    }

    /// Converts a documentation bundle and starts a preview server to render the result of that conversion.
    ///
    /// > Important: On macOS, the bundle will be converted each time the source is modified.
    ///
    /// - Parameter logHandle: The file handle that the convert and preview actions will print debug messages to.
    public func perform(logHandle: LogHandle) throws -> ActionResult {
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
        
        let previewResult = try preview()
        return ActionResult(didEncounterError: previewResult.didEncounterError, outputs: [convertAction.targetDirectory])
    }

    /// Stops a currently running preview session.
    func stop() throws {
        try servers[serverIdentifier]?.stop()
        servers.removeValue(forKey: serverIdentifier)
    }
    
    func preview() throws -> ActionResult {
        // Convert the documentation source for previewing.
        let result = try convert()
        guard !result.didEncounterError else {
            return result
        }

        let previewResult: ActionResult
        // Preview the output and monitor the source bundle for changes.
        do {
            print(String(repeating: "=", count: 40), to: &logHandle)
            if runSecure, let serverUsername = serverUsername, let serverPassword = serverPassword {
                print("Starting TLS-Enabled Web Server", to: &logHandle)
                printPreviewAddresses(base: URL(string: "https://\(ProcessInfo.processInfo.hostName):\(port)")!)
                print("\tUsername: \(serverUsername)", to: &logHandle)
                print("\tPassword: \(serverPassword)", to: &logHandle)
                
            } else {
                print("Starting Local Preview Server", to: &logHandle)
                printPreviewAddresses(base: URL(string: "http://localhost:\(port)")!)
            }
            print(String(repeating: "=", count: 40), to: &logHandle)

            let to: PreviewServer.Bind = bindServerToSocketPath.map { .socket(path: $0) } ?? .localhost(port: port)
            servers[serverIdentifier] = try PreviewServer(contentURL: convertAction.targetDirectory, bindTo: to, username: serverUsername, password: serverPassword, tlsCertificateChainURL: tlsCertificateChain, tlsCertificateKeyURL: tlsCertificateKey, logHandle: &logHandle)
            
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
            diagnosticEngine.emit(.init(description: error.localizedDescription, source: nil))
            // Stale server entry, remove it from the list
            servers.removeValue(forKey: serverIdentifier)
            previewResult = ActionResult(didEncounterError: true)
        }

        return previewResult
    }
    
    func convert() throws -> ActionResult {
        // `cancel()` will throw `cancelPending` if there is already queued conversion.
        try convertAction.cancel()
        
        convertAction = try createConvertAction()
        convertAction.setupContext = setupContext

        let result = try convertAction.perform(logHandle: logHandle)
        previewPaths = try convertAction.context.previewPaths()
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
        monitor = try DirectoryMonitor(root: rootURL) { _, folderURL in
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
                print("Source bundle was modified, converting... ", terminator: "", to: &self.logHandle)
                let result = try self.convert()
                if result.didEncounterError {
                    throw ErrorsEncountered()
                }
                print("Done.", to: &self.logHandle)
            } catch ConvertAction.Error.cancelPending {
                // `monitor.restart()` is already queueing a new convert action which will start when the previous one completes.
                // We can safely ignore the current action and just log to the console.
                print("\nConversion already in progress...", to: &self.logHandle)
            } catch DocumentationContext.ContextError.registrationDisabled {
                // The context cancelled loading the bundles and threw to yield execution early.
                print("\nConversion cancelled...", to: &self.logHandle)
            } catch {
                print("\n\(error.localizedDescription)\nCompilation failed", to: &self.logHandle)
            }
        }
        try monitor.start()
        print("Monitoring \(rootURL.path) for changes...", to: &self.logHandle)
    }
}
#endif

extension DocumentationContext {
    /// Finds the module and technology pages in the context and returns their paths.
    func previewPaths() throws -> [String] {
        let urlGenerator = PresentationURLGenerator(context: self, baseURL: URL(string: "/")!)
        
        let rootModules = try rootModules.filter { try !entity(with: $0).isVirtual }
        
        return (rootModules + rootTechnologies).map { page in
            urlGenerator.presentationURLForReference(page).absoluteString
        }
    }
}
