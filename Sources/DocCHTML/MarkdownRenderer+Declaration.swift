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
    /// When the renderer has a ``RenderGoal/richness`` goal, it creates a `<span>` element for each declaration fragment to enable syntax highlighting.
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
            case .swift:      DeclarationFormatter.prettyPrintedSwiftDeclaration(fragments, using: self)
            case .objectiveC: DeclarationFormatter.prettyPrintedObjectiveCDeclaration(fragments, using: self)
            default:          DeclarationFormatter.withJoinedConsecutiveFragments(fragments) { buffer, _, _ in buffer.map(self.render(_:)) }
        }
    }
    
    fileprivate func render(_ fragment: DeclarationFormatter.Fragment) -> XMLNode {
        let text = XMLNode.text(fragment.text)
        
        switch fragment.kind {
        case .text:
            return consume text
            
        case .link(usr: let usr):
            guard let usr, let reference = linkProvider.pathForSymbolID(usr) else {
                fallthrough
            }
            // If the token refers to a symbol that the `linkProvider` is aware of, make that fragment a link to that symbol.
            return .element(named: "a", children: [consume text], attributes: [
                "href": path(to: reference),
                "class": fragment.kind.htmlClassName
            ])
        case .keyword, .attribute, .number, .string, .internalParameter:
            // The declaration element is expected to scroll, so individual fragments don't need to contain explicit word breaks.
            return .element(named: "span", children: [consume text], attributes: ["class": fragment.kind.htmlClassName])
        }
    }
}

private let openParen  = UInt8(ascii: "(")
private let closeParen = UInt8(ascii: ")")
private let comma      = UInt8(ascii: ",")
private let colon      = UInt8(ascii: ":")
private let space      = UInt8(ascii: " ")

/// A scope for a collection of methods that pretty print declarations
private enum DeclarationFormatter {
    // The general high-level design of these methods are can be described in 3 steps:
    // First, the SymbolKit fragments are transformed into `Fragment` types that join consecutive fragments that display the same. This happens in `withJoinedConsecutiveFragments(...)`
    // Second, some in-place mutation happens on the temporary buffer of those "fragments" to insert line breaks and modify whitespace.
    // Lastly, those fragments are transformed into XMLNode elements by calling `MarkdownRenderer.render(_:)` on each fragment.
    
    /// A compact representation of the information of a SymbolKit fragment for the purpose of rendering an symbol declaration in static HTML.
    ///
    /// This type exist to join consecutive SymbolKit declaration fragments---that map to the same ``Kind``---into a single element.
    /// It also makes it provides some abstractions for manipulating the fragment's ``text``.
    struct Fragment {
        /// The known kinds of symbol fragments (that specifically appear in declarations).
        ///
        /// The SymbolKit kinds `identifier`, `externalParameter`, `genericParameter`, and `text` don't have a custom syntax highlighting color.
        /// To avoid creating unnecessary `<span class="identifier"></span>` (and similar) elements that have no visual impact on the page, these SymbolKit fragment kinds are all mapped to `text`.
        enum Kind: Equatable {
            case link(usr: String?)
            case text
            case keyword, attribute, number, string, internalParameter
            
            init(_ symbolFragment: MarkdownRenderer.DeclarationFragment) {
                self = switch symbolFragment.kind {
                    case .keyword:           .keyword
                    case .attribute:         .attribute
                    case .numberLiteral:     .number
                    case .stringLiteral:     .string
                    case .internalParameter: .internalParameter
                    case .typeIdentifier:    .link(usr: symbolFragment.preciseIdentifier)
                    // Map any fragment that doesn't have a custom syntax highlighting color to "text".
                    default: .text
                }
            }
            
            /// The class name used to syntax highlight the text in the HTML declaration.
            var htmlClassName: String {
                switch self {
                    case .link:              "typeIdentifier"
                    case .text:              fatalError("The caller is responsible for checking that the kind isn't `text` before calling `htmlClassName`")
                    case .keyword:           "keyword"
                    case .attribute:         "attribute"
                    case .number:            "numberLiteral"
                    case .string:            "stringLiteral"
                    case .internalParameter: "internalParameter"
                }
            }
            
            /// Checks if two kinds are the same _without_ comparing the USR String for `link` kinds.
            static func == (lhs: Self, rhs: Self) -> Bool {
                switch (lhs, rhs) {
                    case (.link, .link),
                         (.text, .text),
                         (.keyword, .keyword),
                         (.attribute, .attribute),
                         (.number, .number),
                         (.string, .string),
                         (.internalParameter, .internalParameter): true
                    default: false
                }
            }
        }
        /// The kind of this fragment.
        let kind: Kind
        /// The text of this fragment.
        var text: Substring
    }
    
