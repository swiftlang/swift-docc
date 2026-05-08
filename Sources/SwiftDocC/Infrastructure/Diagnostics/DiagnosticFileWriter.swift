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
    
    /// Creates a new diagnostic file writer with a specific output path.
    /// - Parameter outputPath: The path where the diagnostic file writer should write the diagnostics file.
    public init(outputPath: URL) {
        self.outputLocation = outputPath
        self.fileManager = FileManager.default
    }
    
    package init(outputPath: URL, fileManager: some FileManagerProtocol) {
        self.outputLocation = outputPath
        self.fileManager = fileManager
    }
    
    private var receivedProblems: [Problem] = []
    
    public func receive(_ problems: [Problem]) {
        receivedProblems.append(contentsOf: problems)
    }
    
    public func flush() throws {
        let fileContent = DiagnosticFile(problems: receivedProblems)
        // Don't clear the received problems, `flush()` is called more than once.
        let encoder = RenderJSONEncoder.makeEncoder(emitVariantOverrides: false)
        let data = try encoder.encode(fileContent)
        try fileManager.createFile(at: outputLocation, contents: data, options: .atomic)
    }
}
