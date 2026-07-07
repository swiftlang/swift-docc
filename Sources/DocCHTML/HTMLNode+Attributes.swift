/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension HTMLNode {
    /// An attribute that can be applies to one or more HTML elements.
    package struct Attribute {
        let name: String
        let value: String
        
        /// A short, abbreviated description of a `<th>`element's content.
        package static func abbr(_ description: String) -> Attribute { .init(name: "abbr", value: description) }

        /// A list of file types that the receiver of a `<form>` or `<input>` element's submission accepts.
        ///
        /// The file types are encoded as a comma separated string.
        package static func accept(_ fileTypes: [String]) -> Attribute { .init(name: "accept", value: fileTypes.joined(separator: ",")) }

        /// The character set that the server accepts for the `<form>` element's submission.
        ///
        /// The only accepted character set is "utf-8".
        package static let acceptCharset = Attribute(name: "accept-charset", value: "utf-8")

        /// A hint for the browser to generate a keyboard shortcut for the current element.
        ///
        /// Browsers should use the first character that's found on the user's keyboard layout.
        package static func accessKey(_ keys: [UnicodeScalar]) -> Attribute { .init(name: "accesskey", value: keys.map { String(Character($0)) }.joined(separator: " ")) }

        /// The URL that processes the `<form>` element's submission.
        package static func action(_ urlString: String) -> Attribute { .init(name: "action", value: urlString) }

        @available(*, deprecated, message: "Use CSS to align the content instead")
        package static func align(_ value: Align) -> Attribute { .init(name: "align", value: value.rawValue) }

        /// Determines what container policy that the browser will use for the `<iframe>` element.
        package static func allow(_ policy: String) -> Attribute { .init(name: "allow", value: policy) }

        /// The opacity of a "color" type `<input>` element's color.
        package static func alpha(_ opacity: Int) -> Attribute { .init(name: "alpha", value: opacity.description) }

        /// A textual description that can replace the image when it can't be displayed in an `<img>`, `<area>`, or `<input>` element.
        package static func alt(_ description: String) -> Attribute { .init(name: "alt", value: description) }

        /// The type of content that's referenced by the `<link>` element.
        package static func `as`(_ value: As) -> Attribute { .init(name: "as", value: value.rawValue) }
        
        /// Specifies the that browser should run the `<script>` element's script asynchronously.
        package static let async = Attribute(name: "async", value: "") // A "boolean" attribute
        
        /// A configuration of the autocapitalization behavior of the element.
        package static func autoCapitalize(_ value: AutoCapitalize) -> Attribute { .init(name: "autocapitalize", value: value.rawValue) }

        /// A hint to the browser that the `<form>`, `<input>`, `<select>`, or `<textarea>` element can have its contents automatically completed.
        package static func autoComplete(_ value: String) -> Attribute { .init(name: "autocomplete", value: value) }

        /// A configuration of the autocorrection behavior for the element.
        package static func autoCorrect(_ enabled: Bool) -> Attribute { .init(name: "autocorrect", value: enabled ? "on" : "off") }

        /// An indication that browser it to focus the element as soon as the page is loaded, allowing the user to just start typing without having to manually focus the element.
        package static let autoFocus = Attribute(name: "autofocus", value: "") // A "boolean" attribute

        /// Specifies that the browser should automatically being playing the `<audio>` or `<video>` element's resource as soon as it can, without waiting for the entire resource to finish downloading.
        package static let autoPlay = Attribute(name: "autoplay", value: "") // A "boolean" attribute

        @available(*, deprecated, message: "Use CSS to configure a background image instead")
        package static func background(_ value: String) -> Attribute { .init(name: "background", value: value) } 

        @available(*, deprecated, message: "Use CSS to configure a background color instead")
        package static func bgColor(_ value: String) -> Attribute { .init(name: "bgcolor", value: value) }

        @available(*, deprecated, message: "Use CSS to configure a border instead")
        package static func border(_ value: String) -> Attribute { .init(name: "border", value: value) } 

        /// The media capture input method for a "file" type `<input>` element.
        package static func capture(_ value: Capture) -> Attribute { .init(name: "capture", value: value.rawValue) }

        /// Declares the document's character encoding is UTF-8; which is the only valid encoding.
        package static let charSet = Attribute(name: "charset", value: "utf-8")

        /// Whether or not a "checkbox" type or "radio" type `<input>` element is checked.
        package static let checked = Attribute(name: "checked", value: "") // A "boolean" attribute

        /// The URL to either the source of a `<blockquote>` or `<q>` element's source or to a `<ins>` or `<del>` element's change.
        package static func cite(_ value: String) -> Attribute { .init(name: "cite", value: value) } 

        /// A space-separated list of classes for the element.
        package static func `class`(_ classNames: String...) -> Attribute { .init(name: "class", value: classNames.joined(separator: " ")) }
        
        @available(*, deprecated, message: "Use CSS to configure a text color instead")
        package static func color(_ value: String) -> Attribute { .init(name: "color", value: value) }

        /// The colorspace that the "color" type `<input>` element should use for selecting its color value.
        package static func colorspace(_ value: String) -> Attribute { .init(name: "colorspace", value: value) } 

        /// The width of a `<textarea>` element's textual contents, measured in average character widths.
        package static func cols(_ width: Int) -> Attribute { .init(name: "cols", value: width.description) }

        /// How many columns the `<td>` or `<th>` element spans.
        package static func colSpan(_ count: UInt) -> Attribute { .init(name: "colspan", value: count.description) }

        /// The value associated with a `<meta>` element's ``name(_:)`` attribute.
        package static func contents(_ value: String) -> Attribute { .init(name: "contents", value: value) } 

        /// A configuration that controls whether or not the element is editable.
        package static func contentEditable(_ value: ContentEditable) -> Attribute { .init(name: "contenteditable", value: value.rawValue) }

        /// Specifies if the browser should offer audio playback controls for the `<audio>` or `<video>` element.
        package static let controls = Attribute(name: "controls", value: "") // A "boolean" attribute

        /// A hint to the browser for what controls to show for this `<audio>` element.
        package static func controlsList(_ controls: Controls) -> Attribute { .init(name: "controlslist", value: controls.rawValue) }

        /// The coordinate information of an `<area>` element's ``shape(_:)`` attribute.
        package static func coords(_ value: String) -> Attribute { .init(name: "coords", value: value) } 

        /// Specifies that the browser should use Cross-Origin Resource Sharing (CORS) to fetch the `<audio>`, `<img>`, `<link>`, `<script>`, or `<video>` element's resource.
        package static func crossOrigin(_ value: CrossOrigin) -> Attribute { .init(name: "crossorigin", value: value.rawValue) }

        /// Specifies the Content Security Policy that an `<iframe>` element's embedded document must enforce upon itself.
        package static func csp(_ policy: String) -> Attribute { .init(name: "csp", value: policy) }

        /// The URL of an `<object>` element's resource.
        package static func data(_ value: String) -> Attribute { .init(name: "data", value: value) } 

        /// Either the machine-readable representation of a `<time>` element's date-time value or the date-time value associated with an `<ins>` or `<del>` element's change.
        package static func datetime(_ machineReadableRepresentation: String) -> Attribute { .init(name: "datetime", value: machineReadableRepresentation) }

        /// A hint to the browser for how it should perform image decoding in relation to rendering for the `<img>` element's resource.
        package static func decoding(_ value: Decoding) -> Attribute { .init(name: "decoding", value: value.rawValue) }

        /// A hint to the browser that it should enable the `<track>` element by default unless the user's preferences indicate something different.
        package static let `default` = Attribute(name: "default", value: "") // A "boolean" attribute
        
        /// A hint to the browser that is should run the `<script>` element's source after it has parsed the page.
        package static let `defer` = Attribute(name: "defer", value: "") // A "boolean" attribute
        
        /// The text direction of the element.
        package static func dir(_ textDirection: Dir) -> Attribute { .init(name: "dir", value: textDirection.rawValue) }

        /// The name of the form field that the browser should use to submit the `<input>` or `<textarea>` element's directionality information.
        package static func dirName(_ elementName: String) -> Attribute { .init(name: "dirname", value: elementName) }

        /// Whether or not the  `<button>`, `<fieldset>`, `<input>`, `<optgroup>`, `<option>`, `<select>`, or `<textarea>` element is disabled.
        package static let disabled = Attribute(name: "disabled", value: "") // A "boolean" attribute

        /// A configuration that the browser should disable playback on devices that are connected either via wire or wireless technologies.
        package static let disableRemotePlayback = Attribute(name: "disableremoteplayback", value: "") // A "boolean" attribute

        /// A configuration that the browser should not suggest a Picture-in-Picture context menu.
        package static let disablePictureInPicture = Attribute(name: "disablepictureinpicture", value: "") // A "boolean" attribute

        /// A hint to the browser that the  `<a>` or `<area>` element's linked URL is used to downloading a resource.
        package static let download = Attribute(name: "download", value: "") // A "boolean" attribute

        /// A configuration that controls whether or not the element is draggable.
        package static func draggable(_ enabled: Bool) -> Attribute { .init(name: "draggable", value: enabled ? "true" : "false") }

        /// The MIME type of the `<form>` element's submission if the ``method(_:)`` attribute's value is ``Method/post``.
        package static func encType(_ value: EncodingType) -> Attribute { .init(name: "enctype", value: value.rawValue) }

        /// A configuration of what action label (or icon) the browser should present for the "enter key" on virtual keyboards.
        package static func enterKeyHint(_ value: EnterKeyHint) -> Attribute { .init(name: "enterkeyhint", value: value.rawValue) }

        /// Marks the `<img>` element for observation by the PerformanceElementTiming API and specifies the identifier for the observed timing event.
        package static func elementTiming(_ id: String) -> Attribute { .init(name: "elementtiming", value: id) } 

        /// A hint to the browser about the relative priority it should use when fetching the `<img>`, `<link>`, or `<script>` element's resource.
        package static func fetchPriority(_ value: FetchPriority) -> Attribute { .init(name: "fetchpriority", value: value.rawValue) }

        /// The identifier of the other element that this `<label>` or `<output>` element describes.
        package static func `for`(_ identifier: String) -> Attribute { .init(name: "for", value: identifier) }
        
        /// The identifier of the `<form>` element that this `<button>`, `<fieldset>`, `<input>`, `<object>`, `<output>`, `<select>`, or `<textarea>` element belongs to.
        package static func form(_ identifier: String) -> Attribute { .init(name: "form", value: identifier) }

        /// Overrides the action of the `<form>` element that this `<input>` or `<button>` element belongs to.
        package static func formAction(_ override: String) -> Attribute { .init(name: "formaction", value: override) }

        /// Overrides the encoding type of the `<form>` element that this `<input>` or `<button>` element belongs to.
        package static func formEncType(_ override: EncodingType) -> Attribute { .init(name: "formenctype", value: override.rawValue) }

        /// Overrides the submission method of the `<form>` element that this `<input>` or `<button>` element belongs to.
        package static func formMethod(_ value: Method) -> Attribute { .init(name: "formmethod", value: value.rawValue) }

        /// Overrides the validation configuration of the `<form>` element that this `<input>` or `<button>` element belongs to.
        package static let formValidate = Attribute(name: "formvalidate", value: "") // A "boolean" attribute

        /// Overrides the target of the `<form>` element that this `<input>` or `<button>` element belongs to.
        package static func formTarget(_ value: String) -> Attribute { .init(name: "formtarget", value: value) } 

        /// A list of strings corresponding to the id attributes of the `<th>` elements that provide the headers for this header cell.
        package static func headers(_ ids: [String]) -> Attribute { .init(name: "headers", value: ids.joined(separator: " ")) }

        /// An offset for the heading levels of descendants of the element.
        ///
        /// According to the HTML specification, the value must be a valid non-negative integer between 0 and 8, inclusive.
        package static func headingOffset(_ offset: Int) -> Attribute { .init(name: "headingoffset", value: Swift.min(8, Swift.max(0, offset)).description) }

        /// Prevents a heading offset from traversing beyond this element.
        package static let headingReset = Attribute(name: "headingreset", value: "") // A "boolean" attribute

        /// The intrinsic height, in pixels, of the `<canvas>`, `<embed>`, `<iframe>`, `<img>`, `<input>`, `<object>`, or `<video>` element.
        ///
        /// For all other elements, configure the element's height using the CSS `height` property instead.
        package static func height(_ value: Int) -> Attribute { .init(name: "height", value: value.description) }

        /// An indication that the element is not yet, or is no longer, directly relevant to the page's current state,
        /// or that it is being used to declare content to be reused by other parts of the page as opposed to being directly accessed by the user.
        package static func hidden(_ value: Hidden) -> Attribute { .init(name: "hidden", value: value.rawValue) }

        /// The lower bound of the high end of the `<meter>` element's measured range.
        package static func high(_ value: Int) -> Attribute { .init(name: "high", value: value.description) }

        /// The URL that the `<a>`, `<area>`, `<base>`, or `<link>` element references.
        package static func href(_ urlString: String) -> Attribute { .init(name: "href", value: urlString) }

        /// A hint at the human language of the `<a>` or `<link>` element's referenced content.
        package static func hrefLang(_ languageName: String) -> Attribute { .init(name: "hreflang", value: languageName) }

        /// A `<meta>` element configuration that instructs the browser to process the page as if certain HTTP headers were present.
        package static func httpEquiv(_ value: HTTPEquivalent) -> Attribute { .init(name: "http-equiv", value: value.rawValue) }

        /// An identifier for this element that's unique within the scope of the entire HTML document.
        package static func id(_ id: String) -> Attribute { .init(name: "id", value: id) }

        /// A configuration that controls whether or not the element is inert (cannot be interacted with).
        package static let inert = Attribute(name: "inert", value: "") // A "boolean" attribute

        /// One or more hashes of the `<link>` or `<script>` element's linked resource that the browser can use to ensure that the resource is what it is expected to be.
        package static func integrity(_ hashes: [String]) -> Attribute { .init(name: "integrity", value: hashes.joined(separator: " ")) }

        /// A hint to browsers about the type of virtual keyboard to use when editing this element.
        package static func inputMode(_ value: InputMode) -> Attribute { .init(name: "inputmode", value: value.rawValue) }

        /// Specifies that the `<img>` element's image is part of a server-side map.
        package static let isMap = Attribute(name: "ismap", value: "") // A "boolean" attribute

        /// An indication of how the `<track>` element is meant to be used.
        package static func kind(_ value: Kind) -> Attribute { .init(name: "kind", value: value.rawValue) }

        /// A human-readable title of the `<optgroup>`, `<option>`, or `<track>` element.
        package static func label(_ title: String) -> Attribute { .init(name: "label", value: title) }

        /// The language that a non-editable element is in, or the language that an editable element should be written in by the user.
        ///
        /// A compliant HTTP page should only specify a valid [BCP 47 language tag](https://en.wikipedia.org/wiki/IETF_language_tag) as the value for this attribute.
        package static func lang(_ value: String) -> Attribute { .init(name: "lang", value: value) } 

        @available(*, deprecated, message: "Use the `type` attribute to specify a `<script>` element's scripting language instead.")
        package static func language(_ value: String) -> Attribute { .init(name: "language", value: value) } 

        /// An indication for how the browser should load the `<img>` or `<iframe>` element's resource.
        package static func loading(_ value: Loading) -> Attribute { .init(name: "loading", value: value.rawValue) }

        /// The identifier of a `<datalist>` element that provides predefined values to suggest to the user for the `<input>` element.
        package static func list(_ value: String) -> Attribute { .init(name: "list", value: value) } 

        /// A configuration that the `<audio>` or `<video>` element should automatically seek to the start upon reaching the end.
        package static let loop = Attribute(name: "loop", value: "") // A "boolean" attribute

        /// The upper bound of of the low end of the `<meter>` element's measured range.
        package static func low(_ value: Int) -> Attribute { .init(name: "low", value: value.description) }

        /// The upper bound of the `<meter>` element's measured range.
        package static func max(_ value: Int) -> Attribute { .init(name: "max", value: value.description) }

        /// The maximum number of characters allowed in the `<input>` or `<textarea>` element.
        package static func maxLength(_ value: Int) -> Attribute { .init(name: "maxlength", value: value.description) }

        /// The lower bound of the `<meter>` element's measured range.
        package static func min(_ value: Int) -> Attribute { .init(name: "min", value: value.description) }

        /// The minimum number of characters allowed in the `<input>` or `<textarea>` element.
        package static func minLength(_ value: Int) -> Attribute { .init(name: "minlength", value: value.description) }

        /// The media query for the resource's intended media of the `<a>`, `<area>`, `<link>`, `<source>`, or `<style>` element.
        package static func media(_ value: String) -> Attribute { .init(name: "media", value: value) } 

        /// The HTTP method that the browser should use to submit the `<form>` element.
        package static func method(_ value: Method) -> Attribute { .init(name: "method", value: value.rawValue) }

        /// An indication that this `<input>` or `<select>` element supports multiple values.
        package static let multiple = Attribute(name: "multiple", value: "") // A "boolean" attribute

        /// The `<audio>` or `<video>` element will start out as muted.
        package static let muted = Attribute(name: "muted", value: "") // A "boolean" attribute

        /// Either the name that gives the metadata name for a ``contents(_:)`` value for a `<meta>` element or the name of a form element for the server to identify fields in the form submission.
        package static func name(_ value: String) -> Attribute { .init(name: "name", value: value) } 

        /// A cryptographic nonce ("number used once") which can be used by Content Security Policy to determine whether or not a given fetch will be allowed to proceed.
        package static func nonce(_ value: String) -> Attribute { .init(name: "nonce", value: value) } 

        /// An indication that this `<form>` element should not be validated before its submission.
        package static let noValidate = Attribute(name: "noValidate", value: "") // A "boolean" attribute

        /// A configuration that a `<details>` element is expanded or that a `<dialog>` element is active and can be interacted with.
        package static let open = Attribute(name: "open", value: "") // A "boolean" attribute

        /// The optimal value of the `<meter>` element's measured range.
        package static func optimum(_ value: Int) -> Attribute { .init(name: "optimum", value: value.description) }

        /// A regular expression that validates the `<input>` the element's value.
        package static func pattern(_ value: String) -> Attribute { .init(name: "pattern", value: value) } 

        /// A list of URLs of that are interested in being notified if the user follows the `<a>` or `<area>` element's linked URL.
        package static func ping(_ urlStrings: [String]) -> Attribute { .init(name: "ping", value: urlStrings.joined(separator: " ")) }

        /// A placeholder value that provides a hint to the user of what can be entered in the `<input>` or `<textare>` element.
        package static func placeholder(_ value: String) -> Attribute { .init(name: "placeholder", value: value) } 

        /// An indication that browser should display the video within the `<video>` element's playback area.
        package static let playsInline = Attribute(name: "playsInline", value: "") // A "boolean" attribute

        /// Designates the element as a "popover" that is hidden until it opened via an invoking element.
        package static let popover = Attribute(name: "popover", value: "") // A "boolean" attribute

        /// A URL for an image to display while the video is downloading.
        package static func poster(_ value: String) -> Attribute { .init(name: "poster", value: value) } 

        /// A hint to the browser about how it should load the `<audio>` element's resource.
        package static func preLoad(_ value: PreLoad) -> Attribute { .init(name: "preload", value: value.rawValue) }

        /// An indication whether or not the`<input>` or `<textarea>` element can be edited.
        package static let readOnly = Attribute(name: "readOnly", value: "") // A "boolean" attribute

        /// How much information the browser should send in a referrer header when following the `<a>` element's link.
        package static func referrerPolicy(_ value: ReferrerPolicy) -> Attribute { .init(name: "referrerpolicy", value: value.rawValue) }

        /// A list of relationships between the current document and the `<a>` element's linked destination resource.
        package static func rel(_ relationships: [Rel]) -> Attribute { .init(name: "rel", value: relationships.map(\.rawValue).joined(separator: " ")) }

        /// An indication whether or not the`<input>`, `<select>`, or `<textarea>` element is required to be filled out.
        package static let required = Attribute(name: "required", value: "") // A "boolean" attribute

        /// An indication that a `<ol>` element should displays its list items in descending order (instead of in ascending order).
        package static let revered = Attribute(name: "revered", value: "") // A "boolean" attribute

        /// The semantic meaning of an element.
        package static func role(_ value: Role) -> Attribute { .init(name: "role", value: value.rawValue) }

        /// The number of visible lines of text for the `<textarea>` element.
        package static func rows(_ numberOfLines: Int) -> Attribute { .init(name: "rows", value: numberOfLines.description) }

        /// An indication of how many rows the `<td>` or `<th>` element spans.
        package static func rowSpan(_ count: UInt) -> Attribute { .init(name: "rowspan", value: count.description) }

        /// Restrictions applied to the content embedded in the `<iframe>` element.
        package static func sandbox(_ value: [Sandbox]) -> Attribute { .init(name: "sandbox", value: value.map(\.rawValue).joined(separator: " ")) }

        /// The cells that the `<th>` element relates to.
        package static func scope(_ value: Scope) -> Attribute { .init(name: "scope", value: value.rawValue) }

        /// An indication that the `<option>` element is initially selected when the page loads.
        package static let selected = Attribute(name: "selected", value: "") // A "boolean" attribute

        /// The shape of the `<a>` or `<area>` element.
        package static func shape(_ value: Shape) -> Attribute { .init(name: "shape", value: value.rawValue) }

        /// The width of the `<input>` or `<select>` element.
        ///
        /// If the element's ``type(_:)`` attribute is "text" or "password", the value is measured in number of characters.
        /// Otherwise, the value is measured in pixels.
        package static func size(_ width: Int) -> Attribute { .init(name: "size", value: width.description) }

        /// A list of source sizes that describe the final rendered width of an `<img>`, `<link>`, or `<source>` elements image resource.
        package static func sizes(_ values: [String]) -> Attribute { .init(name: "sizes", value: values.joined(separator: " ")) }

        /// Assigns a slot in the shadow tree to the element.
        ///
        /// The created `<slot>` element will have a ``name(_:)`` attribute that matches the value of this `slot` attribute.
        package static func slot(_ name: String) -> Attribute { .init(name: "slot", value: name) }

        /// The number of columns that a `<col>` or `<colgroup>` element spans.
        package static func span(_ count: Int) -> Attribute { .init(name: "span", value: count.description) }

        /// A configuration that controls whether or not the element is spellchecked.
        package static func spellcheck(_ enabled: Bool) -> Attribute { .init(name: "spellcheck", value: enabled ? "true" : "false") }

        /// The URL of the resource that this `<audio>`, `<embed>`, `<iframe>`, `<img>`, `<input>`, `<script>`, `<source>`, `<track>`, or `<video>` element references.
        package static func src(_ urlString: String) -> Attribute { .init(name: "src", value: urlString) }

        /// Inline HTML to embed instead of the `<iframe>` element's resource.
        ///
        /// If the browser supports this attribute, and it's present, the browser will ignore the the ``src(_:)`` attribute.
        package static func srcDoc(_ value: String) -> Attribute { .init(name: "srcdoc", value: value) } 

        /// The language `<track>` element's textual track data.
        ///
        /// A compliant `<track>` element must only specify a valid [BCP 47 language tag](https://en.wikipedia.org/wiki/IETF_language_tag) as the value for this attribute.
        package static func srcLang(_ value: String) -> Attribute { .init(name: "srclang", value: value) } 

        /// A list of one or more resource URLs and their descriptors for the `<img>` or `<source>` element.
        package static func srcSet(_ urlStrings: [String]) -> Attribute { .init(name: "srcset", value: urlStrings.joined(separator: " ")) }

        /// The number of the `<ol>` element's first list item.
        package static func start(_ number: Int) -> Attribute { .init(name: "start", value: number.description) }

        /// The stepping interval for the `<input>` element with a numeric input type ("date", "month", "week", "time", "number", "range", or "datetime-local").
        package static func step(_ interval: Int) -> Attribute { .init(name: "step", value: interval.description) }

        @available(*, deprecated, message: "Use style sheet file to define CSS instead.")
        package static func style(_ value: String) -> Attribute { .init(name: "style", value: value) } 

        @available(*, deprecated, message: "Us a `<caption>` element to describe this `<table>` element instead.")
        package static func summary(_ value: String) -> Attribute { .init(name: "summary", value: value) } 

        /// A configuration that controls whether or not the element is sequentially focusable and determines its relative oder in the sequential navigation.
        ///
        /// A negative value means that the element is _click_ focusable but not _sequentially_ focusable.
        /// A positive value means that the element is both _click_ focusable and _sequentially_ focusable and creates a relative ordering so that higher values come later.
        package static func tabIndex(_ value: Int) -> Attribute { .init(name: "tabindex", value: value.description) }

        /// The name of the "navigable" that browsers will use when following the `<a>` or `<area>` element's link or where browsers will display the response for a `<form>` element's submission.
        package static func target(_ value: String) -> Attribute { .init(name: "target", value: value) } 

        /// Advisory information for the element, such as would be appropriate for a tooltip.
        package static func title(_ value: String) -> Attribute { .init(name: "title", value: value) } 

        /// A configuration that controls whether the element's text is to be translated when the page is localized, or whether to leave them unchanged.
        package static func translate(_ enabled: Bool) -> Attribute { .init(name: "translate", value: enabled ? "yes" : "no") }

        /// Depending on the element, either:
        /// - the type of control to display for an `<input>` element ("button", "checkbox", "color", "date", "email", "file", "image", "month", "number", "password", "radio", "range", etc.)
        /// - the behavior for a `<button>` element ("submit", "reset", or "button")
        /// - the numbering type for an `<ol>` element ("a", "A", "i" , "I" , or "1")
        /// - the type of script that a `<script>` element represents
        /// - the MIME type that a `<link>` element is referencing.
        /// - the MIME type of the media that a `<source>` element is referencing.
        package static func type(_ value: String) -> Attribute { .init(name: "type", value: value) } 

        /// Depending on the element, either:
        /// - The value of an `<input>` element.
        /// - The ordinal value of a `<li>` element within a `<ol>` element.
        /// - The machine-readable representation of a `<data>` element's content.
        /// - The numeric value of a `<meter>` or `<progress>` element.
        /// - The value that is associated with a `<button>` element's ``name(_:)`` when its containing form is submitted.
        package static func value(_ value: String) -> Attribute { .init(name: "value", value: value) } 

        /// The intrinsic width, in pixels, of the `<canvas>`, `<embed>`, `<iframe>`, `<img>`, `<input>`, `<object>`, or `<video>` element.
        package static func width(_ pixels: Int) -> Attribute { .init(name: "width", value: pixels.description) }

        /// A configuration that the `<textarea>` element's textual content should wrap.
        package static let wrap = Attribute(name: "wrap", value: "") // A "boolean" attribute

        /// A configuration that the browser should offer writing suggestions for this element.
        package static func writingSuggestions(_ enabled: Bool) -> Attribute { .init(name: "writingsuggestions", value: enabled ? "true" : "false") }
    }
}

