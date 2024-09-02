/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import Foundation

/// The list of tags that can appear at the start of a list item to indicate
/// some meaning in the markup, taken from Swift documentation comments. These
/// are maintained for backward compatibility but their use should be
/// discouraged.
private let simpleListItemTags = [
    "attention",
    "author",
    "authors",
    "bug",
    "complexity",
    "copyright",
    "date",
    "experiment",
    "important",
    "invariant",
    "localizationkey",
    "mutatingvariant",
    "nonmutatingvariant",
    "note",
    "postcondition",
    "precondition",
    "remark",
    "remarks",
    "returns",
    "throws",
    "requires",
    "seealso",
    "since",
    "tag",
    "todo",
    "version",
    "warning",
    "keyword",
    "recommended",
    "recommendedover",
]

struct TaggedListItemExtractor: MarkupRewriter {
    var parameters = [Parameter]()
    var dictionaryKeys = [DictionaryKey]()
    var httpResponses = [HTTPResponse]()
    var httpParameters = [HTTPParameter]()
    var httpBody: HTTPBody? = nil
    var returns = [Return]()
    var `throws` = [Throw]()
    var otherTags = [SimpleTag]()
    var possiblePropertyListValues = [PropertyListPossibleValuesSection.PossibleValue]()

    init() {}
    
    mutating func visitDocument(_ document: Document) -> Markup? {
        // Rewrite top level "- Note:" list elements to Note Aside elements. This happens during a Document level visit because the document is
        // the parent of the top level UnorderedList and is where the Aside elements should be added to become a sibling to the UnorderedList.
        var result = [Markup]()

        for child in document.children {
            // Only rewrite top-level unordered lists. Anything else is unmodified.
            guard let unorderedList = child as? UnorderedList else {
                result.append(child)
                continue
            }

            // Separate all the "- Note:" elements from the other list items.
            let (noteItems, otherListItems) = unorderedList.listItems.categorize(where: { item -> [BlockMarkup]? in
                guard let tagName = item.extractTag()?.rawTag.lowercased(),
                      Aside.Kind.allCases.contains(where: { $0.rawValue.lowercased() == tagName })
                else {
                    return nil
                }
                return Array(item.blockChildren)
            })

            // Add the unordered list with the filtered children first.
            result.append(UnorderedList(otherListItems))

            // Then, add the Note asides as siblings after the list they belonged to
            for noteDescription in noteItems {
                result.append(BlockQuote(noteDescription))
            }
        }

        // After extracting the "- Note:" list elements, proceed to visit all markup to do local rewrites.
        return Document(result.compactMap { visit($0) as? BlockMarkup })
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> Markup? {
        var newItems = [ListItem]()
        for item in unorderedList.listItems {
            guard let newItem = visit(item) as? ListItem else {
                continue
            }
            newItems.append(newItem)
        }
        guard !newItems.isEmpty else {
            return nil
        }
        return UnorderedList(newItems)
    }
    
    mutating func visitListItem(_ listItem: ListItem) -> Markup? {
        /*
         This rewriter only extracts list items that are at the "top level", i.e.:

         Document
         List
         ListItem <- These and no deeper

         Any further nesting is left alone and treated as a normal list item.
         */
        do {
            guard let parent = listItem.parent,
                  parent.parent == nil || parent.parent is Document else {
                return listItem
            }
        }

        guard let extractedTag = listItem.extractTag() else {
            return listItem
        }
        
        switch extractedTag.knownTag {
        case .returns:
            // - Returns: ...
            returns.append(.init(extractedTag))
            
        case .throws:
            // "Throws" asides are currently (still) parsed as blockquote-style asides
            return listItem
            
        case .parameter(let name):
            // - Parameter x: ...
            parameters.append(.init(extractedTag, name: name, isStandalone: true))
            
        case .parameters:
            // - Parameters:
            //   - x: ...
            //   - y: ...
            parameters.append(contentsOf: listItem.extractInnerTagOutline().map { .init($0, name: $0.rawTag, isStandalone: false) })
            
        case .dictionaryKey(let name):
            // - DictionaryKey x: ...
            dictionaryKeys.append(.init(extractedTag, name: name))
            
        case .dictionaryKeys:
            // - DictionaryKeys:
            //   - x: ...
            //   - y: ...
            dictionaryKeys.append(contentsOf: listItem.extractInnerTagOutline().map { .init($0, name: $0.rawTag) })
        
        case .possibleValue(let name):
            // - DictionaryKey x: ...
            possiblePropertyListValues.append(.init(extractedTag, name: name))
            
        case .possibleValues:
            // - DictionaryKeys:
            //   - x: ...
            //   - y: ...
            possiblePropertyListValues.append(contentsOf: listItem.extractInnerTagOutline().map { .init($0, name: $0.rawTag) })
            
        case .httpResponse(let name):
            // - HTTPResponse x: ...
            httpResponses.append(.init(extractedTag, name: name))
            
        case .httpResponses:
            // - HTTPResponses:
            //   - x: ...
            //   - y: ...
            httpResponses.append(contentsOf: listItem.extractInnerTagOutline().map { .init($0, name: $0.rawTag) })
            
        case .httpBody:
            // - HTTPBody: ...
            if httpBody == nil {
                httpBody = HTTPBody(mediaType: nil, contents: extractedTag.contents)
            } else {
                httpBody?.contents = extractedTag.contents
            }
            
        case .httpParameter(let name):
            // - HTTPParameter x: ...
            httpParameters.append(.init(extractedTag, name: name))
            
        case .httpParameters:
            // - HTTPParameters:
            //   - x: ...
            //   - y: ...
            httpParameters.append(contentsOf: listItem.extractInnerTagOutline().map { .init($0, name: $0.rawTag)})
            
        case .httpBodyParameter(let name):
            // - HTTPBodyParameter x: ...
            let parameter = HTTPParameter(extractedTag, name: name)
            if httpBody == nil {
                httpBody = HTTPBody(mediaType: nil, contents: [], parameters: [parameter], symbol: nil)
            } else {
                httpBody?.parameters.append(parameter)
            }
            
        case .httpBodyParameters:
            // - HTTPBodyParameters:
            //   - x: ...
            //   - y: ...
            let parameters = listItem.extractInnerTagOutline().map { HTTPParameter($0, name: $0.rawTag) }
            if httpBody == nil {
                httpBody = HTTPBody(mediaType: nil, contents: [], parameters: parameters, symbol: nil)
            } else {
                httpBody?.parameters.append(contentsOf: parameters)
            }
            
        case nil where simpleListItemTags.contains(extractedTag.rawTag.lowercased()):
            otherTags.append(.init(extractedTag, name: extractedTag.rawTag))
            
        case nil:
            // No match, leave this list item alone
            return listItem
        }
        
        // Return `nil` to indicate that this list item was extracted as a tag.
        return nil
    }

    mutating func visitDoxygenParameter(_ doxygenParam: DoxygenParameter) -> Markup? {
        parameters.append(Parameter(doxygenParam))
        return nil
    }

    mutating func visitDoxygenReturns(_ doxygenReturns: DoxygenReturns) -> Markup? {
        returns.append(Return(doxygenReturns))
        return nil
    }
}

// MARK: Extracting tags information

/// Information about an extracted tag
private struct ExtractedTag {
    /// The raw name of the extracted tag
    var rawTag: String
    /// A known type of tag
    var knownTag: KnownTag?
    /// The range of the raw tag text
    var tagRange: SourceRange?
    /// The complete content related to this tag
    var contents: [Markup]
    /// The range of the tag and its content
    var range: SourceRange?
    
