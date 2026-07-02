/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// Apart from the `<head>` and `<body>` elements; the groups of element accessors are defined in alphabetical order.
// This file only exposes package-level accessors for the HTML elements that we currently need outside of this module.
// Accessors that are only needed by the `MarkdownRenderer` visitor pattern can remain internal-only until there's another need for them.

// Apart from the `<head>` and `<body>` elements; the groups of element accessors are defined in alphabetical order.

/// Creates a new `<html>` element with the given attributes and contents.
///
/// The `<html>` element represents the root of an HTML document.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<html>` element.
package func html(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.html, attributes: attributes , contents: contents)
}

// MARK: - Metadata

/// Creates a new `<head>` element with the given attributes and contents.
///
/// The `<head>` element represents a collection of metadata for the HTML document.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<head>` element.
package func head(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.head, attributes: attributes, contents: contents)
}

/// Creates a new `<base>` element with the given attributes.
///
/// The `<base>` element specifies the HTML document's base URL for the purposes of parsing URLs, and the name of the default navigable for the purposes of following links.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<base>` element.
func base(attributes: HTMLNode.Attribute...) -> HTMLNode {
    ._voidElement(.base, attributes: attributes)
}

/// Creates a new `<link>` meta element with the given attributes.
///
/// The `<link>` element allows the document to link to other resources, like fonts, favicons, or stylesheets.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<link>` element.
package func link(_ attributes: HTMLNode.Attribute...) -> HTMLNode {
    ._voidElement(.link, attributes: attributes)
}

/// Creates a new `<meta>` meta element with the given attributes.
///
/// The `<meta>` element various kinds of metadata that cannot be expressed using the `<title>`, `<base>`, `<link>`, `<style>`, or `<script>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<meta>` element.
package func meta(_ attributes: HTMLNode.Attribute...) -> HTMLNode {
    ._voidElement(.meta, attributes: attributes)
}

/// Creates a new `<title>` meta element with the given attributes and textual content.
///
/// The `<title>` element represents metadata about the the HTML document's title.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<title>` element.
package func title(attributes: [HTMLNode.Attribute] = [], text: String) -> HTMLNode {
    ._element(.title, attributes: attributes, contents: [.text(text)])
}

// MARK: - Sections

/// Creates a new `<body>` element with the given attributes and contents.
///
/// The `<body>` element represents the contents of the HTML document.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<body>` element.
package func body(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.body, attributes: attributes, contents: contents)
}

/// Creates a new `<address>` element with the given attributes and contents.
///
/// The `<address>` element semantically represents the contact information for its nearest `<article>` or `<body>` ancestor element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<address>` element.
func address(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.address, attributes: attributes, contents: contents)
}

/// Creates a new `<article>` element with the given attributes and contents.
///
/// The `<article>` element represents a complete, or self-contained, composition in a document, page, application, or site and that is, in principle, independently distributable or reusable.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<article>` element.
package func article(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.article, attributes: attributes, contents: contents)
}
/// Creates a new `<aside>` element with the given attributes and contents.

///
/// The `<aside>` element semantically represents a section of a page that consists of content that is tangentially related to the content around the `<aside>` element, and which could be considered separate from that content.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<aside>` element.
package func aside(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.aside, attributes: attributes, contents: contents)
}

/// Creates a new `<footer>` element with the given attributes and contents.
///
/// The `<footer>` element semantically represents a footer of supplementary introductory about its its nearest `<article>`, `<aside>`, `<nav>`, `<section>`, or `<body>` ancestor element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<footer>` element.
package func footer(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.footer, attributes: attributes, contents: contents)
}

/// Creates a new `<h1>` element with the given attributes and contents.
///
/// The `<h1>` element semantically represents a top-level heading of a conceptual section.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<h1>` element.
package func h1(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.h1, attributes: attributes, contents: contents)
}

/// Creates a new `<h2>` element with the given attributes and contents.
///
/// The `<h2>` element semantically represents a subheading of a conceptual section.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<h2>` element.
package func h2(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.h2, attributes: attributes, contents: contents)
/// Creates a new heading element with the given level, attributes, and contents.
}

