/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Writes diagnostic messages to a text output stream.
///
/// By default, this type writes to `stderr`.
public final class DiagnosticConsoleWriter: DiagnosticFormattingConsumer {

    var outputStream: TextOutputStream
    public var formattingOptions: DiagnosticFormattingOptions

    /// Creates a new instance of this class with the provided output stream and filter level.
    /// - Parameter stream: The output stream to which this instance will write.
    /// - Parameter filterLevel: Determines what diagnostics should be printed. This filter level is inclusive, i.e. if a level of ``DiagnosticSeverity/information`` is specified, diagnostics with a severity up to and including `.information` will be printed.
    @available(*, deprecated, message: "Use init(_:formattingOptions:) instead")
    public init(_ stream: TextOutputStream = LogHandle.standardError, filterLevel: DiagnosticSeverity = .warning) {
        outputStream = stream
        formattingOptions = []
    }

    /// Creates a new instance of this class with the provided output stream.
    /// - Parameter stream: The output stream to which this instance will write.
    public init(_ stream: TextOutputStream = LogHandle.standardError, formattingOptions options: DiagnosticFormattingOptions = []) {
        outputStream = stream
        formattingOptions = options
    }

    public func receive(_ problems: [Problem]) {
        let text = problems.formattedLocalizedDescription(withOptions: formattingOptions).appending("\n")
        outputStream.write(text)
    }
}
