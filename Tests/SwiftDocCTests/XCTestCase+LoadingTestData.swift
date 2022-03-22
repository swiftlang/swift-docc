/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

extension XCTestCase {
    
    /// Loads a documentation catalog from the given source URL and creates a documentation context.
    func loadCatalog(from catalogURL: URL, codeListings: [String : AttributedCodeListing] = [:], externalResolvers: [String: ExternalReferenceResolver] = [:], externalSymbolResolver: ExternalSymbolResolver? = nil, diagnosticFilterLevel: DiagnosticSeverity = .hint, configureContext: ((DocumentationContext) throws -> Void)? = nil) throws -> (URL, DocumentationCatalog, DocumentationContext) {
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace, diagnosticEngine: DiagnosticEngine(filterLevel: diagnosticFilterLevel))
        context.externalReferenceResolvers = externalResolvers
        context.externalSymbolResolver = externalSymbolResolver
        context.externalMetadata.diagnosticLevel = diagnosticFilterLevel
        try configureContext?(context)
        // Load the catalog using automatic discovery
        let automaticDataProvider = try LocalFileSystemDataProvider(rootURL: catalogURL)
        // Mutate the catalog to include the code listings, then apply to the workspace using a manual provider.
        var catalog = try XCTUnwrap(automaticDataProvider.catalogs().first)
        catalog.attributedCodeListings = codeListings
        let dataProvider = PrebuiltLocalFileSystemDataProvider(catalogs: [catalog])
        try workspace.registerProvider(dataProvider)
        return (catalogURL, catalog, context)
    }
    
    func testCatalogAndContext(copying name: String, excludingPaths excludedPaths: [String] = [], codeListings: [String : AttributedCodeListing] = [:], externalResolvers: [CatalogIdentifier : ExternalReferenceResolver] = [:], externalSymbolResolver: ExternalSymbolResolver? = nil,  configureCatalog: ((URL) throws -> Void)? = nil) throws -> (URL, DocumentationCatalog, DocumentationContext) {
        let sourceURL = try XCTUnwrap(Bundle.module.url(
            forResource: name, withExtension: "docc", subdirectory: "Test Catalogs"))
        
        let sourceExists = FileManager.default.fileExists(atPath: sourceURL.path)
        let catalogURL = sourceExists
            ? try createTemporaryDirectory().appendingPathComponent("\(name).docc")
            : try createTemporaryDirectory(named: "\(name).docc")
        
        if sourceExists {
            try FileManager.default.copyItem(at: sourceURL, to: catalogURL)
        }
        
        for path in excludedPaths {
            try FileManager.default.removeItem(at: catalogURL.appendingPathComponent(path))
        }
        
        // Do any additional setup to the custom catalog - adding, modifying files, etc
        try configureCatalog?(catalogURL)
        
        return try loadCatalog(from: catalogURL, codeListings: codeListings, externalResolvers: externalResolvers, externalSymbolResolver: externalSymbolResolver)
    }
    
    func testCatalogAndContext(named name: String, codeListings: [String : AttributedCodeListing] = [:], externalResolvers: [String: ExternalReferenceResolver] = [:]) throws -> (DocumentationCatalog, DocumentationContext) {
        let catalogURL = try XCTUnwrap(Bundle.module.url(
            forResource: name, withExtension: "docc", subdirectory: "Test Catalogs"))
        let (_, catalog, context) = try loadCatalog(from: catalogURL, codeListings: codeListings, externalResolvers: externalResolvers)
        return (catalog, context)
    }
    
    func testCatalog(named name: String) throws -> DocumentationCatalog {
        let (catalog, _) = try testCatalogAndContext(named: name)
        return catalog
    }
    
    func testCatalogFromRootURL(named name: String) throws -> DocumentationCatalog {
        let catalogURL = try XCTUnwrap(Bundle.module.url(
            forResource: name, withExtension: "docc", subdirectory: "Test Catalogs"))
        let dataProvider = try LocalFileSystemDataProvider(rootURL: catalogURL)
        
        let catalogs = try dataProvider.catalogs()
        return catalogs[0]
    }
    
}