/// Creates a new heading element of a given level with the given attributes and contents.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<h1>`-`<h6>` element.
func heading(level: Int, attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    let tag: HTMLNode._Tag = switch level {
        case 1:  .h1
        case 2:  .h2
        case 3:  .h3
        case 4:  .h4
        case 5:  .h5
        default: .h6
    }
    return ._element(tag, attributes: attributes, contents: contents)
}

/// Creates a new `<hgroup>` element with the given attributes and contents.
///
/// The `<hgroup>` element semantically represents a heading and related content representing a subheading, alternative title, or tagline.
///
/// A conforming `<hgroup>` element can only contain zero or more `<p>` elements and one `<h1>`–`<h6>` element.
/// The `<p>` elements---representing subheadings, alternative titles, or taglines---can appear both before and after the `<h1>`–`<h6>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<hgroup>` element.
package func hgroup(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy {
        switch $0._tag {
            case .p, .h1, .h2, .h3, .h4, .h5, .h6: true
            default: false
        }
    }, "<hgroup> tags can only contain zero or more <p> tag and one <h1>–<h6> tags")
    return ._element(.hgroup, attributes: attributes, contents: contents)
}

/// Creates a new `<header>` element with the given attributes and contents.
///
/// The `<header>` element semantically represents a group of introductory or navigational aids for its nearest `<article>`, `<aside>`, `<nav>`, `<section>`, or `<body>` ancestor element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<header>` element.
package func header(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.header, attributes: attributes, contents: contents)
}

/// Creates a new `<nav>` element with the given attributes and contents.
///
/// The `<nav>` element semantically represents section of a page that links to other pages or to parts within the page.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<nav>` element.
package func nav(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.nav, attributes: attributes, contents: contents)
}

/// Creates a new `<section>` element with the given attributes and contents.
///
/// The `<section>` element semantically represents a thematic grouping of content, typically with a heading.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<section>` element.
package func section(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.section, attributes: attributes, contents: contents)
}

// MARK: - Grouping

/// Creates a new `<blockquote>` element with the given attributes and contents.
///
/// The `<blockquote>` element semantically represents a section that is quoted from another source.
/// A conforming `<blockquote>` element must be quoted from another source, whose address, may be cited in a `cite` attribute.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<blockquote>` element.
func blockquote(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.blockquote, attributes: attributes, contents: contents)
}

/// Creates a new `<dd>` element with the given attributes and contents.
///
/// The `<dd>` element semantically represents a description, definition, or value, part of a term-description group in a description list (a `<dl>` element).
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<dd>` element.
func dd(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.dd, attributes: attributes, contents: contents)
}

/// Creates a new `<div>` element with the given attributes and contents.
///
/// The `<div>` element has no special semantically meaning at all.
///
/// - Important: Before using a `<div>` element, consider if there is another element that already semantically represents what this `<div>` element's content represents to you.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<div>` element.
func div(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.div, attributes: attributes, contents: contents)
}

/// Creates a new `<dl>` element with the given attributes and contents.
///
/// The `<dl>` element semantically represents a description list consisting of zero or more name-value groups defined using pairs of `<dt>` and `<dd>` elements.
/// A conforming `<dl>` element can only contain `<dt>` and `<dd>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<dl>` element.
package func dl(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .dt || $0._tag == .dd }, "<dl> tags can only contain <dt> and <dd> tags")
    return ._element(.dl, attributes: attributes, contents: contents)
}

/// Creates a new `<dt>` element with the given attributes and contents.
///
/// The `<dt>` element semantically represents a term, or name, part of a term-description group in a description list (a `<dl>` element).
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<dt>` element.
func dt(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.dt, attributes: attributes, contents: contents)
}

/// Creates a new `<figcaption>` element with the given attributes and contents.
///
/// The `<figcaption>` element semantically represents a caption or legend for the rest of the contents of the containing `<figure>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<figcaption>` element.
func figcaption(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.figcaption, attributes: attributes, contents: contents)
}

/// Creates a new `<figure>` element with the given attributes and contents.
///
/// The `<figure>` element semantically represents a content---for example an illustration, diagram, photo, or code listings---with an optional caption that is self-contained and is typically referenced as a single unit from the main flow of the document.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<figure>` element.
func figure(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.figure, attributes: attributes, contents: contents)
}

/// A `<hr>` element.
///
/// The `<hr>` element semantically represents a paragraph-level thematic break, for example a scene change in a story, or a transition to another topic within a section of a reference book.
/// Alternatively, the `<hr>` elements represents a separator between a set of options of a `<select>` element.
package let hr = HTMLNode._voidElement(.hr)