    /// A helper method that transforms the SymbolKit fragments into partially processed `Fragment` values and joins consecutive fragments of the same kind to produce a smaller HTML output with fewer `span` elements.
    /// 
    /// - Parameters:
    ///   - fragments: The SymbolKit fragments to transform and join
    ///   - body: A closure where the caller can operate on a temporary buffer of `Fragment` values, with the counted number of external and internal parameter fragments for convenience.
    ///     The buffer is mutable so that the closure can in-place modify the fragment values.
    ///     > Important: The closure must not change the length of the buffer. If it does, then this function may not be able to successfully clean up the temporary buffer.
    /// - Returns: The return value of the `body` closure.
    static func withJoinedConsecutiveFragments<Result>(
        _ fragments: [MarkdownRenderer.DeclarationFragment],
        _ body: (_ buffer: UnsafeMutableBufferPointer<Fragment>, _ externalParameterCount: Int, _ internalParameterCount: Int) -> Result
    ) -> Result {
        // We use `withUnsafeTemporaryAllocation` for this temporary buffer, hoping that the compiler uses _stack_ memory for it, so that we can avoid a _heap_ allocation.
        // `withUnsafeTemporaryAllocation` gives us a buffer pointer to some uninitialized memory that will be deallocated by the end of the closure's scope.
        withUnsafeTemporaryAllocation(of: Fragment.self, capacity: fragments.count) { buffer in
            // Keep track of how many fragments we've initialized so that we can deinitialize them at the end.
            var elementCount = 0
            
            // When pretty printing Swift we need to know how many parameters there are based on the _external_ fragments.
            // When pretty printing Objective-C we need to know how many parameters there are based on the _internal_ fragments.
            // We compute both in this function to avoid the caller iterating over the fragments again just to count the parameters.
            var externalParameterCount = 0
            var internalParameterCount = 0
            
            var remaining = fragments[...]
            guard let first = remaining.popFirst() else {
                // This body never initialized any elements so we don't need to deinitialize anything afterwards either.
                // We need to pass the closure a buffer with a `count` so that it can use for-loops and otherwise check the length of the buffer.
                return body(.init(start: buffer.baseAddress, count: 0), externalParameterCount, internalParameterCount)
            }
            if first.kind == .internalParameter {
                internalParameterCount &+= 1
            } else if first.kind == .externalParameter {
                externalParameterCount &+= 1
            }
            
            // An inner helper function that appends a fragment to the buffer
            func append(_ fragment: consuming Fragment) {
                buffer.initializeElement(at: elementCount, to: consume fragment)
                elementCount &+= 1
            }
            append(Fragment(kind: .init(first), text: first.spelling[...]))
            
            while let next = remaining.popFirst() {
                let kind = Fragment.Kind(next)
                if kind == .internalParameter {
                    internalParameterCount &+= 1
                } else if kind == .text, next.kind == .externalParameter {
                    externalParameterCount &+= 1
                }
                
                if buffer[elementCount - 1].kind == kind {
                    // Join fragments that display the same.
                    buffer[elementCount - 1].text.append(contentsOf: next.spelling)
                } else {
                    append(Fragment(kind: kind, text: next.spelling[...]))
                }
            }
            
            defer {
                // The closure is responsible for both deinitializing any memory that it initializes. However, the buffer will trap if it deinitializes memory that it never initialized.
                buffer[0..<elementCount].deinitialize()
            }
            // We need to pass the closure a buffer with a `count` so that it can use for-loops and otherwise check the length of the buffer.
            return body(.init(start: buffer.baseAddress, count: elementCount), externalParameterCount, internalParameterCount)
        }
    }
    
