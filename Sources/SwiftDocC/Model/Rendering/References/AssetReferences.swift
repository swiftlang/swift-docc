/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

public extension RenderNode {
    /// All image, video, file, and download references of this node, grouped by their type.
    var assetReferences: [RenderReferenceType: [RenderReference]] {
        let assetTypes = [RenderReferenceType.image, .video, .file, .download]
        return .init(grouping: references.values.lazy.filter({ assetTypes.contains($0.type) }), by: { $0.type })
    }    
}
