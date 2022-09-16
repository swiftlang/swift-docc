/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A reference to an image.
public struct ImageReference: MediaReference, URLReference, Equatable {
    /// The type of this image reference.
    ///
    /// This value is always `.image`.
    public var type: RenderReferenceType = .image
    
    /// The identifier of this reference.
    public var identifier: RenderReferenceIdentifier
    
    /// Alternate text for the image.
    ///
    /// This text helps screen-readers describe the image.
    public var altText: String?
    
    /// The data associated with this asset, including its variants.
    public var asset: DataAsset
    
    /// Creates a new image reference.
    ///
    /// - Parameters:
    ///   - identifier: The identifier for this image reference.
    ///   - altText: Alternate text for the image.
    ///   - asset: The data associated with this asset, including its variants.
    public init(identifier: RenderReferenceIdentifier, altText: String? = nil, imageAsset asset: DataAsset) {
        self.identifier = identifier
        self.asset = asset
        self.altText = altText
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case identifier
        case alt
        case variants
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(RenderReferenceType.self, forKey: .type)
        identifier = try values.decode(RenderReferenceIdentifier.self, forKey: .identifier)
        altText = try values.decodeIfPresent(String.self, forKey: .alt)
        
        // rebuild the data asset
        asset = DataAsset()
        let variants = try values.decode([VariantProxy].self, forKey: .variants)
        variants.forEach { (variant) in
            asset.register(variant.url, with: DataTraitCollection(from: variant.traits), metadata: .init(svgID: variant.svgID))
        }
    }
    
    /// The relative URL to the folder that contains all images in the built documentation output.
    public static let baseURL = URL(string: "/images/")!
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(altText, forKey: .alt)
        
        // convert the data asset to a serializable object
        var result = [VariantProxy]()
        // sort assets by URL path for deterministic sorting of images
        asset.variants.sorted(by: \.value.path).forEach { (key, value) in
            let url = value.isAbsoluteWebURL ? value : destinationURL(for: value.lastPathComponent)
            result.append(VariantProxy(url: url, traits: key, svgID: asset.metadata[value]?.svgID))
        }
        try container.encode(result, forKey: .variants)
    }
    
    
    /// A codable proxy value that the image reference uses to serialize information about its asset variants.
    public struct VariantProxy: Codable {
        /// The URL to the file for this image variant.
        public var url: URL
        /// The traits of this image reference.
        public var traits: [String]
        /// The ID for the SVG that should be rendered for this variant.
        ///
        /// This value is `nil` for variants that are not SVGs and for SVGs that do not include ids.
        public var svgID: String?
        
        /// Creates a new proxy value with the given information about an image variant.
        /// 
        /// - Parameters:
        ///   - size: The size of the image variant.
        ///   - url: The URL to the file for this image variant.
        ///   - traits: The traits of this image reference.
        init(url: URL, traits: DataTraitCollection, svgID: String?) {
            self.url = url
            self.traits = traits.toArray()
            self.svgID = svgID
        }
        
        enum CodingKeys: String, CodingKey {
            case size
            case url
            case traits
            case svgID
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            url = try values.decode(URL.self, forKey: .url)
            traits = try values.decode([String].self, forKey: .traits)
            svgID = try values.decodeIfPresent(String.self, forKey: .svgID)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(url, forKey: .url)
            try container.encode(traits, forKey: .traits)
            try container.encodeIfPresent(svgID, forKey: .svgID)
        }
    }
}
