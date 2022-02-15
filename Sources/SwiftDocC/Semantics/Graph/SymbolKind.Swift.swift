/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension SymbolGraph.Symbol.KindIdentifier {
    /// The list of Swift-specific symbol kinds that could possibly have other symbols as children.
    public var swiftSymbolCouldHaveChildren: Bool {
        switch self {
        case .associatedtype, .deinit, .case, .func, .operator, .`init`, .method, .property, .typeMethod, .typeProperty, .typealias, .var:
            return false
        default: return true
        }
    }
    
    /// Returns the kind identifier in the form expected when creating render models.
    ///
    /// Used for ``RenderNode`` and ``RenderIndex`` creation.
    var renderingIdentifier: String {
        // This code was originally added to remove `swift.` name-spacing.
        //
        // Since then, SymbolKit has removed language name-spacing from symbol kinds and introduced
        // some kinds that actually rely on name-spacing (like 'type.method' vs. 'method'
        // and 'func.op').
        //
        // However, existing clients are relying on this behavior so we should continue this way
        // for now until we can make a coordinate change to remove this logic and just use the
        // base identifier, including any dot-separated specifics.
        return identifier.components(separatedBy: ".").last ?? identifier
    }
}
