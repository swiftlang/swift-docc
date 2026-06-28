/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

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
