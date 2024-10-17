/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
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
        
        let isSwift = symbol.identifier.interfaceLanguage == SourceLanguage.swift.id
        return (
            signature.parameters.map { parameterTypeSpellings(for: $0.declarationFragments, isSwift: isSwift) },
            returnTypeSpellings(for: signature.returns, isSwift: isSwift).map { [$0] } ?? []
        )
    }
    
    private static func parameterTypeSpellings(for fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment], isSwift: Bool) -> String {
        typeSpellings(for: fragments, isSwift: isSwift)
    }
    
    private static func returnTypeSpellings(for fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment], isSwift: Bool) -> String? {
        if fragments.count == 1, knownVoidReturnValues.contains(fragments.first!) {
            // We don't want to list "void" return values as type disambiguation
            return nil
        }
        return typeSpellings(for: fragments, isSwift: isSwift)
    }
    
    private static let knownVoidReturnValues = ParametersAndReturnValidator.knownVoidReturnValuesByLanguage.flatMap { $0.value }
    
    private static func typeSpellings(for fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment], isSwift: Bool) -> String {
        // This function joins the spelling of the text and identifier declaration fragments and applies Swift syntactic sugar;
        // `Array<Element>` -> `[Element]`, `Optional<Wrapped>` -> `Wrapped?`, and `Dictionary<Key,Value>` -> `[Key:Value]`
        
        // This code get called for every symbol with a type signature, so it needs to be fast.
        // Because all the characters that need to be identified and processed are UTF-8 code units, this implementation works solely on UTF-8 code units.
        var accumulated = ContiguousArray<UTF8.CodeUnit>()
        // Reserve some temporary space to work with. This avoids reallocations for most declarations.
        // The final string will make it's own copy, so this temporary memory is only used until the end of this scope.
        accumulated.reserveCapacity(128)
        
        // Iterating over the declaration fragments to accumulate their spelling and to identify places that need to apply syntactic sugar.
        var markers = ContiguousArray<Int>()
        for fragment in fragments {
            let preciseIdentifier = fragment.preciseIdentifier
            if isSwift {
                // Check if this fragment is a spelled out Swift array, optional, or dictionary.
                switch preciseIdentifier {
                case "s:Sa", // Swift.Array
                     "s:SD", // Swift.Dictionary
                     "s:Sq": // Swift.Optional
                    assert(fragment.spelling == "Array" || fragment.spelling == "Dictionary" || fragment.spelling == "Optional", """
                    Unexpected spelling '\(fragment.spelling)' for Array/Dictionary/Optional fragment in declaration; \(fragments.map(\.spelling).joined())
                    """)
                    
                    // Create a new marker at this location and insert is at the beginning since `withSwiftSyntacticSugar(markers:)`
                    // will iterate the markers from the end to the start.
                    markers.insert(accumulated.count, at: 0)
                    
                    // Since `withSwiftSyntacticSugar(markers:)` below will remove this spelling, only collect the first character.
                    // The first character ("A", "D", or "O") is sufficient to identify which type of sugar to apply.
                    accumulated.append(fragment.spelling.utf8.first!)
                    continue
                    
                default:
                    break
                }
                
                switch fragment.kind {
                case .typeIdentifier:
                    // Accumulate all of the identifier tokens' spelling.
                    accumulated.append(contentsOf: fragment.spelling.utf8)
                    
                case .text: // In Swift, only `text` tokens contains whitespace so they're handled separately.
                    // Text tokens like "[", "?", "<", "...", ",", "(", "->" etc. contribute to the type spellings like
                    // `[Name]`, `Name?`, "Name<T>", "Name...", "()", "(Name, Name)", "(Name)->Name" and more.
                    var spelling = fragment.spelling.utf8[...]
                    // If the type spelling is a parameter, if often starts with a leading ":" that's not part of the type name.
                    if accumulated.isEmpty, spelling.first == colon {
                        _ = spelling.removeFirst()
                    }
                    
                    // Ignore whitespace in text tokens. Here we use a loop instead of `filter` to avoid a potential temporary allocation.
                    for char in spelling where char != space {
                        accumulated.append(char)
                    }
                    
                default:
                    continue
                }
            } else {
                switch fragment.kind {
                case .identifier where preciseIdentifier != nil,
                     .typeIdentifier,
                     .text:
                    let spelling = fragment.spelling.utf8
                    
                    // Ignore whitespace. Here we use a loop instead of `filter` to avoid a potential temporary allocation.
                    for char in spelling where char != space {
                        accumulated.append(char)
                    }
                    
                default:
                    continue
                }
            }
        }
        
        // Check if the type names are wrapped in redundant parenthesis and remove them
        if accumulated.first == openParen, accumulated.last == closeParen, !accumulated[...].isTuple() {
            // In case there are multiple
            // Use a temporary slice until all the layers of redundant parenthesis have been removed.
            var temp = accumulated[...]
            
            repeat {
                temp = temp.dropFirst().dropLast()
            } while temp.first == openParen && temp.last == closeParen && !temp.isTuple()
            
            // Adjust the markers so that they align with the expected characters
            let difference = (accumulated.count - temp.count) / 2
            
            accumulated = .init(temp)
            
            for index in markers.indices {
                markers[index] -= difference
                
                assert(accumulated[markers[index]] == uppercaseA || accumulated[markers[index]] == uppercaseD  || accumulated[markers[index]] == uppercaseO, """
                Unexpectedly found '\(String(cString: [accumulated[index], 0]))' at \(index) which should be either an Array, Optional, or Dictionary marker in \(String(cString: accumulated + [0]))
                """)
            }
        }
        
        assert(markers.allSatisfy { [uppercaseA, uppercaseD, uppercaseO].contains(accumulated[$0]) }, """
        Unexpectedly found misaligned markers: \(markers.map { "(index: \($0), char: \(String(cString: [accumulated[$0], 0])))" })
        """)
        
        // Check if we need to apply syntactic sugar to the accumulated declaration fragment spellings.
        if !markers.isEmpty {
            accumulated.applySwiftSyntacticSugar(markers: markers)
        }
        
        // Add a null-terminator to create a String from the accumulated UTF-8 code units.
        accumulated.append(0)
        return accumulated.withUnsafeBufferPointer { pointer in
            String(cString: pointer.baseAddress!)
        }
    }
}

