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
        /// A short, abbreviated description of a `<th>`element's content.
        case abbr(String)
        /// A list of file types that the receiver of a `<form>` or `<input>` element's submission accepts.
        ///
        /// The file types are encoded as a comma separated string.
        case accept([String])
        /// The character set that the server accepts for the `<form>` element's submission.
        ///
        /// The only accepted value is "utf-8".
        case acceptCharset
        /// A hint for the browser to generate a keyboard shortcut for the current element.
        ///
        /// Browsers should use the first character that's found on the user's keyboard layout.
        case accessKey([UnicodeScalar])
        /// The URL that processes the `<form>` element's submission.
        case action(String)
        @available(*, deprecated, message: "Use CSS to align the content instead")
        case align(Align)
        /// Determines what container policy that the browser will use for the `<iframe>` element.
        case allow(String)
        /// The opacity of a "color" type `<input>` element's color.
        case alpha(Int)
        /// A textual description that can replace the image when it can't be displayed in an `<img>`, `<area>`, or `<input>` element.
        case alt(String)
        /// The type of content that's referenced by the `<link>` element.
        case `as`(As)
        /// Specifies the that browser should run the `<script>` element's script asynchronously.
        case `async`
        /// A configuration of the autocapitalization behavior of the element.
        case autoCapitalize(AutoCapitalize)
        /// A hint to the browser that the `<form>`, `<input>`, `<select>`, or `<textarea>` element can have its contents automatically completed.
        case autoComplete(String)
        /// A configuration of the autocorrection behavior for the element.
        case autoCorrect(Bool)
        /// An indication that browser it to focus the element as soon as the page is loaded, allowing the user to just start typing without having to manually focus the element.
        case autoFocus
        /// Specifies that the browser should automatically being playing the `<audio>` or `<video>` element's resource as soon as it can, without waiting for the entire resource to finish downloading.
        case autoPlay
        @available(*, deprecated, message: "Use CSS to configure a background image instead")
        case background(String)
        @available(*, deprecated, message: "Use CSS to configure a background color instead")
        case bgColor(String)
        @available(*, deprecated, message: "Use CSS to configure a border instead")
        case border(String)
        /// The media capture input method for a "file" type `<input>` element.
        case capture(Capture)
        /// Declares the document's character encoding is UTF-8; which is the only valid encoding.
        case charSet
        /// Whether or not a "checkbox" type or "radio" type `<input>` element is checked.
        case checked
        /// The URL to either the source of a `<blockquote>` or `<q>` element's source or to a `<ins>` or `<del>` element's change.
        case cite(String)
        /// A space-separated list of classes for the element.
        case `class`(String)
        @available(*, deprecated, message: "Use CSS to configure a text color instead")
        case color(String)
        /// The colorspace that the "color" type `<input>` element should use for selecting its color value.
        case colorspace(String)
        /// The width of a `<textarea>` element's textual contents, measured in average character widths.
        case cols(Int)
        /// How many columns the `<td>` or `<th>` element spans.
        case colSpan(UInt)
        /// The value associated with a `<meta>` element's ``name(_:)`` attribute.
        case contents(String)
        /// A configuration that controls whether or not the element is editable.
        case contentEditable(ContentEditable)
        /// Specifies if the browser should offer audio playback controls for the `<audio>` or `<video>` element.
        case controls
        /// A hint to the browser for what controls to show for this `<audio>` element.
        case controlsList(Controls)
        /// The coordinate information of an `<area>` element's ``shape(_:)`` attribute.
        case coords(String)
        /// Specifies that the browser should use Cross-Origin Resource Sharing (CORS) to fetch the `<audio>`, `<img>`, `<link>`, `<script>`, or `<video>` element's resource.
        case crossOrigin(CrossOrigin)
        /// Specifies the Content Security Policy that an `<iframe>` element's embedded document must enforce upon itself.
        case csp(String)
        /// The URL of an `<object>` element's resource.
        case data(String)
        /// Either the machine-readable representation of a `<time>` element's date-time value or the date-time value associated with an `<ins>` or `<del>` element's change.
        case datetime(String)
        /// A hint to the browser for how it should perform image decoding in relation to rendering for the `<img>` element's resource.
        case decoding(Decoding)
        /// A hint to the browser that it should enable the `<track>` element by default unless the user's preferences indicate something different.
        case `default`
        /// A hint to the browser that is should run the `<script>` element's source after it has parsed the page.
        case `defer`
        /// The text direction of the element.
        case dir(Dir)
        /// The name of the form field that the browser should use to submit the `<input>` or `<textarea>` element's directionality information.
        case dirName(String)
        /// Whether or not the  `<button>`, `<fieldset>`, `<input>`, `<optgroup>`, `<option>`, `<select>`, or `<textarea>` element is disabled.
        case disabled
        /// A configuration that the browser should disable playback on devices that are connected either via wire or wireless technologies.
        case disableRemotePlayback
        /// A configuration that the browser should not suggest a Picture-in-Picture context menu.
        case disablePictureInPicture
        /// A hint to the browser that the  `<a>` or `<area>` element's linked URL is used to downloading a resource.
        case download
        /// A configuration that controls whether or not the element is draggable.
        case draggable(Bool)
        /// The MIME type of the `<form>` element's submission if the ``method(_:)`` attribute's value is ``Method/post``.
        case encType(EncodingType)
        /// A configuration of what action label (or icon) the browser should present for the "enter key" on virtual keyboards.
        case enterKeyHint(EnterKeyHint)
        /// Marks the `<img>` element for observation by the PerformanceElementTiming API and specifies the identifier for the observed timing event.
        case elementTiming(String)
        /// A hint to the browser about the relative priority it should use when fetching the `<img>`, `<link>`, or `<script>` element's resource.
        case fetchPriority(FetchPriority)
        /// The identifier of the other element that this `<label>` or `<output>` element describes.
        case `for`(String)
        /// The identifier if the `<form>` element that this `<button>`, `<fieldset>`, `<input>`, `<object>`, `<output>`, `<select>`, or `<textarea>` element belongs to.
        case form(String)
        /// Overrides the action of the `<form>` element that this `<input>` or `<button>` element belongs to.
        case formAction(String)
        /// Overrides the encoding type of the `<form>` element that this `<input>` or `<button>` element belongs to.
        case formEncType(EncodingType)
        /// Overrides the submission method of the `<form>` element that this `<input>` or `<button>` element belongs to.
        case formMethod(Method)
        /// Overrides the validation configuration of the `<form>` element that this `<input>` or `<button>` element belongs to.
        case formValidate
        /// Overrides the target of the `<form>` element that this `<input>` or `<button>` element belongs to.
        case formTarget(String)
        /// A list of strings corresponding to the id attributes of the `<th>` elements that provide the headers for this header cell.
        case headers([String])
        /// An offset for the heading levels of descendants of the element.
        ///
        /// According to the HTML specification, the value must be a valid non-negative integer between 0 and 8, inclusive.
        case headingOffset(Int)
        /// Prevents a heading offset from traversing beyond this element.
        case headingReset
        /// The intrinsic height, in pixels, of the `<canvas>`, `<embed>`, `<iframe>`, `<img>`, `<input>`, `<object>`, or `<video>` element.
        ///
        /// For all other elements, configure the element's height using the CSS `height` property instead.
        case height(Int)
        /// An indication that the element is not yet, or is no longer, directly relevant to the page's current state,
        /// or that it is being used to declare content to be reused by other parts of the page as opposed to being directly accessed by the user.
        case hidden(Hidden)
        /// The lower bound of the high end of the `<meter>` element's measured range.
        case high(Int)
        /// The URL that the `<a>`, `<area>`, `<base>`, or `<link>` element references.
        case href(String)
        /// A hint at the human language of the `<a>` or `<link>` element's referenced content.
        case hrefLang(String)
        /// A `<meta>` element configuration that instructs the browser to process the page as if certain HTTP headers were present.
        case httpEquiv(HTTPEquivalent)
        /// An identifier for this element that's unique within the scope of the entire HTML document.
        case id(String)
        /// A configuration that controls whether or not the element is inert (cannot be interacted with).
        case inert
        /// One or more hashes of the `<link>` or `<script>` element's linked resource that the browser can use to ensure that the resource is what it is expected to be.
        case integrity([String])
        /// A hint to browsers about the type of virtual keyboard to use when editing this element.
        case inputMode(InputMode)
        /// Specifies that the `<img>` element's image is part of a server-side map.
        case isMap
        /// An indication of how the `<track>` element is meant to be used.
        case kind(Kind)
        /// A human-readable title of the `<optgroup>`, `<option>`, or `<track>` element.
        case label(String)
        /// The language that a non-editable element is in, or the language that an editable element should be written in by the user.
        ///
        /// A compliant HTTP page should only specify a valid [BCP 47 language tag](https://en.wikipedia.org/wiki/IETF_language_tag) as the value for this attribute.
        case lang(String)
        @available(*, deprecated, message: "Use the `type` attribute to specify a `<script>` element's scripting language instead.")
        case language(String)
        /// An indication for how the browser should load the `<img>` or `<iframe>` element's resource.
        case loading(Loading)
        /// The identifier of a `<datalist>` element that provides predefined values to suggest to the user for the `<input>` element.
        case list(String)
        /// A configuration that the `<audio>` or `<video>` element should automatically seek to the start upon reaching the end.
        case loop
        /// The upper bound of of the low end of the `<meter>` element's measured range.
        case low(Int)
        /// The upper bound of the `<meter>` element's measured range.
        case max(Int)
        /// The maximum number of characters allowed in the `<input>` or `<textarea>` element.
        case maxLength(Int)
        /// The lower bound of the `<meter>` element's measured range.
        case min(Int)
        /// The minimum number of characters allowed in the `<input>` or `<textarea>` element.
        case minLength(Int)
        /// The media query for the resource's intended media of the `<a>`, `<area>`, `<link>`, `<source>`, or `<style>` element.
        case media(String)
        /// The HTTP method that the browser should use to submit the `<form>` element.
        case method(Method)
        /// An indication that this `<input>` or `<select>` element supports multiple values.
        case multiple
        /// The `<audio>` or `<video>` element will start out as muted.
        case muted
        /// Either the name that gives the metadata name for a ``contents(_:)`` value for a `<meta>` element or the name of a form element for the server to identify fields in the form submission.
        case name(String)
        /// A cryptographic nonce ("number used once") which can be used by Content Security Policy to determine whether or not a given fetch will be allowed to proceed.
        case nonce(String)
        /// An indication that this `<form>` element should not be validated before its submission.
        case noValidate
        /// A configuration that a `<details>` element is expanded or that a `<dialog>` element is active and can be interacted with.
        case open
        /// The optimal value of the `<meter>` element's measured range.
        case optimum(Int)
        /// A regular expression that validates the `<input>` the element's value.
        case pattern(String)
        /// A list of URLs of that are interested in being notified if the user follows the `<a>` or `<area>` element's linked URL.
        case ping([String])
        /// A placeholder value that provides a hint to the user of what can be entered in the `<input>` or `<textare>` element.
        case placeholder(String)
        /// An indication that browser should display the video within the `<video>` element's playback area.
        case playsInline
        /// Designates the element as a "popover" that is hidden until it opened via an invoking element.
        case popover
        /// A URL for an image to display while the video is downloading.
        case poster(String)
        /// A hint to the browser about how it should load the `<audio>` element's resource.
        case preLoad(PreLoad)
        /// An indication whether or not the`<input>` or `<textarea>` element can be edited.
        case readOnly
        /// How much information the browser should send in a referrer header when following the `<a>` element's link.
        case referrerPolicy(ReferrerPolicy)
        /// A list of relationships between the current document and the `<a>` element's linked destination resource.
        case rel([Rel])
        /// An indication whether or not the`<input>`, `<select>`, or `<textarea>` element is required to be filled out.
        case required
        /// An indication that a `<ol>` element should displays its list items in descending order (instead of in ascending order).
        case revered
        /// The semantic meaning of an element.
        case role(Role)
        /// The number of visible lines of text for the `<textarea>` element.
        case rows(Int)
        /// An indication of how many rows the `<td>` or `<th>` element spans.
        case rowSpan(UInt)
        /// Restrictions applied to the content embedded in the `<iframe>` element.
        case sandbox([Sandbox])
        /// The cells that the `<th>` element relates to.
        case scope(Scope)
        /// An indication that the `<option>` element is initially selected when the page loads.
        case selected
        /// The shape of the `<a>` or `<area>` element.
        case shape(Shape)
        /// The width of the `<input>` or `<select>` element.
        ///
        /// If the element's ``type(_:)`` attribute is "text" or "password", the value is measured in number of characters.
        /// Otherwise, the value is measured in pixels.
        case size(Int)
        /// A list of source sizes that describe the final rendered width of an `<img>`, `<link>`, or `<source>` elements image resource.
        case sizes([String])
        /// Assigns a slot in the shadow tree to the element.
        ///
        /// The created `<slot>` element will have a ``name(_:)`` attribute that matches the value of this `slot` attribute.
        case slot(String)
        /// The number of columns that a `<col>` or `<colgroup>` element spans.
        case span(Int)
        /// A configuration that controls whether or not the element is spellchecked.
        case spellcheck(Bool)
        /// The URL of the resource that this `<audio>`, `<embed>`, `<iframe>`, `<img>`, `<input>`, `<script>`, `<source>`, `<track>`, or `<video>` element references.
        case src(String)
        /// Inline HTML to embed instead of the `<iframe>` element's resource.
        ///
        /// If the browser supports this attribute, and it's present, the browser will ignore the the ``src(_:)`` attribute.
        case srcDoc(String)
        /// The language `<track>` element's textual track data.
        ///
        /// A compliant `<track>` element must only specify a valid [BCP 47 language tag](https://en.wikipedia.org/wiki/IETF_language_tag) as the value for this attribute.
        case srcLang(String)
        /// A list of one or more resource URLs and their descriptors for the `<img>` or `<source>` element.
        case srcSet([String])
        /// The number of the `<ol>` element's first list item.
        case start(Int)
        /// The stepping interval for the `<input>` element with a numeric input type ("date", "month", "week", "time", "number", "range", or "datetime-local").
        case step(Int)
        @available(*, deprecated, message: "Use style sheet file to define CSS instead.")
        case style(String)
        @available(*, deprecated, message: "Us a `<caption>` element to describe this `<table>` element instead.")
        case summary(String)
        /// A configuration that controls whether or not the element is sequentially focusable and determines its relative oder in the sequential navigation.
        ///
        /// A negative value means that the element is _click_ focusable but not _sequentially_ focusable.
        /// A positive value means that the element is both _click_ focusable and _sequentially_ focusable and creates a relative ordering so that higher values come later.
        case tabIndex(Int)
        /// The name of the "navigable" that browsers will use when following the `<a>` or `<area>` element's link or where browsers will display the response for a `<form>` element's submission.
        case target(String)
        /// Advisory information for the element, such as would be appropriate for a tooltip.
        case title(String)
        /// A configuration that controls whether the element's text is to be translated when the page is localized, or whether to leave them unchanged.
        case translate(Bool)
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
        /// The intrinsic width, in pixels, of the `<canvas>`, `<embed>`, `<iframe>`, `<img>`, `<input>`, `<object>`, or `<video>` element.
        case width(Int)
        /// A configuration that the `<textarea>` element's textual content should wrap.
        case wrap
        /// A configuration that the browser should offer writing suggestions for this element.
        case writingSuggestions(Bool)
    }
}