    init(rawTag: String, tagRange: SourceRange?, contents: [Markup], range: SourceRange?) {
        self.rawTag = rawTag
        self.knownTag = .init(rawTag)
        self.tagRange = tagRange
        self.contents = contents
        self.range = range
    }
    
    enum KnownTag {
        case returns
        case `throws`
        case parameter(String)
        case parameters
        
        case dictionaryKey(String)
        case dictionaryKeys
        case possibleValue(String)
        case possibleValues
        
        case httpBody
        case httpResponse(String)
        case httpResponses
        case httpParameter(String)
        case httpParameters
        case httpBodyParameter(String)
        case httpBodyParameters
        
        init?(_ string: String) {
            let components = string.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            switch components.first?.lowercased() {
            case "returns":
                self = .returns
            case "throws":
                self = .throws
            case "parameter" where components.count == 2:
                self = .parameter(String(components.last!))
            case "parameters":
                self = .parameters
            case "dictionarykey" where components.count == 2:
                self = .dictionaryKey(String(components.last!))
            case "dictionarykeys":
                self = .dictionaryKeys
            case "possiblevalue" where components.count == 2:
                self = .possibleValue(String(components.last!))
            case "possiblevalues":
                self = .possibleValues
            case "httpbody":
                self = .httpBody
            case "httpresponse" where components.count == 2:
                self = .httpResponse(String(components.last!))
            case "httpresponses":
                self = .httpResponses
            case "httpparameter" where components.count == 2:
                self = .httpParameter(String(components.last!))
            case "httpparameters":
                self = .httpParameters
            case "httpbodyparameter" where components.count == 2:
                self = .httpBodyParameter(String(components.last!))
            case "httpbodyparameters":
                self = .httpBodyParameters
            default:
                return nil
            }
        }
    }
}

private extension ListItem {
    func extractTag() -> ExtractedTag? {
        guard childCount > 0,
              let paragraph = child(at: 0) as? Paragraph,
              let (name, nameRange, remainderOfFirstParagraph) = paragraph.inlineChildren.splitNameAndContent()
        else {
            return nil
        }
        
        return ExtractedTag(rawTag: name, tagRange: nameRange, contents: remainderOfFirstParagraph + children.dropFirst(), range: range)
    }
    
