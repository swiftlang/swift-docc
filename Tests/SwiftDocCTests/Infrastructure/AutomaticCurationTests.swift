/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities

class AutomaticCurationTests: XCTestCase {
    private let (availableExtensionSymbolKinds, availableNonExtensionSymbolKinds) = Set(AutomaticCuration.groupKindOrder).union(SymbolGraph.Symbol.KindIdentifier.allCases)
        .filter { $0.symbolGeneratesPage() }
        .categorize(where: { $0.identifier.hasSuffix(".extension") })
    
    func testAutomaticTopicsGenerationForSameModuleTypes() throws {
        for kind in availableNonExtensionSymbolKinds {
            let containerID = "some-container-id"
            let memberID = "some-member-id"
            
            let tempURL = try createTempFolder(content: [
                Folder(name: "unit-test.docc", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        moduleName: "ModuleName",
                        symbols: [
                            makeSymbol(id: containerID, kind: .class, pathComponents: ["SomeClass"]),
                            makeSymbol(id: memberID, kind: kind, pathComponents: ["SomeClass", "someMember"]),
                        ],
                        relationships: [
                            .init(source: memberID, target: containerID, kind: .memberOf, targetFallback: nil),
                        ]
                    ))
                ])
            ])
            let (_, bundle, context) = try loadBundle(from: tempURL)
            
            try assertRenderedPage(atPath: "/documentation/ModuleName/SomeClass", containsAutomaticTopicSectionFor: kind, context: context, bundle: bundle)
        }
    }
    
    func testAutomaticTopicsGenerationForExtensionSymbols() throws {
        // The extended module behavior is already verified for each extended symbol kind in the module.
        for kind in availableExtensionSymbolKinds where kind != .extendedModule {
            let containerID = "some-container-id"
            let extensionID = "some-extension-id"
            let memberID = "some-member-id"
            
            let nonExtensionKind = SymbolGraph.Symbol.KindIdentifier(identifier: String(kind.identifier.dropLast(".extension".count)))
            
            let tempURL = try createTempFolder(content: [
                Folder(name: "unit-test.docc", content: [
                    // Add an empty main symbol graph file so that the extension symbol graph file is processed
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName")),
                    JSONFile(name: "ModuleName@ExtendedModule.symbols.json", content: makeSymbolGraph(
                        moduleName: "ModuleName",
                        symbols: [
                            // public extension Something {
                            //     func someFunction() { }
                            // }
                            makeSymbol(
                                id: extensionID,
                                kind: .extension,
                                // The extension has the path component of the extended type
                                pathComponents: ["Something"],
                                // Specify the extended symbol's symbol kind
                                otherMixins: [
                                    SymbolGraph.Symbol.Swift.Extension(extendedModule: "ExtendedModule", typeKind: nonExtensionKind, constraints: [])
                                ]
                            ),
                            // No matter what type `ExtendedModule.Something` is, always add a function in the extension
                            makeSymbol(id: memberID, kind: .func, pathComponents: ["Something", "someFunction()"]),
                        ],
                        relationships: [
                            .init(source: extensionID, target: containerID, kind: .extensionTo, targetFallback: "ExtendedModule.Something"),
                            .init(source: memberID, target: extensionID, kind: .memberOf, targetFallback: "ExtendedModule.Something"),
                        ]
                    )),
                ])
            ])
            let (_, bundle, context) = try loadBundle(from: tempURL)
            
            try assertRenderedPage(atPath: "/documentation/ModuleName", containsAutomaticTopicSectionFor: .extendedModule, context: context, bundle: bundle)
            try assertRenderedPage(atPath: "/documentation/ModuleName/ExtendedModule", containsAutomaticTopicSectionFor: kind, context: context, bundle: bundle)
        }
    }
    
    private func assertRenderedPage(
        atPath path: String,
        containsAutomaticTopicSectionFor kind: SymbolGraph.Symbol.KindIdentifier,
        context: DocumentationContext,
        bundle: DocumentationBundle,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: path, sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = try XCTUnwrap(translator.visit(node.semantic) as? RenderNode, file: file, line: line)
        
        for section in renderNode.topicSections {
            XCTAssert(section.generated, "\(section.title?.singleQuoted ?? "Untitled topic section") was not marked as generated.", file: file, line: line)
        }
        
        XCTAssert(
            renderNode.topicSections.contains(where: { group in group.title == AutomaticCuration.groupTitle(for: kind) }),
            """
            Missing automatic \(AutomaticCuration.groupTitle(for: kind).singleQuoted) topic group.
            Add \(kind.identifier) to either 'AutomaticCuration.groupKindOrder or 'SymbolGraph.Symbol.KindIdentifier.noPageKinds'.
            """,
            file: file, line: line
        )
    }
    
    func testAutomaticTopicsSkippingCustomCuratedSymbols() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], configureBundle: { url in
            // Curate some of `SideClass`'s children under SideKit.
            let sideKit = """
            # ``SideKit``
            SideKit framework
            ## Topics
            ### SideKit Basics
            - ``SideClass/path``
            - ``SideClass/url``
            """
            try sideKit.write(to: url.appendingPathComponent("documentation").appendingPathComponent("sidekit.md"), atomically: true, encoding: .utf8)
        })

        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        
        // Compile the render node to flex the automatic curator
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = translator.visit(symbol) as! RenderNode
        
        // Verify that uncurated element `SideKit/SideClass/Element` is
        // automatically curated in `SideClass`'s "Topics"
        XCTAssertFalse(renderNode.topicSections.filter({ section -> Bool in
            return section.identifiers.contains("doc://org.swift.docc.example/documentation/SideKit/SideClass/Element")
        }).isEmpty)

        // Verify that element `SideKit/SideClass/path` curated in sidecar under `SideKit`
        // is NOT automatically curated in `SideClass`'s "Topics"
        XCTAssertTrue(renderNode.topicSections.filter({ section -> Bool in
            return section.identifiers.contains("doc://org.swift.docc.example/documentation/SideKit/SideClass/path")
        }).isEmpty)
    }

    func testMergingAutomaticTopics() throws {
        let allExpectedChildren = [
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/Element",
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/Value(_:)",
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/init()",
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/myFunction()",
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/path",
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/url",
        ]
        
        // Curate one or two of the children at a time and leave the rest for automatic curation.
        let variationsOfChildrenToCurate: [Set<Int>] = allExpectedChildren.indices.flatMap { first in allExpectedChildren.indices.map { second in Set([first, second]) } }
        
        for curatedIndices in variationsOfChildrenToCurate {
            let manualCuration = curatedIndices.map { "- <\(allExpectedChildren[$0])>" }.joined(separator: "\n")
            
            let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
                try """
                # ``SideKit/SideClass``

                Curate some of the children and leave the rest for automatic curation.

                ## Topics
                    
                ### Manually curated

                \(manualCuration)
                """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
            }
            
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
            // Compile docs and verify the generated Topics section
            let symbol = node.semantic as! Symbol
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(symbol) as! RenderNode
            
            // Verify that all the symbols are curated, either manually or automatically
            let curatedSymbols = renderNode.topicSections.flatMap { $0.identifiers }
            XCTAssertEqual(allExpectedChildren.sorted(), curatedSymbols.sorted())
            
            // The manual topic section is listed before any automatic topic sections
            XCTAssertEqual(renderNode.topicSections.first?.title, "Manually curated")
            
            if let firstSection = renderNode.topicSections.first {
                XCTAssertFalse(firstSection.generated, "The first topic section is manually authored.")
            }
            for section in renderNode.topicSections.dropFirst() {
                XCTAssert(section.generated, "The other topic sections are generated")
            }
            
            // Check that the automatic topic sections only exist if its elements weren't manually curated
            XCTAssertEqual(
                !curatedIndices.contains(0),
                renderNode.topicSections.contains(where: { $0.title == "Type Aliases" })
            )
            XCTAssertEqual(
                !curatedIndices.contains(1),
                renderNode.topicSections.contains(where: { $0.title == "Enumeration Cases" })
            )
            XCTAssertEqual(
                !curatedIndices.contains(2),
                renderNode.topicSections.contains(where: { $0.title == "Initializers" })
            )
            XCTAssertEqual(
                !curatedIndices.contains(3),
                renderNode.topicSections.contains(where: { $0.title == "Instance Methods" })
            )
            XCTAssertEqual(
                !curatedIndices.contains(4) || !curatedIndices.contains(5),
                renderNode.topicSections.contains(where: { $0.title == "Instance Properties" })
            )
        }
    }
    
    func testSeeAlsoSectionForAutomaticallyCuratedTopics() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            var graph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: url.appendingPathComponent("sidekit.symbols.json")))
            
            // Copy `SideClass` a handful of times
            let sideClassIdentifier = "s:7SideKit0A5ClassC"
            let sideClassSymbol = graph.symbols[sideClassIdentifier]!
            
            for suffix in ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"] {
                // Duplicate the symbol
                var duplicateSymbol = sideClassSymbol
                let newClassName = duplicateSymbol.names.title + suffix
                duplicateSymbol.names.title = newClassName
                duplicateSymbol.identifier.precise = "s:7SideKit0A\(newClassName.count)\(newClassName)C"
                
                // Update the declaration fragment to use the new name
                let declarationFragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment] = [
                    .init(kind: .keyword, spelling: "class", preciseIdentifier: nil),
                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                    .init(kind: .identifier, spelling: newClassName, preciseIdentifier: nil),
                ]
                let declaration = try JSONDecoder().decode(SymbolGraph.Symbol.DeclarationFragments.self, from: JSONEncoder().encode(declarationFragments))
                duplicateSymbol.mixins[SymbolGraph.Symbol.DeclarationFragments.mixinKey] = declaration
                duplicateSymbol.pathComponents = [newClassName]
                
                graph.symbols[duplicateSymbol.identifier.precise] = duplicateSymbol
                
                // Duplicate all the edges and nodes to and from the symbol
                for relationship in graph.relationships where relationship.source == sideClassIdentifier {
                    var newRelationship = relationship
                    newRelationship.source = duplicateSymbol.identifier.precise
                    
                    // Duplicate the target symbol to avoid symbols being members of more than one other symbol.
                    let newTarget = relationship.target + suffix
                    newRelationship.target = newTarget
                    if let targetSymbol = graph.symbols[relationship.target] {
                        graph.symbols[newTarget] = targetSymbol
                    }
                    
                    graph.relationships.append(newRelationship)
                }
                for relationship in graph.relationships where relationship.target == sideClassIdentifier {
                    var newRelationship = relationship
                    newRelationship.target = duplicateSymbol.identifier.precise
                    
                    // Duplicate the source symbol to avoid symbols being members of more than one other symbol.
                    let newSource = relationship.source + suffix
                    newRelationship.source = newSource
                    if let targetSymbol = graph.symbols[relationship.target] {
                        graph.symbols[newSource] = targetSymbol
                    }
                    
                    graph.relationships.append(newRelationship)
                }
                
                // Add a sidecar file for this symbol
                try """
                # ``SideKit/SideClass\(suffix)``
                
                Curate some of the children and leave the rest for automatic curation.
                
                ## Topics
                
                ### Manually curated
                
                - ``init()``
                - ``path``
                - ``Value(_:)``
                """.write(to: url.appendingPathComponent("documentation/sidekit\(suffix).md"), atomically: true, encoding: .utf8)
            }
            
            let newGraphData = try JSONEncoder().encode(graph)
            try newGraphData.write(to: url.appendingPathComponent("sidekit.symbols.json"))
            
            try """
            # ``SideKit``
            
            Curate the duplicate symbols into different Topic sections and leave some (nr 8, 9, and 10) for automatic curation.
            
            ## Topics
            
            ### First topic
            
            - ``SideClass``
            - ``SideClassOne``
            - ``SideClassTwo``
            
            ### Second topic
            
            - ``SideClassThree``
            - ``SideClassFour``
            - ``SideClassFive``
            
            ### Third topic
            
            - ``SideClassSix``
            - ``SideClassSeven``
            
            """.write(to: url.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)
            
            try """
            # ``SideKit/SideClass``
            
            Curate some of the children and leave the rest for automatic curation.
            
            ## Topics
            
            ### Manually curated
            
            - ``init()``
            - ``path``
            - ``Value(_:)``

            """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
        }
        
        // The first topic section
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // SideKit includes the "Manually curated" task group and additional automatically created groups.
            XCTAssertEqual(renderNode.topicSections.map { $0.title }, ["Manually curated", "Instance Properties", "Instance Methods", "Type Aliases"])
            
            // The other symbols in the same topic section appear in this See Also section
            XCTAssertEqual(renderNode.seeAlsoSections.first?.identifiers, [
                "doc://org.swift.docc.example/documentation/SideKit/SideClassOne",
                "doc://org.swift.docc.example/documentation/SideKit/SideClassTwo",
            ])
        }
        
        // The second topic section
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClassFour", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // The other symbols in the same topic section appear in this See Also section
            XCTAssertEqual(renderNode.seeAlsoSections.first?.identifiers, [
                "doc://org.swift.docc.example/documentation/SideKit/SideClassThree",
                "doc://org.swift.docc.example/documentation/SideKit/SideClassFive",
            ])
        }
        
        // The second topic section
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClassSix", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // The other symbols in the same topic section appear in this See Also section
            XCTAssertEqual(renderNode.seeAlsoSections.first?.identifiers, [
                "doc://org.swift.docc.example/documentation/SideKit/SideClassSeven",
            ])
        }
        
        // The automatically curated symbols shouldn't have a See Also section
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClassEight", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            XCTAssertNil(renderNode.seeAlsoSections.first, "This symbol was automatically curated and shouldn't have a See Also section")
        }
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClassNine", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            XCTAssertNil(renderNode.seeAlsoSections.first, "This symbol was automatically curated and shouldn't have a See Also section")
        }
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClassTen", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            XCTAssertNil(renderNode.seeAlsoSections.first, "This symbol was automatically curated and shouldn't have a See Also section")
        }
    }
    
    func testTopLevelSymbolsAreNotAutomaticallyCuratedIfManuallyCuratedElsewhere() throws {
        // A symbol graph that defines symbol hierarchy of:
        //   TestBed -> A
        //           -> B -> C
        // But curation as:
        //   TestBed -> A -> B -> C
        let topLevelCurationSGFURL = Bundle.module.url(
            forResource: "TopLevelCuration.symbols", withExtension: "json", subdirectory: "Test Resources")!
        
        // Create a test bundle copy with the symbol graph from above
        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: []) { url in
            try? FileManager.default.copyItem(at: topLevelCurationSGFURL, to: url.appendingPathComponent("TopLevelCuration.symbols.json"))
        }
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        do {
            // Get the framework render node
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/TestBed", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // Verify that `B` isn't automatically curated under the framework node
            XCTAssertEqual(
                ["doc://org.swift.docc.example/documentation/TestBed/A"],
                renderNode.topicSections.first?.identifiers
            )
        }
        
        do {
            // Get the `A` render node
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/TestBed/A", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // Verify that `B` was in fact curated under `A`
            XCTAssertEqual(
                ["doc://org.swift.docc.example/documentation/TestBed/B"],
                renderNode.topicSections.first?.identifiers
            )
        }
    }
    
    func testRelevantLanguagesAreAutoCuratedInMixedLanguageFramework() throws {
        let (bundle, context) = try testBundleAndContext(named: "MixedLanguageFramework")
        
        let frameworkDocumentationNode = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/MixedLanguageFramework",
                sourceLanguages: [.swift, .objectiveC]
            )
        )
        
        let swiftTopics = try AutomaticCuration.topics(
            for: frameworkDocumentationNode,
            withTraits: [.swift],
            context: context
        )
        
        XCTAssertEqual(
            swiftTopics.flatMap { taskGroup in
                [taskGroup.title] + taskGroup.references.map(\.path)
            },
            [
                "Classes",
                // 'Bar' is manually curated in a task group titled "Some Swift-only APIs, some Objective-C–only APIs, some mixed" in MixedLanguageFramework.md.
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol",
                // 'SwiftOnlyClass' is manually curated in a task group titled "Some Swift-only APIs, some Objective-C–only APIs, some mixed" in MixedLanguageFramework.md.

                "Protocols",
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol",
                
                "Structures",
                "/documentation/MixedLanguageFramework/Foo-swift.struct",
                
                // 'SwiftOnlyStruct' is manually curated in a task group titled "Swift-only APIs" in MixedLanguageFramework.md.
            ]
        )
        
        let objectiveCTopics = try AutomaticCuration.topics(
            for: frameworkDocumentationNode,
            withTraits: [DocumentationDataVariantsTrait(interfaceLanguage: "occ")],
            context: context
        )
        
        XCTAssertEqual(
            objectiveCTopics.flatMap { taskGroup in
                [taskGroup.title] + taskGroup.references.map(\.path)
            },
            [
                "Classes",
                // 'Bar' is manually curated in a task group titled "Some Swift-only APIs, some Objective-C–only APIs, some mixed" in MixedLanguageFramework.md.
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol",
                
                "Protocols",
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol",
                
                // "Variables",
                // '_MixedLanguageFrameworkVersionNumber is manually curated in a task group titled "Objective-C–only APIs" in MixedLanguageFramework.md.
                // '_MixedLanguageFrameworkVersionString' is manually curated in a task group titled "Some Swift-only APIs, some Objective-C–only APIs, some mixed" in MixedLanguageFramework.md.
                // 'MixedLanguageFramework/Foo-c.typealias' is manually curated in a task group titled "Custom" under 'MixedLanguageFramework/Bar/myStringFunction:error:'
                
                "Enumerations",
                "/documentation/MixedLanguageFramework/Foo-swift.struct",
            ]
        )
    }

    func testIvarsAndMacrosAreCuratedProperly() throws {
        let whatsitSymbols = Bundle.module.url(
            forResource: "Whatsit-Objective-C.symbols", withExtension: "json", subdirectory: "Test Resources")!

        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            try? FileManager.default.copyItem(at: whatsitSymbols, to: url.appendingPathComponent("Whatsit-Objective-C.symbols.json"))
        }
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        let frameworkDocumentationNode = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/Whatsit",
                sourceLanguages: [.objectiveC]
            )
        )
        let objectiveCTopics = try AutomaticCuration.topics(
            for: frameworkDocumentationNode,
            withTraits: [DocumentationDataVariantsTrait(interfaceLanguage: "occ")],
            context: context
        )

        XCTAssertEqual(
            objectiveCTopics.flatMap { taskGroup in
                [taskGroup.title] + taskGroup.references.map(\.path)
            },
            [
                "Classes",
                "/documentation/Whatsit/Whatsit",

                "Macros",
                "/documentation/Whatsit/IS_COOL",
            ]
        )

        let classDocumentationNode = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/Whatsit/Whatsit",
                sourceLanguages: [.objectiveC]
            )
        )
        let classTopics = try AutomaticCuration.topics(
            for: classDocumentationNode,
            withTraits: [DocumentationDataVariantsTrait(interfaceLanguage: "occ")],
            context: context
        )

        XCTAssertEqual(
            classTopics.flatMap { taskGroup in
                [taskGroup.title] + taskGroup.references.map(\.path)
            },
            [
                "Instance Variables",
                "/documentation/Whatsit/Whatsit/Ivar",
            ]
        )
    }

    func testTypeSubscriptsAreCuratedProperly() throws {
        let symbolURL = Bundle.module.url(
            forResource: "TypeSubscript.symbols", withExtension: "json", subdirectory: "Test Resources")!

        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            try? FileManager.default.copyItem(at: symbolURL, to: url.appendingPathComponent("TypeSubscript.symbols.json"))
        }
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        let containerDocumentationNode = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/ThirdOrder/SomeStruct",
                sourceLanguages: [.swift]
            )
        )
        let topics = try AutomaticCuration.topics(
            for: containerDocumentationNode,
            withTraits: [DocumentationDataVariantsTrait(interfaceLanguage: "swift")],
            context: context
        )

        XCTAssertEqual(
            topics.flatMap { taskGroup in
                [taskGroup.title] + taskGroup.references.map(\.path)
            },
            [
                "Type Subscripts",
                "/documentation/ThirdOrder/SomeStruct/subscript(_:)",
            ]
        )
    }

    func testCPlusPlusSymbolsAreCuratedProperly() throws {
        let (bundle, context) = try testBundleAndContext(named: "CxxSymbols")

        let rootDocumentationNode = try context.entity(
            with: .init(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/CxxSymbols",
                sourceLanguage: .objectiveC
            )
        )
        let topics = try AutomaticCuration.topics(
            for: rootDocumentationNode,
            withTraits: [.objectiveC],
            context: context
        )

        XCTAssertEqual(
            topics.flatMap { taskGroup in
                [taskGroup.title] + taskGroup.references.map(\.path)
            },
            [
                "Namespaces",
                "/documentation/CxxSymbols/Foo",

                "Unions",
                "/documentation/CxxSymbols/MyUnion",
            ]
        )
    }

    // Ensures that manually curated sample code articles are not also
    // automatically curated.
    func testSampleCodeArticlesRespectManualCuration() throws {
        let renderNode = try renderNode(atPath: "/documentation/SomeSample", fromTestBundleNamed: "SampleBundle")
        
        guard renderNode.topicSections.count == 2 else {
            XCTFail("Expected to find '2' topic sections. Found: \(renderNode.topicSections.count.description.singleQuoted).")
            return
        }
        
        XCTAssertEqual(renderNode.topicSections[0].title, "Examples")
        XCTAssertEqual(
            renderNode.topicSections[0].identifiers,
            [
                "doc://org.swift.docc.sample/documentation/SampleBundle/MySample",
                "doc://org.swift.docc.sample/documentation/SampleBundle/MyLocalSample",
                "doc://org.swift.docc.sample/documentation/SampleBundle/RelativeURLSample",
                "doc://org.swift.docc.sample/documentation/SampleBundle/MyArticle",
                "doc://org.swift.docc.sample/documentation/SampleBundle/MyExternalSample",
            ]
        )
        
        XCTAssertEqual(renderNode.topicSections[1].title, "Articles")
        XCTAssertEqual(
            renderNode.topicSections[1].identifiers,
            [
                "doc://org.swift.docc.sample/documentation/SampleBundle/MyUncuratedSample",
            ]
        )
    }

    func testOverloadedSymbolsAreCuratedUnderGroup() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let protocolRenderNode = try renderNode(
            atPath: "/documentation/ShapeKit/OverloadedProtocol",
            fromTestBundleNamed: "OverloadedSymbols")

        guard protocolRenderNode.topicSections.count == 1, let protocolTopicSection = protocolRenderNode.topicSections.first else {
            XCTFail("Expected to find 1 topic section, found \(protocolRenderNode.topicSections.count): \(protocolRenderNode.topicSections.map(\.title?.singleQuoted))")
            return
        }

        XCTAssertEqual(protocolTopicSection.title, "Instance Methods")
        XCTAssertEqual(protocolTopicSection.identifiers, [
            "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-9b6be"
        ])

        let overloadGroupRenderNode = try renderNode(
            atPath: "/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-9b6be",
            fromTestBundleNamed: "OverloadedSymbols")

        XCTAssertEqual(
            overloadGroupRenderNode.topicSections.count, 0,
            "Expected no topic sections, found \(overloadGroupRenderNode.topicSections.map(\.title?.singleQuoted))"
        )
    }

    func testAutomaticCurationHandlesOverloadsWithLanguageFilters() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let (bundle, context) = try testBundleAndContext(named: "OverloadedSymbols")

        let protocolDocumentationNode = try context.entity(
            with: .init(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/ShapeKit/OverloadedProtocol",
                sourceLanguage: .swift))

        func assertAutomaticCuration(
            variants: Set<DocumentationDataVariantsTrait>,
            file: StaticString = #file,
            line: UInt = #line
        ) throws {
            let topics = try AutomaticCuration.topics(
                for: protocolDocumentationNode,
                withTraits: variants,
                context: context)

            guard topics.count == 1, let overloadTopic = topics.first else {
                XCTFail(
                    "Expected one automatic curation topic, found \(topics.count): \(topics.map(\.title?.singleQuoted))",
                    file: file, line: line)
                return
            }

            XCTAssertEqual(overloadTopic.title, "Instance Methods", file: file, line: line)
            XCTAssertEqual(overloadTopic.references.map(\.absoluteString), [
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-9b6be"
            ], file: file, line: line)
        }

        // AutomaticCuration uses a different method for collecting child nodes when the variant
        // traits set is empty and when it's not. Ensure that in both cases, we only see the
        // overload group symbol curated under the protocol symbol.
        try assertAutomaticCuration(variants: [])
        try assertAutomaticCuration(variants: [.swift])
    }

    func testAutomaticCurationDropsOverloadGroupWhenOverloadsAreCurated() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let (_, bundle, context) = try testBundleAndContext(copying: "OverloadedSymbols") { url in
            try """
            # ``OverloadedProtocol``

            This is a protocol's docs.

            ## Topics

            - ``fourthTestMemberName(test:)-1h173``
            - ``fourthTestMemberName(test:)-8iuz7``
            - ``fourthTestMemberName(test:)-91hxs``
            - ``fourthTestMemberName(test:)-961zx``
            """.write(to: url.appendingPathComponent("OverloadedProtocol.md"), atomically: true, encoding: .utf8)
        }

        let protocolDocumentationNode = try context.entity(
            with: .init(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/ShapeKit/OverloadedProtocol",
                sourceLanguage: .swift))

        // Compile the render node to flex the automatic curator
        let symbol = protocolDocumentationNode.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: protocolDocumentationNode.reference)
        let renderNode = translator.visit(symbol) as! RenderNode

        XCTAssertEqual(renderNode.topicSections.count, 1)

        // The page should not contain a reference to the overload group node, which would otherwise
        // be automatically curated into an "Instance Methods" topic group with a hash suffix of 9b6be
        let curatedTopic = try XCTUnwrap(renderNode.topicSections.first)
        XCTAssertEqual(curatedTopic.title, nil)
        XCTAssertEqual(curatedTopic.identifiers, [
            "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-1h173",
            "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-8iuz7",
            "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-91hxs",
            "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-961zx",
        ])
    }
    
    func testAutomaticallyCuratedSymbolTopicsAreMergedWithManuallyCuratedTopics() throws {
         for kind in availableNonExtensionSymbolKinds {
             let containerID = "some-container-id"
             let memberID = "some-member-id"
             let topicSectionTitle = AutomaticCuration.groupTitle(for: kind)

             let exampleDocumentation = Folder(name: "CatalogName.docc", content: [
                 JSONFile(name: "ModuleName.symbols.json",
                          content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                             makeSymbol(id: containerID, kind: .class, pathComponents: ["SomeClass"]),
                             makeSymbol(id: memberID, kind: kind, pathComponents: ["SomeClass", "someMember"]),
                          ], relationships: [
                             .init(source: memberID, target: containerID, kind: .memberOf, targetFallback: nil),
                          ])),
                 TextFile(name: "SomeArticle.md", utf8Content: """
              # Some article
              
              An article with some content.
              """),
                 TextFile(name: "SomeExtension.md", utf8Content: """
             # ``ModuleName/SomeClass``
             
             Curate an article under a manually curated section and leave the symbol documentation to automatic curation.
             
             ## Topics
             
             ### \(topicSectionTitle)
             
             - <doc:SomeArticle>
             """),
             ])
             let catalogURL = try exampleDocumentation.write(inside: createTemporaryDirectory())
             let (_, bundle, context) = try loadBundle(from: catalogURL)

             let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/SomeClass", sourceLanguage: .swift))

             // Compile docs and verify the generated Topics section
             var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
             let renderNode = try XCTUnwrap(translator.visit(node.semantic) as? RenderNode)

             // Verify that there are no duplicate sections in `SomeClass`'s "Topics" section
             XCTAssertEqual(renderNode.topicSections.map { $0.title }, [topicSectionTitle])

             // Verify that uncurated element `ModuleName/SomeClass/someMember` is
             // automatically curated in `SomeClass`'s "Topics" under the existing manually curated topics section
             // along with manually curated article "SomeArticle"
             XCTAssertEqual([
                 "doc://CatalogName/documentation/CatalogName/SomeArticle",
                 "doc://CatalogName/documentation/ModuleName/SomeClass/someMember",
             ], renderNode.topicSections.first?.identifiers)

             // Verify that the merged section under `SideClass`'s "Topics" is correctly marked as containing manual content
             XCTAssertFalse(renderNode.topicSections.first?.generated ?? false)
         }
     }
}
