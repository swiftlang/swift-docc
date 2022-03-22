/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DocumentationWorkspaceTests: XCTestCase {
    func testEmptyWorkspace() {
        let workspace = DocumentationWorkspace()
        let workspaceDelegate = SimpleWorkspaceDelegate()
        workspace.delegate = workspaceDelegate
        
        XCTAssertEqual(workspace.catalogs.count, 0)
        
        XCTAssertEqual(workspaceDelegate.record, [])
        
        checkTestWorkspaceContents(workspace: workspace, catalogs: [SimpleDataProvider.catalog1, SimpleDataProvider.catalog2], filled: false)
    }
    
    func testRegisterProvider() throws {
        let provider = SimpleDataProvider(catalogs: [SimpleDataProvider.catalog1, SimpleDataProvider.catalog2])
        let workspace = DocumentationWorkspace()
        let workspaceDelegate = SimpleWorkspaceDelegate()
        workspace.delegate = workspaceDelegate
        
        try workspace.registerProvider(provider)
        
        let events: [SimpleWorkspaceDelegate.Event] = provider._catalogs.map { .add($0.identifier) }
        
        XCTAssertEqual(workspace.catalogs.count, 2)
        for catalogPair in workspace.catalogs {
            XCTAssertEqual(catalogPair.key, catalogPair.value.identifier)
        }
        
        XCTAssertEqual(Set(workspace.catalogs.map { $0.value.identifier }), Set(provider._catalogs.map { $0.identifier }))
        XCTAssertEqual(workspaceDelegate.record, events)
        
        checkTestWorkspaceContents(workspace: workspace, catalogs: provider._catalogs, filled: true)
    }
    
    func testUnregisterProvider() throws {
        let provider = SimpleDataProvider(catalogs: [SimpleDataProvider.catalog1, SimpleDataProvider.catalog2])
        let workspace = DocumentationWorkspace()
        let workspaceDelegate = SimpleWorkspaceDelegate()
        workspace.delegate = workspaceDelegate
        
        try workspace.registerProvider(provider)
        
        var events: [SimpleWorkspaceDelegate.Event] = provider._catalogs.map { .add($0.identifier) }
        
        XCTAssertEqual(workspace.catalogs.count, 2)
        for catalogPair in workspace.catalogs {
            XCTAssertEqual(catalogPair.key, catalogPair.value.identifier)
        }
        
        XCTAssertEqual(Set(workspace.catalogs.map { $0.value.identifier }), Set(provider._catalogs.map { $0.identifier }))
        XCTAssertEqual(workspaceDelegate.record, events)
        
        checkTestWorkspaceContents(workspace: workspace, catalogs: provider._catalogs, filled: true)
        
        try workspace.unregisterProvider(provider)
        
        events.append(contentsOf: provider._catalogs.map { .remove($0.identifier) })
        
        XCTAssertEqual(workspace.catalogs.count, 0)
        XCTAssertEqual(workspaceDelegate.record, events)
        
        checkTestWorkspaceContents(workspace: workspace, catalogs: provider._catalogs, filled: false)
    }
    
    func testMultipleProviders() throws {
        let provider1 = SimpleDataProvider(catalogs: [SimpleDataProvider.catalog1, SimpleDataProvider.catalog2])
        let workspace = DocumentationWorkspace()
        let workspaceDelegate = SimpleWorkspaceDelegate()
        workspace.delegate = workspaceDelegate
        
        try workspace.registerProvider(provider1)
        
        var events: [SimpleWorkspaceDelegate.Event] = provider1._catalogs.map { .add($0.identifier) }
        
        XCTAssertEqual(workspace.catalogs.count, 2)
        for catalogPair in workspace.catalogs {
            XCTAssertEqual(catalogPair.key, catalogPair.value.identifier)
        }
        
        XCTAssertEqual(Set(workspace.catalogs.map { $0.value.identifier }), Set(provider1._catalogs.map { $0.identifier }))
        XCTAssertEqual(workspaceDelegate.record, events)
        
        checkTestWorkspaceContents(workspace: workspace, catalogs: provider1._catalogs, filled: true)
        
        let provider2 = SimpleDataProvider(catalogs: [SimpleDataProvider.catalog3, SimpleDataProvider.catalog4])
        try workspace.registerProvider(provider2)
        
        events.append(contentsOf: provider2._catalogs.map { .add($0.identifier) })
        
        XCTAssertEqual(workspace.catalogs.count, 4)
        for catalogPair in workspace.catalogs {
            XCTAssertEqual(catalogPair.key, catalogPair.value.identifier)
        }
        
        XCTAssertEqual(Set(workspace.catalogs.map { $0.value.identifier }), Set(provider1._catalogs.map { $0.identifier } + provider2._catalogs.map { $0.identifier }))
        XCTAssertEqual(workspaceDelegate.record, events)
        
        checkTestWorkspaceContents(workspace: workspace, catalogs: provider1._catalogs + provider2._catalogs, filled: true)
    }
    
    func checkTestWorkspaceContents(workspace: DocumentationWorkspace, catalogs: [DocumentationCatalog], filled: Bool, line: UInt = #line) {
        func check(file: URL, catalog: DocumentationCatalog, line: UInt) {
            if filled {
                XCTAssertEqual(try workspace.contentsOfURL(file, in: catalog), SimpleDataProvider.files[file]!, line: line)
            } else {
                XCTAssertThrowsError(try workspace.contentsOfURL(file, in: catalog), line: line)
            }
        }
        
        for catalog in catalogs {
            check(file: SimpleDataProvider.testMarkupFile, catalog: catalog, line: line)
            check(file: SimpleDataProvider.testResourceFile, catalog: catalog, line: line)
            check(file: SimpleDataProvider.testSymbolGraphFile, catalog: catalog, line: line)
        }
    }
    
    struct SimpleDataProvider: DocumentationWorkspaceDataProvider {
        let identifier: String = UUID().uuidString
        
        static let testMarkupFile = URL(fileURLWithPath: "/test.documentation/markup.md")
        static let testResourceFile = URL(fileURLWithPath: "/test.documentation/resource.png")
        static let testSymbolGraphFile = URL(fileURLWithPath: "/test.documentation/graph.json")
        
        static var files: [URL: Data] = [
            testMarkupFile: staticDataFromString("markup"),
            testResourceFile: staticDataFromString("image"),
            testSymbolGraphFile: staticDataFromString("symbols"),
        ]
        
        private static func staticDataFromString(_ string: String) -> Data {
            return string.data(using: .utf8)!
        }
        
        static func catalog(_ suffix: String) -> DocumentationCatalog {
            return DocumentationCatalog(
                info: DocumentationCatalog.Info(
                    displayName: "Test" + suffix,
                    identifier: "com.example.test" + suffix,
                    version: "0.1.0"
                ),
                symbolGraphURLs: [testSymbolGraphFile],
                markupURLs: [testMarkupFile],
                miscResourceURLs: [testResourceFile]
            )
        }
        
        static let catalog1 = catalog("1")
        static let catalog2 = catalog("2")
        static let catalog3 = catalog("3")
        static let catalog4 = catalog("4")
        
        enum ProviderError: Error {
            case missing
        }
        
        func contentsOfURL(_ url: URL) throws -> Data {
            guard let data = SimpleDataProvider.files[url] else {
                throw ProviderError.missing
            }
            
            return data
        }
        
        var _catalogs: [DocumentationCatalog] = []
        
        func catalogs(options: CatalogDiscoveryOptions) throws -> [DocumentationCatalog] {
            // Ignore the catalog discovery options. These test catalogs are already built.
            return _catalogs
        }
        
        init(catalogs: [DocumentationCatalog]) {
            self._catalogs = catalogs
        }
    }
    
    class SimpleWorkspaceDelegate: DocumentationContextDataProviderDelegate {
        enum Event: Equatable {
            case add(String)
            case remove(String)
        }
        var record: [Event] = []
        
        func dataProvider(_ dataProvider: DocumentationContextDataProvider, didAddCatalog catalog: DocumentationCatalog) throws {
            record.append(.add(catalog.identifier))
        }
        
        func dataProvider(_ dataProvider: DocumentationContextDataProvider, didRemoveCatalog catalog: DocumentationCatalog) throws {
            record.append(.remove(catalog.identifier))
        }
    }
}