extension HTMLNode.Attribute {
    // The more succinct name "name" is already taken by one of the (meta) attributes.
    // That attribute gets the better name because it has `package` access, and this is only accessible within the DocCHTML module.
    var nameForFormatting: StaticString {
        switch self {
            case .abbr:                    "abbr"
            case .accept:                  "accept"
            case .acceptCharset:           "accept-charset"
            case .accessKey:               "accesskey"
            case .action:                  "action"
            case .align:                   "align"
            case .allow:                   "allow"
            case .alpha:                   "alpha"
            case .alt:                     "alt"
            case .as:                      "as"
            case .async:                   "async"
            case .autoCapitalize:          "autocapitalize"
            case .autoComplete:            "autoComplete"
            case .autoCorrect:             "autocorrect"
            case .autoFocus:               "autofocus"
            case .autoPlay:                "autoplay"
            case .background:              "background"
            case .bgColor:                 "bgColor"
            case .border:                  "border"
            case .capture:                 "capture"
            case .charSet:                 "charset"
            case .checked:                 "checked"
            case .cite:                    "cite"
            case .class:                   "class"
            case .color:                   "color"
            case .colorspace:              "colorspace"
            case .cols:                    "cols"
            case .colSpan:                 "colspan"
            case .contentEditable:         "contenteditable"
            case .contents:                "contents"
            case .controls:                "controls"
            case .controlsList:            "controlslist"
            case .coords:                  "coords"
            case .crossOrigin:             "crossorigin"
            case .csp:                     "csp"
            case .data:                    "data"
            case .datetime:                "datetime"
            case .decoding:                "decoding"
            case .default:                 "default"
            case .defer:                   "defer"
            case .dir:                     "dir"
            case .dirName:                 "dirname"
            case .disabled:                "disabled"
            case .disablePictureInPicture: "disablepictureinpicture"
            case .disableRemotePlayback:   "disableremoteplayback"
            case .download:                "download"
            case .draggable:               "draggable"
            case .elementTiming:           "elementtiming"
            case .encType:                 "enctype"
            case .enterKeyHint:            "enterkeyhint"
            case .fetchPriority:           "fetchpriority"
            case .for:                     "for"
            case .form:                    "form"
            case .formAction:              "formaction"
            case .formEncType:             "formenctype"
            case .formMethod:              "formmethod"
            case .formTarget:              "formtarget"
            case .formValidate:            "formvalidate"
            case .headers:                 "headers"
            case .headingOffset:           "headingoffset"
            case .headingReset:            "headingreset"
            case .height:                  "height"
            case .hidden:                  "hidden"
            case .high:                    "high"
            case .href:                    "href"
            case .hrefLang:                "hreflang"
            case .httpEquiv:               "http-equiv"
            case .id:                      "id"
            case .inert:                   "inert"
            case .inputMode:               "inputmode"
            case .integrity:               "integrity"
            case .isMap:                   "ismap"
            case .kind:                    "kind"
            case .label:                   "label"
            case .lang:                    "lang"
            case .language:                "language"
            case .list:                    "list"
            case .loading:                 "loading"
            case .loop:                    "loop"
            case .low:                     "low"
            case .max:                     "max"
            case .maxLength:               "maxlength"
            case .media:                   "media"
            case .method:                  "method"
            case .min:                     "min"
            case .minLength:               "minlength"
            case .multiple:                "multiple"
            case .muted:                   "muted"
            case .name:                    "name"
            case .nonce:                   "nonce"
            case .noValidate:              "novalidate"
            case .open:                    "open"
            case .optimum:                 "optimum"
            case .pattern:                 "pattern"
            case .ping:                    "ping"
            case .placeholder:             "placeholder"
            case .playsInline:             "playsinline"
            case .popover:                 "popover"
            case .poster:                  "poster"
            case .preLoad:                 "preload"
            case .readOnly:                "readonly"
            case .referrerPolicy:          "referrerpolicy"
            case .rel:                     "rel"
            case .required:                "required"
            case .revered:                 "revered"
            case .role:                    "role"
            case .rows:                    "rows"
            case .rowSpan:                 "rowspan"
            case .sandbox:                 "sandbox"
            case .scope:                   "scope"
            case .selected:                "selected"
            case .shape:                   "shape"
            case .size:                    "size"
            case .sizes:                   "sizes"
            case .slot:                    "slot"
            case .span:                    "span"
            case .spellcheck:              "spellcheck"
            case .src:                     "src"
            case .srcDoc:                  "srcdoc"
            case .srcLang:                 "srclang"
            case .srcSet:                  "srcset"
            case .start:                   "start"
            case .step:                    "step"
            case .style:                   "style"
            case .summary:                 "summary"
            case .tabIndex:                "tabindex"
            case .target:                  "target"
            case .title:                   "title"
            case .translate:               "translate"
            case .type:                    "type"
            case .value:                   "value"
            case .width:                   "width"
            case .wrap:                    "wrap"
            case .writingSuggestions:      "writingsuggestions"

        }
    }
    
