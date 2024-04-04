/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

// MARK: From symbols

extension PathHierarchy {
    /// Returns the lists of the type names for the symbol's parameters and return values.
    static func functionSignatureTypeNames(for symbol: SymbolGraph.Symbol) -> (parameterTypeNames: [String], returnTypeNames: [String])? {
        guard let signature = symbol[mixin: SymbolGraph.Symbol.FunctionSignature.self] else {
            return nil
        }
        
        return (
            signature.parameters.compactMap { parameterTypeSpellings(for: $0.declarationFragments) },
            returnTypeSpellings(for: signature.returns).map { [$0] } ?? []
        )
    }
    
    private static func parameterTypeSpellings(for fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]) -> String? {
        typeSpellings(for: fragments)
    }
    
    private static func returnTypeSpellings(for fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]) -> String? {
        if fragments.count == 1, knownVoidReturnValues.contains(fragments.first!) {
            // We don't want to list "void" return values as type disambiguation
            return nil
        }
        return typeSpellings(for: fragments)
    }
    
    private static let knownVoidReturnValues = ParametersAndReturnValidator.knownVoidReturnValuesByLanguage.flatMap { $0.value }
    
    private static func typeSpellings(for fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]) -> String? {
        var accumulated = ""[...]
        
        for fragment in fragments {
            switch fragment.kind {
            case .identifier,   // Skip the argument label
                    .keyword,   // Skip keywords ("inout", "consuming", "each", etc.)
                    .attribute, // Skip attributes ("@escaping", custom result builders, etc.)
                    .numberLiteral, .stringLiteral, // Skip literals
                    .externalParameter, .genericParameter, .internalParameter:
                continue

            default:
                accumulated += fragment.spelling
            }
        }
        
        accumulated.removeAll(where: \.isWhitespace)
        
        if accumulated.first == ":" {
            _ = accumulated.removeFirst()
        }
        
        while accumulated.first == "(", accumulated.last == ")", !accumulated.isTuple() {
            // Remove extra layers of parenthesis unless the type is a tuple
            accumulated = accumulated.dropFirst().dropLast()
        }
        
        return String(accumulated.withSwiftSyntacticSugar())
    }
    
}

private extension StringProtocol {
    /// Checks if the string looks like a tuple with comma separated values.
    ///
    /// This is used to remove redundant parenthesis around expressions.
    func isTuple() -> Bool {
        guard first == "(", last == ")", contains(",")else { return false }
        var depth = 0
        for char in self {
            switch char {
            case "(": 
                depth += 1
            case ")": 
                depth -= 1
            case "," where depth == 1:
                return true
            default: 
                continue
            }
        }
        return false
    }
    
    /// Transforms the string to apply Swift syntactic sugar.
    ///
    /// The transformed string has all occurrences of `Array<Element>`, `Optional<Wrapped>`, and `Dictionary<Key,Value>` replaced with `[Element]`, `Wrapped?`, and `[Key:Value]`.
    func withSwiftSyntacticSugar() -> String {
        // If this type uses known Objective-C types, return the original type name
        if contains("NSArray<") || contains("NSDictionary<") {
            return String(self)
        }
        // Don't need to do any processing unless this type contains some string that type name that Swift has syntactic sugar for.
        guard contains("Array<") || contains("Optional<") || contains("Dictionary<") else {
            return String(self)
        }
        
        var result = ""
        result.reserveCapacity(count)
        
        var scanner = StringScanner(String(self)[...])
        
        while let prefix = scanner.scan(until: { $0 == "A" || $0 == "O" || $0 == "D" }) {
            result += prefix
            
            if scanner.hasPrefix("Array<") {
                _ = scanner.take("Array".count)
                guard let elementType = scanner.scanGenericSingle() else {
                    // The type is unexpected. Return the original value.
                    return String(self)
                }
                result.append("[\(elementType.withSwiftSyntacticSugar())]")
                assert(scanner.peek() == ">")
                _ = scanner.take()
            }
            else if scanner.hasPrefix("Optional<") {
                _ = scanner.take("Optional".count)
                guard let wrappedType = scanner.scanGenericSingle() else {
                    // The type is unexpected. Return the original value.
                    return String(self)
                }
                result.append("\(wrappedType.withSwiftSyntacticSugar())?")
                assert(scanner.peek() == ">")
                _ = scanner.take()
            }
            else if scanner.hasPrefix("Dictionary<") {
                _ = scanner.take("Dictionary".count)
                guard let (keyType, valueType) = scanner.scanGenericPair() else {
                    // The type is unexpected. Return the original value.
                    return String(self)
                }
                result.append("[\(keyType.withSwiftSyntacticSugar()):\(valueType.withSwiftSyntacticSugar())]")
                assert(scanner.peek() == ">")
                _ = scanner.take()
            }
        }
        result += scanner.takeAll()
        
        return result
    }
}

