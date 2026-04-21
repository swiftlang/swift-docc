/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A type that can receive diagnostics.
public protocol DiagnosticConsumer: AnyObject {
    /// Receive diagnostics encountered by a ``DiagnosticEngine``.
    /// - Parameter diagnostics: The encountered diagnostics.
    func receive(_ diagnostics: [Diagnostic])
    
    @available(*, deprecated, renamed: "receive(_:)", message: "Use 'receive(_:)' instead. This deprecated API will be removed after 6.5 is released.")
    func receive(_ problems: [Problem])
    
    /// Inform the consumer that the engine has sent all diagnostics in a given context.
    func flush() throws
}

// Default implementation so that conforming types don't need to implement deprecated API.
public extension DiagnosticConsumer {
    @available(*, deprecated, renamed: "receive(_:)", message: "Use 'receive(_:)' instead. This deprecated API will be removed after 6.5 is released.")
    func receive(_ problems: [Problem]) {
        receive(problems.map(\.diagnostic))
    }
}

// Default implementation so that existing conformances  by the additional initializer parameter in the protocol requirements.
public extension DiagnosticConsumer {
    @available(*, deprecated) // This needs to be marked deprecated because it calls deprecated API.
    func receive(_ diagnostics: [Diagnostic]) {
        receive(diagnostics.map { Problem(diagnostic: $0, possibleSolutions: $0.possibleSolutions)})
    }
}


/// A type that can format received diagnostics in way that's suitable for writing to a destination such as a file or `TextOutputStream`.
public protocol DiagnosticFormattingConsumer: DiagnosticConsumer {
    /// Options for how diagnostics should be formatted if written to output.
    var formattingOptions: DiagnosticFormattingOptions { get set }
}
