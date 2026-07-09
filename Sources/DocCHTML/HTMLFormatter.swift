/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import struct Foundation.Data // Used as a return value by the formatter

/// A type that formats an hierarchy of HTML nodes into serialized HTML 5 data.
/// 
/// ## Topics
/// 
/// ### Formatting
/// - ``format(_:options:)``
///
/// ### Customizing the output
/// - ``Options``
package struct HTMLFormatter {
    /// The byte buffer that the formatter modifies as it formats the given HTML.
    private var buffer: [UInt8]
    /// Options that customizes aspects of the formatter's output.
    private let options: Options
    
    /// Options that customizes aspects of the formatter's output.
    package struct Options: OptionSet {
        package let rawValue: Int
        package init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Configures the formatter to "pretty print" the HTML hierarchy.
        ///
        /// For example:
        /// ```
        /// <dl>
        ///   <dt>range</dt>
        ///   <dd>
        ///     <p>The range in which to create a random value.</p>
        ///   </dd>
        /// </dl>
        /// ```
        package static let prettyPrint = Self(rawValue: 1 << 0)
        
        /// Configures the formatter to omit quotes around attribute values that don't need to be quoted according to the HTML specification.
        ///
        /// For example: `<nav id=breadcrumbs>` or `<ul id=availability>`.
        package static let omitOptionalQuotesAroundAttributeValues = Self(rawValue: 1 << 1)
        
        /// Configures the formatter to omit end tags for elements and situations where the end of the tag can be inferred from what comes after, according to the HTML specification.
        ///
        /// For example:
        /// ```
        /// <dl><dt>range<dd><p>The range in which to create a random value.</dl>
        /// ```
        /// or combined with the ``prettyPrint`` option:
        /// ```
        /// <dl>
        ///   <dt>range
        ///   <dd>
        ///     <p>The range in which to create a random value.
        /// </dl>
        /// ```
        package static let omitOptionalEndTags = Self(rawValue: 1 << 2)
    }
    
    /// Formats a HTML node into serialized HTML 5 data.
    ///
    /// - Parameters:
    ///   - document: The HTML node that the formatter should format.
    ///   - options: Options for how the formatter should format the serialized data.
    /// - Returns: The serialized HTML 5 data.
    package static func format(_ node: HTMLNode, options: Options = []) -> Data {
        // Even small pages are often close to 512 bytes long. Reserve that capacity to avoid a few reallocations of the formatter's buffer.
        var encoder = Self(initialBufferCapacity: 512, options: options)
        
        if node._tag == .html {
            // Include the document type when encoding a full page.
            encoder._append("<!DOCTYPE html>\n")
        }
        
        if node._tag == .pre {
            // Whitespace is significant for `<pre>` elements; so format that sub-hierarchy _without_ pretty printing.
            encoder._compactFormat(node, nextElementTag: nil)
        } else if options.contains(.prettyPrint) {
            encoder._prettyFormat(node, state: .init())
        } else {
            encoder._compactFormat(node, nextElementTag: nil)
        }
        
        return Data(encoder.buffer)
    }
    
    /// Creates a new formatter with the given initial buffer capacity and options.
    ///
    /// This initializer is private. The only code that can create a formatter is the static ``format(_:options:)`` method.
    private init(initialBufferCapacity: Int, options: Options) {
        self.buffer = [UInt8]()
        self.buffer.reserveCapacity(initialBufferCapacity)
        self.options = options
    }
    
    // MARK: Compact formatting
        
    /// Compactly formats the given HTML element hierarchy.
    ///
    /// For example;
    /// ```
    /// <dl><dt>range</dt><dd><p>The range in which to create a random value.</p></dd></dl>
    /// ```
    ///
    /// - Parameters:
    ///   - element: The HTML element to format compactly.
    ///   - nextElementTag: The tag of the next element in the element's container, or `nil` if there are no more elements in the element's container.
    private mutating func _compactFormat(_ element: HTMLNode, nextElementTag: HTMLNode._Tag?) {
        switch element._storage {
        case .text(let text):
            _format(text: text)
            
        case .element(let tag, let attributes, let contents):
            // Start tag
            let shouldSelfClose = contents.isEmpty
            _formatStartTag(tag, attributes: attributes, selfClosing: shouldSelfClose)
            guard !shouldSelfClose else {
                // Don't create an end tag if the start tag was already self-closing.
                return
            }
            
            // Contents
            for index in contents.indices {
                let node = contents[index]
                let nextIndex = index &+ 1 // The index will exceed `contents.endIndex` long before it overflows.
                _compactFormat(node, nextElementTag: nextIndex < contents.endIndex ? contents[nextIndex]._tag : nil)
            }
                
            // End tag
            if options.contains(.omitOptionalEndTags), tag.canOmitEndTag(whenFollowedBy: nextElementTag) {
                return
            }
            _formatEndTag(tag)
            
        case .voidElement(let tag, let attributes):
            _format(voidElement: tag, attributes: attributes)
        }
    }
    
    // MARK: Pretty print formatting
    
    /// Common indentation data, allocated once.
    private static let _indentationData: [UInt8] = {
        // Stop indenting further after 64 levels of indentation
        var data = [UInt8](repeating: .init(ascii: " "), count: 128)
        data[0] = .init(ascii: "\n")
        return data
    }()
    
    /// Private state that the formatter uses to pretty-print the HTML element hierarchy.
    private struct PrettyPrintingState {
        /// The current depth in the HTML element hierarchy.
        var depth: UInt8 = 0
        /// A Boolean value that s `true` if the formatter should place the element on the current line or `false` if the formatter should place the element on a new line.
        var presentOnCurrentLine: Bool = true
        /// The tag of the next element in the element's container, or `nil` if there are no more elements in the element's container.
        var nextElementTag: HTMLNode._Tag? = nil
    }
    
    /// Compactly formats the given HTML element hierarchy.
    ///
    /// For example:
    /// ```
    /// <dl>
    ///   <dt>range</dt>
    ///   <dd>
    ///     <p>The range in which to create a random value.</p>
    ///   </dd>
    /// </dl>
    /// ```
    ///
    /// - Parameters:
    ///   - element: The HTML element to format compactly.
    ///   - nextElementTag: The tag of the next element in the element's container, or `nil` if there are no more elements in the element's container.
    private mutating func _prettyFormat(_ element: HTMLNode, state: PrettyPrintingState) {
        func appendLineBreakAndIndentation(depth: UInt8 = state.depth) {
            Self._indentationData.withUnsafeBufferPointer {
                buffer.append(contentsOf: $0.prefix(1 /* the newline */ &+ Int(depth) &* 2 /* two spaces per indentation level */))
            }
        }
        
        if !state.presentOnCurrentLine {
            appendLineBreakAndIndentation()
        }
        
        switch element._storage {
        case .text(let text):
            _format(text: text)
            
        case .element(let tag, let attributes, let contents):
            // Start tag
            let shouldSelfClose = contents.isEmpty
            _formatStartTag(tag, attributes: attributes, selfClosing: shouldSelfClose)
            guard !shouldSelfClose else {
                // Don't create an end tag if the start tag was already self-closing.
                return
            }
            
            // The details of how to "pretty print" HTML is a matter of opinion.
            // This formatter opts for the following behaviors:
            //
            // 1. Tags, with the exception of text-level semantics, are displayed on their own line; with 2 spaces indentation per level of depth. For example:
            //    ```
            //    <nav id="breadcrumbs">
            //      <ul>
            //        <li>...
            //    ```
            //
            // 2. Tags with only plain textual content display that content on the same line as the tag. For example:
            //    ```
            //    <dt>generator</dt>
            //    <dd>
            //      <p>The random number generator to use when creating the new random value.</p>
            //    </dd>
            //    ```
            // 3. Tags with attributes display plain textual content on a new line. For example:
            //    ```
            //    <p id="abstract">
            //      Returns a random value within the specified range, using the given generator as a source for randomness.
            //    </p>
            //    ```
            // 4. Text-level semantics display on the same line as their surrounding plain textual contents, but on a new line compared to their container. For example:
            //    ```
            //    <h1>
            //      random(<wbr>in:<wbr>using:)
            //    </h1>
            //    ```
            //    or
            //    ```
            //    <p>
            //      Some <b>bold</b> and <i>italicized</i> text.
            //    </p>
            //    ```
            //
            // Additionally the formatter has two special case behaviors that aims to make slight readability refinements for certain content:
            //
            // 1. Anchors (`<a>`) and table cells (`<td>` or `<th>`) with at most one attribute still displays plain textual contents on the same line. For example:
            //    ```
            //    <a href="something">Some text</a>
            //    ```
            //    or
            //    ```
            //    <tr>
            //      <td>One</td>
            //      <td colspan=2>Two</td>
            //    </tr>
            //    ```
            // 2. Anchors within a paragraph of plain text or other text-level semantics display on a separate line from both the run of contents before and after. For example:
            //    ```
            //    <p>
            //      Some <b>bold</b> text before a
            //      <a href="something">link</a>
            //      and some <i>italicized</i> text after.
            //    </p>
            //    ```
            
            let hasAttributeReasonToPresentOnSeparateLine = switch tag {
                case .a, .td, .th: attributes.count > 1
                default:           !attributes.isEmpty
            }
            let firstContents = contents.first! // verified to be non-empty above
            let shouldPresentContentsOnSeparateLine = contents.count > 1 || !firstContents._isText || hasAttributeReasonToPresentOnSeparateLine
            
            var childState = PrettyPrintingState(depth: state.depth &+ 1)
            
            func shouldPresentInline(for contents: HTMLNode) -> Bool {
                switch contents._storage {
                    case .text:
                        true
                    case .element(    let tag, let attributes, _),
                         .voidElement(let tag, let attributes):
                        tag.isTextLevelSemantic && attributes.isEmpty
                }
            }
            if shouldPresentContentsOnSeparateLine, shouldPresentInline(for: firstContents) {
                // Avoid adding _two_ line breaks when both the container and the first element has reasons to add a line break.
                appendLineBreakAndIndentation(depth: childState.depth)
            }
            
            for index in contents.indices {
                let child = contents[index]
                let nextIndex = index &+ 1 // The index will exceed `contents.endIndex` long before it overflows.
                // It's necessary to know what element comes next in the container (if any) to determine when it's allowed to omit the end tag.
                childState.nextElementTag = nextIndex < contents.endIndex ? contents[nextIndex]._tag : nil
                
                // If the previous element presented on its own line and the current line is text, add a line break before the text as well.
                if childState.presentOnCurrentLine || !child._isText {
                    childState.presentOnCurrentLine = shouldPresentInline(for: child)
                }
                
                // Whitespace is significant inside `<pre>` elements; so we switch to formatting that sub-hierarchy _without_ pretty printing.
                if child._tag == .pre {
                    // However, first we add a new line and indentation so that the `<pre>` element starts appropriately indented on a new line.
                    appendLineBreakAndIndentation(depth: childState.depth)
                    _compactFormat(child, nextElementTag: childState.nextElementTag)
                } else {
                    _prettyFormat(child, state: childState)
                }
            }
            
            // End tag
            if options.contains(.omitOptionalEndTags), tag.canOmitEndTag(whenFollowedBy: state.nextElementTag) {
                return
            }
            if shouldPresentContentsOnSeparateLine {
                appendLineBreakAndIndentation()
            }
            _formatEndTag(tag)
            
        case .voidElement(let voidTag, let attributes):
            _format(voidElement: voidTag, attributes: attributes)
        }
    }
    
    /// Append the static string to the formatter's buffer.
    private mutating func _append(_ string: StaticString) {
        string.withUTF8Buffer { buffer.append(contentsOf: $0) }
    }
    /// Appends the tag's string representation to the formatter's buffer.
    private mutating func _append(_ tag: HTMLNode._Tag) {
        var string = tag.rawValue
        string.withUTF8 { buffer.append(contentsOf: $0) }
    }
    
    /// Formats and escapes the given text---for example `x &lt; y`---and appends it to the formatter's buffer.
    private mutating func _format(text: String) {
        // This can be made nicer with UTF8Span when we can require anyAppleOS 26+
        var text = text
        text.withUTF8 {
            var remaining = $0[...]
            
            // Escape any characters that need to be escaped inside of text.
            while let index = remaining.firstIndex(where: \.needsEscapingInHTMLText) {
                // Append the text as-is up to the character that needs to be escaped.
                buffer.append(contentsOf: remaining[..<index])
                // There are only two characters that need to be escaped inside of text.
                _append(remaining[index] == .init(ascii: "&") ? "&amp;" : "&lt;")
                
                remaining = remaining[remaining.index(after: index)...]
            }
            
            buffer.append(contentsOf: remaining)
        }
    }
    
    /// Format's a start tag and its attributes---for example `<nav id="breadcrumbs">`---and appends it to the formatter's buffer.
    private mutating func _formatStartTag(_ tag: HTMLNode._Tag, attributes: [HTMLNode.Attribute], selfClosing: Bool) {
        buffer.append(.init(ascii: "<"))
        _append(tag)
        _format(attributes: attributes)
        
        if selfClosing {
            _append("/>")
        } else {
            buffer.append(.init(ascii: ">"))
        }
    }
    
    /// Format's an end tag---for example `</p>`---and appends it to the formatter's buffer.
    private mutating func _formatEndTag(_ tag: HTMLNode._Tag) {
        _append("</")
        _append(tag)
        buffer.append(.init(ascii: ">"))
    }
    
    /// Format's a void tag---for example `<hr>`---and appends it to the formatter's buffer.
    private mutating func _format(voidElement tag: HTMLNode._Tag, attributes: [HTMLNode.Attribute]) {
        buffer.append(.init(ascii: "<"))
        _append(tag)
        _format(attributes: attributes)
        buffer.append(.init(ascii: ">"))
    }
    
    /// Format's a list of attributes---for example `id=something class="one two"`---and appends it to the formatter's buffer.
    private mutating func _format(attributes: [HTMLNode.Attribute]) {
        for attribute in attributes {
            buffer.append(.init(ascii: " "))
            _append(attribute.nameForFormatting)
            
            var value = attribute.valueForFormatting
            guard !value.isEmpty else { continue }
            
            value.withUTF8 {
                var remaining = $0[...]
                
                // If the formatter is configured to omit optional quotes around attribute values; check if this value _needs_ to be quoted.
                guard !options.contains(.omitOptionalQuotesAroundAttributeValues) || remaining.contains(where: \.needsQuotingInHTMLAttribute) else {
                    buffer.append(.init(ascii: "="))
                    // If the value doesn't need quoting, the only escapable character is `&`.
                    while let index = remaining.firstIndex(of: .init(ascii: "&")) {
                        buffer.append(contentsOf: remaining[..<index])
                        _append("&amp;")
                        remaining = remaining[remaining.index(after: index)...]
                    }
                    buffer.append(contentsOf: remaining)
                    return
                }
                
                // Quote this attribute
                _append("=\"")
                defer {
                    buffer.append(.init(ascii: "\""))
                }
                
                while let index = remaining.firstIndex(where: \.needsEscapingInHTMLAttribute) {
                    // Append the text as-is up to the character that needs to be escaped.
                    buffer.append(contentsOf: remaining[..<index])
                    // Because the formatter uses `"` to quote attribute values; it only need to escape `&` and `"` in the value.
                    _append(remaining[index] == .init(ascii: "&") ? "&amp;" : "&quot;")
                    
                    remaining = remaining[remaining.index(after: index)...]
                }
                buffer.append(contentsOf: remaining)
            }
        }
    }
}