/// Creates a new `<li>` element with the given attributes and contents.
///
/// The `<li>` element semantically represents a list item.
/// It's relationship to earlier and later list items is determined by its containing `<ol>`, `<ul>`, or `<menu>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<li>` element.
package func li(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.li, attributes: attributes, contents: contents)
}

/// Creates a new `<main>` element with the given attributes and contents.
///
/// The `<main>` element semantically represents the dominant contents of the document.
///
/// A conforming HTML document must not have more than one `<main>` element that does not have the `hidden` attribute specified.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<main>` element.
func main(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.main, attributes: attributes, contents: contents)
}

/// Creates a new `<menu>` element with the given attributes and contents.
///
/// The `<menu>` element semantically represents a toolbar consisting of an unordered list of commands that the user can perform or activate.
///
/// A conforming `<menu>` element can only contain `<li>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<menu>` element.
func menu(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .li }, "<menu> tags can only contain <li> tags")
    return ._element(.menu, attributes: attributes, contents: contents)
}

/// Creates a new `<ol>` element with the given attributes and contents.
///
/// The `<ol>` element semantically represents a list of items, where the items have been intentionally ordered, such that changing the order would change the meaning of the document.
/// A conforming `<ol>` element can only contain `<li>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<ol>` element.
package func ol(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .li }, "<ol> tags can only contain <li> tags")
    return ._element(.ol, attributes: attributes, contents: contents)
}

/// Creates a new `<p>` element with the given attributes and contents.
///
/// The `<p>` element semantically represents a paragraph of contents.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<p>` element.
package func p(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.p, attributes: attributes, contents: contents)
}

/// Creates a new `<pre>` element with the given attributes and contents.
///
/// The `<pre>` element semantically represents a block of pre-formatted text, in which structure is represented by typographic conventions.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<pre>` element.
package func pre(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.pre, attributes: attributes, contents: contents)
}

/// Creates a new `<search>` element with the given attributes and contents.
///
/// The `<search>` element semantically represents part of a document or application that contains controls or content related to performing a search or filtering operation.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<search>` element.
func search(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.search, attributes: attributes, contents: contents)
}

/// Creates a new `<ul>` element with the given attributes and contents.
///
/// The `<ul>` element semantically represents a list of items,  where the order of the items is not important---that is, where changing the order would not materially change the meaning of the document.
/// A conforming `<ul>` element can only contain `<li>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<ul>` element.
package func ul(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .li }, "<ul> tags can only contain <li> tags")
    return ._element(.ul, attributes: attributes, contents: contents)
}

// MARK: - Text-level semantics

/// Creates a new `<a>` element with the given attributes and contents.
///
/// When the `<a>` element has a `href` attribute, it semantically represents a hyperlink (a hypertext anchor) labeled by its contents.
/// When the `<a>` element doesn't have a `href` attribute, it semantically represents a a placeholder for where a link might otherwise have been placed.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<a>` element.
package func a(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.a, attributes: attributes, contents: contents)
}

/// Creates a new `<abbr>` element with the given attributes and contents.
///
/// The `<abbr>` element semantically represents an abbreviation or acronym, optionally with its expansion specifies using the `title` attribute.
/// The `title` attribute may be used to provide an expansion of the abbreviation.
/// A conforming `<abbr>` element must not use the `title` attribute for anything other than an expansion of the abbreviation.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<abbr>` element.
func abbr(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.abbr, attributes: attributes, contents: contents)
}

/// Creates a new `<b>` element with the given attributes and contents.
///
/// The `<b>` element semantically represents a span of text to which attention is being drawn for utilitarian purposes without conveying any extra importance and with no implication of an alternate voice or mood.
///
/// - Note: A `<b>` element is typically presented as bold contents.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<b>` element.
func b(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.b, attributes: attributes, contents: contents)
}

/// Creates a new `<bdi>` element with the given attributes and contents.
///
/// The `<bdi>` element semantically represents a run of text that is to be isolated from its surroundings for the purposes of bidirectional text formatting.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<bdi>` element.
func bdi(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.bdi, attributes: attributes, contents: contents)
}