// A collection of UInt8 raw values for various UTF-8 characters that this implementation frequently checks for

private let space       = UTF8.CodeUnit(ascii: " ")

private let uppercaseA  = UTF8.CodeUnit(ascii: "A")
private let uppercaseO  = UTF8.CodeUnit(ascii: "O")
private let uppercaseD  = UTF8.CodeUnit(ascii: "D")

private let openAngle   = UTF8.CodeUnit(ascii: "<")
private let closeAngle  = UTF8.CodeUnit(ascii: ">")
private let openSquare  = UTF8.CodeUnit(ascii: "[")
private let closeSquare = UTF8.CodeUnit(ascii: "]")
private let openParen   = UTF8.CodeUnit(ascii: "(")
private let closeParen  = UTF8.CodeUnit(ascii: ")")

private let comma       = UTF8.CodeUnit(ascii: ",")
private let question    = UTF8.CodeUnit(ascii: "?")
private let colon       = UTF8.CodeUnit(ascii: ":")
private let hyphen      = UTF8.CodeUnit(ascii: "-")

private extension ContiguousArray<UTF8.CodeUnit>.SubSequence {
     /// Checks if the UTF-8 string looks like a tuple with comma separated values.
    ///
    /// This is used to remove redundant parenthesis around expressions.
    func isTuple() -> Bool {
        guard first == openParen, last == closeParen else { return false }
        var depth = 0
        for char in self {
            switch char {
            case openParen:
                depth += 1
            case closeParen:
                depth -= 1
            case comma where depth == 1:
                return true
            default:
                continue
            }
        }
        return false
    }
}

