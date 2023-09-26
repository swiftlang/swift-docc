/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A diagnostic consumer that writes detailed diagnostic information to a file.
///
/// For tools interacting with DocC, the diagnostic file format includes more information about the diagnostics than what
/// is output to the consoles. 
public final class DiagnosticFileWriter: DiagnosticConsumer {
    /// The path where the diagnostic file writer should write the diagnostics file.
    var outputPath: URL
    
    /// Creates a new diagnostic file writer with a specific output path.
    /// - Parameter outputPath: The path where the diagnostic file writer should write the diagnostics file.
    public init(outputPath: URL) {
        self.outputPath = outputPath
    }
    private var receivedProblems: [Problem] = []
    
    public func receive(_ problems: [Problem]) {
        receivedProblems.append(contentsOf: problems)
    }
    
    public func flush() throws {
        let fileContent = DiagnosticFile(problems: receivedProblems)
        // Don't clear the received problems, `flush()` is called more than once.
        let encoder = RenderJSONEncoder.makeEncoder(emitVariantOverrides: false)
        try encoder.encode(fileContent).write(to: outputPath, options: .atomic)
    }
    
    // This is deprecated but still necessary to implement.
    @available(*, deprecated, renamed: "flush()")
    public func finalize() throws {
        try flush()
    }
}
