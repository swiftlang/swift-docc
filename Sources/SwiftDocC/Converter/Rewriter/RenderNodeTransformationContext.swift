/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A value that tracks state and state changes while transforming a render node.
public struct RenderNodeTransformationContext {
    /// The number of times the render node's content references each reference.
    ///
    /// Transformations that add or remove references to a render node's content are responsible to update this accordingly.
    public var referencesCount: [String: Int] = [:]
}
