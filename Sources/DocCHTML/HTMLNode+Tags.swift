/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// Apart from the `<head>` and `<body>` elements; the groups of element accessors are defined in alphabetical order.
// MARK: - Metadata

/// Creates a new `<title>` meta element with the given attributes and textual content.
///
/// The `<title>` element represents metadata about the the HTML document's title.
package func title(attributes: [HTMLNode.Attribute] = [], text: String) -> HTMLNode {
    ._element(.title, attributes: attributes, contents: [.text(text)])
}

// MARK: - Sections

/// Creates a new `<h1>` element with the given attributes and contents.
///
/// The `<h1>` element semantically represents a top-level heading of a conceptual section.
package func h1(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.h1, attributes: attributes, contents: contents)
}

/// Creates a new `<hgroup>` element with the given attributes and contents.
///
/// The `<hgroup>` element semantically represents a heading and related content representing a subheading, alternative title, or tagline.
///
/// A conforming `<hgroup>` element can only contain zero or more `<p>` elements and one `<h1>`–`<h6>` element.
/// The `<p>` elements---representing subheadings, alternative titles, or taglines---can appear both before and after the `<h1>`–`<h6>` element.
package func hgroup(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy {
        switch $0._tag {
            case .p, .h1, .h2, .h3, .h4, .h5, .h6: true
            default: false
        }
    }, "<hgroup> tags can only contain zero or more <p> tag and one <h1>–<h6> tags")
    return ._element(.hgroup, attributes: attributes, contents: contents)
}

/// Creates a new `<section>` element with the given attributes and contents.
///
/// The `<section>` element semantically represents a thematic grouping of content, typically with a heading.
package func section(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.section, attributes: attributes, contents: contents)
}

// MARK: - Grouping

/// Creates a new `<dd>` element with the given attributes and contents.
///
/// The `<dd>` element semantically represents a description, definition, or value, part of a term-description group in a description list (a `<dl>` element).
func dd(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.dd, attributes: attributes, contents: contents)
}

/// Creates a new `<dl>` element with the given attributes and contents.
///
/// The `<dl>` element semantically represents a description list consisting of zero or more name-value groups defined using pairs of `<dt>` and `<dd>` elements.
/// A conforming `<dl>` element can only contain `<dt>` and `<dd>` elements.
package func dl(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .dt || $0._tag == .dd }, "<dl> tags can only contain <dt> and <dd> tags")
    return ._element(.dl, attributes: attributes, contents: contents)
}

/// Creates a new `<dt>` element with the given attributes and contents.
///
/// The `<dt>` element semantically represents a term, or name, part of a term-description group in a description list (a `<dl>` element).
func dt(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.dt, attributes: attributes, contents: contents)
}

/// Creates a new `<li>` element with the given attributes and contents.
///
/// The `<li>` element semantically represents a list item.
/// It's relationship to earlier and later list items is determined by its containing `<ol>`, `<ul>`, or `<menu>` element.
package func li(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.li, attributes: attributes, contents: contents)
}

/// Creates a new `<ol>` element with the given attributes and contents.
///
/// The `<ol>` element semantically represents a list of items, where the items have been intentionally ordered, such that changing the order would change the meaning of the document.
/// A conforming `<ol>` element can only contain `<li>` elements.
package func ol(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .li }, "<ol> tags can only contain <li> tags")
    return ._element(.ol, attributes: attributes, contents: contents)
}

/// Creates a new `<p>` element with the given attributes and contents.
///
/// The `<p>` element semantically represents a paragraph of contents.
package func p(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.p, attributes: attributes, contents: contents)
}

/// Creates a new `<pre>` element with the given attributes and contents.
///
/// The `<pre>` element semantically represents a block of pre-formatted text, in which structure is represented by typographic conventions.
package func pre(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.pre, attributes: attributes, contents: contents)
}

/// Creates a new `<ul>` element with the given attributes and contents.
///
/// The `<ul>` element semantically represents a list of items,  where the order of the items is not important---that is, where changing the order would not materially change the meaning of the document.
/// A conforming `<ol>` element can only contain `<li>` elements.
package func ul(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .li }, "<ul> tags can only contain <li> tags")
    return ._element(.ul, attributes: attributes, contents: contents)
}

// MARK: - Text-level semantics

