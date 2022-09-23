/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

// MARK: Custom Relationship Kind Identifiers

extension SymbolGraph.Relationship.Kind {
    /// This relationship connects top-level extended type symbols the
    /// respective extended module symbol.
    static let declaredIn = Self(rawValue: "declaredIn")
    
    /// This relationship markes a parent-child hierarchy between a nested
    /// extended type symbol and its parent extended type symbol. It mirrors the
    /// `memberOf` relationship between the two respective original type symbols.
    static let inContextOf = Self(rawValue: "inContextOf")
}

// MARK: Custom Symbol Kind Identifiers

extension SymbolGraph.Symbol.KindIdentifier {
    static let extendedProtocol = Self(rawValue: "protocol.extension")
    
    static let extendedStructure = Self(rawValue: "struct.extension")
    
    static let extendedClass = Self(rawValue: "class.extension")
    
    static let extendedEnumeration = Self(rawValue: "enum.extension")
    
    static let unknownExtendedType = Self(rawValue: "unknown.extension")
    
    static let extendedModule = Self(rawValue: "module.extension")
    
    init?(extending other: Self) {
        switch other {
        case .struct:
            self = .extendedStructure
        case .protocol:
            self = .extendedProtocol
        case .class:
            self = .extendedClass
        case .enum:
            self = .extendedEnumeration
        case .module:
            self = .extendedModule
        default:
            return nil
        }
    }
    
    static func extendedType(for extensionBlock: SymbolGraph.Symbol) -> Self? {
        guard let extensionMixin = extensionBlock.mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] as? SymbolGraph.Symbol.Swift.Extension else {
            return nil
        }
        
        guard let typeKind = extensionMixin.typeKind else {
            return nil
        }
        
        return Self(extending: typeKind)
    }
}

extension SymbolGraph.Symbol.Kind {
    static func extendedType(for extensionBlock: SymbolGraph.Symbol) -> Self {
        let id = SymbolGraph.Symbol.KindIdentifier.extendedType(for: extensionBlock)
        switch id {
        case .some(.extendedProtocol):
            return Self(parsedIdentifier: .extendedProtocol, displayName: "Extended Protocol")
        case .some(.extendedStructure):
            return Self(parsedIdentifier: .extendedStructure, displayName: "Extended Structure")
        case .some(.extendedClass):
            return Self(parsedIdentifier: .extendedClass, displayName: "Extended Class")
        case .some(.extendedEnumeration):
            return Self(parsedIdentifier: .extendedEnumeration, displayName: "Extended Enumeration")
        default:
            return unknownExtendedType
        }
    }
    
    static let unknownExtendedType = Self(parsedIdentifier: .unknownExtendedType, displayName: "Extended Type")
}


// MARK: Swift AccessControl Levels

extension SymbolGraph.Symbol.AccessControl {
    static let `private` = Self(rawValue: "private")
    
    static let filePrivate = Self(rawValue: "fileprivate")
    
    static let `internal` = Self(rawValue: "internal")
    
    static let `public` = Self(rawValue: "public")
    
    static let open = Self(rawValue: "open")
}
