/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A container for a collection of data. Each data can have multiple variants.
struct DataAssetManager {
    enum Error: DescribedError {
        case invalidImageAsset(URL)
        
        var errorDescription: String {
            switch self {
                case .invalidImageAsset(let url):
                    return "The dimensions of the image at \(url.path.singleQuoted) could not be computed because the file is not a valid image."
            }
        }
    }
    
    var storage = [String: DataAsset]()
    
    // A "file name with no extension" to "file name with extension" index
    var fuzzyKeyIndex = [String: String]()
    
    /**
     Returns the data that is registered to an data asset with the specified trait collection.
     
     If no data is registered that exactly matches the trait collection, the data with the trait
     collection that best matches the requested trait collection is returned.
    */
    func data(named name: String, bestMatching traitCollection: DataTraitCollection) -> BundleData? {
        return bestKey(forAssetName: name)
            .flatMap({ storage[$0]?.data(bestMatching: traitCollection) })
    }
    
    /// Finds the best matching storage key for a given asset name.
    /// `name` is one of the following formats:
    /// - "image" - asset name without extension
    /// - "image.png" - asset name including extension
    func bestKey(forAssetName name: String) -> String? {
        guard !storage.keys.contains(name) else { return name }
        
        // Try the fuzzy index
        return fuzzyKeyIndex[name]
    }
    
    /**
     Returns all the data objects for a given name, respective of Bundle rules.
     
     If multiple data objects are registered, the first one will be returned in a non-deterministic way.
     For example if figure1 is asked and the bundle has figure1.png and figure1.jpg, one of the two will be returned.
     
     Returns `nil` if there is no asset registered with the `name` name.
     */
    func allData(named name: String) -> DataAsset? {
        return bestKey(forAssetName: name).flatMap({ storage[$0] })
    }
    
    private let darkSuffix = "~dark"
    // These static regular expressions should always build successfully & therefore we used `try!`.
    private lazy var darkSuffixRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: "(?!^)\(self.darkSuffix)(?=[.$]|@)")
    }()
    private lazy var displayScaleRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: "(?!^)(?<=@)[1|2|3]x(?=\\.\\w*$)")
    }()
    
    private mutating func referenceMetaInformationForDataURL(_ dataURL: URL, dataProvider: DocumentationContextDataProvider? = nil, bundle documentationBundle: DocumentationBundle? = nil) throws -> (reference: String, traits: DataTraitCollection, metadata: DataAsset.Metadata) {
        var dataReference = dataURL.path
        var traitCollection = DataTraitCollection()
        
        var metadata = DataAsset.Metadata()
        if DocumentationContext.isFileExtension(dataURL.pathExtension, supported: .video) {
            // In case of a video read its traits: dark/light variants.

            let userInterfaceStyle: UserInterfaceStyle = darkSuffixRegex.matches(in: dataReference) ? .dark : .light
            // Remove the dark suffix from the image reference.
            if userInterfaceStyle == .dark {
                dataReference = dataReference.replacingOccurrences(of: darkSuffix, with: "")
            }
            traitCollection = .init(userInterfaceStyle: userInterfaceStyle, displayScale: nil)
        
        } else if DocumentationContext.isFileExtension(dataURL.pathExtension, supported: .image) {
            
            // Process dark variants.
            let userInterfaceStyle: UserInterfaceStyle = darkSuffixRegex.matches(in: dataReference) ? .dark : .light
            
            // Process variants with different scale if a file name modifier is found.
            let displayScale = displayScaleRegex.firstMatch(in: dataReference)
                .flatMap(DisplayScale.init(rawValue:)) ?? .standard
            
            // Remove traits information from the image reference to store multiple variants.
            // Remove the dark suffix from the image reference.
            if userInterfaceStyle == .dark {
                dataReference = dataReference.replacingOccurrences(of: darkSuffix, with: "")
            }
            
            // Remove the display scale information from the image reference.
            dataReference = dataReference.replacingOccurrences(of: "@\(displayScale.rawValue)", with: "")
            traitCollection = .init(userInterfaceStyle: userInterfaceStyle, displayScale: displayScale)
            
            if dataURL.pathExtension.lowercased() == "svg" {
                metadata.svgID = SVGIDExtractor.extractID(from: dataURL)
            }
        }
        
        return (reference: dataReference, traits: traitCollection, metadata: metadata)
    }
    
    /**
     Registers a collection of data and determines their trait collection.

     Data objects which have a file name ending with '~dark' are associated to their light variant.
     - Throws: Will throw `Error.invalidImageAsset(URL)` if fails to read the size of an image asset (e.g. the file is corrupt).
     */
    mutating func register<Datas: Collection>(data datas: Datas, dataProvider: DocumentationContextDataProvider? = nil, bundle documentationBundle: DocumentationBundle? = nil) throws where Datas.Element == URL {
        for dataURL in datas {
            let meta = try referenceMetaInformationForDataURL(dataURL, dataProvider: dataProvider, bundle: documentationBundle)

            let referenceURL = URL(fileURLWithPath: meta.reference, isDirectory: false)
            
            // Store the image with given scale information and display scale.
            let name = referenceURL.lastPathComponent
            storage[name, default: DataAsset()]
                .register(dataURL, with: meta.traits, metadata: meta.metadata)
            
            if name.contains(".") {
                let nameNoExtension = referenceURL.deletingPathExtension().lastPathComponent
                fuzzyKeyIndex[nameNoExtension] = name
            }
        }
    }
    
    mutating func register(dataAsset: DataAsset, forName name: String) {
        storage[name] = dataAsset
    }
    
    /// Replaces an existing asset with a new one.
    mutating func update(name: String, asset: DataAsset, dataProvider: DocumentationContextDataProvider? = nil, bundle documentationBundle: DocumentationBundle? = nil) {
        bestKey(forAssetName: name).flatMap({ storage[$0] = asset })
    }
}