/// Creates a new `<a>` element with the given attributes and contents.
///
/// When the `<a>` element has a `href` attribute, it semantically represents a hyperlink (a hypertext anchor) labeled by its contents.
/// When the `<a>` element doesn't have a `href` attribute, it semantically represents a a placeholder for where a link might otherwise have been placed.
package func a(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.a, attributes: attributes, contents: contents)
}

/// Creates a new `<b>` element with the given attributes and contents.
///
/// The `<b>` element semantically represents a span of text to which attention is being drawn for utilitarian purposes without conveying any extra importance and with no implication of an alternate voice or mood.
///
/// - Note: A `<b>` element is typically presented as bold contents.
func b(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.b, attributes: attributes, contents: contents)
}

/// Creates a new `<code>` element with the given attributes and contents.
///
/// The `<code>` element semantically represents a fragment of computer code.
/// There is no formal way to indicate the language of computer code being marked up.
package func code(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.code, attributes: attributes, contents: contents)
}

/// Creates a new `<i>` element with the given attributes and contents.
///
/// The `<i>` element semantically represents a span of text in an alternate voice or mood, or otherwise offset from the normal prose in a manner indicating a different quality of text.
///
/// - Note: An `<i>` element is typically presented as italicized contents.
func i(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.i, attributes: attributes, contents: contents)
}

/// Creates a new `<span>` element with the given attributes and contents.
///
/// The `<span>` element has no special semantically meaning at all.
///
/// - Important: Before using a `<span>` element, consider if there is another element that already semantically represents what this `<span>` element's content represents to you.
package func span(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.span, attributes: attributes, contents: contents)
}

// MARK: - Embedded

/// Creates a new `<img>` element with the given attributes.
///
/// The `<img>` element semantically represents an image.
func img(attributes: consuming [HTMLNode.Attribute]) -> HTMLNode {
    ._voidElement(.img, attributes: consume attributes)
}

/// Creates a new `<picture>` element with the given attributes and contents.
///
/// The `<picture>` element is a container which provides multiple sources to its contained `<img>` element.
/// A conforming `<picture>` element can only contain zero or more `<source>` elements followed by one `<img>` element.
func picture(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.dropLast().allSatisfy { $0._tag == .source }, "<picture> tag's content can only have <source> tags before the <img> tag")
    assert(contents.last?._tag == .img, "<picture> tag's content can only end with an <img> tag")
    return ._element(.picture, attributes: attributes, contents: contents)
}

/// Creates a new `<source>` element with the given attributes.
///
/// The `<source>` element specifies alternate source sets for an `<img>` element or other media element.
/// It doesn't represent anything on its own.
/// A conforming `<source>` element that's contained in a `<picture>` element must include a `srcset` attribute.
func source(attributes: consuming [HTMLNode.Attribute]) -> HTMLNode {
    ._voidElement(.source, attributes: consume attributes)
}

// MARK: - Forms

/// Creates a new `<input>` element with the given attributes.
///
/// The `<input>` element semantically represents a typed data field, usually with a form control to allow the user to edit the data.
func input(_ attributes: HTMLNode.Attribute...) -> HTMLNode {
    ._voidElement(.input, attributes: attributes)
}


// MARK: - Tags

extension HTMLNode {
    // This type is only internally accessible so that HTMLNode, its formatting, and its parsing can be defined in different files.
    enum _Tag: UInt8 {
        case html
        
        // Metadata
        
        case base // a void element
        case head
        case link // a void element
        case meta // a void element
        case style
        case title
        
        // Sections
        
        case address
        case article
        case aside
        case body
        case footer
        case h1, h2, h3, h4, h5, h6
        case header
        case hgroup
        case nav
        case section
        
        // Grouping
        
        case blockquote
        case dd
        case div
        case dl
        case dt
        case figcaption
        case figure
        case hr // a void-element
        case li
        case main
        case menu
        case ol
        case p
        case pre
        case search
        case ul
        
        // Text-level semantics
        
        case a
        case abbr
        case b
        case bdi
        case bdo
        case br  // a void-element
        case cite
        case code
        case data
        case dfn
        case em
        case i
        case kbd
        case mark
        case q
        case rp
        case rt
        case ruby
        case s
        case samp
        case small
        case span
        case strong
        case sub
        case sup
        case time
        case u
        case `var`
        case wbr // a void-element
        
