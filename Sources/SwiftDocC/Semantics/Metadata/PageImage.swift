/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
public import Markdown

/// Associates an image with a page.
///
/// You can use this directive to set the image used when rendering a user-interface element representing the page.
///
/// Use the "icon" purpose to customize the icon that DocC uses to represent this page in the navigation sidebar.
/// For article pages, DocC also uses this icon to represent the article in topics sections and in ``Links`` directives that use the `list` visual style.
///
/// > Tip: Page images with the "icon" purpose work best when they're square and when they have good visual clarity at small sizes (less than 20×20 points).
///
/// Use the "card" purpose to customize the image that DocC uses to represent this page inside ``Links`` directives that use the either the `detailedGrid` or the `compactGrid` visual style.
/// For article pages, DocC also incorporates a partially faded out version of the card image in the background of the page itself.
///
/// > Tip: Page images with the "card" purpose work best when they have a 16:9 aspect ratio. Currently, the largest size that DocC displays a card image is 640×360 points.
///
/// If you specify an "icon" page image without specifying a "card" page image, DocC will use the icon as a fallback in places where the card image is preferred.
/// To avoid upscaled pixelated icons in these places, either configure a "card" page image as well or use a scalable vector image asset for the "icon" page image.
public final class PageImage: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "5.8"
    public let originalMarkup: BlockDirective
    
    /// The image's purpose.
    @DirectiveArgumentWrapped
    public private(set) var purpose: Purpose
    
    /// The base file name of an image in your documentation catalog.
    @DirectiveArgumentWrapped(
        parseArgument: { bundle, argumentValue in
            ResourceReference(bundleID: bundle.id, path: argumentValue)
        }
    )
    public private(set) var source: ResourceReference
    
    /// Alternative text that describes the image to screen readers.
    @DirectiveArgumentWrapped
    public private(set) var alt: String? = nil
    
    static var keyPaths: [String : AnyKeyPath] = [
        "purpose"   : \PageImage._purpose,
        "source"    : \PageImage._source,
        "alt"       : \PageImage._alt,
    ]
    
    /// The name of the display style for this image.
    public enum Purpose: String, CaseIterable, DirectiveArgumentValueConvertible {
        /// The image will be used when representing the page as an icon, such as in the navigation sidebar.
        case icon
        
        /// The image will be used when representing the page as a card, such as in grid styled Topics sections.
        case card
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
