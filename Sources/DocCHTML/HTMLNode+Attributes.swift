/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension HTMLNode {
    /// An attribute that can be applies to one or more HTML elements.
    package enum Attribute {
        /// A textual description that can replace the image when it can't be displayed in an `<img>`, `<area>`, or `<input>` element.
        case alt(String)
        /// An indication that browser it to focus the element as soon as the page is loaded, allowing the user to just start typing without having to manually focus the element.
        case autoFocus
        /// A space-separated list of classes for the element.
        case `class`(String)
        /// How many columns the `<td>` or `<th>` element spans.
        case colSpan(Int)
        /// A hint to the browser for how it should perform image decoding in relation to rendering for the `<img>` element's resource.
        case decoding(Decoding)
        /// An indication that the element is not yet, or is no longer, directly relevant to the page's current state,
        /// or that it is being used to declare content to be reused by other parts of the page as opposed to being directly accessed by the user.
        case hidden(Hidden)
        /// The URL that the `<a>`, `<area>`, `<base>`, or `<link>` element references.
        case href(String)
        /// An identifier for this element that's unique within the scope of the entire HTML document.
        case id(String)
        /// An indication for how the browser should load the `<img>` or `<iframe>` element's resource.
        case loading(Loading)
        /// The media query for the resource's intended media of the `<a>`, `<area>`, `<link>`, `<source>`, or `<style>` element.
        case media(String)
        /// Advisory information for the element, such as would be appropriate for a tooltip.
        case title(String)
        /// Whether or not a "checkbox" type or "radio" type `<input>` element is checked.
        case checked
        /// Either the name that gives the metadata name for a ``contents(_:)`` value for a `<meta>` element or the name of a form element for the server to identify fields in the form submission.
        case name(String)
        /// The URL of the resource that this `<audio>`, `<embed>`, `<iframe>`, `<img>`, `<input>`, `<script>`, `<source>`, `<track>`, or `<video>` element references.
        case src(String)
        /// Depending on the element, either:
        /// - the type of control to display for an `<input>` element ("button", "checkbox", "color", "date", "email", "file", "image", "month", "number", "password", "radio", "range", etc.)
        /// - the behavior for a `<button>` element ("submit", "reset", or "button")
        /// - the numbering type for an `<ol>` element ("a", "A", "i" , "I" , or "1")
        /// - the type of script that a `<script>` element represents
        /// - the MIME type that a `<link>` element is referencing.
        /// - the MIME type of the media that a `<source>` element is referencing.
        case type(String)
        /// Depending on the element, either:
        /// - The value of an `<input>` element.
        /// - The ordinal value of a `<li>` element within a `<ol>` element.
        /// - The machine-readable representation of a `<data>` element's content.
        /// - The numeric value of a `<meter>` or `<progress>` element.
        /// - The value that is associated with a `<button>` element's ``name(_:)`` when its containing form is submitted.
        case value(String)
    }
}

extension HTMLNode.Attribute {
    // The more succinct name "name" is already taken by one of the (meta) attributes.
    // That attribute gets the better name because it has `package` access, and this is only accessible within the DocCHTML module.
    var nameForFormatting: StaticString {
        switch self {
            case .alt:                     "alt"
            case .autoFocus:               "autofocus"
            case .class:                   "class"
            case .colSpan:                 "colspan"
            case .decoding:                "decoding"
            case .hidden:                  "hidden"
            case .href:                    "href"
            case .id:                      "id"
            case .loading:                 "loading"
            case .media:                   "media"
            case .title:                   "title"
            case .checked:                 "checked"
            case .name:                    "name"
            case .src:                     "src"
            case .type:                    "type"
            case .value:                   "value"
        }
    }
    
    // The more succinct name "value" is already taken by one of the (meta) attributes.
    // That attribute gets the better name because it has `package` access, and this is only accessible within the DocCHTML module.
    var valueForFormatting: String {
        switch self {
            case .alt(let string):                 return string
            case .autoFocus:                       return "" // A "boolean" attribute
            case .class(let classNames):           return classNames
            case .colSpan(let number):             return number.description
            case .decoding(let value):             return value.rawValue
            case .hidden(let value):               return value.rawValue
            case .href(let string):                return string
            case .id(let string):                  return string
            case .loading(let value):              return value.rawValue
            case .media(let string):               return string
            case .title(let string):               return string
            case .checked:                         return "" // A "boolean" attribute
            case .name(let string):                return string
            case .src(let string):                 return string
            case .type(let string):                return string
            case .value(let string):               return string
        }
    }
}

// MARK: Associated attribute values

extension HTMLNode.Attribute {
    /// A value for the ``HTMLNode/Attribute/decoding(_:)`` attribute.
    package enum Decoding: String {
        /// A hint that the browser should decode the image synchronously along with rendering.
        case sync
        /// A hint that the browser should decode the image image asynchronously, after rendering.
        case async
        /// Specifies that the browser decides the best decoding behavior for the image.
        case auto
    }
    /// A value for the ``HTMLNode/Attribute/hidden(_:)`` attribute.
    package enum Hidden: String {
        /// The element is will not be rendered
        ///
        /// Can either be represented as an explicit "hidden" value or as an empty value.
        case hidden     = ""
        /// The element is will not be rendered, but content inside will be accessible to find-in-page and fragment navigation.
        case untilFound = "until-found"
    }
    /// A value for the ``HTMLNode/Attribute/loading(_:)`` attribute.
    package enum Loading: String {
        /// An indication that the browser should load the image immediately.
        case eager
        /// An indication that the browser should defer loading the image until it reaches some browser-defined distance from the viewport.
        case lazy
    }
    
    /// A value for the ``HTMLNode/Attribute/method(_:)`` attribute.
    package enum Method: String {
        /// The form data is sent as the body in a POST request.
        case post
        /// The form data is encoded as key-value pairs in the query component of the ``action`` attribute's URL.
        case get
        /// When the `<form>` element is within a `<dialog>` element; closes the dialog and fires a `submit` event without submitting the form.
        case dialog
    }
}
