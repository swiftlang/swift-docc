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

extension Sequence<InlineMarkup> {
    private func splitNameAndContent() -> (name: String, nameRange: SourceRange?, content: [Markup], range: SourceRange?)? {
        var iterator = makeIterator()
        guard let initialTextNode = iterator.next() as? Text else {
            return nil
        }

        let initialText = initialTextNode.string
        guard let colonIndex = initialText.firstIndex(of: ":") else {
            return nil
        }

        let nameStartIndex = initialText[...colonIndex].lastIndex(of: " ").map { initialText.index(after: $0) } ?? initialText.startIndex
        let parameterName = initialText[nameStartIndex..<colonIndex]
        guard !parameterName.isEmpty else {
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
            end.column += parameterName.utf8.count
            return start ..< end
        }
        
        let itemRange: SourceRange? = sequence(first: initialTextNode as Markup, next: { $0.parent })
            .mapFirst(where: { $0 as? ListItem })?.range
        
        return (
            String(parameterName),
            nameRange,
            newContent,
            itemRange
        )
    }
    
    func extractParameter(standalone: Bool) -> Parameter? {
        if let (name, nameRange, content, itemRange) = splitNameAndContent() {
            return Parameter(name: name, nameRange: nameRange, contents: content, range: itemRange, isStandalone: standalone)
        }
        return nil
    }
    
    func extractDictionaryKey() -> DictionaryKey? {
        if let (name, _, content, _) = splitNameAndContent() {
            return DictionaryKey(name: name, contents: content)
        }
        return nil
    }
    
    func extractHTTPParameter() -> HTTPParameter? {
        if let (name, _, content, _) = splitNameAndContent() {
            return HTTPParameter(name: name, source: nil, contents: content)
        }
        return nil
    }
    
    func extractHTTPBodyParameter() -> HTTPParameter? {
        if let (name, _, content, _) = splitNameAndContent() {
            return HTTPParameter(name: name, source: "body", contents: content)
        }
        return nil
    }
    
    func extractHTTPResponse() -> HTTPResponse? {
        if let (name, _, content, _) = splitNameAndContent() {
            let statusCode = UInt(name) ?? 0
            return HTTPResponse(statusCode: statusCode, reason: nil, mediaType: nil, contents: content)
        }
        return nil
    }
    