/// A container for a collection of data that represent multiple ways to describe a single asset.
///
/// Assets can be media files, source code files, or files for download.
/// A ``DataAsset`` instance represents one bundle asset, which might be represented by multiple files. For example, a single image
/// asset might have a light and dark variants, and 1x, 2x, and 3x image sizes.
///
/// Each variant of an asset is identified by a ``DataTraitCollection`` and represents the best asset file for the given
/// combination of traits, e.g. a 2x scale image when rendered for Dark Mode.
/// 
/// ## Topics
///
/// ### Asset Traits
/// - ``DisplayScale``
/// - ``UserInterfaceStyle``
public struct DataAsset: Codable, Equatable {
    /// A context in which you intend clients to use a data asset.
    public enum Context: String, CaseIterable, Codable {
        /// An asset that a user intends to view alongside documentation content.
        case display
        /// An asset that a user intends to download.
        case download
    }
    
    /// The variants associated with the resource.
    ///
    /// An asset can have multiple variants which you can use in different environments.
    /// For example, an image asset can have distinct light and dark variants, so a renderer can select the appropriate variant
    /// depending on the system's appearance.
    public var variants = [DataTraitCollection: URL]()
    
    /// The metadata associated with each variant.
    public var metadata = [URL : Metadata]()
    
    /// The context in which you intend to use the data asset.
    public var context = Context.display
    
    /// Creates an empty asset.
    public init() {}
    
    init(
        variants: [DataTraitCollection : URL] = [DataTraitCollection: URL](),
        metadata: [URL : DataAsset.Metadata] = [URL : Metadata](),
        context: DataAsset.Context = Context.display
    ) {
        self.variants = variants
        self.metadata = metadata
        self.context = context
    }
    
    /// Registers a variant of the asset.
    /// - Parameters:
    ///   - url: The location of the variant.
    ///   - traitCollection: The trait collection associated with the variant.
    public mutating func register(_ url: URL, with traitCollection: DataTraitCollection, metadata: Metadata = Metadata()) {
        variants[traitCollection] = url
        self.metadata[url] = metadata
    }
    
    /// Returns the data that is registered to the data asset that best matches the given trait collection.
    @available(*, deprecated, renamed: "data(bestMatching:)")
    public func data(with traitCollection: DataTraitCollection) -> BundleData {
        return data(bestMatching: traitCollection)
    }
    
    /// Returns the data that is registered to the data asset that best matches the given trait collection.
    ///
    /// If no variant with the exact given trait collection is found, the variant that has the largest trait collection overlap with the
    /// provided one is returned.
    public func data(bestMatching traitCollection: DataTraitCollection) -> BundleData {
        guard let variant = variants[traitCollection] else {
            // FIXME: If we can't find a variant that matches the given trait collection exactly,
            // we should return the variant that has the largest trait collection overlap with the
            // provided one. (rdar://68632024)
            let first = variants.first!
            return BundleData(url: first.value, traitCollection: first.key)
        }
        
        return BundleData(url: variant, traitCollection: traitCollection)
    }
    
}

extension DataAsset {
    /// Metadata specific to this data asset.
    public struct Metadata: Codable, Equatable {
        /// The first ID found in the SVG asset.
        ///
        /// This value is nil if the data asset is not an SVG or if it is an SVG that does not contain an ID.
        public var svgID: String?
        
