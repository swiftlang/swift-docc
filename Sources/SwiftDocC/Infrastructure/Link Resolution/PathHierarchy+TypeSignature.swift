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
    /// Returns the lists of the type names for the symbol's parameters and return values.
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
    
    /// Attempts to parse a path component with type signature disambiguation from a substring.
    ///
    /// - Parameter original: The substring to parse into a path component
    /// - Returns: A path component with type signature disambiguation or `nil` it the substring doesn't contain type signature disambiguation.
    static func parseTypeSignatureDisambiguation(pathComponent original: Substring) -> PathComponent? {
        // Declaration disambiguation is parsed differently from symbol kind or a FNV-1 hash disambiguation.
        // Instead of inspecting the components separated by "-" in reverse order, declaration disambiguation
        // scans the path component from start to end to look for the beginning of the declaration.
        //
        // We parse this way to support closure types, in both parameter types or return types, which may look
        // like additional arguments (if the closure takes multiple arguments) or as return type separator ("->").
        // For example, a link to:
        //
        //     func reduce<Result>(
        //         _ initialResult: Result,
        //         _ nextPartialResult: (Result, Self.Element) throws -> Result
        //     ) rethrows -> Result
        //
        // written as ``reduce(_:_:)-(Result,(Result,Element)->Result)->Result`` has the following components:
        //                           ╰──────────────┬────────────────╯  ╰─┬──╯
        //    parameter types         Result,(Result,Element)->Result     │
        //                            ╰─┬──╯ ╰──────────┬───────────╯     │
        //    first parameter type    Result            │                 │
        //    second parameter type          (Result,Element)->Result     │
        //                                                                │
        //    return type(s)                                            Result
        
        // Look for the start of the parameter disambiguation.
        if let parameterStartRange = original.range(of: "-(") {
            let name = String(original[..<parameterStartRange.lowerBound])
            var scanner = StringScanner(original[parameterStartRange.upperBound...])
            
            let parameterTypes = scanner.scanArguments()
            if scanner.isAtEnd {
                return PathComponent(full: String(original), name: name, disambiguation: .typeSignature(parameterTypes: parameterTypes, returnTypes: nil))
            } else if scanner.hasPrefix("->") {
                _ = scanner.take(2)
                let returnTypes = scanner.scanArguments() // The return types (tuple or not) can be parsed the same as the arguments
                return PathComponent(full: String(original), name: name, disambiguation: .typeSignature(parameterTypes: parameterTypes, returnTypes: returnTypes))
            }
        } else if let parameterStartRange = original.range(of: "->") {
            let name = String(original[..<parameterStartRange.lowerBound])
            var scanner = StringScanner(original[parameterStartRange.upperBound...])
            
            let returnTypes: [String]
            if scanner.peek() == "(" {
                _ = scanner.take() // the leading parenthesis
                returnTypes = scanner.scanArguments() // The return types (tuple or not) can be parsed the same as the arguments
            } else {
                returnTypes = [String(scanner.takeAll())]
            }
            return PathComponent(full: String(original), name: name, disambiguation: .typeSignature(parameterTypes: nil, returnTypes: returnTypes))
        }
        
        // This path component doesn't have type signature disambiguation.
        return nil
    }
}

// MARK: Scanning a substring

private struct StringScanner {
    private var remaining: Substring
    
    init(_ original: Substring) {
        remaining = original
    }
    
    func peek() -> Character? {
        remaining.first
    }
    
    mutating func take() -> Character {
        remaining.removeFirst()
    }
    
    mutating func take(_ count: Int) -> Substring {
        defer { remaining = remaining.dropFirst(count) }
        return remaining.prefix(count)
    }
    
    mutating func takeAll() -> Substring {
        defer { remaining.removeAll() }
        return remaining
    }
    
    mutating func scan(until predicate: (Character) -> Bool) -> Substring? {
        guard let index = remaining.firstIndex(where: predicate) else {
            return nil
        }
        defer { remaining = remaining[index...] }
        return remaining[..<index]
    }
    
    var isAtEnd: Bool {
        remaining.isEmpty
    }
    
    func hasPrefix(_ prefix: String) -> Bool {
        remaining.hasPrefix(prefix)
    }

    // MARK: Parsing argument types by scanning
    
    mutating func scanArguments() -> [String] {
        var arguments = [String]()
        repeat {
            guard let argument = scanArgument() else {
                break
            }
            arguments.append(String(argument))
        } while !isAtEnd && take() == ","
        
        return arguments
    }
    
    
    mutating func scanArgumentAndSkip() -> Substring? {
        guard !remaining.isEmpty, !remaining.hasPrefix("->") else {
            return nil
        }
        defer { remaining = remaining.dropFirst() }
        return scanArgument()
    }
        
    mutating func scanArgument() -> Substring? {
        guard peek() == "(" else {
            // If the argument doesn't start with "(" it can't be neither a tuple nor a closure type.
            // In this case, scan until the next argument (",") or the end of the arguments (")")
            return scan(until: { $0 == "," || $0 == ")" }) ?? takeAll()
        }
        
        guard var argumentString = scanTuple() else {
            return nil
        }
        guard remaining.hasPrefix("->") else {
            // This wasn't a closure type, so the scanner has already scanned the full argument.
            assert(peek() == "," || peek() == ")", "The argument should be followed by a ',' or ')'.")
            return argumentString
        }
        argumentString.append(contentsOf: "->")
        remaining = remaining.dropFirst(2)
        
        guard peek() == "(" else {
            // This closure type has a simple return type.
            guard let returnValue = scan(until: { $0 == "," || $0 == ")" }) else {
                return nil
            }
            return argumentString + returnValue
        }
        guard let returnValue = scanTuple() else {
            return nil
        }
        return argumentString + returnValue
    }
        
    mutating func scanTuple() -> Substring? {
        assert(peek() == "(", "The caller should have checked that this is a tuple")
        
        // The tuple may contain any number of nested tuples. Keep track of the open and close parenthesis while scanning.
        var depth = 0
        let predicate: (Character) -> Bool = {
            if $0 == "(" {
                depth += 1
                return false // keep scanning
            }
            if depth > 0 {
                if $0 == ")" {
                    depth -= 1
                }
                return false // keep scanning
            }
            return $0 == "," || $0 == ")"
        }
        return scan(until: predicate)
    }
}
