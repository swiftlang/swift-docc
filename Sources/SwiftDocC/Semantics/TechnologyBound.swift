/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An entity directly referring to the technology it belongs to.
public protocol TechnologyBound {
    /// The `name` of the ``Technology`` this section refers to.
    var technology: TopicReference { get }
}