/// Creates a new `<bdo>` element with the given attributes and contents.
///
/// The `<bdo>` element represents explicit text directionality formatting control for its contents.
/// A conforming `<bdo>` element must specify the `dir` attribute with a ``HTMLNode/Attribute/Dir`` value.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<bdo>` element.
func bdo(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.bdo, attributes: attributes, contents: contents)
}

/// A `<br>` element.
///
/// The `<br>` element represents an explicit line break.
package let br = HTMLNode._voidElement(.br)

/// Creates a new `<cite>` element with the given attributes and contents.
///
/// The `<cite>` element semantically represents the title of a work that's either quoted, referenced in detail, or mentioned in passing.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<cite>` element.
func cite(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.cite, attributes: attributes, contents: contents)
}

/// Creates a new `<code>` element with the given attributes and contents.
///
/// The `<code>` element semantically represents a fragment of computer code.
/// There is no formal way to indicate the language of computer code being marked up.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<code>` element.
package func code(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.code, attributes: attributes, contents: contents)
}

/// Creates a new `<data>` element with the given attributes and contents.
///
/// The `<data>` element represents its contents, along with a machine-readable form of those contents in the `value` attribute.
/// A conforming `<data>` element must have a `value` attribute whose value must be a representation of the element's contents in a machine-readable format.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<data>` element.
func data(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.data, attributes: attributes, contents: contents)
}

/// Creates a new `<dfn>` element with the given attributes and contents.
///
/// The `<dfn>` element semantically represents the defining instance of a term.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<dfn>` element.
func dfn(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.dfn, attributes: attributes, contents: contents)
}

/// Creates a new `<em>` element with the given attributes and contents.
///
/// The `<em>` element semantically represents stress emphasis of its contents.
/// More than one `<em>` element can be nested to semantically represent a higher level of stress for a particular piece of content.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<em>` element.
func em(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.em, attributes: attributes, contents: contents)
}

/// Creates a new `<i>` element with the given attributes and contents.
///
/// The `<i>` element semantically represents a span of text in an alternate voice or mood, or otherwise offset from the normal prose in a manner indicating a different quality of text.
///
/// - Note: An `<i>` element is typically presented as italicized contents.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<i>` element.
func i(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.i, attributes: attributes, contents: contents)
}

/// Creates a new `<kbd>` element with the given attributes and contents.
///
/// The `<kbd>` element semantically represents keyboard input or other input by a user.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<kbd>` element.
func kbd(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.kbd, attributes: attributes, contents: contents)
}

/// Creates a new `<mark>` element with the given attributes and contents.
///
/// The `<mark>` element semantically represents a run of text in that is marked or highlighted for reference purposes, due to its relevance in another context.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<mark>` element.
func mark(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.mark, attributes: attributes, contents: contents)
}

/// Creates a new `<q>` element with the given attributes and contents.
///
/// The `<q>` element semantically represents content that is quoted from another source.
/// A conforming `<q>` element must not include quotation punctuation and must not be used in place of quotation marks that do not represent quotes.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<q>` element.
func q(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.q, attributes: attributes, contents: contents)
}

/// Creates a new `<rt>` element with the given attributes and contents.
///
/// The `<rt>` element marks the text component of a [ruby annotation](https://en.wikipedia.org/wiki/Ruby_character).
/// It's semantic meaning is determined by what the containing `<ruby>` element represents.
/// A conforming `<rt>` element can only be used as a contents of a `<ruby>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<rt>` element.
func rt(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.rt, attributes: attributes, contents: contents)
}

/// Creates a new `<rp>` element with the given attributes and textual contents.
///
/// The `<rp>` element provide parentheses or other content around a ruby text component of a [ruby annotation](https://en.wikipedia.org/wiki/Ruby_character).
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<rp>` element.
func rp(attributes: [HTMLNode.Attribute] = [], text: String) -> HTMLNode {
    ._element(.rp, attributes: attributes, contents: [.text(text)])
}

/// Creates a new `<ruby>` element with the given attributes and contents.
///
/// The `<ruby>` element is used to add [ruby annotations](https://en.wikipedia.org/wiki/Ruby_character) to content as a guide for pronunciation, primarily in East Asian typography.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<ruby>` element.
func ruby(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.ruby, attributes: attributes, contents: contents)
}