        /// Create a new data asset metadata with the given SVG ID.
        public init(svgID: String? = nil) {
            self.svgID = svgID
        }
    }
}

/// A collection of environment traits for an asset variant.
///
/// Traits describe properties of a rendering environment, such as a user-interface style (light or dark mode) and display-scale
/// (1x, 2x, or 3x). A trait collection is a combination of traits and describes the rendering environment in which an asset variant is best
/// suited for, e.g., an environment that uses the dark mode user-interface style and a display-scale of 3x.
public struct DataTraitCollection: Hashable, Codable {
    /// The style associated with the user-interface.
    public var userInterfaceStyle: UserInterfaceStyle?
    
    /// The display-scale of the trait collection.
    public var displayScale: DisplayScale?
    
    /// Creates a new trait collection with traits set to their default, unspecified, values.
    public init() {
        self.userInterfaceStyle = nil
        self.displayScale = nil
    }
    
    /// Returns a new trait collection consisting of traits merged from a specified array of trait collections.
    public init(traitsFrom traitCollections: [DataTraitCollection]) {
        for trait in traitCollections {
            userInterfaceStyle = trait.userInterfaceStyle ?? userInterfaceStyle
            displayScale = trait.displayScale ?? displayScale
        }
    }
    
    /// Creates a trait collection from an array of raw values.
    public init(from rawValues: [String]) {
        for value in rawValues {
            if let validUserInterfaceStyle = UserInterfaceStyle(rawValue: value) {
                userInterfaceStyle = validUserInterfaceStyle
            } else if let validDisplayScale = DisplayScale(rawValue: value) {
                displayScale = validDisplayScale
            }
        }
    }

    /// Creates a trait collection that contains only the specified user-interface style and display-scale traits.
    public init(userInterfaceStyle: UserInterfaceStyle? = nil, displayScale: DisplayScale? = nil) {
        self.userInterfaceStyle = userInterfaceStyle
        self.displayScale = displayScale
    }
    
    /// Returns an array of raw values associated with the trait collection.
    public func toArray() -> [String] {
        var result = [String]()
        
        result.append((displayScale ?? .standard).rawValue)
        
        if let rawUserInterfaceStyle = userInterfaceStyle?.rawValue {
            result.append(rawUserInterfaceStyle)
        }
        
        return result
    }
    
    /// Returns all the asset's registered variants.
    public static var allCases: [DataTraitCollection] = {
        return UserInterfaceStyle.allCases.flatMap { style in DisplayScale.allCases.map { .init(userInterfaceStyle: style, displayScale: $0)}}
    }()
    
}

/// The interface style for a rendering context.
public enum UserInterfaceStyle: String, CaseIterable, Codable {
    /// The light interface style.
    case light = "light"
    
    /// The dark interface style.
    case dark = "dark"
}

/// The display-scale factor of a rendering environment.
///
/// ## See Also
///  - [Image size and resolution](https://developer.apple.com/design/human-interface-guidelines/macos/icons-and-images/image-size-and-resolution/)
///  - [`UIScreen.scale` documentation](https://developer.apple.com/documentation/uikit/uiscreen/1617836-scale)
public enum DisplayScale: String, CaseIterable, Codable {
    /// The 1x scale factor.
    case standard = "1x"
    
    /// The 2x scale factor.
    case double = "2x"
    
    /// The 3x scale factor.
    case triple = "3x"
    
    /// The scale factor as an integer.
    var scaleFactor: Int {
        switch self {
        case .standard:
            return 1
        case .double:
            return 2
        case .triple:
            return 3
        }
    }
}

fileprivate extension NSRegularExpression {
    
    /// Returns a boolean indicating if a match has been found in the given string.
    func matches(in string: String) -> Bool {
        return firstMatch(in: string) != nil
    }
    
    /// Returns a substring containing the first match found in a given string.
    func firstMatch(in string: String) -> String? {
        guard let match = firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count)) else {
            return nil
        }
        return (string as NSString).substring(with: match.range)
    }
}

/// A reference to an asset.
public struct AssetReference: Hashable, Codable {
    /// The name of the asset.
    public var assetName: String
    /// The identifier of the bundle the asset is apart of.
    public var bundleIdentifier: String
    
    /// Creates a reference from a given asset name and the bundle it is apart of.
    public init(assetName: String, bundleIdentifier: String) {
        self.assetName = assetName
        self.bundleIdentifier = bundleIdentifier
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(assetName)
        hasher.combine(bundleIdentifier)
    }
}
