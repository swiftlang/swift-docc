/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

/// Options to configure the discovery of a documentation catalog
public struct CatalogDiscoveryOptions {
    // When adding new configuration, remember to include a default value in the initializer so that an options
    // value can be created without passing any arguments, resulting in the "default" configuration.
    
    /// Fallback values for information that's missing in the catalog's Info.plist file.
    public let infoPlistFallbacks: [String: Any]
    
    /// Additional symbol graph files that the provider should include in the discovered catalog.
    public let additionalSymbolGraphFiles: [URL]
    
    /// Creates a new options value with the given configurations.
    ///
    /// - Parameters:
    ///   - infoPlistFallbacks: Fallback values for information that's missing in the catalog's Info.plist file.
    ///   - additionalSymbolGraphFiles: Additional symbol graph files that the provider should include in the discovered catalog.
    public init(
        infoPlistFallbacks: [String: Any] = [:],
        additionalSymbolGraphFiles: [URL] = []
    ) {
        self.infoPlistFallbacks = infoPlistFallbacks
        self.additionalSymbolGraphFiles = additionalSymbolGraphFiles
    }
    
    /// Creates new catalog discovery options with the provided documentation info as Info.plist fallback values.
    ///
    /// - Parameters:
    ///   - fallbackInfo: Fallback documentation information to use if the discovered catalog is missing an Info.plist file.
    ///   - additionalSymbolGraphFiles: Additional symbol graph files to augment the discovered catalog.
    public init(
        fallbackInfo: DocumentationContext.Inputs.Info,
        additionalSymbolGraphFiles: [URL] = []
    ) throws {
        // Use JSONEncoder to dynamically create the Info.plist fallback
        // dictionary the `CatalogDiscoveryOption`s expect from given DocumentationContext.Inputs.Info
        // model.
        
        let data = try JSONEncoder().encode(fallbackInfo)
        let serializedFallbackInfo = try JSONSerialization.jsonObject(with: data)
        
        guard let fallbackInfoDictionary = serializedFallbackInfo as? [String: Any] else {
            throw DocumentationContext.Inputs.Info.Error.wrongType(
                expected: [String: Any].Type.self,
                actual: type(of: serializedFallbackInfo)
            )
        }
        
        self.init(
            infoPlistFallbacks: fallbackInfoDictionary,
            additionalSymbolGraphFiles: additionalSymbolGraphFiles
        )
    }
}

@available(*, deprecated, renamed: "CatalogDiscoveryOptions", message: "Use 'CatalogDiscoveryOptions' instead. This deprecated type will be removed after 6.3 is released.")
public typealias BundleDiscoveryOptions = CatalogDiscoveryOptions
