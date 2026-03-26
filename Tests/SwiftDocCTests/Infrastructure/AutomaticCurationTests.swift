/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SymbolKit
@testable import SwiftDocC
import DocCTestUtilities
import DocCCommon

class AutomaticCurationTests: XCTestCase {
    private let (availableExtensionSymbolKinds, availableNonExtensionSymbolKinds) = Set(AutomaticCuration.groupKindOrder).union(SymbolGraph.Symbol.KindIdentifier.allCases)
        .filter { $0.symbolGeneratesPage() }
        .categorize(where: { $0.identifier.hasSuffix(".extension") })
    
    func testAutomaticTopicsGenerationForSameModuleTypes() async throws {
        for kind in availableNonExtensionSymbolKinds {
            let containerID = "some-container-id"
            let memberID = "some-member-id"
            
            let catalog =
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
            
            let (_, context) = try await loadBundle(catalog: catalog)
            
            try assertRenderedPage(atPath: "/documentation/ModuleName/SomeClass", containsAutomaticTopicSectionFor: kind, context: context)
        }
    }
    
    func testAutomaticTopicsGenerationForExtensionSymbols() async throws {
        // The extended module behavior is already verified for each extended symbol kind in the module.
        for kind in availableExtensionSymbolKinds where kind != .extendedModule {
            let containerID = "some-container-id"
            let extensionID = "some-extension-id"
            let memberID = "some-member-id"
            
            let nonExtensionKind = SymbolGraph.Symbol.KindIdentifier(identifier: String(kind.identifier.dropLast(".extension".count)))
            
            let catalog =
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
            
            let (_, context) = try await loadBundle(catalog: catalog)
            
            try assertRenderedPage(atPath: "/documentation/ModuleName", containsAutomaticTopicSectionFor: .extendedModule, context: context)
            try assertRenderedPage(atPath: "/documentation/ModuleName/ExtendedModule", containsAutomaticTopicSectionFor: kind, context: context)
        }
    }
    
