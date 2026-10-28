/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

/// A diagnostic consumer that writes detailed diagnostic information to a file.
///
/// For tools interacting with DocC, the diagnostic file format includes more information about the diagnostics than what
/// is output to the consoles. 
public final class DiagnosticFileWriter: DiagnosticConsumer {
    /// The path where the diagnostic file writer should write the diagnostics file.
    var outputLocation: URL
    /// The file manager that consumer uses to write the diagnostics file to the specific output path.
    private var fileManager: any FileManagerProtocol
    /// The base URL relative to which the diagnostic source paths are written.
    /// If set to `nil`, the absolute source paths are written.
    private var baseURL: URL?
    
    /// Creates a new diagnostic file writer with a specific output path.
    /// - Parameters:
    ///   - outputPath: The path where the diagnostic file writer should write the diagnostics file.
    ///   - baseURL: The base URL relative to which the diagnostic source paths are written.
    public init(outputPath: URL, baseURL: URL? = nil) {
        self.outputLocation = outputPath
        self.fileManager = FileManager.default
        self.baseURL = baseURL
    }
    
    package init(outputPath: URL, baseURL: URL? = nil, fileManager: some FileManagerProtocol) {
        self.outputLocation = outputPath
        self.fileManager = fileManager
        self.baseURL = baseURL
    }
    
    private var receivedDiagnostics: [Diagnostic] = []
    
    public func receive(_ diagnostics: [Diagnostic]) {
        receivedDiagnostics.append(contentsOf: diagnostics)
    }
    
    public func flush() throws {
        let fileContent = DiagnosticFile(receivedDiagnostics, baseURL: baseURL)
        // Don't clear the received diagnostics, `flush()` is called more than once.
        let encoder = RenderJSONEncoder.makeEncoder(emitVariantOverrides: false)
        let data = try encoder.encode(fileContent)
        try fileManager.createFile(at: outputLocation, contents: data, options: .atomic)
    }
}