/// Creates a new `<s>` element with the given attributes and contents.
///
/// The `<s>` element semantically represents contents that are no longer accurate or no longer relevant.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<s>` element.
func s(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.s, attributes: attributes, contents: contents)
}

/// Creates a new `<samp>` element with the given attributes and contents.
///
/// The `<samp>` element semantically represents sample or quoted output from another program or computing system.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<samp>` element.
func samp(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.samp, attributes: attributes, contents: contents)
}

/// Creates a new `<small>` element with the given attributes and contents.
///
/// The `<small>` element semantically represents side comments such as small print.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<small>` element.
func small(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.small, attributes: attributes, contents: contents)
}

/// Creates a new `<span>` element with the given attributes and contents.
///
/// The `<span>` element has no special semantically meaning at all.
///
/// - Important: Before using a `<span>` element, consider if there is another element that already semantically represents what this `<span>` element's content represents to you.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<span>` element.
package func span(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.span, attributes: attributes, contents: contents)
}

/// Creates a new `<strong>` element with the given attributes and contents.
///
/// The `<strong>` element semantically represents strong importance, seriousness, or urgency for its contents.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<strong>` element.
func strong(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.strong, attributes: attributes, contents: contents)
}

/// Creates a new `<sub>` element with the given attributes and contents.
///
/// The `<sub>` element semantically represents a subscript.
/// A conforming `<sub>` element must be used only to mark up typographical conventions with specific meanings, not for typographical presentation for presentation's sake.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<sub>` element.
func sub(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.sub, attributes: attributes, contents: contents)
}

/// Creates a new `<sup>` element with the given attributes and contents.
///
/// The `<sup>` element semantically represents a superscript.
/// A conforming `<sup>` element must be used only to mark up typographical conventions with specific meanings, not for typographical presentation for presentation's sake.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<sup>` element.
func sup(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.sup, attributes: attributes, contents: contents)
}

/// Creates a new `<time>` element with the given attributes and contents.
///
/// The `<time>` element semantically represents a date-time value, along with a machine-readable form of the date-time value in the `datetime` attribute.
/// A conforming `<time>` element must either have a `datetime` attribute whose value must be a representation of the element's contents in a machine-readable format, or it must have only text content in the same machine-readable format.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<time>` element.
func time(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.time, attributes: attributes, contents: contents)
}

/// Creates a new `<u>` element with the given attributes and contents.
///
/// The `<u>` element semantically represents a span of text with an unarticulated, though explicitly rendered, non-textual annotation.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<u>` element.
func u(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.u, attributes: attributes, contents: contents)
}

/// Creates a new `<var>` element with the given attributes and contents.
///
/// The `<var>` element semantically represents a variable. For example a variable in a mathematical expression or programming context, a symbol identifying a physical quantity, or a function parameter.
func `var`(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.var, attributes: attributes, contents: contents)
}

/// A `<wbr>` element.
///
/// The `<wbr>` element represents a line break opportunity.
package let wbr = HTMLNode._voidElement(.wbr)

// MARK: - Embedded

/// Creates a new `<area>` element with the given attributes and contents.
///
/// The `<area>` element semantically represents an area on an image map.
/// A conforming `<area>` element can only be an element ancestor of a `<map>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<area>` element.
func area(attributes: [HTMLNode.Attribute] = []) -> HTMLNode {
    ._voidElement(.area, attributes: attributes)
}

/// Creates a new `<audio>` element with the given attributes and contents.
///
/// The `<audio>` element semantically represents a sound or audio stream.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<audio>` element.
func audio(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.audio, attributes: attributes, contents: contents)
}

/// Creates a new `<embed>` element with the given attributes.
///
/// The `<embed>` element provides an integration point for an external application or interactive content.
/// A conforming `<embed>` element cannot have any contents.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<embed>` element.
func embed(attributes: consuming [HTMLNode.Attribute]) -> HTMLNode {
    ._element(.embed, attributes: consume attributes, contents: [])
}

/// Creates a new `<iframe>` element with the given attributes.
///
/// The `<iframe>` element represents an inline frame that is used to embed another document within the current HTML document.
/// A conforming `<iframe>` element cannot have any contents.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<iframe>` element.
func iframe(attributes: consuming [HTMLNode.Attribute]) -> HTMLNode {
    ._element(.iframe, attributes: consume attributes, contents: [])
}

