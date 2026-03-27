/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(FoundationXML)
// TODO: Consider other HTML rendering options as a future improvement (rdar://165755530)
package import FoundationXML
#else
package import Foundation
#endif

package import DocCCommon
package import SymbolKit

package extension MarkdownRenderer {
 
    typealias DeclarationFragment = SymbolGraph.Symbol.DeclarationFragments.Fragment
    
    /// Creates a`<pre><code>` HTML element hierarchy that represents the symbol's language-specific declarations.
    ///
    /// When the renderer has a ``RenderGoal/richness`` goal, it creates a `<span>` element for each declaration fragment so that to enable syntax highlighting.
    ///
    /// When the renderer has a ``RenderGoal/conciseness`` goal, it joins the different fragments into string.
    func declaration(_ fragmentsByLanguage: [SourceLanguage: [DeclarationFragment]]) -> XMLElement {
        let fragmentsByLanguage = RenderHelpers.sortedLanguageSpecificValues(fragmentsByLanguage)
        
        guard goal == .richness else {
            // On the rendered page, language specific content _could_ be hidden through CSS but that wouldn't help the tool that reads the raw HTML.
            // So that tools don't need to filter out language specific content themselves, include only the primary language's (plain text) declaration.
            let plainTextDeclaration: [XMLNode] = fragmentsByLanguage.first.map { _, fragments in
                // The main purpose of individual HTML elements per declaration fragment would be syntax highlighting on the rendered page.
                // That structure likely won't be beneficial (and could even be detrimental) to the tool's ability to consume the declaration information.
                [.element(named: "code", children: [.text(fragments.map(\.spelling).joined())])]
            } ?? []
            return .element(named: "pre", children: plainTextDeclaration)
        }
        
        let declarations: [XMLElement] = if fragmentsByLanguage.count == 1 {
            // If there's only a single language there's no need to mark anything as language specific.
            [XMLNode.element(named: "code", children: _declarationTokens(for: fragmentsByLanguage[0].value, in: fragmentsByLanguage[0].key))]
        } else {
            fragmentsByLanguage.map { language, fragments in
                XMLNode.element(named: "code", children: _declarationTokens(for: fragments, in: language), attributes: ["class": "\(language.id)-only"])
            }
        }
        return .element(named: "pre", children: declarations, attributes: ["id": "declaration"])
    }
    
    private func _declarationTokens(for fragments: [DeclarationFragment], in language: SourceLanguage) -> [XMLNode] {
        switch language {
            case .swift:      _prettyPrintedSwiftDeclaration(fragments)
            case .objectiveC: _prettyPrintedObjectiveCDeclaration(fragments)
            default:          fragments.map(_render)
        }
    }
    
    private func _prettyPrintedSwiftDeclaration(_ fragments: [DeclarationFragment]) -> [XMLNode] {
        var result = [XMLNode]()
        result.reserveCapacity(fragments.count)
        
        var remaining = fragments[...]
        
        // Place attributes on their own line.
        // Attributes may have parameters, type identifier, and text separators.
        // The first keyword signals the end of the attributes.
        if fragments.first?.kind == .attribute,
           let firstKeyword = remaining.firstIndex(where: { $0.kind == .keyword })
        {
            let attributes = remaining[..<firstKeyword]
            for fragment in attributes.dropLast() {
                result.append(_render(fragment))
            }
            if var fragment = attributes.last {
                if let nonSpaceIndex = fragment.spelling.utf8.lastIndex(where: { $0 != .init(ascii: " ") }) {
                    fragment.spelling = String(fragment.spelling[...nonSpaceIndex])
                }
                result.append(_render(fragment))
            }
        
            result.append(.text("\n"))
            remaining = remaining[firstKeyword...]
        }
        
        guard fragments.count(where: { $0.kind == .externalParameter }) > 1 else {
            for fragment in remaining {
                result.append(_render(fragment))
            }
            return result
        }
        
        let indentation = "\n    "
        var parenthesisDepth = 0
        
        for var fragment in remaining {
            guard fragment.spelling.utf8.containsParenthesis || parenthesisDepth == 1 && fragment.spelling.utf8.contains(where: { $0 == comma }) else {
                result.append(_render(fragment))
                continue
            }
            
            // We can't store `fragment.spelling.utf8` in a variable because it wouldn't update when we insert indentation into `fragment.spelling`
            var index = fragment.spelling.utf8.startIndex
            
            func insertIndentation() {
                // Both "," and " " are in `text` fragments so we expect to find them in the same fragment.
                let existingWhitespaceCount = fragment.spelling.utf8[index...].prefix(while: { $0 == .init(ascii: " ") }).count
            
                fragment.spelling.insert(contentsOf: indentation.dropLast(existingWhitespaceCount), at: index /* already incremented */)
                fragment.spelling.utf8.formIndex(&index, offsetBy: 5) // advance past the added indentation
            }
            
            while index < fragment.spelling.utf8.endIndex {
                let byte = fragment.spelling.utf8[index]
                fragment.spelling.utf8.formIndex(after: &index)
                
                switch byte {
                    case openParen:
                        if parenthesisDepth == 0 {
                           insertIndentation()
                        }
                        parenthesisDepth &+= 1
                    case closeParen:
                        parenthesisDepth &-= 1
                        if parenthesisDepth == 0 {
                            fragment.spelling.insert("\n", at: fragment.spelling.utf8.index(before: index /* already incremented */))
                            fragment.spelling.utf8.formIndex(after: &index) // advance past the added newline
                            
                            // FIXME: Hack to not do any more wrapping for typed errors or tuple return values
                            parenthesisDepth &+= 100
                        }
                    
                    case comma where parenthesisDepth == 1:
                        insertIndentation()
                    default:
                        continue
                }
            }
            
            result.append(_render(fragment))
        }
        
        return result
    }
    
    private func _prettyPrintedObjectiveCDeclaration(_ fragments: [DeclarationFragment]) -> [XMLNode] {
        // FIXME: Do a Swift-like pretty printing for C functions (rdar://173489263)
        
        let parameterCount = fragments.count(where: { $0.kind == .internalParameter })
        guard parameterCount > 1 else {
            return fragments.map(_render)
        }
        
        var result = [XMLNode]()
        result.reserveCapacity(fragments.count)
        
        // Determine how far the parameters need to be indented to align
        var colonAlignmentLength = 0
        var remaining = fragments[...]
        while let fragment = remaining.popFirst() {
            result.append(_render(fragment))
            if let colonIndex = fragment.spelling.utf8.firstIndex(of: colon) {
                colonAlignmentLength += fragment.spelling.distance(from: fragment.spelling.startIndex, to: colonIndex)
                break
            } else {
                colonAlignmentLength += fragment.spelling.count
            }
        }
        
        // Transform the fragments past the first parameter
        while let fragment = remaining.popFirst() {
            result.append(_render(fragment))
            if fragment.kind == .internalParameter {
                break
            }
        }
            
        for _ in 0 ..< parameterCount - 1 { // Don't split after the last parameter, keep the semicolon on the same line.
            var distanceToColon = 0
            for fragment in remaining {
                if let colonIndex = fragment.spelling.utf8.firstIndex(of: colon) {
                    distanceToColon += fragment.spelling.distance(from: fragment.spelling.startIndex, to: colonIndex)
                    break
                } else {
                    distanceToColon += fragment.spelling.count
                }
            }
            
            guard var fragment = remaining.popFirst() else {
                break
            }
            
            let whitespaceToAdd = colonAlignmentLength - distanceToColon
            fragment.spelling.insert(contentsOf: "\n" + String(repeating: " ", count: whitespaceToAdd), at: fragment.spelling.startIndex)
            result.append(_render(fragment))
            
            while let fragment = remaining.popFirst() {
                result.append(_render(fragment))
                if fragment.kind == .internalParameter {
                    break
                }
            }
        }
        
        while let fragment = remaining.popFirst() {
            result.append(_render(fragment))
        }
        
        return result
    }
    
    private func _render(_ fragment: DeclarationFragment) -> XMLNode {
        let elementClass = "token-\(fragment.kind.rawValue)"
        
        if fragment.kind == .typeIdentifier,
           let symbolID = fragment.preciseIdentifier,
           let reference = linkProvider.pathForSymbolID(symbolID)
        {
            // If the token refers to a symbol that the `linkProvider` is aware of, make that fragment a link to that symbol.
            return .element(named: "a", children: [.text(fragment.spelling)], attributes: [
                "href": path(to: reference),
                "class": elementClass
            ])
        } else if fragment.kind == .text {
            // ???: Does text also need a <span> element or can that be avoided?
            return .text(fragment.spelling)
        } else {
            // The declaration element is expected to scroll, so individual fragments don't need to contain explicit word breaks.
            return .element(named: "span", children: [.text(fragment.spelling)], attributes: ["class": elementClass])
        }
    }
}

private let openParen  = UInt8(ascii: "(")
private let closeParen = UInt8(ascii: ")")
private let comma      = UInt8(ascii: ",")
private let colon      = UInt8(ascii: ":")

private extension String.UTF8View {
    var containsParenthesis: Bool {
        for byte in self where byte == openParen || byte == closeParen {
            return true
        }
        return false
    }
}
