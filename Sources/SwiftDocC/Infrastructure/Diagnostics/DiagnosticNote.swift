/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

extension Diagnostic {
    /// A supplementary message, related to a diagnostic, to associate with a location in a certain file.
    public struct Note {
        /// The source file to associate the message with.
        public var source: URL
        
        /// The range within the source file to associate the message with.
        public var range: SourceRange
        
        /// The plain text supplementary message of this note.
        public var message: String
    }
}

@available(*, deprecated, renamed: "Diagnostic.Note", message: "Use 'Diagnostic.Note' instead. This deprecated API will be removed after 6.5 is released.")
public typealias DiagnosticNote = Diagnostic.Note