private extension UTF8.CodeUnit {
    /// A Boolean value that determines whether this UTF-8 code unit needs to be escaped if it appears in the textual contents of an HTML element.
    ///
    /// Various sections of the [HTML specification](https://html.spec.whatwg.org) describes that text may not contain either:
    /// - a less-than sign (`<`)
    /// - an ["ambiguous" ampersand (`&`)](https://html.spec.whatwg.org/#syntax-ambiguous-ampersand).
    ///
    /// Because the formatter inspects each byte individually, it treats every ampersand as "ambiguous".
    ///
    /// - Note: The calling code in the formatter makes assumptions based on this logic.
    var needsEscapingInHTMLText: Bool {
        return self == .init(ascii: "&")
            || self == .init(ascii: "<")
    }
    
    /// A Boolean value that determines whether this UTF-8 code unit needs to be escaped if it appears in the attribute value of an HTML element.
    ///
    /// This is defined in the "Double-quoted attribute value syntax" subsection of the [HTML specification](https://html.spec.whatwg.org/#attributes-2)
    ///
    /// - Note: The calling code in the formatter makes assumptions based on this logic.
    var needsEscapingInHTMLAttribute: Bool {
        return self == .init(ascii: "&")
            || self == .init(ascii: "\"") // Because the formatter uses `"` to quote the attribute value, we don't need to escape `'`.
    }
    
