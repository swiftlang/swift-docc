/*
 This source file is part of the Swift.org open source project

Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/// A directive that enables or provides an override for the "Edit this Page" link.
///
/// Use this directive to explicitly set the URL for the "Edit this Page" link, or to disable it for a specific page.
///
/// This directive is only valid within a ``Metadata`` directive:
/// ```markdown
/// @Metadata {
///    @EditLink(url: "https://github.com/apple/swift-docc/edit/main/Sources/SwiftDocC/Semantics/Metadata/EditLink.swift")
/// }
/// ```
///
/// To disable the link for a page:
/// ```markdown
/// @Metadata {
///    @EditLink(isDisabled: true)
/// }
/// ```
public final class EditLink: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "6.5"
    public let originalMarkup: BlockDirective
    
    /// The URL for the "Edit this Page" link.
    ///
    /// If not provided, DocC will attempt to automatically determine the URL if a source repository is configured.
    @DirectiveArgumentWrapped
    public var url: URL? = nil
    
    /// Whether the "Edit this Page" link should be disabled for this page.
    @DirectiveArgumentWrapped
    public var isDisabled: Bool = false
    
    static var keyPaths: [String : AnyKeyPath] = [
        "url" : \EditLink._url,
        "isDisabled" : \EditLink._isDisabled,
    ]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