private extension ContiguousArray<UTF8.CodeUnit> {
    /// Transforms the UTF-8 string to apply Swift syntactic sugar.
    ///
    /// - Parameter markers: Locations of `A<Element>`, `O<Wrapped>`, and `D<Key,Value>` (truncated above) to replace with `[Element]`, `Wrapped?`, and `[Key:Value]`.
    mutating func applySwiftSyntacticSugar(markers: ContiguousArray<Int>) {
        assert(!markers.isEmpty, "This is a private helper function and it's the callers responsibility to check if it needs to be called or not.")
        
        // Iterating over the UTF-8 string once to find all the balancing angle brackets (`<` and `>`)
        var markedAngleBracketPairs = ContiguousArray<(open: Int, close: Int)>()
        markedAngleBracketPairs.reserveCapacity(32) // Some temporary space to work with.
        
        var angleBracketStack = ContiguousArray<Int>()
        angleBracketStack.reserveCapacity(32) // Some temporary space to work with.
        
        for index in indices {
            switch self[index] {
            case openAngle:
                angleBracketStack.append(index)
            case closeAngle where self[index - 1] != hyphen: // "->" isn't the closing bracket of a generic
                guard let open = angleBracketStack.popLast() else {
                    assertionFailure("Encountered unexpected generic scope brackets in \(String(cString: self + [0]))")
                    return
                }
                
                // Check if this balanced `<` and `>` pair is one of the markers.
                if markers.contains(open - 1) {
                    // Save this angle bracket pair, sorted by the opening bracket location.
                    // Below, these will be iterated over removing the last
                    if let insertionIndex = markedAngleBracketPairs.firstIndex(where: { open < $0.open }) {
                        markedAngleBracketPairs.insert((open: open, close: index), at: insertionIndex)
                    } else {
                        markedAngleBracketPairs.append((open: open, close: index))
                    }
                }
                
            default:
                // Ignore all non `<` or `>` characters
                continue
            }
        }
        
        
        assert(markedAngleBracketPairs.map(\.open) == markedAngleBracketPairs.map(\.open).sorted(),
               "Marked angle bracket pairs \(markedAngleBracketPairs) are unexpectedly not sorted by opening bracket location")
        
        // Iterate over all the marked angle bracket pairs (from end to start) and replace the marked text with the syntactic sugar alternative.
        while !markedAngleBracketPairs.isEmpty {
            let (open, close) = markedAngleBracketPairs.removeLast()
            assert(self[open] == openAngle, "Start marker at \(open) is '\(String(cString: [self[open], 0]))' instead of '<' in \(String(cString: self + [0]))")
            assert(self[close] == closeAngle, "End marker at \(close) is '\(String(cString: [self[close], 0]))' instead of '>' in \(String(cString: self + [0]))")
            
            // The caller accumulated a single character for each marker that indicated the type of syntactic sugar to apply.
            let marker = open - 1
            switch self[marker] {
                
            case uppercaseA: // Array
                // Apply Swift array syntactic sugar; transforming "A<Element>" into "[Element]" (where "Array" was already abbreviated to "A").
                self[close] = closeSquare
                self.replaceSubrange(marker ... open /* "A<" */, with: [openSquare])
                
                // Update later marked locations since the syntactic sugar shortened the string.
                for index in markedAngleBracketPairs.indices where open < markedAngleBracketPairs[index].close {
                    markedAngleBracketPairs[index].close -= 1 // "A<" is replaced by "["
                    // The `open` location doesn't need to be updated because the pairs are iterated over in reverse order
                }
                
            case uppercaseO: // Optional
                // Apply Swift optional syntactic sugar; transforming "O<Wrapped>" into "Wrapped?" (where "Optional" was already abbreviated to "O").
                self[close] = question
                self.removeSubrange(marker ... open /* "O<" */)
                
                // Update later marked locations since the syntactic sugar shortened the string.
                for index in markedAngleBracketPairs.indices where open < markedAngleBracketPairs[index].close {
                    markedAngleBracketPairs[index].close -= 2 // "O<" is removed
                    // The `open` location doesn't need to be updated because the pairs are iterated over in reverse order
                }
                
            case uppercaseD: // Dictionary
                // Find the comma that separates "Key" and "Value" in "Dictionary<Key,Value>"
                var depth = 1
                let predicate: (UInt8) -> Bool = {
                    if $0 == openAngle || $0 == openParen {
                        depth += 1
                        return false // keep scanning
                    }
                    else if depth == 1 {
                        return $0 == comma
                    }
                    else if $0 == closeAngle || $0 == closeParen {
                        depth -= 1
                        assert(depth >= 0, "Unexpectedly found more closing brackets than open brackets in \(String(cString: self[open + 1 ..< close] + [0]))")
                    }
                    return false // keep scanning
                }
                guard let commaIndex = self[open + 1 /* skip the known opening bracket */ ..< close /* skip the known closing bracket */].firstIndex(where: predicate) else {
                    assertionFailure("Didn't find ',' in \(String(cString: self[open + 1 ..< close] + [0]))")
                    return
                }
                
                // Apply Swift dictionary syntactic sugar; transforming "D<Key,Value>" into "[Key:Value]" (where "Dictionary" was already abbreviated to "D").
                self[commaIndex] = colon
                self[close] = closeSquare
                self.replaceSubrange(marker ... open /* "D<" */, with: [openSquare])
                
                // Update later marked locations since the syntactic sugar shortened the string.
                for index in markedAngleBracketPairs.indices where open < markedAngleBracketPairs[index].close {
                    markedAngleBracketPairs[index].close -= 1 // "D<" is replaced by "["
                    // The `open` location doesn't need to be updated because the pairs are iterated over in reverse order
                }
                
            default:
                assertionFailure("Found marker '\(String(cString: [self[marker], 0]))' at \(marker) doesn't match either 'Array<', 'Optional<', or 'Dictionary<' in \(String(cString: self + [0]))")
                return
            }
            
            assert(
                markedAngleBracketPairs.allSatisfy { open, close in
                    self[open] == openAngle && self[close] == closeAngle
                }, """
                Unexpectedly found misaligned angle bracket pairs in \(String(cString: self + [0])):
                \(markedAngleBracketPairs.map { open, close in "('\(String(cString: [self[open], 0]))' @ \(open) - '\(String(cString: [self[close], 0]))' @ \(close))" }.joined(separator: "\n"))
                """
            )
        }
        
        return
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
        guard peek() != ")" else {
            _ = take() // drop the ")"
            return []
        }
        
        var arguments = [Substring]()
        repeat {
            guard let argument = scanArgument() else {
                break
            }
            arguments.append(argument)
        } while !isAtEnd && take() == ","
        
        return arguments
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