    /// A Boolean value that determines whether this UTF-8 code unit needs to be quoted if it appears in the attribute value of an HTML element.
    ///
    /// An attribute value can remain unquoted if it doesn't contain ASCII whitespace or any of " ' \` = < >
    /// This is defined in the "Unquoted attribute value syntax" subsection of the [HTML specification](https://html.spec.whatwg.org/#attributes-2)
    var needsQuotingInHTMLAttribute: Bool {
        return self == .init(ascii: " " )
            || self == .init(ascii: "\t") // Tab
            || self == .init(ascii: "\n") // New line / Line feed
            || self == .init(ascii: "\r") // Carriage return
            || self == .init(ascii: "\"")
            || self == .init(ascii: "'" )
            || self == .init(ascii: "`" )
            || self == .init(ascii: "=" )
            || self == .init(ascii: "<" )
            || self == .init(ascii: ">" )
    }
}

private extension HTMLNode._Tag {
    /// A Boolean value that determines whether or not an element of this tag is a [text-level semantic](https://html.spec.whatwg.org/#text-level-semantics).
    var isTextLevelSemantic: Bool {
        switch self {
        case .a, .abbr, .b, .bdi, .bdo, .br, .cite, .code, .data, .dfn, .em, .i, .kbd, .mark, .q, .rp, .rt, .ruby, .s, .samp, .small, .span, .strong, .sub, .sup, .time, .u, .var, .wbr:
            true
        default:
            false
        }
    }
    
