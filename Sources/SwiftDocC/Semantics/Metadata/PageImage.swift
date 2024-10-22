/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// Associates an image with a page.
///
/// You can use this directive to set the image used when rendering a user-interface element representing the page.
/// For example, use the page image directive to customize the icon used to represent this page in the navigation sidebar,
/// or the card image used to represent this page when using the ``Links`` directive and the ``Links/VisualStyle/detailedGrid``
/// visual style.
public final class PageImage: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "5.8"
    public let originalMarkup: BlockDirective
    
    /// The image's purpose.
    @DirectiveArgumentWrapped
    public private(set) var purpose: Purpose
    
    /// The base file name of an image in your documentation catalog.
    @DirectiveArgumentWrapped(
        parseArgument: { bundle, argumentValue in
            ResourceReference(bundleIdentifier: bundle.id.rawValue, path: argumentValue)
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
