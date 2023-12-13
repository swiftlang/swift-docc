/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A general error that indicates that at least one error was encountered while compiling documentation.
public struct ErrorsEncountered: DescribedError {
    public init() {}
    public var errorDescription: String {
        "An error was encountered while compiling documentation"
    }
}