    func extractInnerTagOutline() -> [ExtractedTag] {
        var tags: [ExtractedTag] = []
        for child in children {
            // The list `- TagName:` should have one child, a list of tags.
            guard let list = child as? UnorderedList else {
                // If it's not, that content is dropped.
                continue
            }
            
            // Those sublist items are assumed to be a valid `- ___: ...` tag form or else they are dropped.
            for child in list.children {
                guard let listItem = child as? ListItem, let extractedTag = listItem.extractTag() else {
                    continue
                }
                tags.append(extractedTag)
            }
        }
        return tags
    }
}

private extension Sequence<InlineMarkup> {
    func splitNameAndContent() -> (name: String, nameRange: SourceRange?, content: [Markup])? {
        var iterator = makeIterator()
        guard let initialTextNode = iterator.next() as? Text else {
            return nil
        }

        let initialText = initialTextNode.string
        guard let colonIndex = initialText.firstIndex(of: ":") else {
            return nil
        }

        let nameStartIndex = initialText[...colonIndex].firstIndex(where: { $0 != " " }) ?? initialText.startIndex
        let tagName = initialText[nameStartIndex..<colonIndex]
        guard !tagName.isEmpty else {
            return nil
        }
        let remainingInitialText = initialText.suffix(from: initialText.index(after: colonIndex)).drop { $0 == " " }

        var newInlineContent: [InlineMarkup] = [Text(String(remainingInitialText))]
        while let more = iterator.next() {
            newInlineContent.append(more)
        }
        let newContent: [Markup] = [Paragraph(newInlineContent)]
        
        let nameRange: SourceRange? = initialTextNode.range.map { fullRange in
            var start = fullRange.lowerBound
            start.column += initialText.utf8.distance(from: initialText.startIndex, to: nameStartIndex)
            var end = start
            end.column += tagName.utf8.count
            return start ..< end
        }
        
        return (String(tagName), nameRange, newContent)
    }
}

// MARK: Creating tag types

private extension ExtractedTag {
    func nameRange(name: String) -> SourceRange? {
        if name == rawTag {
            return tagRange
        } else {
            return tagRange.map { tagRange in
                // For tags like `- TagName someName:`, the extracted tag name is "TagName someName" which means that the name ("someName") is at the end
                let end = tagRange.upperBound
                var start = end
                start.column -= name.utf8.count
                
                return start ..< end
            }
        }
    }
}

private extension Return {
    init(_ tag: ExtractedTag) {
        self.init(contents: tag.contents, range: tag.range)
    }
}

private extension Parameter {
    init(_ tag: ExtractedTag, name: String, isStandalone: Bool) {
        self.init(name: name, nameRange: tag.nameRange(name: name), contents: tag.contents, range: tag.range, isStandalone: isStandalone)
    }
}
  
private extension DictionaryKey {
    init(_ tag: ExtractedTag, name: String) {
        self.init(name: name, contents: tag.contents)
    }
}

private extension PropertyListPossibleValuesSection.PossibleValue {
    init(_ tag: ExtractedTag, name: String) {
        self.init(value: name, contents: tag.contents, nameRange: tag.nameRange(name: name), range: tag.range)
    }
}

private extension HTTPResponse {
    init(_ tag: ExtractedTag, name: String) {
        self.init(statusCode: UInt(name) ?? 0, reason: nil, mediaType: nil, contents: tag.contents)
    }
}

private extension HTTPParameter {
    init(_ tag: ExtractedTag, name: String) {
        self.init(name: name, source: nil, contents: tag.contents)
    }
}

private extension SimpleTag {
    init(_ tag: ExtractedTag, name: String) {
        self.init(tag: name, contents: tag.contents)
    }
}
