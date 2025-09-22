/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation


/// Options to configure the discovery of documentation bundles
public struct BundleDiscoveryOptions {
    // When adding new configuration, remember to include a default value in the initializer so that an options
    // value can be created without passing any arguments, resulting in the "default" configuration.
    //
    // The provider uses the default configuration in the `DocumentationWorkspaceDataProvider.bundles()` function.
    
    /// Fallback values for information that's missing in the bundle's Info.plist file.
    public let infoPlistFallbacks: [String: Any]
    
    /// Additional symbol graph files that the provider should include in the discovered bundles.
    public let additionalSymbolGraphFiles: [URL]
    
    /// Creates a new options value with the given configurations.
    ///
    /// - Parameters:
    ///   - infoPlistFallbacks: Fallback values for information that's missing in the bundle's Info.plist file.
    ///   - additionalSymbolGraphFiles: Additional symbol graph files that the provider should include in the discovered bundles.
    public init(
        infoPlistFallbacks: [String: Any] = [:],
        additionalSymbolGraphFiles: [URL] = []
    ) {
        self.infoPlistFallbacks = infoPlistFallbacks
        self.additionalSymbolGraphFiles = additionalSymbolGraphFiles
    }
    
    /// Creates new bundle discovery options with the provided documentation bundle info
    /// as Info.plist fallback values.
    ///
    /// - Parameters:
    ///   - fallbackInfo: Fallback documentation bundle information to use if any discovered bundles are missing an Info.plist.
    ///   - additionalSymbolGraphFiles: Additional symbol graph files to augment any discovered bundles.
    public init(
        fallbackInfo: DocumentationContext.Inputs.Info,
        additionalSymbolGraphFiles: [URL] = []
    ) throws {
        // Use JSONEncoder to dynamically create the Info.plist fallback
        // dictionary the `BundleDiscoveryOption`s expect from given DocumentationBundle.Info
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