    /// Pretty prints a Swift declaration by placing attributes on their own line and placing each parameter on its own line.
    ///
    /// For example, this function formats declaration `nonisolated func doSomething(with first: Int, and second: Int) -> Int` as:
    /// ```
    /// nonisolated
    /// func doSomething(
    ///     with first: Int,
    ///     and second: Int
    /// ) -> Int
    /// ```
    ///
    /// - Parameters:
    ///   - fragments: The SymbolKit declaration fragments to create a pretty printed HTML output for.
    ///   - renderer: The renderer that resolves USRs and determines the relative path from the current page to the linked page.
    /// - Returns: The list of XML nodes that represent the syntax-highlightable declaration fragments.
    static func prettyPrintedSwiftDeclaration<LinkProvider>(_ fragments: [MarkdownRenderer.DeclarationFragment], using renderer: MarkdownRenderer<LinkProvider>) -> [XMLNode] {
        return withJoinedConsecutiveFragments(fragments) { fragments, externalParametersCount, _ in
            guard !fragments.isEmpty else {
                return []
            }
            
            var index = 0
            
            // Attributes such as `nonisolated`, `@MainActor`, `@frozen`, `@peer(...)`, or `@freestanding(...)` are placed on their own line.
            // We found the end of the attributes when we encounter the first keyword (for example `func`, `struct`, or `macro`.
            if fragments[index].kind == .attribute,
               let firstKeywordIndex = fragments.firstIndex(where: { $0.kind == .keyword })
            {
                fragments[firstKeywordIndex - 1].text.replaceTrailingSpacesWithNewline()
                index = firstKeywordIndex
            }
            
            // Only place parameters on their on lines if the function has more than one parameter.
            // Here we check the _external_ names because Swift parameters always have those in their declaration.
            guard externalParametersCount > 1 else {
                return fragments.map { renderer.render($0) }
            }
            
            // To know where to insert line breaks and indentation, we need to count and balance the parenthesis.
            var parenthesisDepth = 0
            
            lineBreakParameters: while index < fragments.count {
                defer { index &+= 1 }
                
                // We iterate over each fragment's UTF-8 code units to check where we need to insert a line break.
                // Note that can happen in the middle of a fragment, especially since multiple fragments may have already been joined together.
                for utf8Index in fragments[index].text.utf8.indices {
                    let byte = fragments[index].text.utf8[utf8Index]
                    switch byte {
                    case openParen:
                        if parenthesisDepth == 0 {
                            fragments[index].text.replaceSpacesWithNewlineAndIndentation(after: utf8Index)
                        }
                        parenthesisDepth &+= 1
                        
                    case comma where parenthesisDepth == 1:
                        fragments[index].text.replaceSpacesWithNewlineAndIndentation(after: utf8Index)
                        
                    case closeParen:
                        parenthesisDepth &-= 1
                        if parenthesisDepth == 0 {
                            fragments[index].text.replaceSpacesWithNewline(before: utf8Index)
                            
                            // We've found the parenthesis that defines the end of the parameter list.
                            // Because we don't do any pretty printing after this point, we break here to avoid looping unnecessarily.
                            break lineBreakParameters
                        }
                        
                    default:
                        continue
                    }
                }
            }
        
            // Transform the updated fragments into HTML
            return fragments.map { renderer.render($0) }
        }
    }
    
    /// Pretty prints an Objective-C method declaration by placing each parameter on its own line.
    ///
    /// For example, this function formats declaration `- (BOOL) doSomethingWithFirst:(NSInteger)first andSecond:(NSInteger)second;` as:
    /// ```
    /// - (BOOL) doSomethingWithFirst:(NSInteger)first
    ///                     andSecond:(NSInteger)second;
    /// ```
    ///
    /// - Parameters:
    ///   - fragments: The SymbolKit declaration fragments to create a pretty printed HTML output for.
    ///   - renderer: The renderer that resolves USRs and determines the relative path from the current page to the linked page.
    /// - Returns: The list of XML nodes that represent the syntax-highlightable declaration fragments.
    static func prettyPrintedObjectiveCDeclaration<LinkProvider>(_ fragments: [MarkdownRenderer.DeclarationFragment], using renderer: MarkdownRenderer<LinkProvider>) -> [XMLNode] {
        return withJoinedConsecutiveFragments(fragments) { fragments, _, internalParametersCount in
            guard !fragments.isEmpty else {
                return []
            }
            
            // Only place parameters on their on lines if the function has more than one parameter.
            // Here we check the _external_ names because Swift parameters always have those in their declaration.
            guard internalParametersCount > 1 else {
                return fragments.map { renderer.render($0) }
            }
            
            var fragmentIndex = 0
            
            /// An inner helper function that advances `fragmentIndex` and counts the number of characters up until the next colon (or the end of the declaration).
            func countCharactersAndAdvanceUpUntilNextColon() -> Int {
                var length = 0
                
                while fragmentIndex < fragments.count {
                    defer { fragmentIndex &+= 1 }
                    let text = fragments[fragmentIndex].text
                    if let colonIndex = text.utf8.firstIndex(of: colon) {
                        return length &+ text.distance(from: text.startIndex, to: colonIndex)
                    } else {
                        length &+= text.count
                    }
                }
                return length
            }
            /// An inner helper function that advances `fragmentIndex` past the next parameter name (or past the last fragment)
            func advancePastNextParameterName() {
                while fragmentIndex < fragments.count {
                    fragmentIndex &+= 1
                    if fragments[fragmentIndex].kind == .internalParameter {
                        fragmentIndex &+= 1
                        return
                    }
                }
            }
            
            // On the first line, count the distance to the first parameter's colon.
            // This is the point that all other parameters will align their colons with.
            let colonAlignmentLength = countCharactersAndAdvanceUpUntilNextColon()
            
            // From here on we want to add a newline and leading whitespace to each parameter except the last (we keep the semicolon on the same line)
            for _ in 0 ..< internalParametersCount - 1 {
                advancePastNextParameterName()
                // After advancing past the previous name, we know the the fragment that we need to add a line break and indentation to.
                let lineStartIndex = fragmentIndex
                
                let distanceToColon = countCharactersAndAdvanceUpUntilNextColon()
                fragments[lineStartIndex].text.prependNewlineAndSpaces(length: colonAlignmentLength &- distanceToColon)
            }
            
            // Transform the updated fragments into HTML
            return fragments.map { renderer.render($0) }
        }
    }
}

