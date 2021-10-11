/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// The data associated with a documentation resource, for a specific trait collection.
public struct BundleData {
    /// The location of the resource.
    public var url: URL
    
    /// The trait collection associated with the resource.
    public var traitCollection: DataTraitCollection?
    
    /// Creates a bundle data value given its location and an associated trait collection.
    /// - Parameters:
    ///   - url: The location of the resource in the documentation bundle.
    ///   - traitCollection: An optional trait collection associated with the resource.
    public init(url: URL, traitCollection: DataTraitCollection?) {
        self.url = url
        self.traitCollection = traitCollection
    }
}