// MARK: Associated attribute values

extension HTMLNode.Attribute {
    @available(*, deprecated, message: "Use CSS to align the content instead")
    package enum Align: String {
        case center
        case left
        case right
        case justify
    }
    
    /// A value for the ``HTMLNode/Attribute/as(_:)`` attribute.
    package enum As: String {
        /// The loaded content is an audio worklet module.
        case audioWorklet
        /// The loaded content is an additional fetch or XML HTTP Request.
        case fetch
        /// The loaded content is a font.
        case font
        /// The loaded content is an image.
        case image
        /// The loaded content is supplementary JSON file.
        case json
        /// The loaded content is a paint worklet module.
        case paintWorklet
        /// The loaded content is a JavaScript source.
        case script
        /// The loaded content is a service worker module.
        case serviceWorker
        /// The loaded content is a shared worker module.
        case sharedWorked
        /// The loaded content is a stylesheet
        case style
        /// The loaded content is a supplementary plain text file.
        case text
        /// The loaded content is a timed text track for a media element.
        case track
        /// The loaded content is a worker module.
        case worker
    }
    
    /// A value for the ``HTMLNode/Attribute/autocapitalize(_:)`` attribute.
    package enum AutoCapitalize: String {
        /// No autocapitalization should be applied (all letters should default to lowercase).
        case none
        /// The first letter of each sentence should default to a capital letter; all other letters should default to lowercase.
        case sentences
        /// The first letter of each word should default to a capital letter; all other letters should default to lowercase.
        case words
        /// All letters should default to uppercase.
        case characters
    }
    