/// Creates a new `<img>` element with the given attributes.
///
/// The `<img>` element semantically represents an image.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<img>` element.
func img(attributes: consuming [HTMLNode.Attribute]) -> HTMLNode {
    ._voidElement(.img, attributes: consume attributes)
}

/// Creates a new `<map>` element with the given attributes and contents.
///
/// The `<map>` element in conjunction with an `<img>` element and any `<area>` element descendants, defines an image map.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<map>` element.
func map(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.map, attributes: attributes, contents: contents)
}

/// Creates a new `<object>` element with the given attributes and contents.
///
/// The `<object>` element represents an external resource that will either be treated as an image or as a navigable document, depending on the type of the resource.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<object>` element.
func object(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.object, attributes: attributes, contents: contents)
}

/// Creates a new `<picture>` element with the given attributes and contents.
///
/// The `<picture>` element is a container which provides multiple sources to its contained `<img>` element.
/// A conforming `<picture>` element can only contain zero or more `<source>` elements followed by one `<img>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<picture>` element.
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
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<source>` element.
func source(attributes: consuming [HTMLNode.Attribute]) -> HTMLNode {
    ._voidElement(.source, attributes: consume attributes)
}

/// Creates a new `<track>` element with the given attributes.
///
/// The `<track>` element specify explicit external timed text tracks for media elements.
/// It does not represent anything on its own.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<track>` element.
func track(attributes: [HTMLNode.Attribute] = []) -> HTMLNode {
    ._voidElement(.track, attributes: attributes)
}

/// Creates a new `<video>` element with the given attributes and contents.
///
/// The `<video>` element represents a video, movie, or audio file with captions.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<video>` element.
func video(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.video, attributes: attributes, contents: contents)
}

// MARK: Tables

/// Creates a new `<caption>` element with the given attributes and contents.
///
/// The `<caption>` element semantically represents the title of its containing `<table>` element.
/// A conforming `<caption>` element can only be the first element of a `<table>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<caption>` element.
func caption(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.caption, attributes: attributes, contents: contents)
}

/// Creates a new `<col>` element with the given attributes.
///
/// The `<col>` element represents one or more columns in its containing `<colgroup>` element.
/// A conforming `<col>` element can only be the contents of a `<colgroup>` element without an `span` attribute.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<col>` element.
func col(attributes: [HTMLNode.Attribute] = []) -> HTMLNode {
    ._voidElement(.col, attributes: attributes)
}

/// Creates a new `<colgroup>` element with the given attributes and contents.
///
/// The `<colgroup>` element represents a group of one or more columns in its containing `<table>` element.
/// A conforming `<colgroup>` element can only be a descendant of a `<table>` element, after any `<caption>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<colgroup>` element.
func colGroup(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.colgroup, attributes: attributes, contents: contents)
}

/// Creates a new `<table>` element with the given attributes and contents.
///
/// The `<table>` element semantically represents some data with more than one dimension, in the form of a table.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<table>` element.
func table(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy {
        switch $0._tag {
            case .caption, .colgroup, .thead, .tbody, .tfoot: true
            default: false
        }
    }, "<table> tags can only contain <caption>, <colgroup>, <thead>, <tbody>, and <tfoot> tags in that order")
    return ._element(.table, attributes: attributes, contents: contents)
}

/// Creates a new `<tbody>` element with the given attributes and contents.
///
/// The `<tbody>` element semantically represents a block of rows that consist of a body of data its containing `<table>` element.
/// A conforming `<tbody>` element can only contain `<tr>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<tbody>` element.
func tbody(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .tr }, "<tbody> tags can only contain <tr> tags")
    return ._element(.tbody, attributes: attributes, contents: contents)
}

/// Creates a new `<td>` element with the given attributes and contents.
///
/// The `<td>` element semantically represents a data cell in its containing `<table>` element.
/// A conforming `<td>` element can only be the contents of a `<tr>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<td>` element.
func td(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.td, attributes: attributes, contents: contents)
}

/// Creates a new `<tfoot>` element with the given attributes and contents.
///
/// The `<tfoot>` element semantically represents a block of rows that consist of the column summaries (footers) for its containing `<table>` element.
/// A conforming `<tfoot>` element can only contain `<tr>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<tfoot>` element.
func tfoot(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .tr }, "<tfoot> tags can only contain <tr> tags")
    return ._element(.tfoot, attributes: attributes, contents: contents)
}

