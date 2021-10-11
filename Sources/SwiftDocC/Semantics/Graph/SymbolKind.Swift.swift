/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension SymbolGraph.Symbol.Kind {
    /// A static list of Swift-specific symbol kinds.
    public enum Swift: String, Equatable, CaseIterable {
        case `associatedtype` = "swift.associatedtype"
        case `class` = "swift.class"
        case `deinit` = "swift.deinit"
        case `enum` = "swift.enum"
        case `case` = "swift.enum.case"
        case `func` = "swift.func"
        case `operator` = "swift.func.op"
        case `init` = "swift.init"
        case `method` = "swift.method"
        case `property` = "swift.property"
        case `protocol` = "swift.protocol"
        case `struct` = "swift.struct"
        case `subscript` = "swift.subscript"
        case `typeMethod` = "swift.type.method"
        case `typeProperty` = "swift.type.property"
        case `typeSubscript` = "swift.type.subscript"
        case `typealias` = "swift.typealias"
        case `var` = "swift.var"

        case module = "module"
        
        /// The list of Swift-specific symbol kinds that could possibly have other symbols as children. 
        var symbolCouldHaveChildren: Bool {
            switch self {
            case .associatedtype, .deinit, .case, .func, .operator, .`init`, .method, .property, .typeMethod, .typeProperty, .typealias, .var:
                return false
            default: return true
            }
        }
    }
}
