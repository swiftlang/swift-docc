/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown


/// A directive that specifies an additional URL for the page where the directive appears.
///
/// Use this directive to declare a URL where a piece of content was previously located.
/// For example, if you host the compiled documentation on a web server,
/// that server can read this data and set an HTTP "301 Moved Permanently" redirect from
/// the declared URL to the page's current URL and avoid breaking any existing links to the content.
public final class Redirect: Semantic, AutomaticDirectiveConvertible {
    public static let directiveName = "Redirected"
    public let originalMarkup: BlockDirective
    
    /// The URL that redirects to the page associated with the directive.
    @DirectiveArgumentWrapped(name: .custom("from"))
    public private(set) var oldPath: URL
    
    static var keyPaths: [String : AnyKeyPath] = [
        "oldPath" : \Redirect._oldPath,
    ]
    
    init(originalMarkup: BlockDirective, oldPath: URL) {
        self.originalMarkup = originalMarkup
        super.init()
        
        self.oldPath = oldPath
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}

