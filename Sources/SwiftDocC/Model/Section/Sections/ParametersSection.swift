/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section that contains a function's parameters.
public struct ParametersSection {
    public static let title: String? = "Parameters"
    
    /// The list of function parameters.
    public let parameters: [Parameter]
}
