/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A reference to media, such as an image or a video.
public protocol MediaReference: RenderReference {
    /// The data associated with this asset, including its variants.
    var asset: DataAsset { get set }
    /// Alternate text for the media.
    ///
    /// This text helps screen readers describe the media.
    var altText: String? { get set }
}

/// A proxy value for information about an asset variant.
protocol MediaVariantProxy {
    /// The URL of the file for this variant.
    var url: URL { get }
    /// The traits of this variant.
    var traits: [String] { get }
}

extension MediaVariantProxy {
    /// Compares two variants by their rendered URL, and by traits for variants with identical URLs.
    static func isInOrder(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.url.path != rhs.url.path {
            return lhs.url.path < rhs.url.path
        }
        return lhs.traits.joined() < rhs.traits.joined()
    }
}
