/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 A diagnostic note is a simple string message that should appear somewhere in a document.
 */
public struct DiagnosticNote: CustomStringConvertible {
    /// The source file to which to attach the `message`.
    public var source: URL

    /// The range to which to attach the `message`.
    public var range: SourceRange

    /// The message to attach to the document.
    public var message: String

    public var description: String {
        let location = "\(source.path):\(range.lowerBound.line):\(range.lowerBound.column)"
        return "\(location): note: \(message)"
    }
}
