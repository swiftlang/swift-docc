/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

typealias Node = NavigatorTree.Node
typealias PageType = NavigatorIndex.PageType

let testBundleIdentifier = "org.swift.docc.example"

class NavigatorIndexingTests: XCTestCase {
    
    struct Language: OptionSet {
        let rawValue: UInt8
        
        static let swift = Language(rawValue: 1 << 0)
        static let objC = Language(rawValue: 1 << 1)
        static let perl = Language(rawValue: 1 << 2)
        
        static let all: Language = [.swift, .objC, .perl]
    }
    
    func generateLargeTree() -> Node {
        var index = 1
        let rootItem = NavigatorItem(pageType: 1, languageID: Language.all.rawValue, title: "Root", platformMask: 1, availabilityID: 1)
        let root = Node(item: rootItem, bundleIdentifier: "org.swift.docc.example")
        
        @discardableResult func addItems(n: Int, items: [Node], language: Language) -> [Node] {
            var leaves = [Node]()
            for _ in 0..<n {
                guard let parent = items.randomElement() else { fatalError("The provided array of node is empty.") }
                let item = NavigatorItem(pageType: 1, languageID: language.rawValue, title: "Index-\(index)", platformMask: 1, availabilityID: 1)
                guard Language(rawValue: parent.item.languageID).contains(language) else {
                    fatalError("The parent must include the language of a child. Having children with languages not included by the parent is not allowed.")
                }
                let node = Node(item: item, bundleIdentifier: "org.swift.docc.example")
                parent.add(child: node)
                leaves.append(node)
                index += 1
            }
            return leaves
        }
        
        let leaves1 = addItems(n: 50, items: [root], language: [.swift, .objC])
        var leaves2 = addItems(n: 1000, items: leaves1, language: [.swift, .objC])
        var leaves3 = addItems(n: 5000, items: leaves2, language: [.swift, .objC])
        addItems(n: 10000, items: leaves3, language: [.swift, .objC])
        
        leaves2 = addItems(n: 10000, items: leaves1, language: .swift)
        leaves3 = addItems(n: 15000, items: leaves2, language: .swift)
        addItems(n: 100000, items: leaves3, language: .swift)
        
        leaves2 = addItems(n: 5000, items: leaves1, language: .objC)
        leaves3 = addItems(n: 10000, items: leaves2, language: .objC)
        addItems(n: 500000, items: leaves3, language: .objC)
                        
        return root
    }
    
    func generateSmallTree() -> Node {
        var index = 1
        let rootItem = NavigatorItem(pageType: 1, languageID: Language.all.rawValue, title: "Root", platformMask: 1, availabilityID: 1)
        let root = Node(item: rootItem, bundleIdentifier: "org.swift.docc.example")
        
        @discardableResult func addItems(n: Int, items: [Node], language: Language) -> [Node] {
            var leaves = [Node]()
            for _ in 0..<n {
                guard let parent = items.randomElement() else { fatalError("The provided array of node is empty.") }
                let item = NavigatorItem(pageType: 1, languageID: language.rawValue, title: "Index-\(index)", platformMask: 1, availabilityID: 1)
                guard Language(rawValue: parent.item.languageID).contains(language) else {
                    fatalError("The parent must include the language of a child. Having children with languages not included by the parent is not allowed.")
                }
                let node = Node(item: item, bundleIdentifier: "org.swift.docc.example")
                parent.add(child: node)
                leaves.append(node)
                index += 1
            }
            return leaves
        }
        
        let leaves1 = addItems(n: 2, items: [root], language: [.swift, .objC])
        let leaves2 = addItems(n: 4, items: leaves1, language: [.swift, .objC])
        let leaves3 = addItems(n: 8, items: leaves2, language: [.swift, .objC])
        addItems(n: 16, items: leaves3, language: [.swift, .objC])
                        
        return root
    }
    
    func testBasicTree() {
        let rootItem = NavigatorItem(pageType: 1, languageID: 1, title: "Root", platformMask: 1, availabilityID: 1)
        let root = Node(item: rootItem, bundleIdentifier: "org.swift.docc.example")
        
        for i in 0..<2 {
            let item = NavigatorItem(pageType: 1, languageID: 1, title: "Sub Item \(i)", platformMask: 1, availabilityID: 1)
            root.add(child: Node(item: item, bundleIdentifier: "org.swift.docc.example"))
        }
        
        for child in root.children {
            for i in 0..<3 {
                let item = NavigatorItem(pageType: 1, languageID: 1, title: "\(child.item.title) - \(i)", platformMask: 1, availabilityID: 1)
                child.add(child: Node(item: item, bundleIdentifier: "org.swift.docc.example"))
            }
        }
        
        let dumpString = """
Root
┣╸Sub Item 0
┃ ┣╸Sub Item 0 - 0
┃ ┣╸Sub Item 0 - 1
┃ ┗╸Sub Item 0 - 2
┗╸Sub Item 1
  ┣╸Sub Item 1 - 0
  ┣╸Sub Item 1 - 1
  ┗╸Sub Item 1 - 2
"""
        
        XCTAssertEqual(root.countItems(), 9)
        XCTAssertEqual(root.dumpTree(), dumpString)
        
        let rootCopy = root.copy()
        XCTAssertEqual(root, rootCopy)
        XCTAssertEqual(rootCopy.dumpTree(), dumpString)
    }
    
    func testNavigatorItemRawDump() {
        let item = NavigatorItem(pageType: 1, languageID: 4, title: "My Title", platformMask: 256, availabilityID: 1024)
        let data = item.rawValue
        let fromData = NavigatorItem(rawValue: data)
        XCTAssertEqual(item, fromData)
    }
    
    func testObjCLanguage() {
        let root = generateLargeTree()
        var objcFiltered: Node?
        objcFiltered = root.filter({ (item) -> Bool in
            Language(rawValue: item.languageID).contains(.objC)
        })
        XCTAssertEqual(objcFiltered?.countItems(), 531051)
    }
    
    func test2Languages() {
        let root = generateLargeTree()
        var bothFiltered: Node?
        bothFiltered = root.filter({ (item) -> Bool in
            Language(rawValue: item.languageID).contains([.swift, .objC])
        })
        XCTAssertEqual(bothFiltered?.countItems(), 16051)
    }
    
    func testSwiftLanguage() {
        let root = generateLargeTree()
        var swiftFiltered: Node?
        swiftFiltered = root.filter({ (item) -> Bool in
            Language(rawValue: item.languageID).contains(.swift)
        })
        XCTAssertEqual(swiftFiltered?.countItems(), 141051)
    }
    
    func testNavigationTreeDumpAndRead() throws {
        let targetURL = try createTemporaryDirectory()
        let indexURL = targetURL.appendingPathComponent("nav.index")
        
        let root = generateSmallTree()
        XCTAssertEqual(root.countItems(), 31)
        
        let original = NavigatorTree(root: root)
        try original.write(to: indexURL)
        let readTree = try NavigatorTree.read(from: indexURL, bundleIdentifier: testBundleIdentifier, interfaceLanguages: [.swift], atomically: true)
        
        XCTAssertEqual(original.root.countItems(), readTree.root.countItems())
        XCTAssertTrue(compare(lhs: original.root, rhs: readTree.root))
        
        let idValidator: (NavigatorTree.Node) -> Bool = { node in
            return node.id != nil
        }
        
        let bundleIdentifierValidator: (NavigatorTree.Node) -> Bool = { node in
            return !node.bundleIdentifier.isEmpty
        }
        
        let emptyPresentationIdentifierValidator: (NavigatorTree.Node) -> Bool = { node in
            return node.presentationIdentifier == nil
        }
        
        XCTAssertTrue(validateTree(node: readTree.root, validator: idValidator), "The tree has IDs missing.")
        XCTAssertTrue(validateTree(node: readTree.root, validator: bundleIdentifierValidator), "The tree has bundle identifier missing.")
        XCTAssertTrue(validateTree(node: readTree.root, validator: emptyPresentationIdentifierValidator), "The tree has a presentation identifier set which should not be present.")
        
        var treeWithPresentationIdentifier = try NavigatorTree.read(from: indexURL, bundleIdentifier: testBundleIdentifier, interfaceLanguages: [.swift], atomically: true, presentationIdentifier: "com.example.test")
        
        let presentationIdentifierValidator: (NavigatorTree.Node) -> Bool = { node in
            return node.presentationIdentifier == "com.example.test"
        }
        
        XCTAssertTrue(validateTree(node: treeWithPresentationIdentifier.root, validator: idValidator), "The tree has IDs missing.")
        XCTAssertTrue(validateTree(node: treeWithPresentationIdentifier.root, validator: bundleIdentifierValidator), "The tree has bundle identifier missing.")
        XCTAssertTrue(validateTree(node: treeWithPresentationIdentifier.root, validator: presentationIdentifierValidator), "The tree lacks the presentation identifier.")
        
        // Test non-atomic read.
        treeWithPresentationIdentifier = try NavigatorTree.read(from: indexURL, bundleIdentifier: testBundleIdentifier, interfaceLanguages: [.swift], atomically: false, presentationIdentifier: "com.example.test")
        
        XCTAssertTrue(validateTree(node: treeWithPresentationIdentifier.root, validator: idValidator), "The tree has IDs missing.")
        XCTAssertTrue(validateTree(node: treeWithPresentationIdentifier.root, validator: bundleIdentifierValidator), "The tree has bundle identifier missing.")
        XCTAssertTrue(validateTree(node: treeWithPresentationIdentifier.root, validator: presentationIdentifierValidator), "The tree lacks the presentation identifier.")
    }
    
  
    func testNavigationTreeLargeDumpAndRead() throws {
#if os(OSX)
        let targetURL = try createTemporaryDirectory()
        let indexURL = targetURL.appendingPathComponent("nav.index")
        let root = generateLargeTree()
        let original = NavigatorTree(root: root)
        try original.write(to: indexURL)

        measure {
            _ = try! NavigatorTree.read(from: indexURL, interfaceLanguages: [.swift], atomically: true)
        }
#endif
    }
    
