/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SymbolKit
import Markdown
@testable import SwiftDocC

class RenderNodeTranslatorSymbolVariantsTests: XCTestCase {
    
    func testIdentifierVariants() throws {
        try assertMultiVariantSymbol(
            configureContext: { context, resolvedTopicReference in
                var documentationNode = try XCTUnwrap(context.documentationCache[resolvedTopicReference])
                documentationNode.availableSourceLanguages = [.swift, .objectiveC]
                context.documentationCache[resolvedTopicReference] = documentationNode
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.identifier.sourceLanguage.id, "swift")
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.identifier.sourceLanguage.id, "occ")
            }
        )
    }
    
    func testMultipleModules() throws {
        try assertMultiVariantSymbol(
            configureContext: { context, resolvedTopicReference in
                let moduleReference = ResolvedTopicReference(bundleIdentifier: resolvedTopicReference.bundleIdentifier, path: "/documentation/MyKit", sourceLanguage: .swift)
                context.documentationCache[moduleReference]?.name = .conceptual(title: "Custom Module Title")
                context.preResolveModuleNames()
            },
            assertOriginalRenderNode: { renderNode in
                try assertModule(renderNode.metadata.modules, expectedName: "Custom Module Title")
            },
            assertAfterApplyingVariant: { renderNode in
                try assertModule(renderNode.metadata.modules, expectedName: "Custom Module Title")
            }
        )
    }
    
    func testMultipleModulesWithBystanderModule() throws {
        try assertMultiVariantSymbol(
            configureContext: { context, resolvedTopicReference in
                let moduleReference = ResolvedTopicReference(bundleIdentifier: resolvedTopicReference.bundleIdentifier, path: "/documentation/MyKit", sourceLanguage: .swift)
                context.documentationCache[moduleReference]?.name = .conceptual(title: "Custom Module Title")
                context.preResolveModuleNames()
            },
            configureSymbol: { symbol in
                symbol.crossImportOverlayModule = ("Custom Module Title", ["Custom Bystander Title"])
            },
            assertOriginalRenderNode: { renderNode in
                try assertModule(
                    renderNode.metadata.modules,
                    expectedName: "Custom Module Title",
                    expectedRelatedModules: ["Custom Bystander Title"]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                try assertModule(
                    renderNode.metadata.modules,
                    expectedName: "Custom Module Title",
                    expectedRelatedModules: ["Custom Bystander Title"]
                )
            }
        )
    }

    /// Make sure that when a symbol has `crossImportOverlayModule` information, that module name is used instead of its `moduleReference`.
    func testMultipleModulesWithDifferentBystanderModule() throws {
        try assertMultiVariantSymbol(
            configureContext: { context, resolvedTopicReference in
                let moduleReference = ResolvedTopicReference(bundleIdentifier: resolvedTopicReference.bundleIdentifier, path: "/documentation/MyKit", sourceLanguage: .swift)
                context.documentationCache[moduleReference]?.name = .conceptual(title: "Extended Module Title")
                context.preResolveModuleNames()
            },
            configureSymbol: { symbol in
                symbol.crossImportOverlayModule = ("Custom Module Title", ["Custom Bystander Title"])
            },
            assertOriginalRenderNode: { renderNode in
                try assertModule(
                    renderNode.metadata.modules,
                    expectedName: "Custom Module Title",
                    expectedRelatedModules: ["Custom Bystander Title"]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                try assertModule(
                    renderNode.metadata.modules,
                    expectedName: "Custom Module Title",
                    expectedRelatedModules: ["Custom Bystander Title"]
                )
            }
        )
    }
    
    func testExtendedModuleVariants() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.extendedModule = "Custom Title"
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.metadata.extendedModule, "Custom Title")
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.metadata.extendedModule, "Custom Title")
            }
        )
    }
    
    func testPlatformsVariantsDefaultAvailability() throws {
        try assertMultiVariantSymbol(
            configureContext: { context, resolvedTopicReference in
                let moduleReference = ResolvedTopicReference(bundleIdentifier: resolvedTopicReference.bundleIdentifier, path: "/documentation/MyKit", sourceLanguage: .swift)
                context.documentationCache[moduleReference]?.name = .conceptual(title: "Custom Module Title")
                context.preResolveModuleNames()
            },
            configureSymbol: { symbol in
                // no configuration changes
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssert(renderNode.metadata.platforms?.isEmpty == false)
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssert(renderNode.metadata.platforms?.isEmpty == false)
            }
        )
    }
    
    func testPlatformsVariantsCustomAvailability() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.availabilityVariants[.swift] = SymbolGraph.Symbol.Availability(availability: [
                    SymbolGraph.Symbol.Availability.AvailabilityItem(
                        domain: nil,
                        introducedVersion: SymbolGraph.SemanticVersion(string: "1.0"),
                        deprecatedVersion: nil,
                        obsoletedVersion: nil,
                        message: nil,
                        renamed: "Swift renamed",
                        isUnconditionallyDeprecated: false,
                        isUnconditionallyUnavailable: false,
                        willEventuallyBeDeprecated: true
                    )
                ])
                
                symbol.availabilityVariants[.objectiveC] = SymbolGraph.Symbol.Availability(availability: [
                    SymbolGraph.Symbol.Availability.AvailabilityItem(
                        domain: nil,
                        introducedVersion: SymbolGraph.SemanticVersion(string: "2.0"),
                        deprecatedVersion: nil,
                        obsoletedVersion: nil,
                        message: nil,
                        renamed: "Objective-C renamed",
                        isUnconditionallyDeprecated: false,
                        isUnconditionallyUnavailable: false,
                        willEventuallyBeDeprecated: true
                    )
                ])
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.metadata.platforms?.first?.introduced, "1.0")
                XCTAssertEqual(renderNode.metadata.platforms?.first?.renamed, "Swift renamed")
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.metadata.platforms?.first?.introduced, "2.0")
                XCTAssertEqual(renderNode.metadata.platforms?.first?.renamed, "Objective-C renamed")
            }
        )
    }
    
    func testRequiredVariants() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.isRequiredVariants[.swift] = false
                symbol.isRequiredVariants[.objectiveC] = true
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.metadata.required, false)
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.metadata.required, true)
            }
        )
    }
    
    func testRoleHeadingVariants() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.roleHeadingVariants[.swift] = "Swift Title"
                symbol.roleHeadingVariants[.objectiveC] = "Objective-C Title"
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.metadata.roleHeading, "Swift Title")
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.metadata.roleHeading, "Objective-C Title")
            }
        )
    }
    
    func testTitleVariants() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.titleVariants[.swift] = "Swift Title"
                symbol.titleVariants[.objectiveC] = "Objective-C Title"
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.metadata.title, "Swift Title")
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.metadata.title, "Objective-C Title")
            }
        )
    }
    
    func testExternalIDVariants() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.roleHeadingVariants[.swift] = "Swift Title"
                symbol.roleHeadingVariants[.objectiveC] = "Objective-C Title"
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.metadata.roleHeading, "Swift Title")
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.metadata.roleHeading, "Objective-C Title")
            }
        )
    }
    
    func testSymbolKindVariants() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.kindVariants[.swift] = .init(rawIdentifier: "swift.method", displayName: "Swift Kind")
                symbol.kindVariants[.objectiveC] = .init(rawIdentifier: "objc.func", displayName: "Objective-C Kind")
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.metadata.symbolKind, "method")
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.metadata.symbolKind, "func")
            }
        )
    }
    
    func testFragmentsVariants() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.subHeadingVariants[.swift] = [
                    .init(kind: .keyword, spelling: "swift", preciseIdentifier: nil)
                ]
                
                symbol.subHeadingVariants[.objectiveC] = [
                    .init(kind: .keyword, spelling: "objc", preciseIdentifier: nil)
                ]
                
                symbol.titleVariants[.swift] = "Swift Title"
                symbol.titleVariants[.objectiveC] = "Objective-C Title"
                
                symbol.kindVariants[.swift] = .init(rawIdentifier: "swift.method", displayName: "Swift Kind")
                symbol.kindVariants[.objectiveC] = .init(rawIdentifier: "objc.func", displayName: "Objective-C Kind")
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(
                    renderNode.metadata.fragments,
                    [.init(text: "swift", kind: .keyword, identifier: nil, preciseIdentifier: nil)]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(
                    renderNode.metadata.fragments,
                    [.init(text: "objc", kind: .keyword, identifier: nil, preciseIdentifier: nil)]
                )
            }
        )
    }
    
    func testNavigatorTitleVariants() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.navigatorVariants[.swift] = [
                    .init(kind: .keyword, spelling: "swift", preciseIdentifier: nil)
                ]
                
                symbol.navigatorVariants[.objectiveC] = [
                    .init(kind: .keyword, spelling: "objc", preciseIdentifier: nil)
                ]
                
                symbol.titleVariants[.swift] = "Swift Title"
                symbol.titleVariants[.objectiveC] = "Objective-C Title"
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(
                    renderNode.metadata.navigatorTitle,
                    [.init(text: "swift", kind: .keyword, identifier: nil, preciseIdentifier: nil)]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(
                    renderNode.metadata.navigatorTitle,
                    [.init(text: "objc", kind: .keyword, identifier: nil, preciseIdentifier: nil)]
                )
            }
        )
    }
    
    func testVariants() throws {
        let expectedVariants = [
            RenderNode.Variant(
                traits: [.interfaceLanguage("swift")],
                paths: ["/documentation/mykit/myclass"]
            ),
            RenderNode.Variant(
                traits: [.interfaceLanguage("occ")],
                paths: ["/documentation/mykit/myclass"]
            ),
        ]
        
        try assertMultiVariantSymbol(
            configureContext: { context, resolvedTopicReference in
                var documentationNode = try XCTUnwrap(context.documentationCache[resolvedTopicReference])
                documentationNode.availableSourceLanguages = [.swift, .objectiveC]
                context.documentationCache[resolvedTopicReference] = documentationNode
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.variants, expectedVariants)
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.variants, expectedVariants)
            }
        )
    }
    
    func testAbstractVariants() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.abstractSectionVariants[.swift] = AbstractSection(
                    paragraph: Paragraph(Text("Swift abstract"))
                )
                
                symbol.abstractSectionVariants[.objectiveC] = AbstractSection(
                    paragraph: Paragraph(Text("Objective-C abstract"))
                )
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.abstract, [.text("Swift abstract")])
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.abstract, [.text("Objective-C abstract")])
            }
        )
    }
    
    func testDeclarationsSectionVariants() throws {
        func declarationSection(in renderNode: RenderNode) throws -> DeclarationRenderSection {
            try XCTUnwrap(
                (renderNode.primaryContentSections.first as? DeclarationsRenderSection)?.declarations.first
            )
        }
        
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.declarationVariants[.swift] = [
                    [.macOS]: SymbolGraph.Symbol.DeclarationFragments(
                        declarationFragments: [.init(kind: .keyword, spelling: "swift", preciseIdentifier: nil)]
                    )
                ]
                
                symbol.declarationVariants[.objectiveC] = [
                    [.iOS]: SymbolGraph.Symbol.DeclarationFragments(
                        declarationFragments: [.init(kind: .keyword, spelling: "objc", preciseIdentifier: nil)]
                    )
                ]
            },
            assertOriginalRenderNode: { renderNode in
                let declarationSection = try declarationSection(in: renderNode)
                XCTAssertEqual(declarationSection.platforms, [.macOS])
                
                XCTAssertEqual(
                    declarationSection.tokens,
                    [.init(text: "swift", kind: .keyword, identifier: nil, preciseIdentifier: nil)]
                )
                
                XCTAssertEqual(declarationSection.languages, ["swift"])
            },
            assertAfterApplyingVariant: { renderNode in
                let declarationSection = try declarationSection(in: renderNode)
                XCTAssertEqual(declarationSection.platforms, [.iOS])
                
                XCTAssertEqual(
                    declarationSection.tokens,
                    [.init(text: "objc", kind: .keyword, identifier: nil, preciseIdentifier: nil)]
                )
                
                XCTAssertEqual(declarationSection.languages, ["occ"])
            }
        )
    }
    
    func testReturnsSectionVariants() throws {
        func returnsSection(in renderNode: RenderNode) throws -> ContentRenderSection {
            let returnsSectionIndex = 1
            
            guard renderNode.primaryContentSections.indices.contains(returnsSectionIndex) else {
                XCTFail("Missing returns section")
                return ContentRenderSection(kind: .content, content: [], heading: nil)
            }
            
            return try XCTUnwrap(renderNode.primaryContentSections[returnsSectionIndex] as? ContentRenderSection)
        }
        
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.returnsSectionVariants[.swift] = ReturnsSection(
                    content: [Paragraph(Text("Swift Returns Section"))]
                )
                
                symbol.returnsSectionVariants[.objectiveC] = ReturnsSection(
                    content: [Paragraph(Text("Objective-C Returns Section"))]
                )
            },
            assertOriginalRenderNode: { renderNode in
                let returnsSection = try returnsSection(in: renderNode)
                XCTAssertEqual(
                    returnsSection.content,
                    [
                        .heading(.init(level: 2, text: "Return Value", anchor: "return-value")),
                        .paragraph(.init(inlineContent: [.text("Swift Returns Section")]))
                    ]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                let returnsSection = try returnsSection(in: renderNode)
                XCTAssertEqual(
                    returnsSection.content,
                    [
                        .heading(.init(level: 2, text: "Return Value", anchor: "return-value")),
                        .paragraph(.init(inlineContent: [.text("Objective-C Returns Section")]))
                    ]
                )
            }
        )
   }
    
    func testParametersSectionVariants() throws {
        func parametersSection(in renderNode: RenderNode) throws -> ParametersRenderSection {
            let parametersSectionIndex = 1
            
            guard renderNode.primaryContentSections.indices.contains(parametersSectionIndex) else {
                XCTFail("Missing parameters section")
                return ParametersRenderSection(parameters: [])
            }
            
            return try XCTUnwrap(renderNode.primaryContentSections[parametersSectionIndex] as? ParametersRenderSection)
        }
        
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.parametersSectionVariants[.swift] = ParametersSection(
                    parameters: [Parameter(name: "Swift parameter", contents: [])]
                )
                
                symbol.parametersSectionVariants[.objectiveC] = ParametersSection(
                    parameters: [Parameter(name: "Objective-C parameter", contents: [])]
                )
            },
            assertOriginalRenderNode: { renderNode in
                let parametersSection = try parametersSection(in: renderNode)
                
                XCTAssertEqual(parametersSection.parameters.count, 1)
                
                let parameter = try XCTUnwrap(parametersSection.parameters.first)
                XCTAssertEqual(parameter.name, "Swift parameter")
                XCTAssertEqual(parameter.content, [])
            },
            assertAfterApplyingVariant: { renderNode in
                let parametersSection = try parametersSection(in: renderNode)
                
                XCTAssertEqual(parametersSection.parameters.count, 1)
                
                let parameter = try XCTUnwrap(parametersSection.parameters.first)
                XCTAssertEqual(parameter.name, "Objective-C parameter")
                XCTAssertEqual(parameter.content, [])
            }
        )
    }
    
    func testDiscussionSectionVariants() throws {
        func discussionSection(in renderNode: RenderNode) throws -> ContentRenderSection {
            let discussionSectionIndex = 1
            
            guard renderNode.primaryContentSections.indices.contains(discussionSectionIndex) else {
                XCTFail("Missing discussion section")
                return ContentRenderSection(kind: .content, content: [], heading: nil)
            }
            
            return try XCTUnwrap(renderNode.primaryContentSections[discussionSectionIndex] as? ContentRenderSection)
        }
        
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.discussionVariants[.swift] = DiscussionSection(
                    content: [Paragraph(Text("Swift Discussion"))]
                )
                
                symbol.discussionVariants[.objectiveC] = DiscussionSection(
                    content: [Paragraph(Text("Objective-C Discussion"))]
                )
            },
            assertOriginalRenderNode: { renderNode in
                let discussionSection = try discussionSection(in: renderNode)
                
                XCTAssertEqual(
                    discussionSection.content,
                    [
                        .heading(.init(level: 2, text: "Overview", anchor: "overview")),
                        .paragraph(.init(inlineContent: [.text("Swift Discussion")]))
                    ]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                let discussionSection = try discussionSection(in: renderNode)
                
                XCTAssertEqual(
                    discussionSection.content,
                    [
                        .heading(.init(level: 2, text: "Overview", anchor: "overview")),
                        .paragraph(.init(inlineContent: [.text("Objective-C Discussion")]))
                    ]
                )
            }
        )
    }
    
    func testSourceFileURIVariants() throws {
        func makeLocation(uri: String) throws -> SymbolGraph.Symbol.Location {
            let location = """
            {
                "uri": "\(uri)",
                "position": {
                    "line": 0,
                    "character": 0,
                }
            }
            """.data(using: .utf8)!
            
            return try JSONDecoder().decode(SymbolGraph.Symbol.Location.self, from: location)
        }
        
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.locationVariants[.swift] = try makeLocation(uri: "Swift URI")
                symbol.locationVariants[.objectiveC] = try makeLocation(uri: "Objective-C URI")
            },
            configureRenderNodeTranslator: { renderNodeTranslator in
                renderNodeTranslator.shouldEmitSymbolSourceFileURIs = true
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.metadata.sourceFileURI, "Swift URI")
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.metadata.sourceFileURI, "Objective-C URI")
            }
        )
    }
    
    func testSymbolAccessLevelVariants() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.accessLevelVariants[.swift] = "Swift access level"
                symbol.accessLevelVariants[.objectiveC] = "Objective-C access level"
            },
            configureRenderNodeTranslator: { renderNodeTranslator in
                renderNodeTranslator.shouldEmitSymbolAccessLevels = true
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.metadata.symbolAccessLevel, "Swift access level")
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.metadata.symbolAccessLevel, "Objective-C access level")
            }
        )
    }
    
    func testRelationshipSectionsVariants() throws {
        try assertMultiVariantSymbol(
            configureContext: { context, _ in
            
                // Set up an Objective-C title for MyProtocol.
                let myFunctionNode = try context.entity(
                    with: ResolvedTopicReference(
                        bundleIdentifier: "org.swift.docc.example",
                        path: "/documentation/MyKit/MyProtocol",
                        fragment: nil,
                        sourceLanguage: .swift
                    )
                )
                
                let myProtocol = try XCTUnwrap(myFunctionNode.semantic as? Symbol)
                myProtocol.titleVariants[.objectiveC] = "MyProtocol"
            },
            configureSymbol: { symbol in
                symbol.relationshipsVariants[.swift] = makeRelationshipSection(
                    kind: .inheritedBy,
                    path: "/documentation/MyKit/MyClass/myFunction()"
                )
                
                symbol.relationshipsVariants[.objectiveC] = makeRelationshipSection(
                    kind: .conformsTo,
                    path: "/documentation/MyKit/MyProtocol"
                )
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.relationshipSections.count, 1)
                let relationshipSection = try XCTUnwrap(renderNode.relationshipSections.first)
                XCTAssertEqual(relationshipSection.title, "Inherited By")
                
                XCTAssertEqual(
                    relationshipSection.identifiers,
                    ["doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()"]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.relationshipSections.count, 1)
                let relationshipSection = try XCTUnwrap(renderNode.relationshipSections.first)
                XCTAssertEqual(relationshipSection.title, "Conforms To")
                
                XCTAssertEqual(
                    relationshipSection.identifiers,
                    ["doc://org.swift.docc.example/documentation/MyKit/MyProtocol"]
                )
            }
        )
    }
    
    func testDoesNotEmitObjectiveCRelationshipsForTopicThatOnlyHasSwiftRelationships() throws {
        try assertMultiVariantSymbol(
            configureContext: { context, _ in
            
                // Set up an Objective-C title for MyProtocol.
                let myFunctionNode = try context.entity(
                    with: ResolvedTopicReference(
                        bundleIdentifier: "org.swift.docc.example",
                        path: "/documentation/MyKit/MyProtocol",
                        fragment: nil,
                        sourceLanguage: .swift
                    )
                )
                
                let myProtocol = try XCTUnwrap(myFunctionNode.semantic as? Symbol)
                myProtocol.titleVariants[.objectiveC] = "MyProtocol"
            },
            configureSymbol: { symbol in
                symbol.relationshipsVariants[.swift] = makeRelationshipSection(
                    kind: .inheritedBy,
                    path: "/documentation/MyKit/MyClass/myFunction()"
                )
                
                symbol.relationshipsVariants[.objectiveC] = nil
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.relationshipSections.count, 1)
                let relationshipSection = try XCTUnwrap(renderNode.relationshipSections.first)
                XCTAssertEqual(relationshipSection.title, "Inherited By")
                
                XCTAssertEqual(
                    relationshipSection.identifiers,
                    ["doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()"]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssert(renderNode.relationshipSections.isEmpty)
            }
        )
    }
    
    func testTopicsSectionVariants() throws {
        try assertMultiVariantSymbol(
            configureContext: { context, reference in
                try makeSymbolAvailableInSwiftAndObjectiveC(
                    symbolPath: "/documentation/MyKit/MyProtocol",
                    bundleIdentifier: reference.bundleIdentifier,
                    context: context
                )
            },
            configureSymbol: { symbol in
                symbol.automaticTaskGroupsVariants[.swift] = []
                symbol.topicsVariants[.swift] = makeTopicsSection(
                    taskGroupName: "Swift Task Group",
                    destination: "doc://org.swift.docc.example/documentation/MyKit/MyProtocol"
                )
                
                symbol.automaticTaskGroupsVariants[.objectiveC] = []
                symbol.topicsVariants[.objectiveC] = makeTopicsSection(
                    taskGroupName: "Objective-C Task Group",
                    destination: "doc://org.swift.docc.example/documentation/MyKit/MyProtocol"
                )
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.topicSections.count, 3)
                let taskGroup = try XCTUnwrap(renderNode.topicSections.first)
                XCTAssertEqual(taskGroup.title, "Swift Task Group")
                
                XCTAssertEqual(
                    taskGroup.identifiers,
                    ["doc://org.swift.docc.example/documentation/MyKit/MyProtocol"]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.topicSections.count, 1)
                let taskGroup = try XCTUnwrap(renderNode.topicSections.first)
                XCTAssertEqual(taskGroup.title, "Objective-C Task Group")
                
                XCTAssertEqual(
                    taskGroup.identifiers,
                    ["doc://org.swift.docc.example/documentation/MyKit/MyProtocol"]
                )
            }
        )
    }
    
    func testEncodesNilTopicsSectionsForArticleVariantIfDefaultIsNonEmpty() throws {
        try assertMultiVariantArticle(
            configureArticle: { article in
                article.automaticTaskGroups = []
                article.topics = makeTopicsSection(
                    taskGroupName: "Swift Task Group",
                    destination: "doc://org.swift.docc.example/documentation/MyKit/MyProtocol"
                )
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.topicSections.count, 1)
                let taskGroup = try XCTUnwrap(renderNode.topicSections.first)
                XCTAssertEqual(taskGroup.title, "Swift Task Group")
                
                XCTAssertEqual(
                    taskGroup.identifiers,
                    ["doc://org.swift.docc.example/documentation/MyKit/MyProtocol"]
                )
            },
            assertDataAfterApplyingVariant: { renderNodeData in
                // What we want to validate here is that the Objective-C render JSON's `topicSections` is `null` rather
                // than `[]`. Since the `RenderNode` decoder implementation encodes `[]` rather than `nil` into the
                // model when the JSON value is `null` (`topicSections` is not optional in the model), we can't use it
                // for this test. Instead, we decode the JSON using a proxy type that has an optional `topicSections`.
                
                struct RenderNodeProxy: Codable {
                    var topicSections: [TaskGroupRenderSection]?
                }
                
                XCTAssertNil(
                    try JSONDecoder().decode(RenderNodeProxy.self, from: renderNodeData).topicSections,
                    "Expected topicSections to be null in the JSON because the article has no Objective-C topics."
                )
            }
        )
    }
    
    func testEncodesNilTopicsSectionsForSymbolVariantIfDefaultIsNonEmpty() throws {
        try assertMultiVariantSymbol(
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.topicSections.count, 6)
            },
            assertDataAfterApplyingVariant: { renderNodeData in
                // See reasoning for the RenderNodeProxy type in the similar test above.
                
                struct RenderNodeProxy: Codable {
                    var topicSections: [TaskGroupRenderSection]?
                }
                
                XCTAssertNil(
                    try JSONDecoder().decode(RenderNodeProxy.self, from: renderNodeData).topicSections,
                    "Expected topicSections to be null in the JSON because the article has no Objective-C topics."
                )
            }
        )
    }
    
    func testArticleAutomaticTaskGroupsForArticleOnlyIncludeTopicsAvailableInTheArticleLanguage() throws {
        func referenceWithPath(_ path: String) -> ResolvedTopicReference {
            ResolvedTopicReference(
                bundleIdentifier: "org.swift.docc.example",
                path: path,
                fragment: nil,
                sourceLanguage: .swift
            )
        }
        
        try assertMultiVariantArticle(
            configureContext: { context, reference in
                let articleTopicGraphNode = TopicGraph.Node(
                    reference: reference,
                    kind: .article,
                    source: .external,
                    title: "Article"
                )
                
                let myProtocolReference = referenceWithPath("/documentation/MyKit/MyProtocol")
                let myClassReference = referenceWithPath("/documentation/MyKit/MyClass")
                
                let myProtocolTopicGraphNode = TopicGraph.Node(
                    reference: myProtocolReference,
                    kind: .protocol,
                    source: .external,
                    title: "MyProtocol"
                )
                
                let myClassTopicGraphNode = TopicGraph.Node(
                    reference: myClassReference,
                    kind: .protocol,
                    source: .external,
                    title: "MyProtocol"
                )
                
                // Remove MyProtocol and MyClass's parents and make them children of the article instead.
                context.topicGraph.reverseEdges[myProtocolReference] = nil
                context.topicGraph.reverseEdges[myClassReference] = nil
                
                context.topicGraph.addEdge(
                    from: articleTopicGraphNode,
                    to: myProtocolTopicGraphNode
                )
                
                context.topicGraph.addEdge(
                    from: articleTopicGraphNode,
                    to: myClassTopicGraphNode
                )
                
                try makeSymbolAvailableInSwiftAndObjectiveC(
                    symbolPath: "/documentation/MyKit/MyProtocol",
                    bundleIdentifier: reference.bundleIdentifier,
                    context: context
                )
                
                // Add an Objective-C kind to MyProtocol to make it a multi-language symbol.
                try XCTUnwrap(context.documentationCache[myProtocolReference]?.semantic as? Symbol)
                    .kindVariants[.objectiveC] = SymbolGraph.Symbol.Kind(
                        parsedIdentifier: .protocol,
                        displayName: "Protocol"
                    )
            },
            configureArticle: { article in
                article.automaticTaskGroups = []
                article.topics = nil
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(
                    renderNode.topicSections.flatMap { topicSection in
                        [topicSection.title] + topicSection.identifiers
                    },
                    [
                        "Classes",
                        "doc://org.swift.docc.example/documentation/MyKit/MyClass",
                        "Protocols",
                        "doc://org.swift.docc.example/documentation/MyKit/MyProtocol",
                    ]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(
                    renderNode.topicSections.flatMap { topicSection in
                        [topicSection.title] + topicSection.identifiers
                    },
                    [
                        "Protocols",
                        "doc://org.swift.docc.example/documentation/MyKit/MyProtocol",
                    ]
                )
            }
        )
    }
    
    func testTopicsSectionVariantsNoUserProvidedTopics() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.automaticTaskGroupsVariants[.fallback] = []
                symbol.topicsVariants[.fallback] = nil
                
                symbol.automaticTaskGroupsVariants[.swift] = []
                symbol.topicsVariants[.swift] = nil
                
                symbol.automaticTaskGroupsVariants[.objectiveC] = []
                symbol.topicsVariants[.objectiveC] = nil
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.topicSections.count, 2)
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssert(
                    renderNode.topicSections.isEmpty,
                    """
                    Expected no topics section for the Objective-C variant, because there are no Objective-C \
                    relationships.
                    """
                )
            }
        )
    }
    
    func testDefaultImplementationsSectionsVariants() throws {
        func createDefaultImplementationsSection(path: String) -> DefaultImplementationsSection {
            DefaultImplementationsSection(
                targetFallbacks: [:],
                implementations: [
                    Implementation(
                        reference: .successfullyResolved(
                            ResolvedTopicReference(
                                bundleIdentifier: "org.swift.docc.example",
                                path: path,
                                fragment: nil,
                                sourceLanguage: .swift
                            )
                        ),
                        parent: nil,
                        fallbackName: nil
                    )
                ]
            )
        }
        
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.defaultImplementationsVariants[.swift] = createDefaultImplementationsSection(
                    path: "/documentation/MyKit/MyProtocol"
                )
                
                symbol.relationshipsVariants[.swift] = makeRelationshipSection(
                    kind: .inheritedBy,
                    path: "/documentation/MyKit/MyClass/myFunction()"
                )
                
                symbol.defaultImplementationsVariants[.objectiveC] = createDefaultImplementationsSection(
                    path: "/documentation/MyKit/MyClass/myFunction()"
                )
                
                symbol.relationshipsVariants[.objectiveC] = makeRelationshipSection(
                    kind: .conformsTo,
                    path: "/documentation/MyKit/MyProtocol"
                )
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.defaultImplementationsSections.count, 1)
                let defaultImplementationsSection = try XCTUnwrap(renderNode.defaultImplementationsSections.first)
                XCTAssertEqual(defaultImplementationsSection.title, "Implementations")
                XCTAssertEqual(
                    defaultImplementationsSection.identifiers,
                    ["doc://org.swift.docc.example/documentation/MyKit/MyProtocol"]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.defaultImplementationsSections.count, 1)
                let defaultImplementationsSection = try XCTUnwrap(renderNode.defaultImplementationsSections.first)
                XCTAssertEqual(defaultImplementationsSection.title, "Implementations")
                XCTAssertEqual(
                    defaultImplementationsSection.identifiers,
                    ["doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()"]
                )
            }
        )
    }
    
    func testSeeAlsoSectionVariants() throws {
        func makeSeeAlsoSection(destination: String) -> SeeAlsoSection {
            SeeAlsoSection(content: [
                UnorderedList(
                    ListItem(Paragraph(Link(destination: destination)))
                )
            ])
        }
        
        try assertMultiVariantSymbol(
            configureContext: { context, reference in
                try makeSymbolAvailableInSwiftAndObjectiveC(
                    symbolPath: "/documentation/MyKit/MyProtocol",
                    bundleIdentifier: reference.bundleIdentifier,
                    context: context
                )
            },
            configureSymbol: { symbol in
                symbol.seeAlsoVariants[.swift] = makeSeeAlsoSection(
                    destination: "doc://org.swift.docc.example/documentation/MyKit/MyProtocol"
                )
                
                symbol.seeAlsoVariants[.objectiveC] = makeSeeAlsoSection(
                    destination: "doc://org.swift.docc.example/documentation/MyKit/MyProtocol"
                )
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.seeAlsoSections.count, 2)
                let taskGroup = try XCTUnwrap(renderNode.seeAlsoSections.first)
                XCTAssertEqual(taskGroup.title, "Related Documentation")
                
                XCTAssertEqual(
                    taskGroup.identifiers,
                    ["doc://org.swift.docc.example/documentation/MyKit/MyProtocol"]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(renderNode.seeAlsoSections.count, 2)
                let taskGroup = try XCTUnwrap(renderNode.seeAlsoSections.first)
                XCTAssertEqual(taskGroup.title, "Related Documentation")
                
                XCTAssertEqual(
                    taskGroup.identifiers,
                    ["doc://org.swift.docc.example/documentation/MyKit/MyProtocol"]
                )
            }
        )
    }
    
    func testDoesNotEmitObjectiveCSeeAlsoIfEmpty() throws {
        func makeSeeAlsoSection(destination: String) -> SeeAlsoSection {
            SeeAlsoSection(content: [
                UnorderedList(
                    ListItem(Paragraph(Link(destination: destination)))
                )
            ])
        }
        
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.seeAlsoVariants[.swift] = makeSeeAlsoSection(
                    destination: "doc://org.swift.docc.example/documentation/MyKit/MyProtocol"
                )
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(renderNode.seeAlsoSections.count, 2)
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssert(renderNode.seeAlsoSections.isEmpty)
            }
        )
    }
    
    func testDeprecationSummaryVariants() throws {
        try assertMultiVariantSymbol(
            configureSymbol: { symbol in
                symbol.deprecatedSummaryVariants[.swift] = DeprecatedSection(
                    text: "Swift Deprecation Variant"
                )
                
                symbol.deprecatedSummaryVariants[.objectiveC] = DeprecatedSection(
                    text: "Objective-C Deprecation Variant"
                )
            },
            assertOriginalRenderNode: { renderNode in
                XCTAssertEqual(
                    renderNode.deprecationSummary,
                    [.paragraph(.init(inlineContent: [.text("Swift Deprecation Variant")]))]
                )
            },
            assertAfterApplyingVariant: { renderNode in
                XCTAssertEqual(
                    renderNode.deprecationSummary,
                    [.paragraph(.init(inlineContent: [.text("Objective-C Deprecation Variant")]))]
                )
            }
        )
    }
    
    func testTopicRenderReferenceVariants() throws {
        func myFunctionReference(in renderNode: RenderNode) throws -> TopicRenderReference {
            return try XCTUnwrap(
                renderNode.references[
                    "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()"
                ] as? TopicRenderReference
            )
        }
        
        try assertMultiVariantSymbol(
            configureContext: { context, _ in
                // Set up a symbol with variants.
                
                let myFunctionNode = try context.entity(
                    with: ResolvedTopicReference(
                        bundleIdentifier: "org.swift.docc.example",
                        path: "/documentation/MyKit/MyClass/myFunction()",
                        fragment: nil,
                        sourceLanguage: .swift
                    )
                )
                
                let myFunction = try XCTUnwrap(myFunctionNode.semantic as? Symbol)
                
                myFunction.titleVariants[.swift] = "myFunction in Swift"
                myFunction.abstractSectionVariants[.swift] = AbstractSection(
                    paragraph: Paragraph(Text("myFunction abstract in Swift"))
                )
                
                myFunction.titleVariants[.objectiveC] = "myFunction in Objective-C"
                myFunction.abstractSectionVariants[.objectiveC] = AbstractSection(
                    paragraph: Paragraph(Text("myFunction abstract in Objective-C"))
                )
            }, assertOriginalRenderNode: { renderNode in
                let reference = try myFunctionReference(in: renderNode)
                XCTAssertEqual(reference.title, "myFunction in Swift")
                XCTAssertEqual(reference.abstract, [.text("myFunction abstract in Swift")])
            }, assertAfterApplyingVariant: { renderNode in
                let reference = try myFunctionReference(in: renderNode)
                XCTAssertEqual(reference.title, "myFunction in Objective-C")
                XCTAssertEqual(reference.abstract, [.text("myFunction abstract in Objective-C")])
            }
        )
    }
    
    private func assertMultiVariantSymbol(
        configureContext: (DocumentationContext, ResolvedTopicReference) throws -> () = { _, _ in },
        configureSymbol: (Symbol) throws -> () = { _ in },
        configureRenderNodeTranslator: (inout RenderNodeTranslator) -> () = { _ in },
        assertOriginalRenderNode: (RenderNode) throws -> (),
        assertAfterApplyingVariant: (RenderNode) throws -> () = { _ in },
        assertDataAfterApplyingVariant: (Data) throws -> () = { _ in }
    ) throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle")
        
        let identifier = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/MyKit/MyClass",
            sourceLanguage: .swift
        )
        
        try configureContext(context, identifier)
        context.documentationCache[identifier]?.availableSourceLanguages = [.swift, .objectiveC]
        
        let node = try context.entity(with: identifier)
        
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        try configureSymbol(symbol)
        
        try assertMultiLanguageSemantic(
            symbol,
            context: context,
            bundle: bundle,
            identifier: identifier,
            configureRenderNodeTranslator: configureRenderNodeTranslator,
            assertOriginalRenderNode: assertOriginalRenderNode,
            assertAfterApplyingVariant: assertAfterApplyingVariant,
            assertDataAfterApplyingVariant: assertDataAfterApplyingVariant
        )
    }
    
    private func assertMultiVariantArticle(
        configureContext: (DocumentationContext, ResolvedTopicReference) throws -> () = { _, _ in },
        configureArticle: (Article) throws -> () = { _ in },
        configureRenderNodeTranslator: (inout RenderNodeTranslator) -> () = { _ in },
        assertOriginalRenderNode: (RenderNode) throws -> (),
        assertAfterApplyingVariant: (RenderNode) throws -> () = { _ in },
        assertDataAfterApplyingVariant: (Data) throws -> () = { _ in }
    ) throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle")
        
        let identifier = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/Test-Bundle/article",
            sourceLanguage: .swift
        )
        
        try configureContext(context, identifier)
        context.documentationCache[identifier]?.availableSourceLanguages = [.swift, .objectiveC]
        
        let node = try context.entity(with: identifier)
        
        let article = try XCTUnwrap(node.semantic as? Article)
        
        try configureArticle(article)
       
        try assertMultiLanguageSemantic(
            article,
            context: context,
            bundle: bundle,
            identifier: identifier,
            assertOriginalRenderNode: assertOriginalRenderNode,
            assertAfterApplyingVariant: assertAfterApplyingVariant,
            assertDataAfterApplyingVariant: assertDataAfterApplyingVariant
        )
    }
    
    private func assertMultiLanguageSemantic(
        _ semantic: Semantic,
        context: DocumentationContext,
        bundle: DocumentationBundle,
        identifier: ResolvedTopicReference,
        configureRenderNodeTranslator: (inout RenderNodeTranslator) -> () = { _ in },
        assertOriginalRenderNode: (RenderNode) throws -> (),
        assertAfterApplyingVariant: (RenderNode) throws -> (),
        assertDataAfterApplyingVariant: (Data) throws -> () = { _ in }
    ) throws {
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: identifier,
            source: nil
        )
        
        configureRenderNodeTranslator(&translator)
        
        let renderNode = translator.visit(semantic) as! RenderNode
        
        let data = try renderNode.encodeToJSON()
        
        try assertOriginalRenderNode(RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: data))
        
        let variantRenderNode = try RenderNodeVariantOverridesApplier()
            .applyVariantOverrides(in: data, for: [.interfaceLanguage("occ")])
        
        try assertDataAfterApplyingVariant(variantRenderNode)
        
        try assertAfterApplyingVariant(RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: variantRenderNode))
    }
    
    private func assertModule(
        _ modules: [RenderMetadata.Module]?,
        expectedName: String,
        expectedRelatedModules: [String]? = nil
    ) throws {
        XCTAssertEqual(modules?.count, 1)
        let module = try XCTUnwrap(modules?.first)
        
        XCTAssertEqual(module.name, expectedName)
        XCTAssertEqual(module.relatedModules, expectedRelatedModules)
    }
    
    private func makeRelationshipSection(kind: RelationshipsGroup.Kind, path: String) -> RelationshipsSection {
        RelationshipsSection(
            groups: [
                RelationshipsGroup(
                    kind: kind,
                    destinations: [
                        TopicReference.successfullyResolved(
                            ResolvedTopicReference(
                                bundleIdentifier: "org.swift.docc.example",
                                path: path,
                                fragment: nil,
                                sourceLanguage: .swift
                            )
                        )
                    ]
                )
            ],
            targetFallbacks: [:],
            constraints: [:]
        )
    }
    
    private func makeTopicsSection(taskGroupName: String, destination: String) -> TopicsSection {
        TopicsSection(content: [
            Heading(level: 3, Text(taskGroupName)),
            
            UnorderedList(
                ListItem(Paragraph(Link(destination: destination)))
            )
        ])
    }
    
    private func makeSymbolAvailableInSwiftAndObjectiveC(
        symbolPath: String,
        bundleIdentifier: String,
        context: DocumentationContext
    ) throws {
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundleIdentifier,
            path: symbolPath,
            sourceLanguage: .swift
        )
        
        context.documentationCache[reference]?.availableSourceLanguages = [.swift, .objectiveC]
    }
}

private extension DocumentationDataVariantsTrait {
    static var objectiveC: DocumentationDataVariantsTrait { .init(interfaceLanguage: "occ") }
}
