/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A custom script, declared in a documentation catalog's `custom-scripts.json` file, to include in a full-page static HTML document.
///
/// Each static HTML page is a separate document, so every navigation is a page load and every custom script runs on each page,
/// regardless of the custom script's `run` value.
package struct CustomScript: Decodable, Equatable {
    /// The URL of an external script.
    package var url: String?
    /// The name of a local script, optionally including the ".js" extension.
    package var name: String?
    /// The `type` attribute of the script element.
    package var type: String?
    /// Whether the script element is `async`.
    package var async: Bool?
    /// The `integrity` attribute of the script element.
    package var integrity: String?

    package init(url: String? = nil, name: String? = nil, type: String? = nil, async: Bool? = nil, integrity: String? = nil) {
        self.url = url
        self.name = name
        self.type = type
        self.async = async
        self.integrity = integrity
    }
}

package extension HTMLNode {
    /// Creates a `<script>` element for the given custom script.
    ///
    /// - Parameters:
    ///   - customScript: The custom script to create an element for.
    ///   - localScriptsPath: The relative path from the page to the directory of local scripts, including a trailing slash.
    init(from customScript: CustomScript, localScriptsPath: String) {
        var attributes: [HTMLNode.Attribute] = []
        if customScript.async == true {
            attributes.append(.async)
        }
        if let url = customScript.url {
            // An integrity check on an external script requires a CORS request.
            if let integrity = customScript.integrity {
                attributes.append(.crossOrigin(.anonymous))
                attributes.append(.integrity([integrity]))
            }
            attributes.append(.src(url))
        } else if let name = customScript.name {
            if let integrity = customScript.integrity {
                attributes.append(.integrity([integrity]))
            }
            let fileName = name.hasSuffix(".js") ? name : "\(name).js"
            attributes.append(.src(localScriptsPath + fileName))
        }
        if let type = customScript.type {
            attributes.append(.type(type))
        }
        self = script(attributes: attributes, contents: [])
    }
}