    // This test has been disabled because of frequent failures in Swift CI.
    //
    // rdar://87737744 tracks updating this test to remove any flakiness.
    func disabled_testNavigationTreeLargeDumpAndReadAsync() throws {
        let targetURL = try createTemporaryDirectory()
        let indexURL = targetURL.appendingPathComponent("nav.index")
        
        let root = generateLargeTree()
        let original = NavigatorTree(root: root)
        try original.write(to: indexURL)
        
        // Counts the number of times the broadcast callback is called.
        var counter = 0
        
        let expectation = XCTestExpectation(description: "Load the tree asynchronously.")
        
        let readTree = NavigatorTree()
        try! readTree.read(from: indexURL, interfaceLanguages: [.swift], timeout: 0.25, queue: DispatchQueue.main) { (nodes, completed, error) in
            counter += 1
            XCTAssertNil(error)
            if completed { expectation.fulfill() }
        }
                
        wait(for: [expectation], timeout: 10.0)
        XCTAssert(counter > 2, "The broadcast callback has to be called at least 2 times.")
        XCTAssertEqual(original.root.countItems(), readTree.root.countItems())
        XCTAssertTrue(compare(lhs: original.root, rhs: readTree.root))
        
        let expectation2 = XCTestExpectation(description: "Load the tree asynchronously, again with presentation identifier.")
        let readTreePresentationIdentifier = NavigatorTree()
        try! readTreePresentationIdentifier.read(from: indexURL, interfaceLanguages: [.swift], timeout: 0.25, queue: DispatchQueue.main, presentationIdentifier: "com.example.test") { (nodes, completed, error) in
            XCTAssertNil(error)
            if completed { expectation2.fulfill() }
        }
        wait(for: [expectation2], timeout: 10.0)
        XCTAssertEqual(original.root.countItems(), readTreePresentationIdentifier.root.countItems())
        
        let presentationIdentifierValidator: (NavigatorTree.Node) -> Bool = { node in
            return node.presentationIdentifier == "com.example.test"
        }
        
        XCTAssertTrue(validateTree(node: readTreePresentationIdentifier.root, validator: presentationIdentifierValidator), "The tree lacks the presentation identifier.")
    }
    
    func testNavigatorIndexGenerationEmpty() throws {
        let targetURL = try createTemporaryDirectory()
        
        let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: testBundleIdentifier)
        builder.setup()
        builder.finalize()
               
        XCTAssertNotNil(builder.navigatorIndex)
        
        let indexURL = targetURL.appendingPathComponent("nav.index")
                
        let readTree = NavigatorTree()
        XCTAssertThrowsError(try readTree.read(from: indexURL, interfaceLanguages: [.swift], timeout: 0.25, queue: DispatchQueue.main, broadcast: nil))
        
