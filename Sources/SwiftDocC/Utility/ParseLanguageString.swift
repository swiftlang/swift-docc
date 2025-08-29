/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
/// A function that parses array values on code block options from the language line string
public func parseCodeBlockOptionArray(_ value: String?) -> [Int]? {
    guard var s = value?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return [] }

    if s.hasPrefix("[") && s.hasSuffix("]") {
        s.removeFirst()
        s.removeLast()
    }

    return s.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
}

/// A function that parses the language line options on code blocks, returning the language and tokens, an array of OptionName and option values
public func tokenizeLanguageString(_ input: String?) -> (lang: String?, tokens: [(RenderBlockContent.CodeListing.OptionName, String?)]) {
    guard let input else { return (lang: nil, tokens: []) }

    let parts = parseLanguageString(input)
    var tokens: [(RenderBlockContent.CodeListing.OptionName, String?)] = []
    var lang: String? = nil

    for (index, part) in parts.enumerated() {
        if let eq = part.firstIndex(of: "=") {
            let key = part[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            let value = part[part.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if key == "wrap" {
                tokens.append((.wrap, value))
            } else if key == "highlight" {
                tokens.append((.highlight, value))
            } else if key == "strikeout" {
                tokens.append((.strikeout, value))
            } else {
                tokens.append((.unknown, key))
            }
        } else {
            let key = part.trimmingCharacters(in: .whitespaces).lowercased()
            if key == "nocopy" {
                tokens.append((.nocopy, nil as String?))
            } else if key == "wrap" {
                tokens.append((.wrap, nil as String?))
            } else if key == "highlight" {
                tokens.append((.highlight, nil as String?))
            } else if key == "strikeout" {
                tokens.append((.strikeout, nil as String?))
            } else if index == 0 && !key.contains("[") && !key.contains("]") {
                lang = key
            } else {
                tokens.append((.unknown, key))
            }
        }
    }
    return (lang, tokens)
}

// helper function for tokenizeLanguageString to parse the language line
func parseLanguageString(_ input: String?) -> [Substring] {

    guard let input else { return [] }
    var parts: [Substring] = []
    var start = input.startIndex
    var i = input.startIndex

    var bracketDepth = 0

    while i < input.endIndex {
        let c = input[i]

        if c == "[" { bracketDepth += 1 }
        else if c == "]" { bracketDepth = max(0, bracketDepth - 1) }
        else if c == "," && bracketDepth == 0 {
            let seq = input[start..<i]
            if !seq.isEmpty {
                parts.append(seq)
            }
            input.formIndex(after: &i)
            start = i
            continue
        }
        input.formIndex(after: &i)
    }
    let tail = input[start..<input.endIndex]
    if !tail.isEmpty {
        parts.append(tail)
    }

    return parts
}
