/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

extension ExternalSymbolResolver {
    
    /// Converts a documentation node kind value for a symbol to the closest matching symbol-graph symbol kind value.
    ///
    /// When resolving an external symbol, the node needs to have a `Symbol` semantic for some of the symbol relationships
    /// to work as expected. The creation of a `Symbol` semantic requires a "kind" value.
    ///
    /// For most purposes it's enough that the kind is "any symbol". When rendered, the `role` is simply going to be "symbol",
    /// but there are a few exceptions where kind value impacts where the relationship is displayed. For example, a "conformsTo"
    /// relationship between A and B is considered an "inheritsFrom" relationship if both A and B are protocols.
    ///
    /// By matching all the node kind values that have a known symbol kind and providing a fallback value for the other cases,
    /// everything should work as expected in practice — covering the exceptions with the known values and having "any symbol"
    /// value for the rest.
    static func symbolKind(forNodeKind kind: DocumentationNode.Kind) -> SymbolGraph.Symbol.Kind {
        let symbolKind: SymbolGraph.Symbol.KindIdentifier
        
        switch kind {
        case .associatedType:
            symbolKind = .associatedtype
        case .class:
            symbolKind = .class
        case .deinitializer:
            symbolKind = .deinit
        case .enumeration:
            symbolKind = .enum
        case .enumerationCase:
            symbolKind = .case
        case .function:
            symbolKind = .func
        case .operator:
            symbolKind = .operator
        case .initializer:
            symbolKind = .`init`
        case .instanceMethod:
            symbolKind = .method
        case .instanceProperty:
            symbolKind = .property
        case .protocol:
            symbolKind = .protocol
        case .structure:
            symbolKind = .struct
        case .instanceSubscript:
            symbolKind = .subscript
        case .typeMethod:
            symbolKind = .typeMethod
        case .typeProperty:
            symbolKind = .typeProperty
        case .typeSubscript:
            symbolKind = .typeSubscript
        case .typeAlias:
            symbolKind = .typealias
        case .localVariable, .globalVariable, .instanceVariable:
            symbolKind = .var
        case .module:
            symbolKind = .module
        case .extendedModule:
            symbolKind = .extendedModule
        case .extendedStructure:
            symbolKind = .extendedStructure
        case .extendedClass:
            symbolKind = .extendedClass
        case .extendedEnumeration:
            symbolKind = .extendedEnumeration
        case .extendedProtocol:
            symbolKind = .extendedProtocol
        case .unknownExtendedType:
            symbolKind = .unknownExtendedType
            
        // There shouldn't be any reason for a symbol graph file to reference one of these kinds outside of the symbol graph itself.
        // Return `.class` as the symbol kind (acting as "any symbol") so that the render reference gets a "symbol" role.
        case .typeDef, .macro, .union, .extension:
            fallthrough
         default:
            symbolKind = .class
        }
        
        return .init(parsedIdentifier: symbolKind, displayName: kind.name)
    }
}