    private func assertRenderedPage(
        atPath path: String,
        containsAutomaticTopicSectionFor kind: SymbolGraph.Symbol.KindIdentifier,
        context: DocumentationContext,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: path, sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
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
    
    func testAutomaticTopicsSkippingCustomCuratedSymbols() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", excludingPaths: [], configureBundle: { url in
            // Curate some of members of SideClass in an API collection
            try """
            # Some API collection
            
            ## Topics
            - ``/SideKit/SideClass/path``
            - ``/SideKit/SideClass/url``
            """.write(to: url.appendingPathComponent("API Collection.md"), atomically: true, encoding: .utf8)
            
            // Curate the API collection under SideClass
            try """
            # ``/SideKit/SideClass``
            
            ## Topics
            - <doc:API-Collection>
            """.write(to: url.appendingPathComponent("sideclass.md"), atomically: true, encoding: .utf8)
        })

        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        
        // Compile the render node to flex the automatic curator
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
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

    func testMergingAutomaticTopics() async throws {
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
            
            let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests") { url in
                try """
                # ``SideKit/SideClass``

                Curate some of the children and leave the rest for automatic curation.

                ## Topics
                    
                ### Manually curated

                \(manualCuration)
                """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
            }
            
            let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
            // Compile docs and verify the generated Topics section
            let symbol = node.semantic as! Symbol
            var translator = RenderNodeTranslator(context: context, identifier: node.reference)
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
    
    func testSeeAlsoSectionForAutomaticallyCuratedTopics() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests") { url in
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
            let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, identifier: node.reference)
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
            let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/SideKit/SideClassFour", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // The other symbols in the same topic section appear in this See Also section
            XCTAssertEqual(renderNode.seeAlsoSections.first?.identifiers, [
                "doc://org.swift.docc.example/documentation/SideKit/SideClassThree",
                "doc://org.swift.docc.example/documentation/SideKit/SideClassFive",
            ])
        }
        
        // The second topic section
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/SideKit/SideClassSix", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // The other symbols in the same topic section appear in this See Also section
            XCTAssertEqual(renderNode.seeAlsoSections.first?.identifiers, [
                "doc://org.swift.docc.example/documentation/SideKit/SideClassSeven",
            ])
        }
        
        // The automatically curated symbols shouldn't have a See Also section
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/SideKit/SideClassEight", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            XCTAssertNil(renderNode.seeAlsoSections.first, "This symbol was automatically curated and shouldn't have a See Also section")
        }
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/SideKit/SideClassNine", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            XCTAssertNil(renderNode.seeAlsoSections.first, "This symbol was automatically curated and shouldn't have a See Also section")
        }
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/SideKit/SideClassTen", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            XCTAssertNil(renderNode.seeAlsoSections.first, "This symbol was automatically curated and shouldn't have a See Also section")
        }
    }
    
    func testTopLevelSymbolsAreNotAutomaticallyCuratedIfManuallyCuratedElsewhere() async throws {
        // A symbol graph that defines symbol hierarchy of:
        //   TestBed -> A
        //           -> B -> C
        // But curation as:
        //   TestBed -> A -> B -> C
        let topLevelCurationSGFURL = Bundle.module.url(
            forResource: "TopLevelCuration.symbols", withExtension: "json", subdirectory: "Test Resources")!
        
        // Create a test bundle copy with the symbol graph from above
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", excludingPaths: []) { url in
            try? FileManager.default.copyItem(at: topLevelCurationSGFURL, to: url.appendingPathComponent("TopLevelCuration.symbols.json"))
        }

        do {
            // Get the framework render node
            let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/TestBed", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // Verify that `B` isn't automatically curated under the framework node
            XCTAssertEqual(
                ["doc://org.swift.docc.example/documentation/TestBed/A"],
                renderNode.topicSections.first?.identifiers
            )
        }
        
        do {
            // Get the `A` render node
            let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/TestBed/A", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, identifier: node.reference)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // Verify that `B` was in fact curated under `A`
            XCTAssertEqual(
                ["doc://org.swift.docc.example/documentation/TestBed/B"],
                renderNode.topicSections.first?.identifiers
            )
        }
    }

    func testNoAutoCuratedMixedLanguageDuplicates() async throws {
        let (_, bundle, context) = try await testBundleAndContext(copying: "MixedLanguageFramework") { url in

            // Load the existing Obj-C symbol graph from this fixture.
            let path = "symbol-graphs/clang/MixedLanguageFramework.symbols.json"
            var graph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: url.appendingPathComponent(path)))

            // Add an Objective-C relationship between MixedLanguageClassConformingToProtocol.mixedLanguageMethod
            // and the protocol requirement: MixedLanguageProtocol.mixedLanguageMethod. This matches an existing
            // Swift relationship, causing duplicate memberOf relationships.
            var relationship = SymbolGraph.Relationship(
                source: "c:@CM@TestFramework@objc(cs)MixedLanguageClassConformingToProtocol(im)mixedLanguageMethod",
                target: "c:@M@TestFramework@objc(cs)MixedLanguageClassConformingToProtocol",
                kind: .memberOf,
                targetFallback: nil
            )
            relationship.mixins["sourceOrigin"] = SymbolKit.SymbolGraph.Relationship.SourceOrigin(
                identifier: "c:@M@TestFramework@objc(pl)MixedLanguageProtocol(im)mixedLanguageMethod",
                displayName: "MixedLanguageProtocol.mixedLanguageMethod()"
            )
            graph.relationships.append(relationship)
            let newGraphData = try JSONEncoder().encode(graph)
            try newGraphData.write(to: url.appendingPathComponent("symbol-graphs/clang/MixedLanguageFramework.symbols.json"))
        }

        // Load the "MixedLanguageProtocol Implementations" API COllection
        let protocolImplementationsNode = try context.entity(
            with: ResolvedTopicReference(
                bundleID: bundle.id,
                path: "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/MixedLanguageProtocol-Implementations",
                sourceLanguages: [.swift, .objectiveC]
            )
        )

        // This page should contain an auto-curated "Instance Methods" task group.
        let protocolImplementationsArticle = try XCTUnwrap(protocolImplementationsNode.semantic as? Article)
        XCTAssertEqual(1, protocolImplementationsArticle.automaticTaskGroups.count)
        let instanceMethodsTaskGroup = protocolImplementationsArticle.automaticTaskGroups.first!
        XCTAssertEqual("Instance Methods", instanceMethodsTaskGroup.title)

        // And this task group should contain only one reference, to a combined Swift/Obj-C child node.
        XCTAssertEqual(1, instanceMethodsTaskGroup.references.count)
        let ref = instanceMethodsTaskGroup.references.first!
        XCTAssertEqual(
            "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/mixedLanguageMethod()",
            ref.absoluteString
        )
    }

    func testRelevantLanguagesAreAutoCuratedInMixedLanguageFramework() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "MixedLanguageFramework")
        
        let frameworkDocumentationNode = try context.entity(
            with: ResolvedTopicReference(
                bundleID: bundle.id,
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
                // Because this is top-level type is curated under the _member_ of another type, it's not removed from automatic curation.
                "Type Aliases",
                "/documentation/MixedLanguageFramework/Foo-c.typealias",
                
                "Enumerations",
                "/documentation/MixedLanguageFramework/Foo-swift.struct",
            ]
        )
    }

    func testIvarsAndMacrosAreCuratedProperly() async throws {
        let whatsitSymbols = Bundle.module.url(
            forResource: "Whatsit-Objective-C.symbols", withExtension: "json", subdirectory: "Test Resources")!

        let (bundleURL, bundle, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests") { url in
            try? FileManager.default.copyItem(at: whatsitSymbols, to: url.appendingPathComponent("Whatsit-Objective-C.symbols.json"))
        }
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        let frameworkDocumentationNode = try context.entity(
            with: ResolvedTopicReference(
                bundleID: bundle.id,
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
                bundleID: bundle.id,
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

    func testTypeSubscriptsAreCuratedProperly() async throws {
        let symbolURL = Bundle.module.url(
            forResource: "TypeSubscript.symbols", withExtension: "json", subdirectory: "Test Resources")!

        let (bundleURL, bundle, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests") { url in
            try? FileManager.default.copyItem(at: symbolURL, to: url.appendingPathComponent("TypeSubscript.symbols.json"))
        }
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        let containerDocumentationNode = try context.entity(
            with: ResolvedTopicReference(
                bundleID: bundle.id,
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

    func testCPlusPlusSymbolsAreCuratedProperly() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "CxxSymbols")

        let rootDocumentationNode = try context.entity(
            with: .init(
                bundleID: bundle.id,
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
    func testSampleCodeArticlesRespectManualCuration() async throws {
        let renderNode = try await renderNode(atPath: "/documentation/SomeSample", fromTestBundleNamed: "SampleBundle")
        
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

    func testOverloadedSymbolsAreCuratedUnderGroup() async throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let protocolRenderNode = try await renderNode(
            atPath: "/documentation/ShapeKit/OverloadedProtocol",
            fromTestBundleNamed: "OverloadedSymbols")

        guard protocolRenderNode.topicSections.count == 1, let protocolTopicSection = protocolRenderNode.topicSections.first else {
            XCTFail("Expected to find 1 topic section, found \(protocolRenderNode.topicSections.count): \(protocolRenderNode.topicSections.map(\.title?.singleQuoted))")
            return
        }

        XCTAssertEqual(protocolTopicSection.title, "Instance Methods")
        XCTAssertEqual(protocolTopicSection.identifiers, [
            "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)"
        ])

        let overloadGroupRenderNode = try await renderNode(
            atPath: "/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)",
            fromTestBundleNamed: "OverloadedSymbols")

        XCTAssertEqual(
            overloadGroupRenderNode.topicSections.count, 0,
            "Expected no topic sections, found \(overloadGroupRenderNode.topicSections.map(\.title?.singleQuoted))"
        )
    }

    func testAutomaticCurationHandlesOverloadsWithLanguageFilters() async throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let (bundle, context) = try await testBundleAndContext(named: "OverloadedSymbols")

        let protocolDocumentationNode = try context.entity(
            with: .init(
                bundleID: bundle.id,
                path: "/documentation/ShapeKit/OverloadedProtocol",
                sourceLanguage: .swift))

        func assertAutomaticCuration(
            variants: Set<DocumentationDataVariantsTrait>,
            file: StaticString = #filePath,
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
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)"
            ], file: file, line: line)
        }

        // AutomaticCuration uses a different method for collecting child nodes when the variant
        // traits set is empty and when it's not. Ensure that in both cases, we only see the
        // overload group symbol curated under the protocol symbol.
        try assertAutomaticCuration(variants: [])
        try assertAutomaticCuration(variants: [.swift])
    }

    func testAutomaticCurationDropsOverloadGroupWhenOverloadsAreCurated() async throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let (_, bundle, context) = try await testBundleAndContext(copying: "OverloadedSymbols") { url in
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
                bundleID: bundle.id,
                path: "/documentation/ShapeKit/OverloadedProtocol",
                sourceLanguage: .swift))

        // Compile the render node to flex the automatic curator
        let symbol = protocolDocumentationNode.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, identifier: protocolDocumentationNode.reference)
        let renderNode = translator.visit(symbol) as! RenderNode

        XCTAssertEqual(renderNode.topicSections.count, 2)

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
        
        let defaultTopic = try XCTUnwrap(renderNode.topicSections.last)
        XCTAssertEqual(defaultTopic.title, "Instance Methods")
        XCTAssertEqual(defaultTopic.identifiers, [
            "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)",
        ])
    }
    
    func testCuratingTopLevelSymbolUnderModuleStopsAutomaticCuration() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["FirstClass"]),
                makeSymbol(id: "second-symbol-id", kind: .class, pathComponents: ["SecondClass"]),
            ])),
            
            TextFile(name: "ModuleExtension.md", utf8Content: """
            # ``Something``
            
            ## Topics
            - ``SecondClass``
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let firstNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass")])
        XCTAssert(firstNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        
        let secondNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("SecondClass")])
        XCTAssertFalse(secondNode.shouldAutoCurateInCanonicalLocation, "This symbol is manually curated under its module")
    }
    
    func testCuratingTopLevelSymbolUnderAPICollectionInModuleStopsAutomaticCuration() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["FirstClass"]),
                makeSymbol(id: "second-symbol-id", kind: .class, pathComponents: ["SecondClass"]),
            ])),
            
            TextFile(name: "API Collection.md", utf8Content: """
            # Some API collection
            
            ## Topics
            - ``SecondClass``
            """),
            
            TextFile(name: "ModuleExtension.md", utf8Content: """
            # ``Something``
            
            ## Topics
            - <doc:API-Collection>
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let firstNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass")])
        XCTAssert(firstNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        
        let secondNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("SecondClass")])
        XCTAssertFalse(secondNode.shouldAutoCurateInCanonicalLocation, "This symbol is manually curated under an API collection under its module")
        
        let apiCollectionNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("API-Collection")])
        XCTAssertFalse(apiCollectionNode.shouldAutoCurateInCanonicalLocation, "Any curation of non-symbols stops automatic curation")
    }
    
    func testCuratingTopLevelSymbolUnderOtherTopLevelSymbolStopsAutomaticCuration() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["FirstClass"]),
                makeSymbol(id: "second-symbol-id", kind: .class, pathComponents: ["SecondClass"]),
            ])),
            
            TextFile(name: "SymbolExtension.md", utf8Content: """
            # ``Something/FirstClass``
            
            ## Topics
            - ``SecondClass``
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let firstNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass")])
        XCTAssert(firstNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        
        let secondNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("SecondClass")])
        XCTAssertFalse(secondNode.shouldAutoCurateInCanonicalLocation, "Curating a top-level symbol under another top-level symbol stops automatic curation")
    }
    
    func testCuratingTopLevelSymbolUnderOtherTopLevelSymbolAPICollectionStopsAutomaticCuration() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["FirstClass"]),
                makeSymbol(id: "second-symbol-id", kind: .class, pathComponents: ["SecondClass"]),
            ])),
            
            TextFile(name: "API Collection.md", utf8Content: """
            # Some API collection
            
            ## Topics
            - ``SecondClass``
            """),
            
            TextFile(name: "SymbolExtension.md", utf8Content: """
            # ``Something/FirstClass``
            
            ## Topics
            - <doc:API-Collection>
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let firstNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass")])
        XCTAssert(firstNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        
        let secondNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("SecondClass")])
        XCTAssertFalse(secondNode.shouldAutoCurateInCanonicalLocation, "Curating a top-level symbol under another top-level symbol's API collection stops automatic curation")
    }
    
    func testCuratingTopLevelSymbolUnderDeeperThanTopLevelDoesNotStopAutomaticCuration() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["FirstClass"]),
                makeSymbol(id: "first-member-symbol-id", kind: .func, pathComponents: ["FirstClass", "firstMember"]),
                makeSymbol(id: "second-symbol-id", kind: .class, pathComponents: ["SecondClass"]),
            ], relationships: [
                .init(source: "first-member-symbol-id", target: "first-symbol-id", kind: .memberOf, targetFallback: nil),
            ])),
            
            TextFile(name: "SymbolExtension.md", utf8Content: """
            # ``FirstClass/firstMember``
            
            ## Topics
            - ``SecondClass``
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let firstNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass")])
        XCTAssert(firstNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        let memberNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass/firstMember")])
        XCTAssert(memberNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        
        let secondNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("SecondClass")])
        XCTAssert(secondNode.shouldAutoCurateInCanonicalLocation, "Curating a top-level symbol deeper than top-level doesn't stops automatic curation")
    }
    
    func testCuratingMemberOutsideCanonicalContainerDoesNotStopAutomaticCuration() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["FirstClass"]),
                makeSymbol(id: "first-member-symbol-id", kind: .func, pathComponents: ["FirstClass", "firstMember"]),
            ], relationships: [
                .init(source: "first-member-symbol-id", target: "first-symbol-id", kind: .memberOf, targetFallback: nil),
            ])),
            
            TextFile(name: "SymbolExtension.md", utf8Content: """
            # ``Something``
            
            ## Topics
            - ``FirstClass/firstMember``
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let firstNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass")])
        XCTAssert(firstNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        
        let memberNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass/firstMember")])
        XCTAssert(memberNode.shouldAutoCurateInCanonicalLocation, "Curation of member outside its canonical container's hierarchy doesn't stop automatic curation")
    }
    
    func testCuratingMemberUnderAPICollectionOutsideCanonicalContainerDoesNotStopAutomaticCuration() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["FirstClass"]),
                makeSymbol(id: "first-member-symbol-id", kind: .func, pathComponents: ["FirstClass", "firstMember"]),
            ], relationships: [
                .init(source: "first-member-symbol-id", target: "first-symbol-id", kind: .memberOf, targetFallback: nil),
            ])),
            
            TextFile(name: "API Collection.md", utf8Content: """
            # Some API collection
            
            ## Topics
            - ``FirstClass/firstMember``
            """),
            
            TextFile(name: "ModuleExtension.md", utf8Content: """
            # ``Something``
            
            ## Topics
            - <doc:API-Collection>
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let firstNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass")])
        XCTAssert(firstNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        
        let memberNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass/firstMember")])
        XCTAssert(memberNode.shouldAutoCurateInCanonicalLocation, "Curation of member outside its canonical container's hierarchy doesn't stop automatic curation")
    }
    
    func testCuratingMemberInCanonicalContainerStopsAutomaticCuration() async throws {
        let outerContainerID = "outer-container-symbol-id"
        let innerContainerID = "inner-container-symbol-id"
        let memberID = "some-member-symbol-id"
        
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: outerContainerID,  kind: .class, pathComponents: ["FirstClass"]),
                makeSymbol(id: memberID,          kind: .func,  pathComponents: ["FirstClass", "firstMember"]),
            ], relationships: [
                .init(source: innerContainerID, target: outerContainerID, kind: .memberOf, targetFallback: nil),
                .init(source: memberID,         target: outerContainerID, kind: .memberOf, targetFallback: nil),
            ])),
            
            TextFile(name: "SymbolExtension.md", utf8Content: """
            # ``FirstClass``
            
            ## Topics
            - ``FirstClass/firstMember``
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let firstNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass")])
        XCTAssert(firstNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        
        let memberNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass/firstMember")])
        XCTAssertFalse(memberNode.shouldAutoCurateInCanonicalLocation)
    }
    
    func testCuratingMemberInLevelsOfAPICollectionsStopsAutomaticCuration() async throws {
        let outerContainerID = "outer-container-symbol-id"
        let innerContainerID = "inner-container-symbol-id"
        let memberID = "some-member-symbol-id"
        
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: outerContainerID,  kind: .class, pathComponents: ["FirstClass"]),
                makeSymbol(id: memberID,          kind: .func,  pathComponents: ["FirstClass", "firstMember"]),
            ], relationships: [
                .init(source: innerContainerID, target: outerContainerID, kind: .memberOf, targetFallback: nil),
                .init(source: memberID,         target: outerContainerID, kind: .memberOf, targetFallback: nil),
            ])),
            
            TextFile(name: "API Collection 1.md", utf8Content: """
            # First API collection
            
            ## Topics
            - <doc:API-Collection-2>
            """),
            
            TextFile(name: "API Collection 2.md", utf8Content: """
            # Second API collection
            
            ## Topics
            - ``FirstClass/firstMember``
            """),
            
            TextFile(name: "SymbolExtension.md", utf8Content: """
            # ``FirstClass``
            
            ## Topics
            - <doc:API-Collection-1>
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let firstNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass")])
        XCTAssert(firstNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        
        let memberNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass/firstMember")])
        XCTAssertFalse(memberNode.shouldAutoCurateInCanonicalLocation)
    }
    
    func testCuratingMemberUnderOtherMemberDoesNotStopAutomaticCuration() async throws {
        let outerContainerID = "outer-container-symbol-id"
        let innerContainerID = "inner-container-symbol-id"
        let memberID = "some-member-symbol-id"
        
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: outerContainerID,  kind: .class, pathComponents: ["OuterClass"]),
                makeSymbol(id: innerContainerID,  kind: .class, pathComponents: ["OuterClass", "InnerClass"]),
                makeSymbol(id: memberID,          kind: .func,  pathComponents: ["OuterClass", "someMember"]),
            ], relationships: [
                .init(source: innerContainerID, target: outerContainerID, kind: .memberOf, targetFallback: nil),
                .init(source: memberID,         target: outerContainerID, kind: .memberOf, targetFallback: nil),
            ])),
            
            TextFile(name: "SymbolExtension.md", utf8Content: """
            # ``OuterClass/InnerClass``
            
            ## Topics
            - ``OuterClass/someMember``
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        
        let outerNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("OuterClass")])
        XCTAssert(outerNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        let innerNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("OuterClass/InnerClass")])
        XCTAssert(innerNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        
        let memberNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("OuterClass/someMember")])
        XCTAssert(memberNode.shouldAutoCurateInCanonicalLocation, "Curating a member under another member doesn't stop automatic curation")
    }
    
    func testCuratingArticleAnywhereStopAutomaticCuration() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["FirstClass"]),
                makeSymbol(id: "first-member-symbol-id", kind: .func, pathComponents: ["FirstClass", "firstMember"]),
                makeSymbol(id: "second-symbol-id", kind: .class, pathComponents: ["SecondClass"]),
            ], relationships: [
                .init(source: "first-member-symbol-id", target: "first-symbol-id", kind: .memberOf, targetFallback: nil),
            ])),
            
            TextFile(name: "MemberExtension.md", utf8Content: """
            # ``FirstClass/firstMember``
            
            ## Topics
            - <doc:SecondArticle>
            """),
            
            TextFile(name: "FirstArticle.md", utf8Content: """
            # First article
            """),
            
            TextFile(name: "SecondArticle.md", utf8Content: """
            # First article
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let firstNode  = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass")])
        XCTAssert(firstNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        let memberNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstClass/firstMember")])
        XCTAssert(memberNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        let firstArticleNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("FirstArticle")])
        XCTAssert(firstArticleNode.shouldAutoCurateInCanonicalLocation, "This symbol is never manually curated")
        
        let secondArticleNode = try XCTUnwrap(context.topicGraph.nodes[moduleReference.appendingPath("SecondArticle")])
        XCTAssertFalse(secondArticleNode.shouldAutoCurateInCanonicalLocation)
    }
    
    func testAutomaticallyCuratedSymbolTopicsAreMergedWithManuallyCuratedTopics() async throws {
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
             let (_, _, context) = try await loadBundle(from: catalogURL)

             let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/ModuleName/SomeClass", sourceLanguage: .swift))

             // Compile docs and verify the generated Topics section
             var translator = RenderNodeTranslator(context: context, identifier: node.reference)
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

    func testAutomaticallyCuratedArticlesAreSortedByTitle() async throws {
        // Test bundle with articles where file names and titles are in different orders
        let catalog = Folder(name: "TestBundle.docc", content: [
            JSONFile(name: "TestModule.symbols.json", content: makeSymbolGraph(moduleName: "TestModule")),
            
            TextFile(name: "C-Article.md", utf8Content: """
            # A Article
            """),
            
            TextFile(name: "B-Article.md", utf8Content: """
            # B Article
            """),
            
            TextFile(name: "A-Article.md", utf8Content: """
            # C Article
            """),
        ])
        
        // Load the bundle
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        // Get the module and its automatic curation groups
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let moduleNode = try XCTUnwrap(context.entity(with: moduleReference))
        let symbol = try XCTUnwrap(moduleNode.semantic as? Symbol)
        let articlesGroup = try XCTUnwrap(
            symbol.automaticTaskGroups.first(where: { $0.title == "Articles" }),
            "Expected 'Articles' automatic task group"
        )
        
        // Get the titles of the articles in the order they appear in the automatic curation
        let titles = articlesGroup.references.compactMap { 
            context.topicGraph.nodes[$0]?.title
        }
        
        // Verify we have 3 articles in title order (A, B, C)—file order does not matter
        XCTAssertEqual(titles, ["A Article", "B Article", "C Article"], 
                      "Articles should be sorted by title, not by file name")
    }

    // autoCuratedArticles are sorted by title in a case-insensitive manner
    // this test verifies that the sorting is correct even when the file names have different cases
    func testAutomaticallyCuratedArticlesAreSortedByTitleDifferentCases() async throws {

        // In the catalog, the articles are named with the same letter, different cases,
        // and other articles are added as well
        let catalog = Folder(name: "TestBundle.docc", content: [
            JSONFile(name: "TestModule.symbols.json", content: makeSymbolGraph(moduleName: "TestModule")),

            TextFile(name: "C-article.md", utf8Content: """
            # C Article
            """),

            TextFile(name: "c-article-2.md", utf8Content: """
            # c Article2
            """),

            TextFile(name: "A-article.md", utf8Content: """
            # A Article
            """),

            TextFile(name: "a-article-2.md", utf8Content: """
            # a Article2
            """),

            TextFile(name: "B-article.md", utf8Content: """
            # B Article
            """),

            TextFile(name: "b-article-2.md", utf8Content: """
            # b Article2
            """),

            TextFile(name: "k-article.md", utf8Content: """
            # k Article
            """),
            
            TextFile(name: "random-article.md", utf8Content: """
            # Z Article
            """),
        ])

        // Load the bundle
        let (_, context) = try await loadBundle(catalog: catalog)
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        // Get the module and its automatic curation groups
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        let moduleNode = try XCTUnwrap(context.entity(with: moduleReference))
        let symbol = try XCTUnwrap(moduleNode.semantic as? Symbol)
        let articlesGroup = try XCTUnwrap(
            symbol.automaticTaskGroups.first(where: { $0.title == "Articles" }),
            "Expected 'Articles' automatic task group"
        )

        let titles = articlesGroup.references.compactMap { 
            context.topicGraph.nodes[$0]?.title
        }

        // Verify that the articles are sorted by title, not by file name
        XCTAssertEqual(titles, ["A Article", "a Article2", "B Article", "b Article2", "C Article", "c Article2", "k Article", "Z Article"], 
                      "Articles should be sorted by title, not by file name")
    }
}
