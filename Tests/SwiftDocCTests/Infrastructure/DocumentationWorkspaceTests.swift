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
        
        XCTAssertEqual(workspace.bundles.count, 0)
        
        XCTAssertEqual(workspaceDelegate.record, [])
        
        checkTestWorkspaceContents(workspace: workspace, bundles: [SimpleDataProvider.bundle1, SimpleDataProvider.bundle2], filled: false)
    }
    
    func testRegisterProvider() throws {
        let provider = SimpleDataProvider(bundles: [SimpleDataProvider.bundle1, SimpleDataProvider.bundle2])
        let workspace = DocumentationWorkspace()
        let workspaceDelegate = SimpleWorkspaceDelegate()
        workspace.delegate = workspaceDelegate
        
        try workspace.registerProvider(provider)
        
        let events: [SimpleWorkspaceDelegate.Event] = provider._bundles.map { .add($0.identifier) }
        
        XCTAssertEqual(workspace.bundles.count, 2)
        for bundlePair in workspace.bundles {
            XCTAssertEqual(bundlePair.key, bundlePair.value.identifier)
        }
        
        XCTAssertEqual(Set(workspace.bundles.map { $0.value.identifier }), Set(provider._bundles.map { $0.identifier }))
        XCTAssertEqual(workspaceDelegate.record, events)
        
        checkTestWorkspaceContents(workspace: workspace, bundles: provider._bundles, filled: true)
    }
    
    func testUnregisterProvider() throws {
        let provider = SimpleDataProvider(bundles: [SimpleDataProvider.bundle1, SimpleDataProvider.bundle2])
        let workspace = DocumentationWorkspace()
        let workspaceDelegate = SimpleWorkspaceDelegate()
        workspace.delegate = workspaceDelegate
        
        try workspace.registerProvider(provider)
        
        var events: [SimpleWorkspaceDelegate.Event] = provider._bundles.map { .add($0.identifier) }
        
        XCTAssertEqual(workspace.bundles.count, 2)
        for bundlePair in workspace.bundles {
            XCTAssertEqual(bundlePair.key, bundlePair.value.identifier)
        }
        
        XCTAssertEqual(Set(workspace.bundles.map { $0.value.identifier }), Set(provider._bundles.map { $0.identifier }))
        XCTAssertEqual(workspaceDelegate.record, events)
        
        checkTestWorkspaceContents(workspace: workspace, bundles: provider._bundles, filled: true)
        
        try workspace.unregisterProvider(provider)
        
        events.append(contentsOf: provider._bundles.map { .remove($0.identifier) })
        
        XCTAssertEqual(workspace.bundles.count, 0)
        XCTAssertEqual(workspaceDelegate.record, events)
        
        checkTestWorkspaceContents(workspace: workspace, bundles: provider._bundles, filled: false)
    }
    
    func testMultipleProviders() throws {
        let provider1 = SimpleDataProvider(bundles: [SimpleDataProvider.bundle1, SimpleDataProvider.bundle2])
        let workspace = DocumentationWorkspace()
        let workspaceDelegate = SimpleWorkspaceDelegate()
        workspace.delegate = workspaceDelegate
        
        try workspace.registerProvider(provider1)
        
        var events: [SimpleWorkspaceDelegate.Event] = provider1._bundles.map { .add($0.identifier) }
        
        XCTAssertEqual(workspace.bundles.count, 2)
        for bundlePair in workspace.bundles {
            XCTAssertEqual(bundlePair.key, bundlePair.value.identifier)
        }
        
        XCTAssertEqual(Set(workspace.bundles.map { $0.value.identifier }), Set(provider1._bundles.map { $0.identifier }))
        XCTAssertEqual(workspaceDelegate.record, events)
        
        checkTestWorkspaceContents(workspace: workspace, bundles: provider1._bundles, filled: true)
        
        let provider2 = SimpleDataProvider(bundles: [SimpleDataProvider.bundle3, SimpleDataProvider.bundle4])
        try workspace.registerProvider(provider2)
        
        events.append(contentsOf: provider2._bundles.map { .add($0.identifier) })
        
        XCTAssertEqual(workspace.bundles.count, 4)
        for bundlePair in workspace.bundles {
            XCTAssertEqual(bundlePair.key, bundlePair.value.identifier)
        }
        
        XCTAssertEqual(Set(workspace.bundles.map { $0.value.identifier }), Set(provider1._bundles.map { $0.identifier } + provider2._bundles.map { $0.identifier }))
        XCTAssertEqual(workspaceDelegate.record, events)
        
        checkTestWorkspaceContents(workspace: workspace, bundles: provider1._bundles + provider2._bundles, filled: true)
    }
    
    func checkTestWorkspaceContents(workspace: DocumentationWorkspace, bundles: [DocumentationBundle], filled: Bool, line: UInt = #line) {
        func check(file: URL, bundle: DocumentationBundle, line: UInt) {
            if filled {
                XCTAssertEqual(try workspace.contentsOfURL(file, in: bundle), SimpleDataProvider.files[file]!, line: line)
            } else {
                XCTAssertThrowsError(try workspace.contentsOfURL(file, in: bundle), line: line)
            }
        }
        
        for bundle in bundles {
            check(file: SimpleDataProvider.testMarkupFile, bundle: bundle, line: line)
            check(file: SimpleDataProvider.testResourceFile, bundle: bundle, line: line)
            check(file: SimpleDataProvider.testSymbolGraphFile, bundle: bundle, line: line)
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
        
        static func bundle(_ suffix: String) -> DocumentationBundle {
            return DocumentationBundle(
                info: DocumentationBundle.Info(
                    displayName: "Test" + suffix,
                    identifier: "com.example.test" + suffix,
                    version: "0.1.0"
                ),
                symbolGraphURLs: [testSymbolGraphFile],
                markupURLs: [testMarkupFile],
                miscResourceURLs: [testResourceFile]
            )
        }
        
        static let bundle1 = bundle("1")
        static let bundle2 = bundle("2")
        static let bundle3 = bundle("3")
        static let bundle4 = bundle("4")
        
        enum ProviderError: Error {
            case missing
        }
        
        func contentsOfURL(_ url: URL) throws -> Data {
            guard let data = SimpleDataProvider.files[url] else {
                throw ProviderError.missing
            }
            
            return data
        }
        
        var _bundles: [DocumentationBundle] = []
        
        func bundles(options: BundleDiscoveryOptions) throws -> [DocumentationBundle] {
            // Ignore the bundle discovery options. These test bundles are already built.
            return _bundles
        }
        
        init(bundles: [DocumentationBundle]) {
            self._bundles = bundles
        }
    }
    
    class SimpleWorkspaceDelegate: DocumentationContextDataProviderDelegate {
        enum Event: Equatable {
            case add(String)
            case remove(String)
        }
        var record: [Event] = []
        
        func dataProvider(_ dataProvider: DocumentationContextDataProvider, didAddBundle bundle: DocumentationBundle) throws {
            record.append(.add(bundle.identifier))
        }
        
        func dataProvider(_ dataProvider: DocumentationContextDataProvider, didRemoveBundle bundle: DocumentationBundle) throws {
            record.append(.remove(bundle.identifier))
        }
    }
}