/// Creates a new `<th>` element with the given attributes and contents.
///
/// The `<th>` element semantically represents a header cell in its containing `<table>` element.
/// A conforming `<th>` element can only be the contents of a `<tr>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<th>` element.
func th(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.th, attributes: attributes, contents: contents)
}

/// Creates a new `<thead>` element with the given attributes and contents.
///
/// The `<thead>` element semantically represents a block of rows that consist of column labels (headers) and any ancillary non-header cells for its containing `<table>` element.
/// A conforming `<thead>` element can only contain `<tr>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<thead>` element.
func thead(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .tr }, "<thead> tags can only contain <tr> tags")
    return ._element(.thead, attributes: attributes, contents: contents)
}

/// Creates a new `<tr>` element with the given attributes and contents.
///
/// The `<tr>` element semantically represents a row of in its containing `<table>` element.
/// A conforming `<tr>` element can only contain `<td>` and `<ht>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<tr>` element.
func tr(contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .td || $0._tag == .th }, "<tr> tags can only contain <td> and <th> tags")
    return ._element(.tr, contents: contents)
}

// MARK: - Forms

/// Creates a new `<button>` element with the given attributes and contents.
///
/// The `<button>` element semantically represents a button in a user interface. The button is labeled by its contents.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<button>` element.
func button(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.button, attributes: attributes, contents: contents)
}

/// Creates a new `<datalist>` element with the given attributes and contents.
///
/// The `<datalist>` element semantically represents a set of predefined options for other controls in the user interface.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<datalist>` element.
func dataList(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.datalist, attributes: attributes, contents: contents)
}

/// Creates a new `<fieldset>` element with the given attributes and contents.
///
/// The `<fieldset>` element semantically represents a set of form controls (or other content) grouped together, optionally with a caption.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<fieldset>` element.
func fieldSet(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.fieldset, attributes: attributes, contents: contents)
}

/// Creates a new `<form>` element with the given attributes and contents.
///
/// The `<form>` element semantically represents a hyperlink that can be manipulated through a collection of form-associated elements,
/// some of which can represent editable values that can be submitted to a server for processing.
/// A conforming `<form>` element cannot have any other `<flow>` element descendants.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<form>` element.
func form(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.form, attributes: attributes, contents: contents)
}

/// Creates a new `<input>` element with the given attributes.
///
/// The `<input>` element semantically represents a typed data field, usually with a form control to allow the user to edit the data.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<input>` element.
func input(_ attributes: HTMLNode.Attribute...) -> HTMLNode {
    ._voidElement(.input, attributes: attributes)
}

/// Creates a new `<label>` element with the given attributes and contents.
///
/// The `<label>` element semantically represents a caption in a user interface that can be associated with a specific form control.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<label>` element.
func label(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.label, attributes: attributes, contents: contents)
}

/// Creates a new `<legend>` element with the given attributes and contents.
///
/// The `<legend>` element semantically represents a caption for the rest of the contents of its containing `<fieldset>` element.
/// A conforming `<legend>` can only be the first elements of a `<fieldset>` or `<optgroup>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<legend>` element.
func legend(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.legend, attributes: attributes, contents: contents)
}

/// Creates a new `<meter>` element with the given attributes and contents.
///
/// The `<meter>` element semantically represents a scalar measurement within a known range.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<meter>` element.
func meter(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.meter, attributes: attributes, contents: contents)
}

/// Creates a new `<optgroup>` element with the given attributes and contents.
///
/// The `<optgroup>` element semantically represents a group of options with a common label, in a user interface.
/// A conforming `<optgroup>` element can only contain `<legend>` and nested `<optgroup>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<optgroup>` element.
func optGroup(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .button || $0._tag == .optgroup}, "<optgroup> tags can only contain <legend> or nested <optgroup> tags")
    return ._element(.optgroup, attributes: attributes, contents: contents)
}

/// Creates a new `<option>` element with the given attributes and contents.
///
/// The `<option>` element semantically represents a selectable option in a `<select>` element or a suggestion in a `<datalist>` element.
/// A conforming `<option>` element can only be the contents of `<select>`, `<datalist>`, and `<optgroup>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<option>` element.
func option(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.option, attributes: attributes, contents: contents)
}

