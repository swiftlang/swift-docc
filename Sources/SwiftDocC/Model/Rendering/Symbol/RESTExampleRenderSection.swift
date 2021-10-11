/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A section that contains a code example.
public struct CodeExample: Codable, Equatable {
    /// A piece of code.
    public struct Code: Codable, Equatable {
        /// If `true`, the lines are not essential to the example.
        let collapsible: Bool
        /// A list of code lines.
        let code: [String]
    }
    
    /// An optional type for the example.
    public let type: String?
    /// An optional source language for syntax highlighting.
    public let syntax: String?
    /// A list of code chunks.
    public let content: [Code]
}
