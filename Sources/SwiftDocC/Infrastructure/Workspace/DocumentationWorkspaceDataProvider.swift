/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that vends bundles and responds to requests for data.
public protocol DocumentationWorkspaceDataProvider {
    /// A string that uniquely identifies this data provider.
    ///
    /// Unless your implementation needs a stable identifier to associate with an external system, it's reasonable to
    /// use `UUID().uuidString`  for the provider's identifier.
    var identifier: String { get }

    /// Returns the data backing one of the files that this data provider provides.
    ///
    /// Your implementation can expect to only receive URLs that it provides. It's acceptable to assert if you receive
    /// a URL that wasn't provided by your data provider, because this indicates a bug in the ``DocumentationWorkspace``.
    ///
    /// - Parameter url: The URL of a file to return the backing data for.
    func contentsOfURL(_ url: URL) throws -> Data
    
    /// Returns the documentation bundles that your data provider provides.
    ///
    /// - Parameter options: Configuration that controls how the provider discovers documentation bundles.
    ///
    /// If your data provider also conforms to ``FileSystemProvider``, there is a default implementation of this method
    /// that traverses the ``FileSystemProvider/fileSystem`` to find all documentation bundles in it.
    func bundles(options: BundleDiscoveryOptions) throws -> [DocumentationBundle]
}

public extension DocumentationWorkspaceDataProvider {
    /// Returns the documentation bundles that your data provider provides; discovered with the default options.
    ///
    /// If your data provider also conforms to ``FileSystemProvider``, there is a default implementation of this method
    /// that traverses the ``FileSystemProvider/fileSystem`` to find all documentation bundles in it.
    func bundles() throws -> [DocumentationBundle] {
        return try bundles(options: BundleDiscoveryOptions())
    }
}

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
        fallbackInfo: DocumentationBundle.Info,
        additionalSymbolGraphFiles: [URL] = []
    ) throws {
        // Use JSONEncoder to dynamically create the Info.plist fallback
        // dictionary the `BundleDiscoveryOption`s expect from given DocumentationBundle.Info
        // model.
        
        let data = try JSONEncoder().encode(fallbackInfo)
        let serializedFallbackInfo = try JSONSerialization.jsonObject(with: data)
        
        guard let fallbackInfoDictionary = serializedFallbackInfo as? [String: Any] else {
            throw DocumentationBundle.Info.Error.wrongType(
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
