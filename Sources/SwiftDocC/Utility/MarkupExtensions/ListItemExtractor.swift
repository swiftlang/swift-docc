/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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
let simpleListItemTags = [
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

extension Collection where Element == InlineMarkup {
    func extractParameter() -> Parameter? {
        guard let initialTextNode = first as? Text else {
            return nil
        }

        let initialText = initialTextNode.string
        guard let colonIndex = initialText.firstIndex(of: ":") else {
            return nil
        }

        let parameterName = initialText.prefix(upTo: colonIndex)
        guard !parameterName.isEmpty else {
            return nil
        }
        let remainingInitialText = initialText.suffix(from: initialText.index(after: colonIndex)).drop { $0 == " " }
        let remainingChildren = self.dropFirst()

        let newContent: [Markup] = [
            Paragraph([Text(String(remainingInitialText))] + Array(remainingChildren))
        ]
        return Parameter(name: String(parameterName), contents: newContent)
    }
}

extension ListItem {

    /**
     Try to extract a tag start from this list item.

     - returns: If the tag was matched, return the remaining content after the match. Otherwise, return `nil`.
     */
    func extractTag(_ tag: String, dropTag: Bool = true) -> [InlineMarkup]? {
        guard let firstParagraph = child(at: 0) as? Paragraph,
              let text = firstParagraph.child(at: 0) as? Text else {
            return nil
        }

        let trimmedText = text.string.drop { char -> Bool in
            guard let scalar = char.unicodeScalars.first else { return false }
            return CharacterSet.whitespaces.contains(scalar)
        }.lowercased()

        if trimmedText.starts(with: tag.lowercased()) {
            var newText = text.string
            if dropTag {
                newText = String(text.string.dropFirst(text.string.count - trimmedText.count + tag.count).drop(while: { $0 == " " }))
            }
            return [Text(newText)] + Array(firstParagraph.inlineChildren.dropFirst(1))
        }

        return nil
    }

    /**
     Extract a "simple tag" from the list of known list item tags.

     Expected form:

     ```markdown
     - todo: ...
     - seeAlso: ...
     ```
     ...etc.
     */
    func extractSimpleTag() -> SimpleTag? {
        for tag in simpleListItemTags {
            if let contents = extractTag(tag + ":") {
                return SimpleTag(tag: tag, contents: contents)
            }
        }
        return nil
    }

    /**
     Extract a standalone parameter description from this list item.

     Expected form:

     ```markdown
     - parameter x: A number.
     ```
     */
    func extractStandaloneParameter() -> Parameter? {
        guard let remainder = extractTag(TaggedListItemExtractor.parameterTag) else {
            return nil
        }
        return remainder.extractParameter()

    }

    /**
     Extracts an outline of parameters from a sublist underneath this list item.

     Expected form:

     ```markdown
     - Parameters:
     - x: a number
     - y: a number
     ```

     > Warning: Content underneath `- Parameters` that doesn't match this form will be dropped.
     */
    func extractParameterOutline() -> [Parameter]? {
        guard extractTag(TaggedListItemExtractor.parametersTag + ":") != nil else {
            return nil
        }

        var parameters = [Parameter]()

        for child in children {
            // The list `- Parameters:` should have one child, a list of parameters.
            guard let parameterList = child as? UnorderedList else {
                // If it's not, that content is dropped.
                continue
            }

            // Those sublist items are assumed to be a valid `- ___: ...` parameter form or else they are dropped.
            for child in parameterList.children {
                guard let listItem = child as? ListItem,
                      let firstParagraph = listItem.child(at: 0) as? Paragraph,
                      let parameter = Array(firstParagraph.inlineChildren).extractParameter() else {
                    continue
                }
                // Don't forget the rest of the content under this parameter list item.
                let contents = parameter.contents + Array(listItem.children.dropFirst(1))

                parameters.append(Parameter(name: parameter.name, contents: contents))
            }
        }
        return parameters
    }

    /**
     Extract a return description from a list item.

     Expected form:

     ```markdown
     - returns: ...
     ```
     */
    func extractReturnDescription() -> Return? {
        guard let remainder = extractTag(TaggedListItemExtractor.returnsTag + ":") else {
            return nil
        }
        return Return(contents: [Paragraph(remainder)])
    }

    /**
     Extract a throw description from a list item.

     Expected form:

     ```markdown
     - throws: ...
     ```
     */
    func extractThrowsDescription() -> Throw? {
        guard let remainder = extractTag(TaggedListItemExtractor.throwsTag + ":") else {
            return nil
        }
        return Throw(contents: remainder)
    }
}

struct TaggedListItemExtractor: MarkupRewriter {
    static let returnsTag = "returns"
    static let throwsTag = "throws"
    static let parameterTag = "parameter"
    static let parametersTag = "parameters"

    var parameters = [Parameter]()
    var returns = [Return]()
    var `throws` = [Throw]()
    var otherTags = [SimpleTag]()

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
            let (noteItems, otherListItems) = unorderedList.listItems.categorize(where: { item in
                return Aside.Kind.allCases.mapFirst {
                    item.extractTag($0.rawValue + ": ", dropTag: false)
                }
            })

            // Add the unordered list with the filtered children first.
            result.append(UnorderedList(otherListItems))

            // Then, add the Note asides as siblings after the list they belonged to
            for noteDescription in noteItems {
                result.append(BlockQuote(Paragraph(noteDescription)))
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

        //Try to extract one of the several specially interpreted list items.

        if let returnDescription = listItem.extractReturnDescription() {
            // - returns: ...
            returns.append(returnDescription)
            return nil
        // "Throws" asides are currently parsed as blockquote-style asides
        // } else if let throwsDescription = listItem.extractThrowsDescription() {
        //     `throws`.append(throwsDescription)
        //     return nil
        } else if let parameterDescriptions = listItem.extractParameterOutline() {
            // - Parameters:
            //   - x: ...
            //   - y: ...
            parameters.append(contentsOf: parameterDescriptions)
            return nil
        } else if let parameterDescription = listItem.extractStandaloneParameter() {
            // - parameter x: ...
            parameters.append(parameterDescription)
            return nil
        } else if let simpleTag = listItem.extractSimpleTag() {
            // - todo: ...
            // etc.
            otherTags.append(simpleTag)
            return nil
        }

        // No match; leave this list item alone.
        return listItem
    }
}
