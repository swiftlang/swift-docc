/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A response for a successful documentation conversion.
///
/// This response is sent by a ``ConvertService`` if the conversion was successful. If the conversion was not successful, a
/// ``ConvertServiceError`` is returned instead.
public struct ConvertResponse: Codable {
    /// The render nodes that were created as part of the conversion, encoded as JSON.
    public var renderNodes: [Data]
    
    /// The render reference store that was created as part of the bundle's conversion, encoded as JSON.
    ///
    /// The ``RenderReferenceStore`` contains compiled information for documentation nodes that were registered as part of
    /// the conversion. This information can be used as a lightweight index of the available documentation content in the bundle that's
    /// been converted.
    public var renderReferenceStore: Data?
    
    /// Creates a conversion response given the render nodes that were created as part of the conversion.
    public init(renderNodes: [Data], renderReferenceStore: Data? = nil) {
        self.renderNodes = renderNodes
        self.renderReferenceStore = renderReferenceStore
    }
}