    // The more succinct name "value" is already taken by one of the (meta) attributes.
    // That attribute gets the better name because it has `package` access, and this is only accessible within the DocCHTML module.
    var valueForFormatting: String {
        switch self {
            case .abbr(let string):                return string
            case .accept(let types):               return types.joined(separator: ",")
            case .acceptCharset:                   return "utf-8"
            case .accessKey(let keys):             return keys.map { String(Character($0)) }.joined(separator: " ")
            case .action(let string):              return string
            case .align(let value):                return value.rawValue
            case .allow(let string):               return string
            case .alpha(let number):               return number.description
            case .alt(let string):                 return string
            case .as(let value):                   return value.rawValue
            case .async:                           return "" // A "boolean" attribute
            case .autoCapitalize(let value):       return value.rawValue
            case .autoComplete(let string):        return string
            case .autoCorrect(let enabled):        return enabled ? "on" : "off"
            case .autoFocus:                       return "" // A "boolean" attribute
            case .autoPlay:                        return "" // A "boolean" attribute
            case .background(let string):          return string
            case .bgColor(let string):             return string
            case .border(let string):              return string
            case .capture(let value):              return value.rawValue
            case .charSet:                         return "utf-8" // There's only one valid HTML 5 character encoding.
            case .checked:                         return "" // A "boolean" attribute
            case .cite(let string):                return string
            case .class(let classNames):           return classNames
            case .color(let string):               return string
            case .colorspace(let string):          return string
            case .cols(let number):                return number.description
            case .colSpan(let number):             return number.description
            case .contentEditable(let value):      return value.rawValue
            case .contents(let string):            return string
            case .controls:                        return "" // A "boolean" attribute
            case .controlsList(let value):         return value.rawValue
            case .coords(let string):              return string
            case .crossOrigin(let value):          return value.rawValue
            case .csp(let string):                 return string
            case .data(let string):                return string
            case .datetime(let string):            return string
            case .decoding(let value):             return value.rawValue
            case .default:                         return "" // A "boolean" attribute
            case .defer:                           return "" // A "boolean" attribute
            case .dir(let value):                  return value.rawValue
            case .dirName(let string):             return string
            case .disabled:                        return "" // A "boolean" attribute
            case .disablePictureInPicture:         return "" // A "boolean" attribute
            case .disableRemotePlayback:           return "" // A "boolean" attribute
            case .download:                        return "" // A "boolean" attribute
            case .draggable(let enabled):          return enabled ? "true" : "false"
            case .elementTiming(let string):       return string
            case .encType(let value):              return value.rawValue
            case .enterKeyHint(let value):         return value.rawValue
            case .fetchPriority(let value):        return value.rawValue
            case .for(let string):                 return string
            case .form(let string):                return string
            case .formAction(let string):          return string
            case .formEncType(let value):          return value.rawValue
            case .formMethod(let value):           return value.rawValue
            case .formTarget(let string):          return string
            case .formValidate:                    return "" // A "boolean" attribute
            case .headers(let strings):            return strings.joined(separator: " ")
            case .headingOffset(let number):       return number.description //min(0, max(8, number)).description
            case .headingReset:                    return "" // A "boolean" attribute
            case .height(let number):              return number.description
            case .hidden(let value):               return value.rawValue
            case .high(let number):                return number.description
            case .href(let string):                return string
            case .hrefLang(let string):            return string
            case .httpEquiv(let value):            return value.rawValue
            case .id(let string):                  return string
            case .inert:                           return "" // A "boolean" attribute
            case .inputMode(let value):            return value.rawValue
            case .integrity(let string):           return string.joined(separator: " ")
            case .isMap:                           return "" // A "boolean" attribute
            case .kind(let string):                return string.rawValue
            case .label(let string):               return string
            case .lang(let string):                return string
            case .language(let string):            return string
            case .list(let string):                return string
            case .loading(let value):              return value.rawValue
            case .loop:                            return "" // A "boolean" attribute
            case .low(let number):                 return number.description
            case .max(let number):                 return number.description
            case .maxLength(let number):           return number.description
            case .media(let string):               return string
            case .method(let value):               return value.rawValue
            case .min(let number):                 return number.description
            case .minLength(let number):           return number.description
            case .multiple:                        return "" // A "boolean" attribute
            case .muted:                           return "" // A "boolean" attribute
            case .name(let string):                return string
            case .nonce(let string):               return string
            case .noValidate:                      return "" // A "boolean" attribute
            case .open:                            return "" // A "boolean" attribute
            case .optimum(let number):             return number.description
            case .pattern(let string):             return string
            case .ping(let urls):                  return urls.joined(separator: " ")
            case .placeholder(let string):         return string
            case .playsInline:                     return "" // A "boolean" attribute
            case .popover:                         return "" // A "boolean" attribute
            case .poster(let string):              return string
            case .preLoad(let value):              return value.rawValue
            case .readOnly:                        return "" // A "boolean" attribute
            case .referrerPolicy(let value):       return value.rawValue
            case .rel(let values):                 return values.map(\.rawValue).joined(separator: " ")
            case .required:                        return "" // A "boolean" attribute
            case .revered:                         return "" // A "boolean" attribute
            case .role(let value):                 return value.rawValue
            case .rows(let number):                return number.description
            case .rowSpan(let number):             return number.description
            case .sandbox(let restrictions):       return restrictions.map(\.rawValue).joined(separator: " ")
            case .scope(let value):                return value.rawValue
            case .selected:                        return "" // A "boolean" attribute
            case .shape(let value):                return value.rawValue
            case .size(let number):                return number.description
            case .sizes(let strings):              return strings.joined(separator: " ")
            case .slot(let string):                return string
            case .span(let number):                return number.description
            case .spellcheck(let enabled):         return enabled ? "true" : "false"
            case .src(let string):                 return string
            case .srcDoc(let string):              return string
            case .srcLang(let string):             return string
            case .srcSet(let strings):             return strings.joined(separator: ",")
            case .start(let number):               return number.description
            case .step(let number):                return number.description
            case .style(let string):               return string
            case .summary(let string):             return string
            case .tabIndex(let number):            return number.description
            case .target(let string):              return string
            case .title(let string):               return string
            case .translate(let enabled):          return enabled ? "yes" : "no"
            case .type(let string):                return string
            case .value(let string):               return string
            case .width(let number):               return number.description
            case .wrap:                            return "" // A "boolean" attribute
            case .writingSuggestions(let enabled): return enabled ? "true" : "false"

        }
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