    /// A value for the ``HTMLNode/Attribute/capture(_:)`` attribute.
    package enum Capture: String {
        /// An indication that the capture should use the user-facing camera and/or microphone.
        case user
        /// An indication that the capture should use the outward-facing camera and/or microphone.
        case environment
    }
    
    /// A value for the ``HTMLNode/Attribute/contentEditable(_:)`` attribute.
    package enum ContentEditable: String {
        /// The element is editable.
        case `true`
        /// The element is not editable.
        case `false`
        /// Only the element's raw text content is editable; rich formatting is disabled.
        case plaintextOnly = "plaintext-only"
    }
    
    /// A value for the ``HTMLNode/Attribute/controls(_:)`` attribute.
    package enum Controls: String {
        /// Hints that the browser should not display a download control.
        case noDownload = "nodownload"
        /// Hints that the browser should not display a full screen control.
        case noFullscreen = "nofullscreen"
        /// Hints that the browser should not display a remote playback control.
        case noRemotePlayback = "noremoteplayback"
    }
    
    /// A value for the ``HTMLNode/Attribute/crossOrigin(_:)`` attribute.
    package enum CrossOrigin: String {
        /// The browser should send a cross-origin request without a credential.
        case anonymous
        /// The browser should send a cross-origin request with a credential
        case useCredentials = "use-credentials"
    }
    
