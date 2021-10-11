/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that can receive diagnostics.
public protocol DiagnosticConsumer: AnyObject {
    /// Receive diagnostics encountered by a ``DiagnosticEngine``.
    /// - Parameter problems: The encountered diagnostics.
    func receive(_ problems: [Problem])
}

/// A type that can format received diagnostics in way that's suitable for writing to a destination such as a file or `TextOutputStream`.
public protocol DiagnosticFormattingConsumer: DiagnosticConsumer {
    /// Options for how problems should be formatted if written to output.
    var formattingOptions: DiagnosticFormattingOptions { get set }
}
