/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// The documentation workspace provides a unified interface for accessing serialized documentation bundles and their files, from a variety of sources.
///
/// The ``DocumentationContext`` and the workspace that the context is operating in are connected in two ways:
///  - The workspace is the context's data provider.
///  - The context is the workspace's ``DocumentationContextDataProviderDelegate``.
///
/// The first lets the workspace multiplex the bundles from any number of data providers (``DocumentationWorkspaceDataProvider``) into a single list of
/// ``DocumentationContextDataProvider/bundles`` and allows the context to access the contents of the various bundles without knowing any specifics
/// of its source (files on disk, a database, or a web services).
///
/// The second lets the the workspace notify the context when bundles are added or removed so that the context stays up to date, even after the context is created.
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
/// │MyCustomDatabase│─▶ WorkspaceDataProvider ─┘        │    Bundle or       ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐     Event push    │
/// └────────────────┘  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘          └───────file ───────▶ ContextDataProviderDelegate ─────interface─────┘
///                                                             change        └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
/// ```
///
/// > Note: Each data provider is treated as a separate file system. A single documentation bundle may not span multiple data providers.
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
        /// A bundle with the provided ID wasn't found in the workspace.
        case unknownBundle(id: String)
        /// A data provider with the provided ID wasn't found in the workspace.
        case unknownProvider(id: String)
        
        /// A plain-text description of the error.
        public var errorDescription: String {
            switch self {
            case .unknownBundle(let id):
                return "The requested data could not be located because a containing bundle with id '\(id)' could not be found in the workspace."
            case .unknownProvider(let id):
                return "The requested data could not be located because a containing data provider with id '\(id)' could not be found in the workspace."
            }
        }
    }
    
    /// Reads the data for a given file in a given documentation bundle.
    ///
    /// - Parameters:
    ///   - url: The URL of the file to read.
    ///   - bundle: The documentation bundle that the file belongs to.
    /// - Throws: A ``WorkspaceError/unknownBundle(id:)`` error if the bundle doesn't exist in the workspace or
    ///           a ``WorkspaceError/unknownProvider(id:)`` error if the bundle's data provider doesn't exist in the workspace.
    /// - Returns: The raw data for the given file.
    public func contentsOfURL(_ url: URL, in bundle: DocumentationBundle) throws -> Data {
        guard let providerID = bundleToProvider[bundle.identifier] else {
            throw WorkspaceError.unknownBundle(id: bundle.identifier)
        }
        
        guard let provider = providers[providerID] else {
            throw WorkspaceError.unknownProvider(id: providerID)
        }
        
        return try provider.contentsOfURL(url)
    }

    /// A map of bundle identifiers to documentation bundles.
    public var bundles: [String: DocumentationBundle] = [:]
    /// A map of provider identifiers to data providers.
    private var providers: [String: DocumentationWorkspaceDataProvider] = [:]
    /// A map of bundle identifiers to provider identifiers (in other words, a map from a bundle to the provider that vends the bundle).
    private var bundleToProvider: [String: String] = [:]
    /// The delegate to notify when documentation bundles are added or removed from this workspace.
    public weak var delegate: DocumentationContextDataProviderDelegate?
    /// Creates a new, empty documentation workspace.
    public init() {}
    
    /// Adds a new data provider to the workspace.
    ///
    /// Adding a data provider also adds the documentation bundles that it provides, and notifies the ``delegate`` of the added bundles.
    ///
    /// - Parameter provider: The workspace data provider to add to the workspace.
    public func registerProvider(_ provider: DocumentationWorkspaceDataProvider, options: BundleDiscoveryOptions = .init()) throws {
        // We must add the provider before adding the bundle so that the delegate
        // may start making requests immediately.
        providers[provider.identifier] = provider
        
        for bundle in try provider.bundles(options: options) {
            bundles[bundle.identifier] = bundle
            bundleToProvider[bundle.identifier] = provider.identifier
            try delegate?.dataProvider(self, didAddBundle: bundle)
        }
    }

    /// Removes a given data provider from the workspace.
    ///
    /// Removing a data provider also removes all its provided documentation bundles and notifies the ``delegate`` of the removed bundles.
    ///
    /// - Parameter provider: The workspace data provider to remove from the workspace.
    public func unregisterProvider(_ provider: DocumentationWorkspaceDataProvider, options: BundleDiscoveryOptions = .init()) throws {
        for bundle in try provider.bundles(options: options) {
            bundles[bundle.identifier] = nil
            bundleToProvider[bundle.identifier] = nil
            try delegate?.dataProvider(self, didRemoveBundle: bundle)
        }
        
        // The provider must be removed after removing the bundle so that the delegate
        // may continue making requests as part of removing the bundle.
        providers[provider.identifier] = nil
    }
}