    /// Determines whether or not an element of this tag can omit its end tag when followed by the given `next` element in the same container.
    ///
    /// Which end tags can be omitted is defined in the [HTML specification](https://html.spec.whatwg.org/#semantics) for each type of element,
    /// and is summarized in the [Optional tags section](https://html.spec.whatwg.org/#optional-tags) of the specification.
    func canOmitEndTag(whenFollowedBy next: Self?) -> Bool {
        switch self {
        case .p:
            switch next {
            case .address, .article, .aside, .blockquote, .details, .dialog, .div, .dl, .fieldset, .figcaption, .figure, .footer, .form, .h1, .h2, .h3, .h4, .h5, .h6, .hgroup, .hr, .main, .menu, .nav, .ol, .p, .pre, .search, .section, .table, .ul, nil:
                true
            default:
                false
            }
            
        case .body:
            true
            
        case .li:
            next == .li || next == nil
            
        case .dt:
            next == .dt || next == .dd
            
        case .dd:
            next == .dt || next == .dd || next == nil
            
        case .rt, .rp:
            next == .rt || next == .rp || next == nil
            
        case .caption:
            true

        case .thead:
            next == .tbody || next == .tfoot
            
        case .tfoot:
            next == nil
            
        case .tr:
            next == .tr || next == nil
            
        case .td, .th:
            next == .td || next == .th || next == nil
            
        case .optgroup:
            next == .optgroup || next == .hr || next == nil
            
        case .option:
            next == .option || next == .optgroup || next == .hr || next == nil
            
        default:
            false
        }
    }
}
