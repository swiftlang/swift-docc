/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/**
 A solution to a `Problem`.
 */
public struct Solution {
    /// A *brief* description of what the solution is.
    public var summary: String
    
    /// The replacements necessary to fix a problem.
    public var replacements: [Replacement]

    /// Creates a new `Solution` with the provided summary and replacements
    /// - Parameters:
    ///   - summary: A brief description of the solution to a problem
    ///   - replacements: The replacements necessary to fix a problem. This array may be empty.
    public init(summary: String, replacements: [Replacement]) {
        self.summary = summary
        self.replacements = replacements
    }
}
