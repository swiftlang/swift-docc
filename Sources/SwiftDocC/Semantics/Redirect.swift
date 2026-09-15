/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown


/// A directive that specifies a previous URL for the page where the directive appears.
///
/// If the page has moved more than once you can add multiple  `Redirected` directives, each specifying one previous URL. For example:
///
/// ```md
/// @Redirected(from: "old/path/to/this/page")
/// @Redirected(from: "another/old/path/to/this/page")
/// ```
///
/// > Note: Starting with version 6.0, the `Redirected` directive is supported both top-level and as a member of a ``Metadata`` directive. In
/// earlier versions, the `Redirected` directive is only supported as a top-level directive.
///
/// ### Setting up Redirects
///
/// If you host your documentation on a web server, you can set a HTTP "301 Moved Permanently" redirect for each `Redirected` value to avoid breaking existing links to your content.
///
/// To find each page’s Redirected values, pass the `--emit-digest` flag to DocC.
/// This flag configures DocC to write additional metadata files to the output directory.
/// One of these files, `linkable-entities.json`, contains summarized information about all pages and on-page landmarks that you can link to from outside the DocC documentation.
/// Each of these "entities" has a `"path"`---which represents the current relative path of that page---and an optional list of `"redirects"`---which represent all the `Redirected` values for page as they were authored in the markup.
/// You can write either relative redirect values or absolute redirect values in the markup depending on what information you need when setting up HTTP "301 Moved Permanently" redirects on your web server.
public final class Redirect: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "5.5"
    public static let directiveName = "Redirected"
    public let originalMarkup: BlockDirective
    
    /// The URL that redirects to the page associated with the directive.
    @DirectiveArgumentWrapped(name: .custom("from"))
    public private(set) var oldPath: URL
    
    static var keyPaths: [String : AnyKeyPath] = [
        "oldPath" : \Redirect._oldPath,
    ]
    
    static var hiddenFromDocumentation = false
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}