        try XCTAssertEqual(
            RenderIndex.fromURL(targetURL.appendingPathComponent("index.json")),
            RenderIndex.fromString(
                """
                {
                  "interfaceLanguages": {},
                  "schemaVersion": {
                    "major": 0,
                    "minor": 1,
                    "patch": 0
                  }
                }
                """
            )
        )
    }
    
    func testNavigatorIndexGenerationOneNode() throws {
        let targetURL = try createTemporaryDirectory()
        let indexURL = targetURL.appendingPathComponent("nav.index")
        
        let original = NavigatorTree(root: NavigatorTree.rootNode(bundleIdentifier: NavigatorIndex.UnknownBundleIdentifier))
        try original.write(to: indexURL)
        
        // Counts the number of times the broadcast callback is called.
        var counter = 0
        
        let expectation = XCTestExpectation(description: "Load the tree asynchronously.")
        
        let readTree = NavigatorTree()
        try! readTree.read(from: indexURL, interfaceLanguages: [.swift], timeout: 0.25, queue: DispatchQueue.main) { (nodes, completed, error) in
            counter += 1
            XCTAssertNil(error)
            if completed { expectation.fulfill() }
        }
                
        wait(for: [expectation], timeout: 10.0)
        XCTAssert(counter == 1, "The broadcast callback has to be called at exactly 1 time.")
        XCTAssertEqual(original.root.countItems(), readTree.root.countItems())
        XCTAssertTrue(compare(lhs: original.root, rhs: readTree.root))
    }
    
    func testNavigatorIndexGenerationOperator() throws {
        let operatorURL = Bundle.module.url(
            forResource: "Operator", withExtension: "json", subdirectory: "Test Resources")!
        
        let renderNode = try RenderNode.decode(fromJSON: Data(contentsOf: operatorURL))

        let targetURL = try createTemporaryDirectory()

        let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: testBundleIdentifier)
        builder.setup()
        try builder.index(renderNode: renderNode)
        builder.finalize(emitJSONRepresentation: false, emitLMDBRepresentation: false)
               
        XCTAssertNotNil(builder.navigatorIndex)
    }
    
    func testNavigatorIndexGeneration() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        var results = Set<String>()
        
        // Create an index 10 times to ensure we have not undeterministic behavior across builds
        for _ in 0..<10 {
            let targetURL = try createTemporaryDirectory()
            let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: testBundleIdentifier, sortRootChildrenByName: true)
            builder.setup()
            
            for identifier in context.knownPages {
                let source = context.documentURL(for: identifier)
                let entity = try context.entity(with: identifier)
                let renderNode = try XCTUnwrap(converter.renderNode(for: entity, at: source))
                try builder.index(renderNode: renderNode)
            }
            
            builder.finalize()
            
            let renderIndex = try RenderIndex.fromURL(targetURL.appendingPathComponent("index.json"))
            XCTAssertEqual(renderIndex.interfaceLanguages.keys.count, 1)
            XCTAssertEqual(renderIndex.interfaceLanguages["swift"]?.count, 27)
            
            XCTAssertEqual(renderIndex.interfaceLanguages["swift"]?.first?.title, "Functions")
            XCTAssertEqual(renderIndex.interfaceLanguages["swift"]?.first?.path, nil)
            XCTAssertEqual(renderIndex.interfaceLanguages["swift"]?.first?.type, "groupMarker")
            
            let navigatorIndex = builder.navigatorIndex!
            
            XCTAssertEqual(navigatorIndex.availabilityIndex.platforms, [.watchOS, .macCatalyst, .iOS, .tvOS, .macOS])
            XCTAssertEqual(navigatorIndex.availabilityIndex.versions(for: .iOS), Set([
                Platform.Version(string: "13.0")!,
                Platform.Version(string: "10.15")!,
                Platform.Version(string: "11.1")!,
                Platform.Version(string: "14.0")!,
            ]))
            XCTAssertEqual(Set(navigatorIndex.languages), Set(["Swift"]))
            XCTAssertEqual(navigatorIndex.navigatorTree.root.countItems(), navigatorIndex.navigatorTree.numericIdentifierToNode.count)
            XCTAssertTrue(validateTree(node: navigatorIndex.navigatorTree.root, validator: { (node) -> Bool in
                return node.bundleIdentifier == testBundleIdentifier
            }))
            
            let allNodes = navigatorIndex.navigatorTree.numericIdentifierToNode.values
            let symbolPages = allNodes.filter { NavigatorIndex.PageType(rawValue: $0.item.pageType)! == .symbol }
            // Pages with type `symbol` should be 6 (collectionGroup type of pages) as all the others should have a proper type.
            XCTAssertEqual(symbolPages.count, 6)
            
            assertUniqueIDs(node: navigatorIndex.navigatorTree.root)
            results.insert(navigatorIndex.navigatorTree.root.dumpTree())
            try FileManager.default.removeItem(at: targetURL)
        }
        
        XCTAssertEqual(results.count, 1)
        assertEqualDumps(results.first ?? "", try testTree(named: "testNavigatorIndexGeneration"))
    }
    
    func testNavigatorIndexGenerationVariantsPayload() throws {
        let jsonFile = Bundle.module.url(forResource: "Variant-render-node", withExtension: "json", subdirectory: "Test Resources")!
        let jsonData = try Data(contentsOf: jsonFile)
        
        let targetURL = try createTemporaryDirectory()
        let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: testBundleIdentifier, sortRootChildrenByName: true, groupByLanguage: true)
        builder.setup()
        
        let renderNode = try XCTUnwrap(RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: jsonData))
        try builder.index(renderNode: renderNode)
        
        builder.finalize()
        
        let navigatorIndex = builder.navigatorIndex!
        
        assertUniqueIDs(node: navigatorIndex.navigatorTree.root)
        assertEqualDumps(navigatorIndex.navigatorTree.root.dumpTree(), """
        [Root]
        ┣╸Objective-C
        ┃ ┗╸My Article in Objective-C
        ┃   ┣╸Task Group 1
        ┃   ┣╸Task Group 2
        ┃   ┗╸Task Group 3
        ┗╸Swift
          ┗╸My Article
            ┣╸Task Group 1
            ┣╸Task Group 2
            ┗╸Task Group 3
        """)
        
        try XCTAssertEqual(
            RenderIndex.fromURL(targetURL.appendingPathComponent("index.json")),
            RenderIndex.fromString(#"""
                {
                  "interfaceLanguages": {
                    "occ": [
                      {
                        "children": [
                          {
                            "title": "Task Group 1",
                            "type": "groupMarker"
                          },
                          {
                            "title": "Task Group 2",
                            "type": "groupMarker"
                          },
                          {
                            "title": "Task Group 3",
                            "type": "groupMarker"
                          }
                        ],
                        "path": "\/documentation\/mykit\/my-article",
                        "title": "My Article in Objective-C",
                        "type": "article"
                      }
                    ],
                    "swift": [
                      {
                        "children": [
                          {
                            "title": "Task Group 1",
                            "type": "groupMarker"
                          },
                          {
                            "title": "Task Group 2",
                            "type": "groupMarker"
                          },
                          {
                            "title": "Task Group 3",
                            "type": "groupMarker"
                          }
                        ],
                        "path": "\/documentation\/mykit\/my-article",
                        "title": "My Article",
                        "type": "article"
                      }
                    ]
                  },
                  "schemaVersion": {
                    "major": 0,
                    "minor": 1,
                    "patch": 0
                  }
                }
                """#
            )
        )
        
        try FileManager.default.removeItem(at: targetURL)
    }
    
    func testNavigatorIndexUsingPageTitleGeneration() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        var results = Set<String>()
        
        // Create an index 10 times to ensure we have not undeterministic behavior across builds
        for _ in 0..<10 {
            let targetURL = try createTemporaryDirectory()
            let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: testBundleIdentifier, sortRootChildrenByName: true, usePageTitle: true)
            builder.setup()
            
            for identifier in context.knownPages {
                let source = context.documentURL(for: identifier)
                let entity = try context.entity(with: identifier)
                let renderNode = try XCTUnwrap(converter.renderNode(for: entity, at: source))
                try builder.index(renderNode: renderNode)
            }
            
            builder.finalize()
            
            let navigatorIndex = builder.navigatorIndex!
            
            XCTAssertEqual(navigatorIndex.availabilityIndex.platforms, [.watchOS, .macCatalyst, .iOS, .tvOS, .macOS])
            XCTAssertEqual(navigatorIndex.availabilityIndex.versions(for: .iOS), Set([
                Platform.Version(string: "13.0")!,
                Platform.Version(string: "10.15")!,
                Platform.Version(string: "11.1")!,
                Platform.Version(string: "14.0")!,
            ]))
            XCTAssertEqual(Set(navigatorIndex.languages), Set(["Swift"]))
            XCTAssertEqual(navigatorIndex.navigatorTree.root.countItems(), navigatorIndex.navigatorTree.numericIdentifierToNode.count)
            XCTAssertTrue(validateTree(node: navigatorIndex.navigatorTree.root, validator: { (node) -> Bool in
                return node.bundleIdentifier == testBundleIdentifier
            }))
            
            let allNodes = navigatorIndex.navigatorTree.numericIdentifierToNode.values
            let symbolPages = allNodes.filter { NavigatorIndex.PageType(rawValue: $0.item.pageType)! == .symbol }
            // Pages with type `symbol` should be 6 (collectionGroup type of pages) as all the others should have a proper type.
            XCTAssertEqual(symbolPages.count, 6)
            
            assertUniqueIDs(node: navigatorIndex.navigatorTree.root)
            results.insert(navigatorIndex.navigatorTree.root.dumpTree())
            try FileManager.default.removeItem(at: targetURL)
        }
        
        XCTAssertEqual(results.count, 1)
        assertEqualDumps(results.first ?? "", try testTree(named: "testNavigatorIndexPageTitleGeneration"))
    }
    
    func testNavigatorIndexGenerationNoPaths() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        var results = Set<String>()
        
        // Create an index 10 times to ensure we have not undeterministic behavior across builds
        for _ in 0..<10 {
            let targetURL = try createTemporaryDirectory()
            let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: testBundleIdentifier, sortRootChildrenByName: true, writePathsOnDisk: false)
            builder.setup()
            
            for identifier in context.knownPages {
                let source = context.documentURL(for: identifier)
                let entity = try context.entity(with: identifier)
                let renderNode = try converter.convert(entity, at: source)
                try builder.index(renderNode: renderNode)
            }
            
            builder.finalize()
            
            // Read the index back from disk
            let navigatorIndex = try NavigatorIndex(url: targetURL)
            
            XCTAssertEqual(navigatorIndex.availabilityIndex.platforms, [.watchOS, .macCatalyst, .iOS, .tvOS, .macOS])
            XCTAssertEqual(navigatorIndex.availabilityIndex.versions(for: .iOS), Set([
                Platform.Version(string: "13.0")!,
                Platform.Version(string: "10.15")!,
                Platform.Version(string: "11.1")!,
                Platform.Version(string: "14.0")!,
            ]))
            XCTAssertEqual(Set(navigatorIndex.languages), Set(["Swift"]))
            XCTAssertEqual(navigatorIndex.navigatorTree.root.countItems(), navigatorIndex.navigatorTree.numericIdentifierToNode.count)
            XCTAssertTrue(validateTree(node: navigatorIndex.navigatorTree.root, validator: { (node) -> Bool in
                return node.bundleIdentifier == testBundleIdentifier
            }))
            
            let allNodes = navigatorIndex.navigatorTree.numericIdentifierToNode.values
            let symbolPages = allNodes.filter { NavigatorIndex.PageType(rawValue: $0.item.pageType)! == .symbol }
            // Pages with type `symbol` should be 6 (collectionGroup type of pages) as all the others should have a proper type.
            XCTAssertEqual(symbolPages.count, 6)
            
            // Test path persistence
            XCTAssertNil(navigatorIndex.path(for: 0)) // Root should have not path persisted.
            XCTAssertEqual(navigatorIndex.path(for: 1), "/documentation/fillintroduced")
            XCTAssertEqual(navigatorIndex.path(for: 4), "/tutorials/testoverview")
            XCTAssertEqual(navigatorIndex.path(for: 10), "/documentation/fillintroduced/maccatalystonlydeprecated()")
            
            assertUniqueIDs(node: navigatorIndex.navigatorTree.root)
            results.insert(navigatorIndex.navigatorTree.root.dumpTree())
        }
        
        XCTAssertEqual(results.count, 1)
        assertEqualDumps(results.first ?? "", try testTree(named: "testNavigatorIndexGeneration"))
    }
    
    func testNavigatorIndexGenerationWithLanguageGrouping() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        
        let targetURL = try createTemporaryDirectory()
        let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: testBundleIdentifier, sortRootChildrenByName: true, groupByLanguage: true)
        builder.setup()
        
        for identifier in context.knownPages {
            let source = context.documentURL(for: identifier)
            let entity = try context.entity(with: identifier)
            let renderNode = try XCTUnwrap(converter.renderNode(for: entity, at: source))
            try builder.index(renderNode: renderNode)
        }
        
        builder.finalize()
        
        let navigatorIndex = try NavigatorIndex(url: targetURL, readNavigatorTree: false)
        
        let expectation = XCTestExpectation(description: "Load the tree asynchronously.")
        
        try navigatorIndex.readNavigatorTree(timeout: 1.0, queue: DispatchQueue(label: "org.swift.docc.example.queue")) { (_, isCompleted, error) in
            XCTAssertNil(error)
            if isCompleted {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertEqual(navigatorIndex.availabilityIndex.platforms, [.watchOS, .macCatalyst, .iOS, .tvOS, .macOS])
        XCTAssertEqual(navigatorIndex.availabilityIndex.versions(for: .iOS), Set([
            Platform.Version(string: "13.0")!,
            Platform.Version(string: "10.15")!,
            Platform.Version(string: "14.0")!,
            Platform.Version(string: "11.1")!,
        ]))
        XCTAssertEqual(Set(navigatorIndex.languages), Set(["Swift"]))
        
        // Get the Swift language group.
        XCTAssertEqual(navigatorIndex.navigatorTree.numericIdentifierToNode[1]?.children.count, 5)

        assertUniqueIDs(node: navigatorIndex.navigatorTree.root)
        assertEqualDumps(navigatorIndex.navigatorTree.root.dumpTree(), try testTree(named: "testNavigatorIndexGenerationWithLanguageGrouping"))
    }

    
    func testNavigatorIndexGenerationWithCuratedFragment() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        var results = Set<String>()
        
        // Create an index 10 times to ensure we have no undeterministic behavior across builds
        for _ in 0..<10 {
            let targetURL = try createTemporaryDirectory()
            let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: testBundleIdentifier, sortRootChildrenByName: true)
            builder.setup()
            
            for identifier in context.knownPages {
                let source = context.documentURL(for: identifier)
                let entity = try context.entity(with: identifier)
                var renderNode = try XCTUnwrap(converter.renderNode(for: entity, at: source))
                
                if renderNode.identifier.path == "/documentation/MyKit" {
                    guard let reference = renderNode.topicSections.first?.identifiers.first else {
                        XCTFail("A topic section is missing a reference.")
                        return
                    }
                    let referenceWithFragment = reference.appending("#Section")
                    let topicsSections: [TaskGroupRenderSection] = renderNode.topicSections.compactMap { section in
                        if section.identifiers.contains(reference) {
                            var identifiers = section.identifiers
                            identifiers.append(referenceWithFragment)
                            return TaskGroupRenderSection(title: section.title,
                                                          abstract: section.abstract,
                                                          discussion: section.discussion,
                                                          identifiers: identifiers,
                                                          generated: section.generated)
                        }
                        return section
                    }
                    renderNode.topicSections = topicsSections
                    
                    guard var topicReference = renderNode.references[reference] as? TopicRenderReference else {
                        XCTFail("Missing expected reference \(reference)")
                        return
                    }
                    topicReference.identifier = RenderReferenceIdentifier(referenceWithFragment)
                    topicReference.url = topicReference.url.appending("#Section")
                    renderNode.references[referenceWithFragment] = topicReference
                }
                
                
                try builder.index(renderNode: renderNode)
            }
            
            builder.finalize()
            
            let navigatorIndex = try XCTUnwrap(builder.navigatorIndex)
            
            assertUniqueIDs(node: navigatorIndex.navigatorTree.root)
            results.insert(navigatorIndex.navigatorTree.root.dumpTree())
            try FileManager.default.removeItem(at: targetURL)
        }
        
        XCTAssertEqual(results.count, 1)
        assertEqualDumps(results.first ?? "", try testTree(named: "testNavigatorIndexGeneration"))
    }
    
    func testNavigatorIndexAvailabilityGeneration() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        
        let targetURL = try createTemporaryDirectory()
        let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: testBundleIdentifier, sortRootChildrenByName: true)
        builder.setup()
        
        for identifier in context.knownPages {
            let source = context.documentURL(for: identifier)
            let entity = try context.entity(with: identifier)
            let renderNode = try XCTUnwrap(converter.renderNode(for: entity, at: source))
            try builder.index(renderNode: renderNode)
        }
        
        builder.finalize()
        
        let navigatorIndex = try NavigatorIndex(url: targetURL)
        
        XCTAssertEqual(navigatorIndex.pathHasher, .md5)
        XCTAssertEqual(navigatorIndex.bundleIdentifier, testBundleIdentifier)
        XCTAssertEqual(navigatorIndex.availabilityIndex.platforms, [.watchOS, .iOS, .macCatalyst, .tvOS, .macOS])
        XCTAssertEqual(navigatorIndex.availabilityIndex.versions(for: .macOS), Set([
            Platform.Version(string: "10.9")!,
            Platform.Version(string: "10.10")!,
            Platform.Version(string: "10.15")!,
            Platform.Version(string: "10.16")!,
        ]))
        XCTAssertEqual(navigatorIndex.availabilityIndex.versions(for: .iOS), Set([
            Platform.Version(string: "13.0")!,
            Platform.Version(string: "14.0")!,
            Platform.Version(string: "10.15")!,
            Platform.Version(string: "11.1")!,
        ]))
        XCTAssertEqual(navigatorIndex.availabilityIndex.versions(for: .watchOS), Set([
            Platform.Version(string: "6.0")!,
            Platform.Version(string: "13.3")!,
        ]))
        XCTAssertEqual(navigatorIndex.availabilityIndex.versions(for: .tvOS), Set([
            Platform.Version(string: "12.2")!,
            Platform.Version(string: "13.0")!,
        ]))
        XCTAssertEqual(Set(navigatorIndex.languages), Set(["Swift"]))
        XCTAssertEqual(Set(navigatorIndex.availabilityIndex.platforms(for: InterfaceLanguage.swift) ?? []), Set([.watchOS, .iOS, .macCatalyst, .tvOS, .macOS]))
        XCTAssertEqual(navigatorIndex.availabilityIndex.platform(named: "macOS"), .macOS)
        XCTAssertEqual(navigatorIndex.availabilityIndex.platform(named: "watchOS"), .watchOS)
        XCTAssertEqual(navigatorIndex.availabilityIndex.platform(named: "tvOS"), .tvOS)
        XCTAssertEqual(navigatorIndex.availabilityIndex.platform(named: "ios"), .undefined, "Incorrect capitalization")
        XCTAssertEqual(navigatorIndex.availabilityIndex.platform(named: "iOS"), .iOS)
        
        // Check ID mapping
        XCTAssertNotNil(navigatorIndex.id(for:"/documentation/sidekit/sideclass", with: .swift))
        XCTAssertNotNil(navigatorIndex.id(for:"/documentation/sidekit/sideclass/myfunction()", with: .swift))
        XCTAssertNotNil(navigatorIndex.id(for:"/documentation/sidekit/sideclass/path", with: .swift))
        XCTAssertNil(navigatorIndex.id(for:"/non/exisint/path", with: .swift))
        
        // Check USR mapping
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC", language: .swift), "/documentation/sidekit/sideclass")
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC10myFunctionyyF"), "/documentation/sidekit/sideclass/myfunction()")
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC4pathSSvp", language: .swift), "/documentation/sidekit/sideclass/path")
        XCTAssertNil(navigatorIndex.path(for: "s:5SideKit"))
        
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC", language: .swift, hashed: false), "/documentation/sidekit/sideclass")
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC10myFunctionyyF", language: .swift, hashed: false), "/documentation/sidekit/sideclass/myfunction()")
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC4pathSSvp", hashed: false), "/documentation/sidekit/sideclass/path")
        XCTAssertNil(navigatorIndex.path(for: "s:5SideKit", hashed: false))
        
        XCTAssertEqual(navigatorIndex.path(for: "18xs4rl", hashed: true), "/documentation/sidekit/sideclass")
        XCTAssertEqual(navigatorIndex.path(for: "1ug5ui4", hashed: true), "/documentation/sidekit/sideclass/myfunction()")
        XCTAssertEqual(navigatorIndex.path(for: "1wfp7eu", hashed: true), "/documentation/sidekit/sideclass/path")
        XCTAssertNil(navigatorIndex.path(for: "1m2njn2", hashed: true))
        
        // Check we don't return valid values for other languages
        XCTAssertNil(navigatorIndex.path(for: "s:7SideKit0A5ClassC", language: .objc))
        XCTAssertNil(navigatorIndex.path(for: "s:7SideKit0A5ClassC4pathSSvp", language: .data))
        XCTAssertNil(navigatorIndex.path(for: "1ug5ui4", language: .objc, hashed: true))
        XCTAssertNil(navigatorIndex.path(for: "1wfp7eu", language: .data, hashed: true))
        
        let sideClassNode = try XCTUnwrap(search(node: navigatorIndex.navigatorTree.root) { navigatorIndex.path(for: $0.id!) == "/documentation/sidekit/sideclass" })
        let availabilities = navigatorIndex.availabilities(for: sideClassNode.item.availabilityID)
        XCTAssertEqual(availabilities.count, 1)
        
        // Extract availability and check it against some queries.
        let availabilityInfo = availabilities[0]
        XCTAssertFalse(availabilityInfo.belongs(to: .macOS))
        XCTAssertTrue(availabilityInfo.belongs(to: .iOS))
        XCTAssertFalse(availabilityInfo.isDeprecated(on: Platform(name: .iOS, version: Platform.Version(string: "13.0")!)))
        XCTAssertTrue(availabilityInfo.isAvailable(on: Platform(name: .iOS, version: Platform.Version(string: "13.0")!)))
        XCTAssertFalse(availabilityInfo.isAvailable(on: Platform(name: .iOS, version: Platform.Version(string: "10.0")!)))
        
        // Ensure we can't write to an index which is read-only.
        let availabilityDB = try XCTUnwrap(navigatorIndex.environment).openDatabase(named: "availability")
        XCTAssertThrowsError(try availabilityDB.put(key: "content", value: "test"))
        XCTAssertNil(availabilityDB.get(type: String.self, forKey: "content"))
    }
    
    func testNavigatorIndexDifferenHasherGeneration() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        
        let targetURL = try createTemporaryDirectory()
        let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: testBundleIdentifier, sortRootChildrenByName: true)
        builder.setup()
        
        // Change the path hasher to the FNV-1 implementation and make sure paths and mappings are still working.
        builder.navigatorIndex?.pathHasher = .fnv1
        
        for identifier in context.knownPages {
            let source = context.documentURL(for: identifier)
            let entity = try context.entity(with: identifier)
            let renderNode = try XCTUnwrap(converter.renderNode(for: entity, at: source))
            try builder.index(renderNode: renderNode)
        }
        
        builder.finalize()
        
        let navigatorIndex = try NavigatorIndex(url: targetURL)
        
        XCTAssertEqual(navigatorIndex.pathHasher, .fnv1)
        
        // Check ID mapping
        XCTAssertNotNil(navigatorIndex.id(for:"/documentation/sidekit/sideclass", with: .swift))
        XCTAssertNotNil(navigatorIndex.id(for:"/documentation/sidekit/sideclass/myfunction()", with: .swift))
        XCTAssertNotNil(navigatorIndex.id(for:"/documentation/sidekit/sideclass/path", with: .swift))
        XCTAssertNil(navigatorIndex.id(for:"/non/exisint/path", with: .swift))
        
        // Check USR mapping
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC", language: .swift), "/documentation/sidekit/sideclass")
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC10myFunctionyyF"), "/documentation/sidekit/sideclass/myfunction()")
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC4pathSSvp", language: .swift), "/documentation/sidekit/sideclass/path")
        XCTAssertNil(navigatorIndex.path(for: "s:5SideKit"))
        
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC", language: .swift, hashed: false), "/documentation/sidekit/sideclass")
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC10myFunctionyyF", language: .swift, hashed: false), "/documentation/sidekit/sideclass/myfunction()")
        XCTAssertEqual(navigatorIndex.path(for: "s:7SideKit0A5ClassC4pathSSvp", hashed: false), "/documentation/sidekit/sideclass/path")
        XCTAssertNil(navigatorIndex.path(for: "s:5SideKit", hashed: false))
        
        XCTAssertEqual(navigatorIndex.path(for: "18xs4rl", hashed: true), "/documentation/sidekit/sideclass")
        XCTAssertEqual(navigatorIndex.path(for: "1ug5ui4", hashed: true), "/documentation/sidekit/sideclass/myfunction()")
        XCTAssertEqual(navigatorIndex.path(for: "1wfp7eu", hashed: true), "/documentation/sidekit/sideclass/path")
        XCTAssertNil(navigatorIndex.path(for: "1m2njn2", hashed: true))
        
        // Check we don't return valid values for other languages
        XCTAssertNil(navigatorIndex.path(for: "s:7SideKit0A5ClassC", language: .objc))
        XCTAssertNil(navigatorIndex.path(for: "s:7SideKit0A5ClassC4pathSSvp", language: .data))
        XCTAssertNil(navigatorIndex.path(for: "1ug5ui4", language: .objc, hashed: true))
        XCTAssertNil(navigatorIndex.path(for: "1wfp7eu", language: .data, hashed: true))
        
        let sideClassNode = try XCTUnwrap(search(node: navigatorIndex.navigatorTree.root) { navigatorIndex.path(for: $0.id!) == "/documentation/sidekit/sideclass" })
        let availabilities = navigatorIndex.availabilities(for: sideClassNode.item.availabilityID)
        XCTAssertEqual(availabilities.count, 1)
    }
    
    func testPlatformVersion() {
        guard let version1 = Platform.Version(string: "12.0") else {
            XCTFail("The version string is valid, but failed to be processed.")
            return
        }
        
        guard let version2 = Platform.Version(string: "12.1") else {
            XCTFail("The version string is valid, but failed to be processed.")
            return
        }
        
        guard let version3 = Platform.Version(string: "12.1.1") else {
            XCTFail("The version string is valid, but failed to be processed.")
            return
        }
        
        guard let version4 = Platform.Version(string: "12.1.2") else {
            XCTFail("The version string is valid, but failed to be processed.")
            return
        }
        
        guard let version5 = Platform.Version(string: "12.2.0") else {
            XCTFail("The version string is valid, but failed to be processed.")
            return
        }
        
        guard let version6 = Platform.Version(string: "13") else {
            XCTFail("The version string is valid, but failed to be processed.")
            return
        }
        
        guard let version2alt = Platform.Version(string: "12.1.0") else {
            XCTFail("The version string is valid, but failed to be processed.")
            return
        }
        
        guard let version10 = Platform.Version(string: "13.0.1") else {
            XCTFail("The version string is valid, but failed to be processed.")
            return
        }
        
        // Verify progressive versions
        XCTAssert(version1 < version2)
        XCTAssert(version1 < version3)
        XCTAssert(version1 < version4)
        XCTAssert(version1 < version5)
        XCTAssert(version1 < version6)
        
        XCTAssert(version2 < version3)
        XCTAssert(version2 < version4)
        XCTAssert(version2 < version5)
        XCTAssert(version2 < version6)
        
        XCTAssert(version3 < version4)
        XCTAssert(version3 < version5)
        XCTAssert(version3 < version6)
        
        XCTAssert(version4 < version5)
        XCTAssert(version4 < version6)
        
        XCTAssert(version5 < version6)
        
        XCTAssertFalse(version10 < version3)
        
        // Verify inversion
        XCTAssert(version2 > version1)
        XCTAssert(version3 > version1)
        XCTAssert(version4 > version1)
        XCTAssert(version5 > version1)
        XCTAssert(version6 > version1)
        
        // Verify equality
        XCTAssert(version1 != version2)
        XCTAssert(version1 != version3)
        XCTAssert(version1 != version4)
        XCTAssert(version1 != version5)
        XCTAssert(version1 != version6)
        
        XCTAssert(version2 == version2alt)
        XCTAssertFalse(version2 < version2alt)
        XCTAssertFalse(version2 > version2alt)
        
        // Checks invalid inputs
        XCTAssertNil(Platform.Version(string: "192.168.0.0"))
        XCTAssertNil(Platform.Version(string: "lorem ipsum"))
        XCTAssertNil(Platform.Version(string: "12.1.2a"))
        
        // Check the UInt32 encoding
        XCTAssertEqual(version2.uint32, version2alt.uint32)
        XCTAssertEqual(version2, Platform.Version(uint32: version2alt.uint32))
        
        // This should be 13.3.0 composed by:
        // UInt8(0) UInt8(13) UInt8(3) UInt8(0)
        let bitVersion: UInt32 = 0b00000000000011010000001100000000
        let converted = Platform.Version(uint32: bitVersion)
        XCTAssertEqual(converted, Platform.Version(string: "13.3.0"))
    }
    
    func testNavigatorIndexLoopBreak() throws {
        let navigatorNode1 = NavigatorTree.Node(item: NavigatorItem(pageType: 0,
                                                                    languageID: 0,
                                                                    title: "Top Page",
                                                                    platformMask: 0,
                                                                    availabilityID: 0),
                                                bundleIdentifier: "com.test.bundle")
        
        let navigatorNode2 = NavigatorTree.Node(item: NavigatorItem(pageType: 0,
                                                                    languageID: 0,
                                                                    title: "Middle Page",
                                                                    platformMask: 0,
                                                                    availabilityID: 0),
                                                bundleIdentifier: "com.test.bundle")
        
        let navigatorNode3 = NavigatorTree.Node(item: NavigatorItem(pageType: 0,
                                                                    languageID: 0,
                                                                    title: "Bottom Page",
                                                                    platformMask: 0,
                                                                    availabilityID: 0),
                                                bundleIdentifier: "com.test.bundle")
        
        let navigatorNode4 = NavigatorTree.Node(item: NavigatorItem(pageType: 0,
                                                                    languageID: 0,
                                                                    title: "Multi Page",
                                                                    platformMask: 0,
                                                                    availabilityID: 0),
                                                bundleIdentifier: "com.test.bundle")
        
        navigatorNode1.add(child: navigatorNode2)
        navigatorNode1.add(child: navigatorNode4.copy())
        navigatorNode2.add(child: navigatorNode3)
        navigatorNode2.add(child: navigatorNode4.copy())
        
        // Create a cycle
        navigatorNode3.add(child: navigatorNode1)
        
        let copy = navigatorNode1.copy()
        XCTAssertEqual(copy.dumpTree(), """
                       Top Page
                       ┣╸Middle Page
                       ┃ ┣╸Bottom Page
                       ┃ ┗╸Multi Page
                       ┗╸Multi Page
                       """)
    }
    
    func testAvailabilityIndexCreation() throws {
        #if !os(Linux) && !os(Android)
        let availabilityIndex = AvailabilityIndex()
        
        let macOS_10_14 = Platform(name: .macOS, version: Platform.Version(string: "10.14")!)
        let macOS_10_14_9 = Platform(name: .macOS, version: Platform.Version(string: "10.14.9")!)
        let iOS_10_15 = Platform(name: .iOS, version: Platform.Version(string: "10.15")!)
        let iOS_11_11 = Platform(name: .iOS, version: Platform.Version(string: "11.1")!)
        let iOS_9_1 = Platform(name: .iOS, version: Platform.Version(string: "9.1")!)
        let iOS_9 = Platform(name: .iOS, version: Platform.Version(string: "9")!)
        let iOS_6 = Platform(name: .iOS, version: Platform.Version(string: "6.0")!)
        let iOS_5 = Platform(name: .iOS, version: Platform.Version(string: "5.0")!)
        
        let info0 = AvailabilityIndex.Info(platformName: .macOS, introduced: Platform.Version(string: "10.15"))
        let info1 = AvailabilityIndex.Info(platformName: .iOS, introduced: Platform.Version(string: "6.0"), deprecated: Platform.Version(string: "11.0"))
        let info2 = AvailabilityIndex.Info(platformName: .iOS, introduced: Platform.Version(string: "12.0"))
        let info3 = AvailabilityIndex.Info(platformName: .iOS, introduced: Platform.Version(string: "9.0"), deprecated: Platform.Version(string: "12.0"))
        let info1alt = AvailabilityIndex.Info(platformName: .iOS, introduced: Platform.Version(string: "6.0"), deprecated: Platform.Version(string: "11.0"))
        let infoMissing = AvailabilityIndex.Info(platformName: .watchOS, introduced: Platform.Version(string: "2.0"))
        let platformOnly = AvailabilityIndex.Info(platformName: .iOS)
        
        // Queries
        XCTAssertFalse(info0.isDeprecated(on: iOS_10_15))
        XCTAssertTrue(info1.isDeprecated(on: iOS_11_11))
        XCTAssertFalse(info1.isDeprecated(on: iOS_9))
        
        XCTAssertFalse(info0.isAvailable(on: macOS_10_14_9))
        XCTAssertTrue(info1.isAvailable(on: iOS_9_1))
        XCTAssertFalse(info1.isAvailable(on: iOS_5))
        
        XCTAssertFalse(info0.isIntroduced(on: macOS_10_14))
        XCTAssertTrue(info1.isIntroduced(on: iOS_6))
        XCTAssertFalse(info1.isIntroduced(on: iOS_9))
        
        XCTAssertTrue(platformOnly.isAvailable(on: iOS_9_1))
        
        // Creation
        XCTAssertEqual(availabilityIndex.id(for: info0, createIfMissing: true), 1)
        XCTAssertEqual(availabilityIndex.id(for: info1, createIfMissing: true), 2)
        XCTAssertEqual(availabilityIndex.id(for: info2, createIfMissing: true), 3)
        XCTAssertEqual(availabilityIndex.id(for: info3, createIfMissing: true), 4)
        
        // Ensure we match
        XCTAssertEqual(availabilityIndex.id(for: info0), 1)
        XCTAssertEqual(availabilityIndex.id(for: info1), 2)
        XCTAssertEqual(availabilityIndex.id(for: info2), 3)
        XCTAssertEqual(availabilityIndex.id(for: info3), 4)
        
        // Alternate version
        XCTAssertEqual(availabilityIndex.id(for: info1alt, createIfMissing: true), 2)
        
        // Missing
        XCTAssertNil(availabilityIndex.id(for: infoMissing))
        
        XCTAssertEqual(availabilityIndex.platforms.count, 2)
        XCTAssertEqual(availabilityIndex.versions(for: .iOS)?.count, 4)
        XCTAssertEqual(availabilityIndex.versions(for: .macOS)?.count, 1)
        
        let targetFolder = try createTemporaryDirectory()
        let targetURL = targetFolder.appendingPathComponent("availability.index")
        let jsonEncoder = JSONEncoder()
        let data = try jsonEncoder.encode(availabilityIndex)
        try data.write(to: targetURL)
        let readData = try Data(contentsOf: targetURL)
        let decodedIndex = try JSONDecoder().decode(AvailabilityIndex.self, from: readData)
        
        // Ensure we still match
        XCTAssertEqual(decodedIndex.id(for: info0), 1)
        XCTAssertEqual(decodedIndex.id(for: info1), 2)
        XCTAssertEqual(decodedIndex.id(for: info2), 3)
        XCTAssertEqual(decodedIndex.id(for: info3), 4)
        
        XCTAssertEqual(decodedIndex.platforms.count, 2)
        XCTAssertEqual(decodedIndex.versions(for: .iOS)?.count, 4)
        XCTAssertEqual(decodedIndex.versions(for: .macOS)?.count, 1)
        #endif
    }
    
    func testAvailabilityIndexInterfaceLanguageBackwardsCompatibility() throws {
        // Tests for backwards compatibility with an encoded `InterfaceLanguage` that does not include
        // an `id`.
        
        let plistWithoutLanguageID = """
            <plist version="1.0">
            <dict>
                <key>data</key>
                <dict>
                </dict>
                <key>interfaceLanguages</key>
                <array>
                    <dict>
                        <key>mask</key>
                        <integer>1</integer>
                        <key>name</key>
                        <string>Swift</string>
                    </dict>
                </array>
                <key>languageToPlatforms</key>
                <array>
                </array>
                <key>platforms</key>
                <array>
                </array>
            </dict>
            </plist>
            """
        
        let availabilityIndex = try PropertyListDecoder().decode(
            AvailabilityIndex.self,
            from: Data(plistWithoutLanguageID.utf8)
        )
        
        XCTAssertEqual(availabilityIndex.interfaceLanguages.first?.name, "Swift")
        XCTAssertEqual(availabilityIndex.interfaceLanguages.first?.id, "swift")
        XCTAssertEqual(availabilityIndex.interfaceLanguages.first?.mask, 1)
    }
    
    func testRenderNodeToPageType() {
        
        XCTAssertEqual(PageType(role: "symbol"), .symbol)
        XCTAssertEqual(PageType(role: "containersymbol"), .symbol)
        XCTAssertEqual(PageType(role: "restrequestsymbol"), .httpRequest)
        XCTAssertEqual(PageType(role: "dictionarysymbol"), .dictionarySymbol)
        XCTAssertEqual(PageType(role: "pseudosymbol"), .symbol)
        XCTAssertEqual(PageType(role: "pseudocollection"), .framework)
        XCTAssertEqual(PageType(role: "collection"), .framework)
        XCTAssertEqual(PageType(role: "collectiongroup"), .symbol)
        XCTAssertEqual(PageType(role: "article"), .article)
        XCTAssertEqual(PageType(role: "samplecode"), .sampleCode)
        
        XCTAssertEqual(PageType(symbolKind: "module"), .framework)
        XCTAssertEqual(PageType(symbolKind: "class"), .class)
        XCTAssertEqual(PageType(symbolKind: "cl"), .class)
        XCTAssertEqual(PageType(symbolKind: "struct"), .structure)
        XCTAssertEqual(PageType(symbolKind: "tag"), .structure)
        XCTAssertEqual(PageType(symbolKind: "intf"), .protocol)
        XCTAssertEqual(PageType(symbolKind: "protocol"), .protocol)
        XCTAssertEqual(PageType(symbolKind: "enum"), .enumeration)
        XCTAssertEqual(PageType(symbolKind: "func"), .function)
        XCTAssertEqual(PageType(symbolKind: "function"), .function)
        XCTAssertEqual(PageType(symbolKind: "extension"), .extension)
        XCTAssertEqual(PageType(symbolKind: "data"), .globalVariable)
        XCTAssertEqual(PageType(symbolKind: "tdef"), .typeAlias)
        XCTAssertEqual(PageType(symbolKind: "typealias"), .typeAlias)
        XCTAssertEqual(PageType(symbolKind: "intftdef"), .associatedType)
        XCTAssertEqual(PageType(symbolKind: "op"), .operator)
        XCTAssertEqual(PageType(symbolKind: "opfunc"), .operator)
        XCTAssertEqual(PageType(symbolKind: "intfopfunc"), .operator)
        XCTAssertEqual(PageType(symbolKind: "macro"), .macro)
        XCTAssertEqual(PageType(symbolKind: "union"), .union)
        XCTAssertEqual(PageType(symbolKind: "property"), .instanceProperty)
        XCTAssertEqual(PageType(symbolKind: "dict"), .dictionarySymbol)
        
        func verifySymbolKind(_ inputs: [String], _ result: PageType) {
            for input in inputs {
                XCTAssertEqual(PageType(symbolKind:input), result)
            }
        }
        
        verifySymbolKind(["enumelt", "econst"], .enumerationCase)
        verifySymbolKind(["enumctr", "structctr", "instctr", "intfctr", "constructor", "initializer"], .initializer)
        verifySymbolKind(["enumm", "structm", "instm", "intfm"], .instanceMethod)
        verifySymbolKind(["enump", "structp", "instp", "intfp", "unionp", "pseudo", "variable"], .instanceProperty)
        verifySymbolKind(["enumdata", "structdata", "cldata", "clconst", "intfdata"], .instanceVariable)
        verifySymbolKind(["enumsub", "structsub", "instsub", "intfsub"], .subscript)
        verifySymbolKind(["enumcm", "structcm", "clm", "intfcm"], .typeMethod)
        verifySymbolKind(["httpget", "httpput", "httppost", "httppatch", "httpdelete"], .httpRequest)
        
        // Verify mappings provided from Delphi to SymbolKit
        
        XCTAssertEqual(PageType(symbolKind: "tdef"), PageType(symbolKind: "typealias"))
        XCTAssertEqual(PageType(symbolKind: "data"), PageType(symbolKind: "var"))
        XCTAssertEqual(PageType(symbolKind: "func"), PageType(symbolKind: "func"))
        XCTAssertEqual(PageType(symbolKind: "opfunc"), PageType(symbolKind: "func.op"))
        XCTAssertEqual(PageType(symbolKind: "enum"), PageType(symbolKind: "enum"))
        XCTAssertEqual(PageType(symbolKind: "enumdata"), PageType(symbolKind: "type.property"))
        XCTAssertEqual(PageType(symbolKind: "enumcm"), PageType(symbolKind: "type.method"))
        XCTAssertEqual(PageType(symbolKind: "enumctr"), PageType(symbolKind: "init"))
        XCTAssertEqual(PageType(symbolKind: "enumm"), PageType(symbolKind: "method"))
        XCTAssertEqual(PageType(symbolKind: "enumsub"), PageType(symbolKind: "subscript"))
        XCTAssertEqual(PageType(symbolKind: "enump"), PageType(symbolKind: "property"))
        XCTAssertEqual(PageType(symbolKind: "enumelt"), PageType(symbolKind: "enum.case"))
        XCTAssertEqual(PageType(symbolKind: "struct"), PageType(symbolKind: "struct"))
        XCTAssertEqual(PageType(symbolKind: "structcm"), PageType(symbolKind: "type.method"))
        XCTAssertEqual(PageType(symbolKind: "structctr"), PageType(symbolKind: "init"))
        XCTAssertEqual(PageType(symbolKind: "structdata"), PageType(symbolKind: "type.property"))
        XCTAssertEqual(PageType(symbolKind: "structm"), PageType(symbolKind: "method"))
        XCTAssertEqual(PageType(symbolKind: "structsub"), PageType(symbolKind: "subscript"))
        XCTAssertEqual(PageType(symbolKind: "structp"), PageType(symbolKind: "property"))
        XCTAssertEqual(PageType(symbolKind: "cl"), PageType(symbolKind: "class"))
        XCTAssertEqual(PageType(symbolKind: "cldata"), PageType(symbolKind: "type.property"))
        XCTAssertEqual(PageType(symbolKind: "clm"), PageType(symbolKind: "type.method"))
        XCTAssertEqual(PageType(symbolKind: "instctr"), PageType(symbolKind: "init"))
        XCTAssertEqual(PageType(symbolKind: "instm"), PageType(symbolKind: "method"))
        XCTAssertEqual(PageType(symbolKind: "instsub"), PageType(symbolKind: "subscript"))
        XCTAssertEqual(PageType(symbolKind: "instp"), PageType(symbolKind: "property"))
        XCTAssertEqual(PageType(symbolKind: "intf"), PageType(symbolKind: "protocol"))
        XCTAssertEqual(PageType(symbolKind: "intfdata"), PageType(symbolKind: "type.property"))
        XCTAssertEqual(PageType(symbolKind: "intfcm"), PageType(symbolKind: "type.method"))
        XCTAssertEqual(PageType(symbolKind: "intfctr"), PageType(symbolKind: "init"))
        XCTAssertEqual(PageType(symbolKind: "intfm"), PageType(symbolKind: "method"))
        XCTAssertEqual(PageType(symbolKind: "intfsub"), PageType(symbolKind: "subscript"))
        XCTAssertEqual(PageType(symbolKind: "intfp"), PageType(symbolKind: "property"))
        XCTAssertEqual(PageType(symbolKind: "intfopfunc"), PageType(symbolKind: "func.op"))
        XCTAssertEqual(PageType(symbolKind: "intftdef"), PageType(symbolKind: "associatedtype"))
    }

    // rdar://84986427
    // Mounting and unmounting the dmg creates noise on the bots when it fails.
    // If the test fails before unmounting, the resource is leaked.
    // This is currently the only test mounting anything, but with tests running
    // in parallel, this could cause collisions.
    func skip_testNavigatorIndexOnReadOnlyFilesystem() throws {
        #if os(macOS)
        // To verify we're able to open a read-only index, we need to mount a small DMG in read-only mode.
        let dmgPath = Bundle.module.url(
            forResource: "read-only-index", withExtension: "dmg", subdirectory: "Test Resources")!
        
        // Mount the DMG.
        let mountProcess = Process()
        mountProcess.launchPath = "/usr/bin/hdiutil"
        mountProcess.arguments = ["attach", dmgPath.path]
        mountProcess.launch()
        mountProcess.waitUntilExit()
        
        // Check mounting worked.
        guard mountProcess.terminationStatus == 0 else {
            XCTFail("Read-only DMG mounting failed.")
            return
        }
        
        // Verify we can open the index without errors.
        let path = URL(fileURLWithPath: "/Volumes/ReadOnlyIndex/index")
        XCTAssertNoThrow(try NavigatorIndex(url: path))
        
        // Detatch the Volume.
        let detatchProcess = Process()
        detatchProcess.launchPath = "/usr/bin/hdiutil"
        detatchProcess.arguments = ["detach", "/Volumes/ReadOnlyIndex"]
        detatchProcess.launch()
        detatchProcess.waitUntilExit()
        
        XCTAssertEqual(detatchProcess.terminationStatus, 0)
        #endif
    }
    
    func testNavigatorIndexAsReadOnlyFile() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        
        let targetURL = try createTemporaryDirectory()
        let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: "org.swift.docc.test", sortRootChildrenByName: true)
        builder.setup()
        
        for identifier in context.knownPages {
            let source = context.documentURL(for: identifier)
            let entity = try context.entity(with: identifier)
            let renderNode = try converter.convert(entity, at: source)
            try builder.index(renderNode: renderNode)
        }
        
        builder.finalize()
        
        // Get the database file.
        let dataFileURL = targetURL.appendingPathComponent("data.mdb")
        
        // Set data file as read-only so we make sure we don't crash if the user has not writing permission on the database file.
        try FileManager.default.setAttributes([FileAttributeKey.posixPermissions: NSNumber(value: 0o400)], ofItemAtPath: dataFileURL.path)
        
        // Ensure we can read the navigator index even if the data file is read-only.
        _ = try NavigatorIndex(url: targetURL, readNavigatorTree: false)
        
        // Remove all permissions to the file.
        try FileManager.default.setAttributes([FileAttributeKey.posixPermissions: NSNumber(value: 0o000)], ofItemAtPath: dataFileURL.path)
        
        // Make sure we throw if an index can't be opened even after the fallback, avoiding entering an infinite loop.
        XCTAssertThrowsError(try NavigatorIndex(url: targetURL, readNavigatorTree: false))
    }
    
    func testNavigatorTitle() throws {
        
        func buildJSON(title: String, symbolKind: String, fragments: String) -> String {
            return """
        {
          "abstract": [],
          "hierarchy": { "paths": [] },
          "identifier": { "interfaceLanguage": "swift", "url": "doc://org.swift.docc.example/documentation/test-item" },
          "kind": "symbol",
          "metadata": {
            "modules": [ { "name": "MyKit" } ],
            "roleHeading": "My Heading",
            "title": "\(title)",
            "symbolKind": "\(symbolKind)",
            "fragments": \(fragments)
          },
          "primaryContentSections": [],
          "references": {},
          "schemaVersion": { "major": 1, "minor": 0, "patch": 0 },
          "sections": [],
          "seeAlsoSections": [],
          "topicSections": []
        }
        """
        }
        
        var json = buildJSON(title: "Failure", symbolKind: "associatedtype", fragments: """
            [
                {
                    "text": "associatedtype",
                    "kind": "keyword"
                },
                {
                    "kind": "text",
                    "text": " "
                },
                {
                    "text": "Failure",
                    "kind": "identifier"
                },
                {
                    "text": " : ",
                    "kind": "text"
                },
                {
                    "kind": "typeIdentifier",
                    "preciseIdentifier": "s:s5ErrorP",
                    "text": "Error"
                }
            ]
        """
        )
        var renderNode = try RenderNode.decode(fromJSON: Data(json.utf8))
        XCTAssertEqual(renderNode.navigatorTitle(), "Failure")
        
        json = buildJSON(title: "Subscriber", symbolKind: "protocol", fragments: """
            [
                {
                    "text": "protocol",
                    "kind": "keyword"
                },
                {
                    "kind": "text",
                    "text": " "
                },
                {
                    "text": "Subscriber",
                    "kind": "identifier"
                }
            ]
        """
        )
        renderNode = try RenderNode.decode(fromJSON: Data(json.utf8))
        XCTAssertEqual(renderNode.navigatorTitle(), "Subscriber")
        
        json = buildJSON(title: "receive(subscription:)", symbolKind: "method", fragments: """
        [
            {
                "kind": "keyword",
                "text": "func"
            },
            {
                "text": " ",
                "kind": "text"
            },
            {
                "text": "receive",
                "kind": "identifier"
            },
            {
                "kind": "text",
                "text": "("
            },
            {
                "text": "subscription",
                "kind": "externalParam"
            },
            {
                "kind": "text",
                "text": ": "
            },
            {
                "kind": "typeIdentifier",
                "preciseIdentifier": "s:7Combine12SubscriptionP",
                "text": "Subscription"
            },
            {
                "text": ")",
                "kind": "text"
            }
        ]
        """
        )
        renderNode = try RenderNode.decode(fromJSON: Data(json.utf8))
        XCTAssertEqual(renderNode.navigatorTitle(), "func receive(subscription: Subscription)")
        
        json = buildJSON(title: "init(_:)", symbolKind: "structctr", fragments: """
        [
            {
                "kind": "identifier",
                "text": "init"
            },
            {
                "kind": "text",
                "text": "(Double)"
            }
        ]
        """
        )
        renderNode = try RenderNode.decode(fromJSON: Data(json.utf8))
        XCTAssertEqual(renderNode.navigatorTitle(), "init(Double)")
    }
    
    func testSavesNodePresentationDisambiguator() {
        let node = Node(
            item: NavigatorItem(
                pageType: PageType.article.rawValue,
                languageID: Language.swift.rawValue,
                title: "",
                platformMask: 0,
                availabilityID: 0),
            bundleIdentifier: ""
        )
        node.presentationIdentifier = "the-disambiguator"
        XCTAssertEqual(node.presentationIdentifier, "the-disambiguator")
    }
    
    func testPathHasher() throws {
        let pathHasher = try XCTUnwrap(PathHasher(rawValue: "MD5"))
        // Test that the results are stable for the given inputs
        (0...100).forEach { _ in
            XCTAssertEqual("41dc6c05a0b5", pathHasher.hash("/documentation/foundation/nsurlsessionwebsockettask"))
            XCTAssertEqual("ffdc704430d3", pathHasher.hash("/documentation/foundation/urlsessionwebsockettask/3281790-send"))
            XCTAssertEqual("1161063e700c", pathHasher.hash("/documentation/swiftui/texteditor/disableautocorrection(_:)"))
            XCTAssertEqual("e47cfd13c4af", pathHasher.hash("/mykit/myclass/myfunc"))
        }
    }
}

/// This function compares two nodes to ensure their data is equal.
fileprivate func compare(lhs: Node, rhs: Node) -> Bool {
    
    func dump(node: Node) -> [NavigatorItem]  {
        var index = 0
        var queue = [node]
        while index < queue.count  {
            let node = queue[index]
            if node.children.count > 0 {
                queue.append(contentsOf: node.children)
            }
            index += 1
        }
        return queue.map { $0.item }
    }
    
    let dump1 = dump(node: lhs)
    let dump2 = dump(node: rhs)
    
    return dump1 == dump2
}

/// Search for the first node with
fileprivate func search(node: Node, matching predicate: (Node) -> Bool) -> Node? {
    if predicate(node) { return node }
    for child in node.children {
        if let result = search(node: child, matching: predicate) {
            return result
        }
    }
    return nil
}

/// Validate a tree with a given validator function
fileprivate func validateTree(node: NavigatorTree.Node, validator: (NavigatorTree.Node) -> Bool) -> Bool {
    if validator(node) == false { return false }
    for child in node.children {
        if validateTree(node: child, validator: validator) == false { return false }
    }
    return true
}

fileprivate func assertUniqueIDs(node: NavigatorTree.Node, message: String = "The tree has duplicated IDs.", file: StaticString = #file, line: UInt = #line) {
    var collector = Set<UInt32>()
    var brokenItemTitle = ""
    
    let valid = validateTree(node: node) { (node) -> Bool in
        guard let id = node.id, !collector.contains(id) else {
            brokenItemTitle = node.item.title
            return false
        }
        collector.insert(id)
        return true
    }
    
    XCTAssertTrue(valid, message + " Item title: \"\(brokenItemTitle)\".", file: file, line: line)
}

fileprivate func testTree(named name: String) throws -> String {
    let fileURL = Bundle.module.url(
        forResource: name, withExtension: "txt", subdirectory: "Test Resources")!
    return try String(contentsOf: fileURL).trimmingCharacters(in: .newlines)
}