    /// A value for the ``HTMLNode/Attribute/decoding(_:)`` attribute.
    package enum Decoding: String {
        /// A hint that the browser should decode the image synchronously along with rendering.
        case sync
        /// A hint that the browser should decode the image image asynchronously, after rendering.
        case async
        /// Specifies that the browser decides the best decoding behavior for the image.
        case auto
    }
    
    /// A value for the ``HTMLNode/Attribute/dir(_:)`` attribute.
    package enum Dir: String {
        /// The contents of the element are explicitly directionally isolated left-to-right text.
        case ltr
        /// The contents of the element are explicitly directionally isolated right-to-left text.
        case rtl
        /// The contents of the element are explicitly directionally isolated text, but the direction is to be determined programmatically using the contents of the element.
        case auto
    }
    
    /// A value for the ``HTMLNode/Attribute/encType(_:)`` attribute.
    package enum EncodingType: String {
        /// Submits the form as URL encoded key-value pairs.
        case wwwFormURLEncoded = "application/x-www-form-urlencoded"
        /// Submits the form as a multipart request body.
        case multiPartFormData = "multipart/form-data"
        /// Submits the form as plain text.
        @available(*, deprecated, message: "Submitting forms as plain text is discouraged other than for debugging.")
        case textPlain = "text/plain"
    }
    
