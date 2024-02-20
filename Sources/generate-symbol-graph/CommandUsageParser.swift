/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

struct CommandUsageToken: Equatable {
    var text: String
    var kind: Kind
    enum Kind: Equatable {
        case command, text, flag, value
    }
}

struct CommandUsageScanner {
    private var remaining: Substring
    
    init(_ original: Substring) {
        remaining = original
    }
    
    func peek() -> Character? {
        remaining.first
    }
    
    mutating func take(_ count: Int = 1) -> Substring {
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
    
    mutating func scan(while predicate: (Character) -> Bool) -> Substring? {
        return scan(until: { !predicate($0) })
    }
    
    var isAtEnd: Bool {
        remaining.isEmpty
    }
    
    func hasPrefix(_ prefix: String) -> Bool {
        remaining.hasPrefix(prefix)
    }
    
    // MARK: Parsing argument types by scanning
    
    mutating func scanTokens() -> [CommandUsageToken] {
        var arguments = [CommandUsageToken]()
        repeat {
            switch peek() {
            case "<":
                let valueName = scan(until: { $0 == ">" }).map { $0 + take() } ?? takeAll()
                arguments.append(.init(text: String(valueName), kind: .value))
                
            case "-":
                let flagName = scan(until: { $0.isWhitespace }) ?? takeAll()
                arguments.append(.init(text: String(flagName), kind: .flag))
                  
            case " ", "]":
                let text = scan(while: { $0 == " " || $0 == "]" || $0 == "[" || $0 == "\\" || $0 == "\n" }) ?? takeAll()
                arguments.append(.init(text: String(text), kind: .text))
                
            default:
                let valueName = scan(until: { $0 == " " }) ?? takeAll()
                arguments.append(.init(text: String(valueName), kind: .command))
            }
        } while !isAtEnd
        
        return arguments
    }
}
