/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

extension RenderNode {
    /// Encodes the render node as JSON data, using a new empty render reference cache.
    func encodeToJSON(with encoder: JSONEncoder = RenderJSONEncoder.makeEncoder()) throws -> Data {
        try encodeToJSON(with: encoder, renderReferenceCache: RenderReferenceCache([:]))
    }
}
