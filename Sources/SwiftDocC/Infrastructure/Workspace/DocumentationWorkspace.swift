/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// The documentation workspace provides a unified interface for accessing serialized documentation catalogs and their files, from a variety of sources.
///
/// The ``DocumentationContext`` and the workspace that the context is operating in are connected in two ways:
///  - The workspace is the context's data provider.
///  - The context is the workspace's ``DocumentationContextDataProviderDelegate``.
///
/// The first lets the workspace multiplex the catalogs from any number of data providers (``DocumentationWorkspaceDataProvider``) into a single list of
/// ``DocumentationContextDataProvider/catalogs`` and allows the context to access the contents of the various catalogs without knowing any specifics
/// of its source (files on disk, a database, or a web services).
///
/// The second lets the the workspace notify the context when catalogs are added or removed so that the context stays up to date, even after the context is created.
///
/// ```
///                                                                                       ┌─────┐
///                                                      ┌────────────────────────────────│ IDE │─────────────────────────────┐
///       ┌──────────┐  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐          │                                └─────┘                             │
///       │FileSystem│─▶ WorkspaceDataProvider ─┐        │                                                                    │
///       └──────────┘  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘ │        │                                                                    │
///                                             │        │                                                                    │
///                                             │        │                                                                    │
///       ┌──────────┐  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐ │  ┌───────────┐     Read-only     ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐                 ┌─────────┐
///       │WebService│─▶ WorkspaceDataProvider ─┼─▶│ Workspace │◀────interface───── ContextDataProvider ◀────get data────│ Context │
///       └──────────┘  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘ │  └───────────┘                   └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘                 └─────────┘
///                                             │        │                                                                    ▲
///                                             │        │                                                                    │
/// ┌────────────────┐  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐ │        │                                                                    │
/// │MyCustomDatabase│─▶ WorkspaceDataProvider ─┘        │    Catalog or      ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐     Event push    │
/// └────────────────┘  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘          └───────file ───────▶ ContextDataProviderDelegate ─────interface─────┘
///                                                             change        └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
/// ```
///
/// > Note: Each data provider is treated as a separate file system. A single documentation catalog may not span multiple data providers.
///
/// ## Topics
///
/// ### Data Providers
///
/// - ``DocumentationWorkspaceDataProvider``
/// - ``LocalFileSystemDataProvider``
/// - ``PrebuiltLocalFileSystemDataProvider``
///
/// ## See Also
///
/// - ``DocumentationContext``
/// - ``DocumentationContextDataProvider``
/// - ``DocumentationContextDataProviderDelegate``
///
public class DocumentationWorkspace: DocumentationContextDataProvider {
    /// An error when requesting information from a workspace.
    public enum WorkspaceError: DescribedError {
        /// A catalog with the provided ID wasn't found in the workspace.
        case unknownCatalog(id: String)
        /// A data provider with the provided ID wasn't found in the workspace.
        case unknownProvider(id: String)
        
        @available(*, deprecated,  renamed: "unknownCatalog(id:)")
        public static func unknownBundle(id: String) -> WorkspaceError {
            return .unknownCatalog(id: id)
        }
        
        /// A plain-text description of the error.
        public var errorDescription: String {
            switch self {
            case .unknownCatalog(let id):
                return "The requested data could not be located because a containing catalog with id '\(id)' could not be found in the workspace."
            case .unknownProvider(let id):
                return "The requested data could not be located because a containing data provider with id '\(id)' could not be found in the workspace."
            }
        }
    }
    
    /// Reads the data for a given file in a given documentation catalog.
    ///
    /// - Parameters:
    ///   - url: The URL of the file to read.
    ///   - catalog: The documentation catalog that the file belongs to.
    /// - Throws: A ``WorkspaceError/unknownCatalog(id:)`` error if the catalog doesn't exist in the workspace or
    ///           a ``WorkspaceError/unknownProvider(id:)`` error if the catalog's data provider doesn't exist in the workspace.
    /// - Returns: The raw data for the given file.
    public func contentsOfURL(_ url: URL, in catalog: DocumentationCatalog) throws -> Data {
        guard let providerID = catalogToProvider[catalog.identifier] else {
            throw WorkspaceError.unknownCatalog(id: catalog.identifier)
        }
        
        guard let provider = providers[providerID] else {
            throw WorkspaceError.unknownProvider(id: providerID)
        }
        
        return try provider.contentsOfURL(url)
    }

    /// A map of catalog identifiers to documentation catalogs.
    public var catalogs: [String: DocumentationCatalog] = [:]
    
    @available(*, deprecated, renamed: "catalogs")
    public var bundles: [String: DocumentationCatalog] {
        get {
            return catalogs
        }
        
        set {
            catalogs = newValue
        }
    }
    /// A map of provider identifiers to data providers.
    private var providers: [String: DocumentationWorkspaceDataProvider] = [:]
    /// A map of catalog identifiers to provider identifiers (in other words, a map from a catalog to the provider that vends the catalog).
    private var catalogToProvider: [String: String] = [:]
    /// The delegate to notify when documentation catalogs are added or removed from this workspace.
    public weak var delegate: DocumentationContextDataProviderDelegate?
    /// Creates a new, empty documentation workspace.
    public init() {}
    
    /// Adds a new data provider to the workspace.
    ///
    /// Adding a data provider also adds the documentation catalogs that it provides, and notifies the ``delegate`` of the added catalogs.
    ///
    /// - Parameter provider: The workspace data provider to add to the workspace.
    public func registerProvider(_ provider: DocumentationWorkspaceDataProvider, options: CatalogDiscoveryOptions = .init()) throws {
        // We must add the provider before adding the catalog so that the delegate
        // may start making requests immediately.
        providers[provider.identifier] = provider
        
        for catalog in try provider.catalogs(options: options) {
            catalogs[catalog.identifier] = catalog
            catalogToProvider[catalog.identifier] = provider.identifier
            try delegate?.dataProvider(self, didAddCatalog: catalog)
        }
    }

    /// Removes a given data provider from the workspace.
    ///
    /// Removing a data provider also removes all its provided documentation catalogs and notifies the ``delegate`` of the removed catalogs.
    ///
    /// - Parameter provider: The workspace data provider to remove from the workspace.
    public func unregisterProvider(_ provider: DocumentationWorkspaceDataProvider, options: CatalogDiscoveryOptions = .init()) throws {
        for catalog in try provider.catalogs(options: options) {
            catalogs[catalog.identifier] = nil
            catalogToProvider[catalog.identifier] = nil
            try delegate?.dataProvider(self, didRemoveCatalog: catalog)
        }
        
        // The provider must be removed after removing the catalog so that the delegate
        // may continue making requests as part of removing the catalog.
        providers[provider.identifier] = nil
    }
}