        // Embedded
        
        case area   // a void-element
        case audio
        case embed  // a void-element
        case iframe
        case img    // a void-element
        case map
        case object
        case picture
        case source // a void-element
        case track  // a void-element
        case video
        
        // Tables
        
        case caption
        case col // a void-element
        case colgroup
        case table
        case tbody
        case td
        case tfoot
        case th
        case thead
        case tr
        
        // Forms
        
        case button
        case datalist
        case fieldset
        case form
        case input // a void-element
        case label
        case legend
        case meter
        case optgroup
        case option
        case output
        case progress
        case select
        case selectedcontent
        case textarea
        
        // Interactive
        
        case details
        case dialog
        case summary
        
        // Scripting
        
        case canvas
        case noscript
        case script
        case slot
        case template
    }
}

extension HTMLNode._Tag {
    var name: StaticString {
        switch self {
            case .a:               "a"
            case .abbr:            "abbr"
            case .address:         "address"
            case .area:            "area"
            case .article:         "article"
            case .aside:           "aside"
            case .audio:           "audio"
            case .b:               "b"
            case .base:            "base"
            case .bdi:             "bdi"
            case .bdo:             "bdo"
            case .blockquote:      "blockquote"
            case .body:            "body"
            case .br:              "br"
            case .button:          "button"
            case .canvas:          "canvas"
            case .caption:         "caption"
            case .cite:            "cite"
            case .code:            "code"
            case .col:             "col"
            case .colgroup:        "colgroup"
            case .data:            "data"
            case .datalist:        "datalist"
            case .dd:              "dd"
            case .details:         "details"
            case .dfn:             "dfn"
            case .dialog:          "dialog"
            case .div:             "div"
            case .dl:              "dl"
            case .dt:              "dt"
            case .em:              "em"
            case .embed:           "embed"
            case .fieldset:        "fieldset"
            case .figcaption:      "figcaption"
            case .figure:          "figure"
            case .footer:          "footer"
            case .form:            "form"
            case .h1:              "h1"
            case .h2:              "h2"
            case .h3:              "h3"
            case .h4:              "h4"
            case .h5:              "h5"
            case .h6:              "h6"
            case .head:            "head"
            case .header:          "header"
            case .hgroup:          "hgroup"
            case .hr:              "hr"
            case .html:            "html"
            case .i:               "i"
            case .iframe:          "iframe"
            case .img:             "img"
            case .input:           "input"
            case .kbd:             "kbd"
            case .label:           "label"
            case .legend:          "legend"
            case .li:              "li"
            case .link:            "link"
            case .main:            "main"
            case .map:             "map"
            case .mark:            "mark"
            case .menu:            "menu"
            case .meta:            "meta"
            case .meter:           "meter"
            case .nav:             "nav"
            case .noscript:        "noscript"
            case .object:          "object"
            case .ol:              "ol"
            case .optgroup:        "optgroup"
            case .option:          "option"
            case .output:          "output"
            case .p:               "p"
            case .picture:         "picture"
            case .pre:             "pre"
            case .progress:        "progress"
            case .q:               "q"
            case .rp:              "rp"
            case .rt:              "rt"
            case .ruby:            "ruby"
            case .s:               "s"
            case .samp:            "samp"
            case .script:          "script"
            case .search:          "search"
            case .section:         "section"
            case .select:          "select"
            case .selectedcontent: "selectedcontent"
            case .slot:            "slot"
            case .small:           "small"
            case .source:          "source"
            case .span:            "span"
            case .strong:          "strong"
            case .style:           "style"
            case .sub:             "sub"
            case .summary:         "summary"
            case .sup:             "sup"
            case .table:           "table"
            case .tbody:           "tbody"
            case .td:              "td"
            case .template:        "template"
            case .textarea:        "textarea"
            case .tfoot:           "tfoot"
            case .th:              "th"
            case .thead:           "thead"
            case .time:            "time"
            case .title:           "title"
            case .tr:              "tr"
            case .track:           "track"
            case .u:               "u"
            case .ul:              "ul"
            case .var:             "var"
            case .video:           "video"
            case .wbr:             "wbr"
        }
    }
}