/// Creates a new `<output>` element with the given attributes and contents.
///
/// The `<output>` element semantically represents the result of a calculation performed by the application, or the result of a user action.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<output>` element.
func output(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.output, attributes: attributes, contents: contents)
}

/// Creates a new `<progress>` element with the given attributes and contents.
///
/// The `<progress>` element semantically represents the completion progress of a task.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<progress>` element.
func progress(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.progress, attributes: attributes, contents: contents)
}

/// Creates a new `<select>` element with the given attributes and contents.
///
/// The `<select>` element semantically represents a control, in a user interface, for selecting amongst a set of options.
/// A conforming `<select>` element can only contain `<button>` elements.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<select>` element.
func select(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    assert(contents.allSatisfy { $0._tag == .button }, "<select> tags can only contain <button> tags")
    return ._element(.select, attributes: attributes, contents: contents)
}

/// Creates a new `<selectedcontent>` element with the given attributes and contents.
///
/// The `<selectedcontent>` element reflects the contents of the a `<select>` elements currently selected `<option>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<selectedcontent>` element.
func selectedContent(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.selectedcontent, attributes: attributes, contents: contents)
}

/// Creates a new `<textarea>` element with the given attributes and textual contents.
///
/// The `<textarea>` element semantically represents a multiline plain text edit control in a user interface.
/// A conforming `<textarea>` element can only contain textual contents.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<textarea>` element.
func textarea(attributes: [HTMLNode.Attribute] = [], text: String) -> HTMLNode {
    ._element(.textarea, attributes: attributes, contents: [.text(text)])
}

// MARK: - Interactive elements

/// Creates a new `<details>` element with the given attributes and contents.
///
/// The `<details>` element semantically represents a disclosure widget that the user can expand to obtain additional information.
/// A conforming `<details>` element should have a `<summary>` element as its first content.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<details>` element.
func details(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.details, attributes: attributes, contents: contents)
}

/// Creates a new `<dialog>` element with the given attributes and contents.
///
/// The `<dialog>` element semantically represents a dialog box in a web application.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<dialog>` element.
func dialog(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.dialog, attributes: attributes, contents: contents)
}

/// Creates a new `<summary>` element with the given attributes and contents.
///
/// The `<summary>` element semantically represents a summary, caption, or legend for the rest of the contents of the containing `<details>` element.
/// A conforming `<summary>` element can only be the first element content of a `<details>` element.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<summary>` element.
func summary(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.summary, attributes: attributes, contents: contents)
}

// MARK: - Scripting

/// Creates a new `<canvas>` element with the given attributes and contents.
///
/// The `<canvas>` element provides scripts with a resolution-dependent bitmap canvas, which can be used for rendering graphs, game graphics, art, or other visual images on the fly.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<canvas>` element.
func canvas(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.canvas, attributes: attributes, contents: contents)
}

/// Creates a new `<noscript>` element with the given attributes and contents.
///
/// The `<noscript>` element represents nothing if scripting is enabled, and represents its contents if scripting is disabled.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<noscript>` element.
func noScript(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.noscript, attributes: attributes, contents: contents)
}

/// Creates a new `<script>` element with the given attributes and contents.
///
/// The `<script>` element allows authors to include dynamic script in their HTML documents.
/// The `<script>` element itself does not represent content for the user.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<script>` element.
func script(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.script, attributes: attributes, contents: contents)
}

/// Creates a new `<slot>` element with the given attributes and contents.
///
/// The `<slot>` element defined a slot to be used in a shadow tree. It semantically represents its assigned nodes.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<slot>` element.
func slot(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.slot, attributes: attributes, contents: contents)
}

/// Creates a new `<template>` element with the given attributes and contents.
///
/// The `<template>` element is used to declare fragments of HTML that can be cloned and inserted in the document by script.
///
/// - Parameters:
///   - attributes: The list of attributes for the new element.
///   - contents: The inner contents for the new element.
/// - Returns: A new `<template>` element.
func template(attributes: [HTMLNode.Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
    ._element(.template, attributes: attributes, contents: contents)
}

// MARK: - Tags

extension HTMLNode {
    // This type is only internally accessible so that HTMLNode, its formatting, and its parsing can be defined in different files.
    enum _Tag: String {
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
