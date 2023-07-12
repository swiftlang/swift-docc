/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

// The path hierarchy implementation is divided into different files for different responsibilities.
// This file defines specific additions for disambiguating symbol links with type signature information.

// MARK: From symbols

extension PathHierarchy {
    /// Returns lists of the type names for all the symbol's parameters and return values.
    static func functionSignatureTypeNames(for symbol: SymbolGraph.Symbol) -> (parameterTypeNames: [String], returnTypeNames: [String])? {
        guard let signature = symbol[mixin: SymbolGraph.Symbol.FunctionSignature.self] else {
            return nil
        }
        
        let returnTypeSpellings = signature.returns.compactMap {
            $0.preciseIdentifier != nil ? $0.spelling : nil
        }
        let parameterTypeSpellings = signature.parameters.compactMap({
            $0.declarationFragments.first(where: { $0.kind == .typeIdentifier })?.spelling
        })
        return (parameterTypeSpellings, returnTypeSpellings)
    }
}

// MARK: Parsing links

extension PathHierarchy {
    static func parseTypeSignatureDisambiguation(pathComponent original: Substring) -> PathComponent? {
        let full = String(original)
        let dashIndex = original.lastIndex(of: "-")! // This was already parsed in the
        let disambiguation = String(original[dashIndex...].dropFirst())
        let name = String(original[..<dashIndex])
        
        // The return type disambiguation start with a ">" to form an arrow together with the dash ("->")
        if disambiguation.hasPrefix(">") {
            var returnTypesString = disambiguation.dropFirst()
            // A single return type appear directly after the arrow. Multiple return types are comma separated within parenthesis.
            if returnTypesString.hasPrefix("("), returnTypesString.hasSuffix(")") {
                returnTypesString = returnTypesString.dropFirst().dropLast()
            }
            if let dashIndex = name.lastIndex(of: "-") {
                // Parameters are always within parenthesis. Drop "-(" before and ")" after.
                let parameterTypesString = name[dashIndex...].dropFirst(2).dropLast()
                let name = String(name[..<dashIndex])
                
                return PathComponent(full: full, name: name, disambiguation: .typeSignature(parameterTypes: parameterTypesString.components(separatedBy: ","), returnTypes: returnTypesString.components(separatedBy: ",")))
            }
            
            return PathComponent(full: full, name: name, disambiguation: .typeSignature(parameterTypes: nil, returnTypes: returnTypesString.components(separatedBy: ",")))
        }
        
        // If the disambiguation didn't include return type information it can still include parameter type disambiguation.
        if disambiguation.hasPrefix("("), disambiguation.hasSuffix(")") {
            // Parameters are always within parenthesis. Drop "(" before and ")" after.
            let parameterTypesString = disambiguation.dropFirst().dropLast()
            return PathComponent(full: full, name: name, disambiguation: .typeSignature(parameterTypes: parameterTypesString.components(separatedBy: ","), returnTypes: nil))
        }
        
        // This path component doesn't have type signature disambiguation.
        return nil
    }
}
