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
}
