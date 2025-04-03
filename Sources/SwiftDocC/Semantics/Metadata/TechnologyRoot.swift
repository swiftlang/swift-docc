/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
public import Markdown

/// Configures an article to become a top-level page.
///
/// If your documentation only consists of articles, without any framework documentation or other top-level pages, DocC will use the only article or the article with the same base name as the documentation catalog ('.docc' directory) as the top-level page.
/// If the documentation doesn't contain an article with the same base name as the documentation catalog, DocC will synthesize a minimal top-level page.
///
/// To customize which article is the top-level page of your documentation, add a `TechnologyRoot` directive within a `Metadata` directive in that article:
///
/// ```md
/// # Page Title
///
/// @Metadata {
///    @TechnologyRoot
/// }
/// ```
///
/// > Earlier Versions:
/// > Before Swift-DocC 6.0, article-only documentation catalogs require one of the articles to be marked as a `TechnologyRoot`.
///
/// ### Containing Elements
///
/// The following items can include a technology root element:
///
/// - ``Metadata``
///
/// ## See Also
///
/// - <doc:formatting-your-documentation-content>
public final class TechnologyRoot: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "5.5"
    public let originalMarkup: BlockDirective
    
    static var keyPaths: [String : AnyKeyPath] = [:]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