    func extractPossibleValueTag() -> PossibleValueTag? {
        if let (value, nameRange, content, itemRange) = splitNameAndContent() {
            return PossibleValueTag(value: value, contents: content, nameRange: nameRange, range: itemRange)
        }
        return nil
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
     Extract a standalone dictionary key description from this list item.

     Expected form:

     ```markdown
     - dictionaryKey x: A number.
     ```
     */
    func extractStandaloneDictionaryKey() -> DictionaryKey? {
        guard let remainder = extractTag(TaggedListItemExtractor.dictionaryKeyTag) else {
            return nil
        }
        return remainder.extractDictionaryKey()
    }

    /**
     Extracts an outline of dictionary keys from a sublist underneath this list item.

     Expected form:

     ```markdown
     - DictionaryKeys:
       - x: a number
       - y: a number
     ```

     > Warning: Content underneath `- DictionaryKeys` that doesn't match this form will be dropped.
     */
    func extractDictionaryKeyOutline() -> [DictionaryKey]? {
        guard extractTag(TaggedListItemExtractor.dictionaryKeysTag + ":") != nil else {
            return nil
        }

        var dictionaryKeys = [DictionaryKey]()

        for child in children {
            // The list `- DictionaryKeys:` should have one child, a list of dictionary keys.
            guard let dictionaryKeysList = child as? UnorderedList else {
                // If it's not, that content is dropped.
                continue
            }

            // Those sublist items are assumed to be a valid `- ___: ...` dictionary key form or else they are dropped.
            for child in dictionaryKeysList.children {
                guard let listItem = child as? ListItem,
                      let firstParagraph = listItem.child(at: 0) as? Paragraph,
                      let dictionaryKey = Array(firstParagraph.inlineChildren).extractDictionaryKey() else {
                    continue
                }
                // Don't forget the rest of the content under this dictionary key list item.
                let contents = dictionaryKey.contents + Array(listItem.children.dropFirst(1))

                dictionaryKeys.append(DictionaryKey(name: dictionaryKey.name, contents: contents))
            }
        }
        return dictionaryKeys
    }
    
    /**
    Extract a standalone possible value description from this list item.
     
    Expected form:
     
    ```markdown
    - PossibleValue x: The meaning of x
    ```
    */
    func extractStandalonePossibleValueTag() -> PossibleValueTag? {
        guard let remainder = extractTag(TaggedListItemExtractor.possibleValueTag) else {
            return nil
        }
        return remainder.extractPossibleValueTag()
    }
    
    /**
     Extracts an outline of possible values from a sublist underneath this list item.
     
     Expected form:
     
     ```markdown
     - PossibleValues:
       - x: Meaning of x
       - y: Meaning of y
     ```
     */
    func extractPossibleValueOutline() -> [PossibleValueTag]? {
        guard extractTag(TaggedListItemExtractor.possibleValuesTag + ":") != nil else {
           return nil
        }
        var possibleValues = [PossibleValueTag]()
        
        for child in children {
            // The list `- PossibleValues:` should have one child, a list of values.
            guard let possibleValuesList = child as? UnorderedList else {
                // If it's not, that content is dropped.
                continue
            }

            // Those sublist items are assumed to be a valid `- ___: ...` possible value form or else they are dropped.
            for child in possibleValuesList.children {
                guard let listItem = child as? ListItem,
                      let firstParagraph = listItem.child(at: 0) as? Paragraph,
                      let possibleValue = Array(firstParagraph.inlineChildren).extractPossibleValueTag() else {
                    continue
                }
                // Don't forget the rest of the content under this possible value list item.
                let contents = possibleValue.contents + Array(listItem.children.dropFirst(1))
                possibleValues.append(PossibleValueTag(value: possibleValue.value, contents: contents, nameRange: possibleValue.nameRange, range: possibleValue.range))
            }
        }
        return possibleValues
    }

    /**
     Extract a standalone HTTP parameter description from this list item.

     Expected form:

     ```markdown
     - httpParameter x: A number.
     ```
     */
    func extractStandaloneHTTPParameter() -> HTTPParameter? {
        guard let remainder = extractTag(TaggedListItemExtractor.httpParameterTag) else {
            return nil
        }
        return remainder.extractHTTPParameter()
    }

    /**
     Extracts an outline of HTTP parameters from a sublist underneath this list item.

     Expected form:

     ```markdown
     - HTTPParameters:
       - x: a number
       - y: another
     ```

     > Warning: Content underneath `- HTTPParameters` that doesn't match this form will be dropped.
     */
    func extractHTTPParameterOutline() -> [HTTPParameter]? {
        guard extractTag(TaggedListItemExtractor.httpParametersTag + ":") != nil else {
            return nil
        }

        var parameters = [HTTPParameter]()

        for child in children {
            // The list `- HTTPParameters:` should have one child, a list of parameters.
            guard let parametersList = child as? UnorderedList else {
                // If it's not, that content is dropped.
                continue
            }

            // Those sublist items are assumed to be a valid `- ___: ...` parameter form or else they are dropped.
            for child in parametersList.children {
                guard let listItem = child as? ListItem,
                      let firstParagraph = listItem.child(at: 0) as? Paragraph,
                      let parameter = Array(firstParagraph.inlineChildren).extractHTTPParameter() else {
                    continue
                }
                // Don't forget the rest of the content under this list item.
                let contents = parameter.contents + Array(listItem.children.dropFirst(1))

                parameters.append(HTTPParameter(name: parameter.name, source:parameter.source, contents: contents))
            }
        }
        return parameters
    }

    /**
     Extract a standalone HTTP body parameter description from this list item.

     Expected form:

     ```markdown
     - HTTPBodyParameter x: A number.
     ```
     */
    func extractStandaloneHTTPBodyParameter() -> HTTPParameter? {
        guard let remainder = extractTag(TaggedListItemExtractor.httpBodyParameterTag) else {
            return nil
        }
        return remainder.extractHTTPBodyParameter()
    }
    
    /**
     Extracts an outline of HTTP parameters from a sublist underneath this list item.

     Expected form:

     ```markdown
     - HTTPBodyParameters:
       - x: a number
       - y: another
     ```

     > Warning: Content underneath `- HTTPBodyParameters` that doesn't match this form will be dropped.
     */
    func extractHTTPBodyParameterOutline() -> [HTTPParameter]? {
        guard extractTag(TaggedListItemExtractor.httpBodyParametersTag + ":") != nil else {
            return nil
        }

        var parameters = [HTTPParameter]()

        for child in children {
            // The list `- HTTPBodyParameters:` should have one child, a list of parameters.
            guard let parametersList = child as? UnorderedList else {
                // If it's not, that content is dropped.
                continue
            }

            // Those sublist items are assumed to be a valid `- ___: ...` parameter form or else they are dropped.
            for child in parametersList.children {
                guard let listItem = child as? ListItem,
                      let firstParagraph = listItem.child(at: 0) as? Paragraph,
                      let parameter = Array(firstParagraph.inlineChildren).extractHTTPParameter() else {
                    continue
                }
                // Don't forget the rest of the content under this list item.
                let contents = parameter.contents + Array(listItem.children.dropFirst(1))

                parameters.append(HTTPParameter(name: parameter.name, source:"body", contents: contents))
            }
        }
        return parameters
    }
    
    /**
     Extract a standalone HTTP response description from this list item.

     Expected form:

     ```markdown
     - httpResponse 200: A number.
     ```
     */
    func extractStandaloneHTTPResponse() -> HTTPResponse? {
        guard let remainder = extractTag(TaggedListItemExtractor.httpResponseTag) else {
            return nil
        }
        return remainder.extractHTTPResponse()
    }

    /**
     Extracts an outline of dictionary keys from a sublist underneath this list item.

     Expected form:

     ```markdown
     - HTTPResponses:
       - 200: a status code
       - 204: another status code
     ```

     > Warning: Content underneath `- HTTPResponses` that doesn't match this form will be dropped.
     */
    func extractHTTPResponseOutline() -> [HTTPResponse]? {
        guard extractTag(TaggedListItemExtractor.httpResponsesTag + ":") != nil else {
            return nil
        }

        var responses = [HTTPResponse]()

        for child in children {
            // The list `- HTTPResponses:` should have one child, a list of responses.
            guard let responseList = child as? UnorderedList else {
                // If it's not, that content is dropped.
                continue
            }

            // Those sublist items are assumed to be a valid `- ___: ...` response form or else they are dropped.
            for child in responseList.children {
                guard let listItem = child as? ListItem,
                      let firstParagraph = listItem.child(at: 0) as? Paragraph,
                      let response = Array(firstParagraph.inlineChildren).extractHTTPResponse() else {
                    continue
                }
                // Don't forget the rest of the content under this dictionary key list item.
                let contents = response.contents + Array(listItem.children.dropFirst(1))

                responses.append(HTTPResponse(statusCode: response.statusCode, reason: response.reason, mediaType: response.mediaType, contents: contents))
            }
        }
        return responses
    }

    /**
     Extract a standalone parameter description from this list item.

     Expected form:

     ```markdown
     - parameter x: A number.
     ```
     */
    func extractStandaloneParameter() -> Parameter? {
        guard extractTag(TaggedListItemExtractor.parameterTag) != nil else {
            return nil
        }
        // Don't use the return value from `extractTag` here. It drops the range and source information from the markup which means that we can't present diagnostics about the parameter.
        return (child(at: 0) as? Paragraph)?.inlineChildren.extractParameter(standalone: true)
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
                      var parameter = Array(firstParagraph.inlineChildren).extractParameter(standalone: false) else {
                    continue
                }
                // Don't forget the rest of the content under this parameter list item.
                parameter.contents += Array(listItem.children.dropFirst(1))

                parameters.append(parameter)
            }
        }
        return parameters
    }

    /**
     Extract an HTTP body description from a list item.

     Expected form:

     ```markdown
     - httpBody: ...
     ```
     */
    func extractHTTPBody() -> HTTPBody? {
        guard let remainder = extractTag(TaggedListItemExtractor.httpBodyTag + ":") else {
            return nil
        }
        return HTTPBody(mediaType: nil, contents: [Paragraph(remainder)])
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
        return Return(contents: [Paragraph(remainder)], range: range)
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
    static let dictionaryKeyTag = "dictionarykey"
    static let dictionaryKeysTag = "dictionarykeys"
    
    static let httpBodyTag = "httpbody"
    static let httpResponseTag = "httpresponse"
    static let httpResponsesTag = "httpresponses"
    static let httpParameterTag = "httpparameter"
    static let httpParametersTag = "httpparameters"
    static let httpBodyParameterTag = "httpbodyparameter"
    static let httpBodyParametersTag = "httpbodyparameters"
    
    static let possibleValueTag = "possiblevalue"
    static let possibleValuesTag = "possiblevalues"

    var parameters = [Parameter]()
    var dictionaryKeys = [DictionaryKey]()
    var httpResponses = [HTTPResponse]()
    var httpParameters = [HTTPParameter]()
    var httpBody: HTTPBody? = nil
    var returns = [Return]()
    var `throws` = [Throw]()
    var otherTags = [SimpleTag]()
    var possibleValues = [PossibleValueTag]()

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
        } else if let dictionaryKeyDescription = listItem.extractDictionaryKeyOutline() {
            // - DictionaryKeys:
            //   - x: ...
            //   - y: ...
            dictionaryKeys.append(contentsOf: dictionaryKeyDescription)
            return nil
        } else if let dictionaryKeyDescription = listItem.extractStandaloneDictionaryKey() {
            // - dictionaryKey x: ...
            dictionaryKeys.append(dictionaryKeyDescription)
            return nil
        } else if let httpParameterDescription = listItem.extractHTTPParameterOutline() {
            // - HTTPParameters:
            //   - x: ...
            //   - y: ...
            httpParameters.append(contentsOf: httpParameterDescription)
            return nil
        } else if let httpParameterDescription = listItem.extractStandaloneHTTPParameter() {
            // - HTTPParameter x: ...
            httpParameters.append(httpParameterDescription)
            return nil
        } else if let httpBodyDescription = listItem.extractHTTPBody() {
            // - httpBody: ...
            if httpBody == nil {
                httpBody = httpBodyDescription
            } else {
                httpBody?.contents = httpBodyDescription.contents
            }
            return nil
        } else if let httpBodyParameterDescription = listItem.extractHTTPBodyParameterOutline() {
            // - HTTPBodyParameters:
            //   - x: ...
            //   - y: ...
            if httpBody == nil {
                httpBody = HTTPBody(mediaType: nil, contents: [], parameters: httpBodyParameterDescription, symbol: nil)
            } else {
                httpBody?.parameters.append(contentsOf: httpBodyParameterDescription)
            }
            return nil
        } else if let httpBodyParameterDescription = listItem.extractStandaloneHTTPBodyParameter() {
            // - HTTPBodyParameter x: ...
            if httpBody == nil {
                httpBody = HTTPBody(mediaType: nil, contents: [], parameters: [httpBodyParameterDescription], symbol: nil)
            } else {
                httpBody?.parameters.append(httpBodyParameterDescription)
            }
            return nil
        } else if let httpResponseDescription = listItem.extractHTTPResponseOutline() {
            // - HTTPResponses:
            //   - x: ...
            //   - y: ...
            httpResponses.append(contentsOf: httpResponseDescription)
            return nil
        } else if let httpResponseDescription = listItem.extractStandaloneHTTPResponse() {
            // - HTTPResponse x: ...
            httpResponses.append(httpResponseDescription)
            return nil
        } else if let simpleTag = listItem.extractSimpleTag() {
            // - todo: ...
            // etc.
            otherTags.append(simpleTag)
            return nil
        } else if let possibleValueOutline = listItem.extractPossibleValueOutline() {
            // - PossibleValues:
            //   - x: ...
            //   - y: ...
            possibleValues.append(contentsOf: possibleValueOutline)
            return nil
        } else if let possibleValueTag = listItem.extractStandalonePossibleValueTag() {
            // - PossibleValue x:
            possibleValues.append(possibleValueTag)
            return nil
        }

        // No match; leave this list item alone.
        return listItem
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