// MARK: Parsing links

extension PathHierarchy.PathParser {
    
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
        
        let possibleDisambiguationText: Substring
        if let name = parseOperatorName(original) {
            possibleDisambiguationText = original[name.endIndex...]
        } else {
            possibleDisambiguationText = original
        }
        
        // Look for the start of the parameter disambiguation.
        if let parameterStartRange = possibleDisambiguationText.range(of: "-(") {
            let name = original[..<parameterStartRange.lowerBound]
            var scanner = StringScanner(original[parameterStartRange.upperBound...])
            
            let parameterTypes = scanner.scanArguments()
            if scanner.isAtEnd {
                return PathComponent(full: String(original), name: name, disambiguation: .typeSignature(parameterTypes: parameterTypes, returnTypes: nil))
            } else if scanner.hasPrefix("->") {
                _ = scanner.take(2)
                let returnTypes = scanner.scanArguments() // The return types (tuple or not) can be parsed the same as the arguments
                return PathComponent(full: String(original), name: name, disambiguation: .typeSignature(parameterTypes: parameterTypes, returnTypes: returnTypes))
            }
        } else if let parameterStartRange = possibleDisambiguationText.range(of: "->") {
            let name = original[..<parameterStartRange.lowerBound]
            var scanner = StringScanner(original[parameterStartRange.upperBound...])
            
            let returnTypes: [Substring]
            if scanner.peek() == "(" {
                _ = scanner.take() // the leading parenthesis
                returnTypes = scanner.scanArguments() // The return types (tuple or not) can be parsed the same as the arguments
            } else {
                returnTypes = [scanner.takeAll()]
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
    
    mutating func scanArguments() -> [Substring] {
        var arguments = [Substring]()
        repeat {
            guard let argument = scanArgument() else {
                break
            }
            arguments.append(argument)
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
    
    // MARK: Parsing syntactic sugar by scanning
     
    mutating func scanGenericSingle() -> Substring? {
        assert(peek() == "<", "The caller should have checked that this is a generic")
        _ = take()
        
        // The generic may contain any number of nested generics. Keep track of the open and close parenthesis while scanning.
        var depth = 0
        let predicate: (Character) -> Bool = {
            if $0 == "<" {
                depth += 1
                return false // keep scanning
            }
            if depth > 0 {
                if $0 == ">" {
                    depth -= 1
                }
                return false // keep scanning
            }
            return $0 == ">"
        }
        return scan(until: predicate)
    }
    
    mutating func scanGenericPair() -> (Substring, Substring)? {
        assert(peek() == "<", "The caller should have checked that this is a generic")
        _ = take() // Discard the opening "<"
        
        // The generic may contain any number of nested generics. Keep track of the open and close parenthesis while scanning.
        var depth = 0
        let firstPredicate: (Character) -> Bool = {
            if $0 == "<" || $0 == "(" {
                depth += 1
                return false // keep scanning
            }
            if depth > 0 {
                if $0 == ">" || $0 == ")" {
                    depth -= 1
                }
                return false // keep scanning
            }
            return $0 == ","
        }
        guard let first = scan(until: firstPredicate) else { return nil }
        _ = take() // Discard the ","
        
        assert(depth == 0, "Scanning the first generic should encountered a balanced number of brackets.")
        let secondPredicate: (Character) -> Bool = {
            if $0 == "<" || $0 == "(" {
                depth += 1
                return false // keep scanning
            }
            if depth > 0 {
                if $0 == ">" || $0 == ")" {
                    depth -= 1
                }
                return false // keep scanning
            }
            return $0 == ">"
        }
        guard let second = scan(until: secondPredicate) else { return nil }
        
        return (first, second)
    }
}
