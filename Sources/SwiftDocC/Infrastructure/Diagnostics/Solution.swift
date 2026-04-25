/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A possible solution to a problem or issue that's reported about in a diagnostic.
public struct Solution: Hashable {
    /// A brief summary that describe what the solution is to the end-user.
    public var summary: String
    
    /// A list of replacements that make up this solution to resolve the original problem or issue.
    ///
    /// This list may be empty if the solution cannot be described as a series of textual replacements.
    public var replacements: [Replacement]

    /// Creates a new `Solution` with the provided summary and replacements
    /// - Parameters:
    ///   - summary: A brief description of the solution
    ///   - replacements: A list of replacements that make up this solution, if this solution can be described as a series of replacements.
    public init(summary: String, replacements: [Replacement]) {
        self.summary = summary
        self.replacements = replacements
    }
}