    /// A value for the ``HTMLNode/Attribute/enterKeyHint(_:)`` attribute.
    package enum EnterKeyHint: String {
        /// The browser should present a cue for the operation 'enter', typically inserting a new line.
        case enter
        /// The browser should present a cue for the operation 'done', typically meaning there is nothing more to input and the input method editor (IME) will be closed.
        case done
        /// The browser should present a cue for the operation 'go', typically meaning to take the user to the target of the text they typed.
        case go
        /// The browser should present a cue for the operation 'next', typically taking the user to the next field that will accept text.
        case next
        /// The browser should present a cue for the operation 'previous', typically taking the user to the previous field that will accept text.
        case previous
        /// The browser should present a cue for the operation 'search', typically taking the user to the results of searching for the text they have typed.
        case search
        /// The browser should present a cue for the operation 'send', typically delivering the text to its target.
        case send
    }
    
    /// A value for the ``HTMLNode/Attribute/fetchPriority(_:)`` attribute.
    package enum FetchPriority: String {
        /// A hint that the browser should fetch the image at a high priority relative to other images.
        case high
        /// A hint that the browser should fetch the image at a low priority relative to other images.
        case low
        /// No specific preference for the fetch priority of this image.
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
    
    /// A value for the ``HTMLNode/Attribute/httpEquiv(_:)`` attribute.
    package enum HTTPEquivalent: String {
        @available(*, deprecated, message: "Use the `lang` attribute to configure the page's language instead.")
        case contentLanguage
        /// Equivalent to the `Content-Type` HTTP header.
        case contentType
        /// Equivalent to the `Content-Security-Policy` HTTP header.
        case contentSecurityPolicy
        /// Specifies the name of the default CSS style sheet set.
        case defaultStyle
        /// Equivalent to the `Refresh` HTTP header.
        case refresh
        @available(*, deprecated, message: "Use the `Set-Cookie` HTTP response header instead.")
        case setCookie
    }
    
    /// A value for the ``HTMLNode/Attribute/inputMode(_:)`` attribute.
    package enum InputMode: String {
        /// The browser should not display any virtual keyboard
        case none
        /// The browser should display a keyboard for text input.
        case text
        /// The browser should display a keyboard for telephone number input.
        case tel
        /// The browser should display a keyboard for text input with keys for aiding the input of URLs.
        case url
        /// The browser should display a keyboard for text input with keys for aiding the input of email addresses.
        case email
        /// The browser should display a keyboard for numeric input.
        case numeric
        /// The browser should display a keyboard for fractional numeric input.
        case decimal
        /// The browser should display a keyboard for search.
        case search
    }
    
    /// A value for the ``HTMLNode/Attribute/kind(_:)`` attribute.
    package enum Kind: String {
        /// The track is meant to provide transcription or translation of the dialog.
        case subtitles
        /// The track is meant provide transcription or translation of the dialog, sound effects, relevant musical cues, and other relevant audio information
        case captions
        /// The track is meant to summarize the video component of the media resource.
        case descriptions
        /// The track is meant to navigate the media resource.
        case chapters
        /// The track is meant to be used by scripts and isn't visible to the user.
        case metadata
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

    /// A value for the ``HTMLNode/Attribute/preLoad(_:)`` attribute.
    package enum PreLoad: String {
        /// An indication that the media file should not be preloaded.
        case none
        /// An indication that only media file's metadata (e.g., length) is fetched.
        case metadata
        /// An indication that the whole media file can be downloaded, even if the user is not expected to use it.
        case auto = ""
    }
    
    /// A value for the ``HTMLNode/Attribute/referrerPolicy(_:)`` attribute.
    package enum ReferrerPolicy: String {
        /// The browser should not send a referrer header.
        case noReferrer = "no-referrer"
        /// The browser should not send a referrer header. to origins without TLS (HTTPS).
        case noReferrerWhenDowngrade = "no-referrer-when-downgrade"
        /// The browser should limit the referrer information to the origin of the referring page: its scheme, host, and port.
        case origin
        /// The browser should limit the referrer information to the origin of the referring page: its scheme, host, and port. Navigations on the same origin should still include the path.
        case originWhenCrossOrigin = "origin-when-cross-origin"
        /// The browser should send referred information for the same origin, but cross-origin requests should contain no referrer information.
        case sameOrigin = "same-origin"
        // Only send the origin of the document as the referrer when the protocol security level stays the same (HTTPS→HTTPS), but don't send it to a less secure destination (HTTPS→HTTP).
        
        case strictOrigin = "strict-origin"
        // Send a full URL when performing a same-origin request, only send the origin when the protocol security level stays the same (HTTPS→HTTPS), and send no header to a less secure destination (HTTPS→HTTP).
        case strictOriginWhenCrossOrigin = "strict-origin-when-cross-origin"
        
        @available(*, deprecated, message: "This policy is unsafe because it leaks origins and paths from TLS-protected resources to insecure origins.")
        case unsafeURL = "unsafe-url"
    }
    
    /// A value for the ``HTMLNode/Attribute/rel(_:)`` attribute.
    package enum Rel: String {
        /// An alternate representation of the document.
        case alternate
        /// Information about the author of the document.
        case author
        /// A permalink for the nearest ancestor section.
        case bookmark
        /// The preferred URL for the document (only allowed in `<link>` elements).
        case canonical
        /// A compression dictionary that can be used to compress future downloads on the same site.
        case compressionDictionary = "compression-dictionary"
        /// A configuration that the browser should preemptively perform DNS resolution for the target resource's origin.
        case dnsPrefetch = "dns-prefetch"
        /// An annotation that the referenced document is part of a different site than the current document.
        case external
        /// Configures the browser to be render-blocked---when used together with `blocking="render"`---so that the document will render consistently (only allowed in `<link>` elements).
        case expect
        /// A link to context-sensitive help
        case help
        /// An icon representing the current document (only allowed in `<link>` elements).
        case icon
        /// An indication that the current document is covered by the copyright license described by the referenced document.
        case license
        /// A web app manifest (only allowed in `<link>` elements)
        case manifest
        /// An indication that the current document represents the person who owns the linked content.
        case me
        /// A configuration that the browser should preemptively fetch the script and store it in the document's module map for later evaluation.
        case modulePreload = "modulepreload"
        /// An indication that the current document is a part of a series and that the next document in the series is the referenced document.
        case next
        /// Tells search engine crawlers to ignore the link. It may indicate that the current document's owner does not endorse the referenced document.
        case noFollow = "nofollow"
        /// An indication that the browser should create top-level browsing context if the hyperlink would otherwise create an auxiliary browsing context.
        case noOpener = "no-opener"
        /// An indication that the browser should not include a referrer header.
        case noReferrer = "no-referrer"
        /// An indication that the browser should create an auxiliary browsing context if the hyperlink would otherwise create a top-level browsing context.
        case opener
        /// An address of the pingback server that handles pingbacks to the current document (only allowed in `<link>` elements).
        case pingback
        /// A hint to the browser suggesting that it open a connection to the linked website in advance, without disclosing any private information or downloading any content (only allowed in `<link>` elements).
        case preConnect = "pre-connect"
        /// Specifies that the browser _should_ preemptively fetch and cache the target resource (only allowed in `<link>` elements).
        case preFetch = "pre-fetch"
        /// Specifies that the browser _must_ preemptively fetch and cache the target resource (only allowed in `<link>` elements).
        case preLoad = "pre-load"
        /// An indication that the current document is a part of a series and that the previous document in the series is the referenced document.
        case prev
        /// An indication that the referenced document is the Privacy Policy which describes the data collection and usage practices of the current document.
        case privacyPolicy = "privacy-policy"
        /// An indication that the hyperlink references a document whose interface is specially designed for searching in the current document
        case search
        /// Imports an external resource to be used as a stylesheet.
        case stylesheet
        /// An indication that the link refers to a document describing a tag that applies to the current document.
        case tag
        /// An indication that the referenced document is the Terms of Service that describes the agreements between the current document's provider and users who wish to use the document provided.
        case termsOfService = "terms-of-service"
    }
    
    /// A value for the ``HTMLNode/Attribute/role(_:)`` attribute.
    package enum Role: String {
        /// This element represents important and usually time-sensitive information.
        case alert
        /// This element represents a modal dialog that interrupts the user's workflow to communicate important information.
        case alertDialog = "alertdialog"
        /// This element _and all its members_ should be treated as a desktop application by assistive technologies.
        case application
        @available(*, deprecated, message: "Use a <article> element instead.")
        case article
        @available(*, deprecated, message: "Use a <header> element instead.")
        case banner
        @available(*, deprecated, message: "Use a <td> element instead.")
        case cell
        @available(*, deprecated, message: "Use a <th scope=col> element instead.")
        case columnHeader = "columnheader"
        /// This element represents a control that can dynamically present a list or grid to let the user select a value.
        case combobox
        @available(*, deprecated, message: "Use a <aside> element instead.")
        case complementary
        @available(*, deprecated, message: "Use a <footer> element instead.")
        case contentInfo = "contentinfo"
        @available(*, deprecated, message: "Use a <dfn> element instead.")
        case definition
        /// This element represents a web application dialog or window that's separate from the rest of the web application.
        case dialog
        @available(*, deprecated, message: "Use a <ul> or <ol> element instead.")
        case directory
        /// This element represents a top container of content that assistive technology users may want to browse in a reading mode.
        case document
        /// This element represents a scrollable list of articles.
        case feed
        @available(*, deprecated, message: "Use a <figure> element instead.")
        case figure
        @available(*, deprecated, message: "Use a <form> element instead.")
        case form
        /// This element represents a set of elements that are not intended to be included in assistive technologies' summaries or table of contents.
        case group
        @available(*, deprecated, message: "Use a <h1> - <h6> element instead.")
        case heading
        @available(*, deprecated, message: "Use a <img> element instead.")
        case img
        @available(*, deprecated, message: "Use a <ul> or <ol> element instead.")
        case list
        @available(*, deprecated, message: "Use a <li> element instead.")
        case listItem = "listitem"
        /// This element represents a live region where new information may be added and old information may disappear.
        case log
        @available(*, deprecated, message: "Use a <main> element instead.")
        case main
        /// This element represents a live region of non-essential content that may change frequently.
        case marquee
        /// This element represents a mathematical expression.
        case math
        /// This element represents a widget or user interface element that offers a list of choices to the user.
        case menu
        /// This element represents a presentation of a ``menu`` element that usually remains visible.
        case menubar
        @available(*, deprecated, message: "Use a <meter> element instead.")
        case meter
        @available(*, deprecated, message: "Use a <nav> element instead.")
        case navigation
        /// This element represents a section of parenthetic or ancillary content.
        case note
        /// This role removes the elements ARIA semantics.
        case presentation
        /// This element is a group of radio buttons.
        case radioGroup = "radiogroup"
        @available(*, deprecated, message: "Use a <section> element instead.")
        case region
        @available(*, deprecated, message: "Use a <tr> element instead.")
        case row
        @available(*, deprecated, message: "Use a <thead>, <hody>, or <tfoot> element instead.")
        case rowGroup  = "rowgroup"
        @available(*, deprecated, message: "Use a <th scope=row> element instead.")
        case rowHeader = "rowheader"
        /// This element represents a user interface element that displays and controls  the scrolling of content within a viewing area.
        case scrollbar
        @available(*, deprecated, message: "Use a <search> element instead.")
        case search
        /// This element represents a text box that specifies search criteria.
        case searchBox = "searchbox"
        @available(*, deprecated, message: "Use a <hr> element instead.")
        case separator
        /// This element represents a user interface element where the user can select a value within a given range.
        case slider
        /// This element represents a user interface element where the user can select a value from some discrete choices.
        case spinButton = "spinbutton"
        /// This element represents a live region of advisory information that is not important enough to have an ``alert`` role.
        case status
        /// This element represents a user interface element where the user can select generic "on" and "off" values.
        case `switch`
        /// This element represents a user interface element that, when activated, displays its associated ``tabPanel`` in the containing ``tabList``.
        case tab
        @available(*, deprecated, message: "Use a <table> element instead.")
        case table
        /// This element represents a container for a set of ``tab`` controls and their associated ``tabPanel`` contents.
        case tabList  = "tablist"
        /// This element represents a container for contents that can be displayed in its containing ``tabList`` when the corresponding ``tab`` element is activated.
        case tabPanel = "tabpanel"
        @available(*, deprecated, message: "Use a <dfn> element instead.")
        case term
        /// This element represents a numerical counter of elapsed time.
        case timer
        /// This element represents a container for commonly used function buttons
        case toolbar
        /// This element represents a text bubble that displays a description for an element.
        case tooltip
        /// This element represents a user interface element where the user can select items from a hierarchical organization.
        case tree
        /// This element represents a grid of rows that can be expanded or collapsed.
        case treeGrid = "treegrid"
        /// This element represents an item within a ``tree`` element.
        case treeItem = "treeitem"
    }
    
    /// A value for the ``HTMLNode/Attribute/sandbox(_:)`` attribute.
    package enum Sandbox: String {
        /// Allows the sandboxed resource to download files through an `<a>` or `<area>` element with the ``download`` attribute.
        case allowDownloads
        /// Allows the sandboxed resource to submit forms
        case allowForms
        /// Allows the sandboxed resource to open modal windows.
        case allowModels
        /// Allows the sandboxed resource to lock the screen orientation.
        case allowOrientationLock
        /// Allows the sandboxed resource to use the Pointer Lock API.
        case allowPointerLock
        /// Allows the sandboxed resource to create popups.
        case allowPopups
        /// Allows the sandboxed resource to open a new browsing context without the sandbox attribute.
        case allowPopupsToEscapeSandbox
        /// If missing; configures the sandboxed resource to be treated as being from a special origin that always fails the same-origin policy.
        case allowSameOrigin
        /// Allows the sandboxed resource to run scripts.
        case allowScripts
        /// Allows the sandboxed resource to navigate the top-level browsing context.
        case allowTopNavigation = "allow-top-navigation"
        /// Allows the sandboxed resource to navigate the top-level browsing context. but only if initiated by a user gesture.
        case allowTopNavigationByUserInteraction = "allow-top-navigation-by-user-activation"
        /// Allows the sandboxed resource to navigate to non-HTTP protocols built into browser.
        case allowTopNavigationToCustomProtocols = "allow-top-navigation-to-custom-protocols"
    }
    
    /// A value for the ``HTMLNode/Attribute/scope(_:)`` attribute.
    package enum Scope: String {
        /// The header relates to all cells of the row it belongs to.
        case row
        /// The header relates to all cells of the column it belongs to.
        case col
        /// The header belongs to a row group and relates to all of its cells.
        case rowGroup = "rowgroup"
        /// The header belongs to a column group and relates to all of its cells.
        case colGroup = "colgroup"
    }
    
    /// A value for the ``HTMLNode/Attribute/shape(_:)`` attribute.
    package enum Shape: String {
        /// This area is the whole image and doesn't use the ``coords(_:)``attribute.
        case `default`
        /// This area is a circle.
        ///
        /// A compliant `<area>` element's ``coords(_:)``attribute should contain exactly three integers.
        case circle
        /// This area is a rectangle.
        ///
        /// A compliant `<area>` element's ``coords(_:)``attribute should contain exactly four integers.
        case rectangle
        /// This area is a polygon.
        ///
        /// A compliant `<area>` element's ``coords(_:)``attribute should contain at least integers.
        case polygon
    }
}