private extension Substring {
    /// Replaces all trailing spaces with a single newline.
    mutating func replaceTrailingSpacesWithNewline() {
        guard let lastNonNewlineIndex = startOfTrailingSpaces() else {
            append("\n")
            return
        }
        
        replaceSubrange(lastNonNewlineIndex..., with: CollectionOfOne("\n"))
    }
    
    /// Returns the index of the first trailing space; or `nil` if the string doesn't have any trailing spaces.
    private func startOfTrailingSpaces() -> UTF8View.Index? {
        var lastNonNewlineIndex: UTF8View.Index?
        for index in utf8.indices.reversed() {
            guard utf8[index] == space else {
                break
            }
            lastNonNewlineIndex = index
        }
        return lastNonNewlineIndex
    }
    
    /// Replaces all consecutive spaces from index onwards with a single whitespace.
    /// - Parameter index: The insertion location.
    mutating func replaceSpacesWithNewline(before index: UTF8View.Index) {
        guard let replacementRange = rangeOfConsecutiveSpaces(from: index) else {
            insert("\n", at: index)
            return
        }
        
        replaceSubrange(replacementRange, with: CollectionOfOne("\n"))
    }
    
    /// Replaces all consecutive spaces from one-past the index onwards with one whitespace and four spaces (for indentation on the new line).
    /// - Parameter index: The insertion location.
    mutating func replaceSpacesWithNewlineAndIndentation(after index: UTF8View.Index) {
        let index = utf8.index(after: index)
        guard let replacementRange = rangeOfConsecutiveSpaces(from: index) else {
            insert(contentsOf: "\n    ", at: index)
            return
        }
        
        replaceSubrange(replacementRange, with: "\n    ")
    }
    
    /// Returns the range of consecutive spaces from `index` onwards; or `nil` if the UTF-8 code unit at `index` is not a space.
    private func rangeOfConsecutiveSpaces(from index: UTF8View.Index) -> Range<UTF8View.Index>? {
        var index = index
        guard index < utf8.endIndex else {
            return nil
        }
        let start = index
        while index < utf8.endIndex {
            guard utf8[index] == space else {
                break
            }
            utf8.formIndex(after: &index)
        }
        return start..<index
    }
    
    /// Inserts a newline and `length` spaces (for indentation on the new line) at the start of the string.
    /// - Parameter length: The number of spaces to add after the newline.
    mutating func prependNewlineAndSpaces(length: Int) {
        // When the later parameters have longer names than the first parameter, we don't try to indent them any further.
        // For example; `- (BOOL) somethingShort:(NSInteger)first andSomethingVeryVeryLong:(NSInteger)second;` will pretty print as:
        // ```
        // - (BOOL) somethingShort:(NSInteger)first
        // andSomethingVeryVeryLong:(NSInteger)second;
        // ```
        // A potential future enhancement could count the _longest_ line and insert extra spaces on the first line as well; between the return value and the method name.
        insert(contentsOf: "\n" + String(repeating: " ", count: Swift.max(0, length)), at: startIndex)
    }
}
