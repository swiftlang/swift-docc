/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
import SymbolKit
@testable import SwiftDocC
import DocCTestUtilities
import DocCCommon

struct LinkDestinationSummaryTests {
    @Test
    func summarizeSymbolPagesWithDifferentLanguageRepresentations() async throws {
        let context = try await loadFromDisk(catalogName: "GeometricalShapes")
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let moduleReference = try #require(context.soleRootModuleReference)
        
        func summary(for reference: ResolvedTopicReference, sourceLocation: SourceLocation = #_sourceLocation) throws -> LinkDestinationSummary {
            let node = try context.entity(with: reference)
            let renderNode = DocumentationNodeConverter(context: context).convert(node)
            return try #require(node.externallyLinkableElementSummaries(context: context, renderNode: renderNode).first, sourceLocation: sourceLocation)
        }
        
        // typedef struct {
        //     CGPoint center;
        //     CGFloat radius;
        // } TLACircle NS_SWIFT_NAME(Circle);
        do {
            let reference = try #require(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/Circle" }))
            #expect(reference.sourceLanguages.count == 2, "Symbol has 2 language representations")
            
            let summary = try summary(for: reference)
            
            #expect(summary.title == "Circle")
            #expect(summary.relativePresentationURL.absoluteString == "/documentation/geometricalshapes/circle")
            #expect(summary.referenceURL.absoluteString == "doc://GeometricalShapes/documentation/GeometricalShapes/Circle")
            #expect(summary.language == .swift)
            #expect(summary.kind     == .structure)
            #expect(summary.abstract == [.text("A circle.")])
            #expect(summary.availableLanguages == [.swift, .objectiveC])
            #expect(summary.platforms == nil)
            #expect(summary.usr       == "c:@SA@TLACircle")
            #expect(summary.plainTextDeclaration == "struct Circle")
            #expect(summary.subheadingDeclarationFragments == [
                .init(text: "struct", kind: .keyword),
                .init(text: " ",      kind: .text),
                .init(text: "Circle", kind: .identifier),
            ])
            #expect(summary.navigatorDeclarationFragments == [
                .init(text: "Circle", kind: .identifier),
            ])
            #expect(summary.topicImages == nil)
            #expect(summary.references  == nil)
            
            #expect(summary.variants.count == 1)
            let variant = try #require(summary.variants.first)
            
            #expect(variant.title == "TLACircle")
            #expect(variant.relativePresentationURL?.absoluteString == nil, "Same presentation URL as the summarized element")
            #expect(variant.language == .objectiveC)
            #expect(variant.kind     == nil, "Same kind as the summarized element")
            #expect(variant.abstract == nil, "Same abstract as the summarized element")
            #expect(variant.usr      == nil, "Same USR as the summarized element")
            #expect(variant.plainTextDeclaration == "typedef struct TLACircle;")
            #expect(variant.subheadingDeclarationFragments == [
                .init(text: "typedef",   kind: .keyword),
                .init(text: " ",         kind: .text),
                .init(text: "struct",    kind: .keyword),
                .init(text: " ",         kind: .text),
                .init(text: "TLACircle", kind: .identifier),
                .init(text: ";",         kind: .text),
            ])
            #expect(variant.navigatorDeclarationFragments == [
                .init(text: "TLACircle", kind: .identifier),
            ])
            
            try assertRoundTripCoding(summary)
        }
        
        // extern const TLACircle TLACircleZero NS_SWIFT_NAME(Circle.zero);
        do {
            let reference = try #require(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/Circle/zero" }))
            #expect(reference.sourceLanguages.count == 2, "Symbol has 2 language representations")
            
            let summary = try summary(for: reference)
            
            #expect(summary.title == "zero")
            #expect(summary.relativePresentationURL.absoluteString == "/documentation/geometricalshapes/circle/zero")
            #expect(summary.referenceURL.absoluteString == "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/zero")
            #expect(summary.language == .swift)
            #expect(summary.kind     == .typeProperty)
            #expect(summary.abstract == [.text("The empty circle.")])
            #expect(summary.availableLanguages == [.swift, .objectiveC])
            #expect(summary.platforms == nil)
            #expect(summary.usr       == "c:@TLACircleZero")
            #expect(summary.plainTextDeclaration == "static let zero: Circle")
            #expect(summary.subheadingDeclarationFragments == [
                .init(text: "static", kind: .keyword),
                .init(text: " ",      kind: .text),
                .init(text: "let",    kind: .keyword),
                .init(text: " ",      kind: .text),
                .init(text: "zero",   kind: .identifier),
                .init(text: ": ",     kind: .text),
                .init(text: "Circle", kind: .typeIdentifier, preciseIdentifier: "c:@SA@TLACircle"),
            ])
            #expect(summary.navigatorDeclarationFragments == nil, "This symbol doesn't have a dedicated navigator name")
            #expect(summary.topicImages == nil)
            #expect(summary.references  == nil)
            
            #expect(summary.variants.count == 1)
            let variant = try #require(summary.variants.first)
            
            #expect(variant.title == "TLACircleZero")
            #expect(variant.relativePresentationURL?.absoluteString == nil, "Same presentation URL as the summarized element")
            #expect(variant.language == .objectiveC)
            #expect(variant.kind     == .globalVariable)
            #expect(variant.abstract == nil, "Same abstract as the summarized element")
            #expect(variant.usr      == nil, "Same USR as the summarized element")
            #expect(variant.plainTextDeclaration == "extern const TLACircle TLACircleZero;")
            #expect(variant.subheadingDeclarationFragments == [
                .init(text: "TLACircleZero", kind: .identifier),
            ])
            #expect(variant.navigatorDeclarationFragments == [
                .init(text: "TLACircleZero", kind: .identifier),
            ])
            
            try assertRoundTripCoding(summary)
        }
        
        // BOOL TLACircleIntersects(TLACircle circle, TLACircle otherCircle) NS_SWIFT_NAME(Circle.intersects(self:_:));
        do {
            let reference = try #require(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/Circle/intersects(_:)" }))
            #expect(reference.sourceLanguages.count == 2, "Symbol has 2 language representations")
            
            let summary = try summary(for: reference)
            
            #expect(summary.title == "intersects(_:)")
            #expect(summary.relativePresentationURL.absoluteString == "/documentation/geometricalshapes/circle/intersects(_:)")
            #expect(summary.referenceURL.absoluteString == "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/intersects(_:)")
            #expect(summary.language == .swift)
            #expect(summary.kind     == .instanceMethod)
            #expect(summary.abstract == [.text("Returns whether two circles intersect.")])
            #expect(summary.availableLanguages == [.swift, .objectiveC])
            #expect(summary.platforms == nil)
            #expect(summary.usr       == "c:@F@TLACircleIntersects")
            #expect(summary.plainTextDeclaration == "func intersects(_ otherCircle: Circle) -> Bool")
            #expect(summary.subheadingDeclarationFragments == [
                .init(text: "func",       kind: .keyword),
                .init(text: " ",          kind: .text),
                .init(text: "intersects", kind: .identifier),
                .init(text: "(",          kind: .text),
                .init(text: "Circle",     kind: .typeIdentifier, preciseIdentifier: "c:@SA@TLACircle"),
                .init(text: ") -> ",      kind: .text),
                .init(text: "Bool",       kind: .typeIdentifier, preciseIdentifier: "s:Sb"),
            ])
            #expect(summary.navigatorDeclarationFragments == nil, "This symbol doesn't have a dedicated navigator name")
            #expect(summary.topicImages == nil)
            #expect(summary.references  == nil)
            
            #expect(summary.variants.count == 1)
            let variant = try #require(summary.variants.first)
            
            #expect(variant.title == "TLACircleIntersects")
            #expect(variant.relativePresentationURL?.absoluteString == nil, "Same presentation URL as the summarized element")
            #expect(variant.language == .objectiveC)
            #expect(variant.kind     == .function)
            #expect(variant.abstract == nil, "Same abstract as the summarized element")
            #expect(variant.usr      == nil, "Same USR as the summarized element")
            #expect(variant.plainTextDeclaration == "BOOL TLACircleIntersects(TLACircle circle, TLACircle otherCircle);")
            #expect(variant.subheadingDeclarationFragments == [
                .init(text: "TLACircleIntersects", kind: .identifier),
            ])
            #expect(variant.navigatorDeclarationFragments == [
                .init(text: "TLACircleIntersects", kind: .identifier),
            ])
            
            try assertRoundTripCoding(summary)
        }

        // TLACircle TLACircleMake(CGPoint center, CGFloat radius) NS_SWIFT_UNAVAILABLE("Use 'Circle.init(center:radius:)' instead.");
        do {
            let reference = try #require(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/TLACircleMake" }))
            #expect(reference.sourceLanguages.count == 1, "Symbol only has one language representation")
            
            let summary = try summary(for: reference)
            
            #expect(summary.title == "TLACircleMake")
            #expect(summary.relativePresentationURL.absoluteString == "/documentation/geometricalshapes/tlacirclemake")
            #expect(summary.referenceURL.absoluteString == "doc://GeometricalShapes/documentation/GeometricalShapes/TLACircleMake")
            #expect(summary.language == .objectiveC)
            #expect(summary.kind     == .function)
            #expect(summary.abstract == [.text("Creates a circle with the specified center location and radius.")])
            #expect(summary.availableLanguages == [.objectiveC])
            #expect(summary.platforms == nil)
            #expect(summary.usr       == "c:@F@TLACircleMake")
            #expect(summary.plainTextDeclaration == "TLACircle TLACircleMake(CGPoint center, CGFloat radius);")
            #expect(summary.subheadingDeclarationFragments == [
                .init(text: "TLACircleMake", kind: .identifier),
            ])
            #expect(summary.navigatorDeclarationFragments == [
                .init(text: "TLACircleMake", kind: .identifier),
            ])
            #expect(summary.topicImages == nil)
            #expect(summary.references  == nil)
            
            #expect(summary.variants.isEmpty)
            
            try assertRoundTripCoding(summary)
        }
        
        do {
            let reference = try #require(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/Circle/init(center:radius:)" }))
            #expect(reference.sourceLanguages.count == 1, "Symbol only has one language representation")
            
            let summary = try summary(for: reference)
            
            #expect(summary.title == "init(center:radius:)")
            #expect(summary.relativePresentationURL.absoluteString == "/documentation/geometricalshapes/circle/init(center:radius:)")
            #expect(summary.referenceURL.absoluteString == "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/init(center:radius:)")
            #expect(summary.language == .swift)
            #expect(summary.kind     == .initializer)
            #expect(summary.abstract == nil, "This symbol doesn't have a documentation comment")
            #expect(summary.availableLanguages == [.swift])
            #expect(summary.platforms == nil)
            #expect(summary.usr       == "s:So9TLACirclea6center6radiusABSo7CGPointV_14CoreFoundation7CGFloatVtcfc")
            #expect(summary.plainTextDeclaration == "init(center: CGPoint, radius: CGFloat)")
            #expect(summary.subheadingDeclarationFragments == [
                .init(text: "init",    kind: .keyword),
                .init(text: "(",       kind: .text),
                .init(text: "center",  kind: .externalParam),
                .init(text: ": ",      kind: .text),
                .init(text: "CGPoint", kind: .typeIdentifier, preciseIdentifier: "c:@S@CGPoint"),
                .init(text: ", ",      kind: .text),
                .init(text: "radius",  kind: .externalParam),
                .init(text: ": ",      kind: .text),
                .init(text: "CGFloat", kind: .typeIdentifier, preciseIdentifier: "s:14CoreFoundation7CGFloatV"),
                .init(text: ")",       kind: .text),
            ])
            #expect(summary.navigatorDeclarationFragments == nil, "This symbol doesn't have a dedicated navigator name")
            #expect(summary.topicImages == nil)
            #expect(summary.references  == nil)
            
            #expect(summary.variants.isEmpty)
            
            try assertRoundTripCoding(summary)
        }
    }
    
    @Test
    func summarizeArticleWithTopicImages() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            TextFile(name: "First.md", utf8Content: """
            # Some article
            
            This article has two page images.
            
            @Metadata {
              @PageImage(purpose: card, source: card.png, alt: "Card image alt text")
              @PageImage(purpose: icon, source: icon.png, alt: "Icon image alt text")
            }
            """),
            
            DataFile(name: "card.png",      data: Data()),
            DataFile(name: "card~dark.png", data: Data()),
            
            DataFile(name: "icon@2x.png",   data: Data()),
            
            TextFile(name: "Second.md", utf8Content: """
            # Another article
            This second article exist so that the first article isn't elevated to be the root page.
            """)
        ])
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "First" }))
        let node = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)
        var summary = try #require(node.externallyLinkableElementSummaries(context: context, renderNode: renderNode).first)
        
        #expect(summary.title == "Some article")
        #expect(summary.relativePresentationURL.absoluteString == "/documentation/something/first")
        #expect(summary.referenceURL.absoluteString == "doc://Something/documentation/Something/First")
        #expect(summary.language == .swift)
        #expect(summary.kind     == .article)
        #expect(summary.abstract == [.text("This article has two page images.")])
        #expect(summary.availableLanguages == [.swift])
        #expect(summary.platforms == nil)
        #expect(summary.usr                            == nil, "Only symbols have USRs.")
        #expect(summary.plainTextDeclaration           == nil, "Only symbols have USRs.")
        #expect(summary.subheadingDeclarationFragments == nil, "Only symbols have USRs.")
        #expect(summary.navigatorDeclarationFragments  == nil, "Only symbols have USRs.")
        
        #expect(summary.topicImages == [
            TopicImage(type: .card, identifier: RenderReferenceIdentifier("card.png")),
            TopicImage(type: .icon, identifier: RenderReferenceIdentifier("icon.png")),
        ])
        
        #expect(summary.references?.count == 2)
        
        // The order of the references is expected to be stable.
        do {
            let imageReference = try #require(summary.references?.first as? ImageReference)
            #expect(imageReference.identifier.identifier == "card.png")
            #expect(imageReference.altText == "Card image alt text")
            #expect(imageReference.asset.context == .display)
            
            #expect((renderNode.references[imageReference.identifier.identifier] as? ImageReference)?.altText == "Card image alt text",
                    "The reference in the page itself also has the altText")
            
            #expect(Set(imageReference.asset.variants.keys) == [
                DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard),
                DataTraitCollection(userInterfaceStyle:  .dark, displayScale: .standard),
            ])
            let lightImageURL = try #require(imageReference.asset.variants[DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard)])
            let darkImageURL  = try #require(imageReference.asset.variants[DataTraitCollection(userInterfaceStyle:  .dark, displayScale: .standard)])
            #expect(lightImageURL.path == "/Something.docc/card.png")
            #expect(darkImageURL.path  == "/Something.docc/card~dark.png")
            
            #expect(Set(imageReference.asset.metadata.keys) == [lightImageURL, darkImageURL])
            let lightImageMetadata = try #require(imageReference.asset.metadata[lightImageURL])
            #expect(lightImageMetadata.svgID == nil)
            let darkImageMetadata = try #require(imageReference.asset.metadata[darkImageURL])
            #expect(darkImageMetadata.svgID == nil)
        }
        
        do {
            let imageReference = try #require(summary.references?.last as? ImageReference)
            #expect(imageReference.identifier.identifier == "icon.png")
            #expect(imageReference.altText == "Icon image alt text")
            #expect(imageReference.asset.context == .display)
            
            #expect((renderNode.references[imageReference.identifier.identifier] as? ImageReference)?.altText == "Icon image alt text",
                    "The reference in the page itself also has the altText")
            
            #expect(Set(imageReference.asset.variants.keys) == [
                DataTraitCollection(userInterfaceStyle: .light, displayScale: .double),
            ])
            let lightImageURL = try #require(imageReference.asset.variants[DataTraitCollection(userInterfaceStyle: .light, displayScale: .double)])
            #expect(lightImageURL.path == "/Something.docc/icon@2x.png")
            
            #expect(Set(imageReference.asset.metadata.keys) == [lightImageURL])
            let lightImageMetadata = try #require(imageReference.asset.metadata[lightImageURL])
            #expect(lightImageMetadata.svgID == nil)
        }
        
        // TODO: DataAsset doesn't round-trip encode/decode
        summary.references = summary.references?.compactMap { (original: RenderReference) -> (any RenderReference)? in
            guard var imageRef = original as? ImageReference else { return nil }
            imageRef.asset.variants = imageRef.asset.variants.mapValues { variant in
                return imageRef.destinationURL(for: variant.lastPathComponent, prefixComponent: context.inputs.id.rawValue)
            }
            imageRef.asset.metadata = .init(uniqueKeysWithValues: imageRef.asset.metadata.map { key, value in
                return (imageRef.destinationURL(for: key.lastPathComponent, prefixComponent: context.inputs.id.rawValue), value)
            })
            return imageRef as (any RenderReference)
        }
        
        try assertRoundTripCoding(summary)
        
        // Also verify that round trip coding preserves asset prefixes
        let encoded = try RenderJSONEncoder.makeEncoder(assetPrefixComponent: context.inputs.id.rawValue).encode(summary)
        let decoded = try JSONDecoder().decode(LinkDestinationSummary.self, from: encoded)
        #expect(decoded == summary)
    }
    
    @Test
    func decodingUnknownKindAndLanguage() throws {
        let json = """
        {
          "kind" : {
            "id" : "kind-id",
            "name" : "Kind name",
            "isSymbol" : false
          },
          "language" : {
            "id" : "language-id",
            "name" : "Language name",
            "idAliases" : [
              "language-alias-id"
            ],
            "linkDisambiguationID" : "language-id"
          },
          "availableLanguages" : [
            "swift",
            "data",
            {
              "id" : "language-id",
              "idAliases" : [
                "language-alias-id"
              ],
              "linkDisambiguationID" : "language-id",
              "name" : "Language name"
            },
            {
              "id" : "language-id-2",
              "linkDisambiguationID" : "language-id-2",
              "name" : "Other language name"
            },
            "occ"
          ],
          "title" : "Something",
          "path" : "/documentation/something",
          "referenceURL" : "/documentation/something"
        }
        """
        
        let decoded = try JSONDecoder().decode(LinkDestinationSummary.self, from: Data(json.utf8))
        try assertRoundTripCoding(decoded)
        
        #expect(decoded.kind == DocumentationNode.Kind(name: "Kind name", id: "kind-id", isSymbol: false))
        #expect(decoded.language == SourceLanguage(name: "Language name", id: "language-id", idAliases: ["language-alias-id"]))
        #expect(decoded.availableLanguages == [
            // Known languages
            .swift,
            .objectiveC,
            .data,
            
            // Custom languages
            SourceLanguage(name: "Language name", id: "language-id", idAliases: ["language-alias-id"]),
            SourceLanguage(name: "Other language name", id: "language-id-2"),
        ])
    }
    
    @Test
    func decodingLegacyData() throws {
        let legacyData = """
        {
          "title": "ClassName",
          "referenceURL": "doc://org.swift.docc.example/documentation/MyKit/ClassName",
          "language": "swift",
          "path": "documentation/MyKit/ClassName",
          "availableLanguages": [
            "swift"
          ],
          "kind": "org.swift.docc.kind.class",
          "abstract": [
            {
              "type": "text",
              "text": "A brief explanation of my class."
            }
          ],
          "platforms": [
            {
              "name": "PlatformName",
              "introducedAt": "1.0"
            },
          ],
          "fragments": [
            {
              "kind": "keyword",
              "text": "class"
            },
            {
              "kind": "text",
              "text": " "
            },
            {
              "kind": "identifier",
              "text": "ClassName"
            }
          ]
        }
        """
        
        let decoded = try JSONDecoder().decode(LinkDestinationSummary.self, from: Data(legacyData.utf8))
        
        #expect(decoded.referenceURL == ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit/ClassName", sourceLanguage: .swift).url)
        #expect(decoded.platforms?.count == 1)
        #expect(decoded.platforms?.first?.name == "PlatformName")
        #expect(decoded.platforms?.first?.introduced == "1.0")
        #expect(decoded.kind  == .class)
        #expect(decoded.title == "ClassName")
        #expect(decoded.abstract?.plainText == "A brief explanation of my class.")
        #expect(decoded.relativePresentationURL.absoluteString == "documentation/MyKit/ClassName")
        #expect(decoded.subheadingDeclarationFragments == [
            .init(text: "class", kind: .keyword, identifier: nil),
            .init(text: " ", kind: .text, identifier: nil),
            .init(text: "ClassName", kind: .identifier, identifier: nil),
        ])
        #expect(decoded.topicImages == nil)
        #expect(decoded.references  == nil)
        
        #expect(decoded.variants.isEmpty)
    }
    
    @Test
    func apiCollectionIsCategorizedAsCollectionGroupKind() async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "APICollection.md", utf8Content: """
            # Some API Collection
            This is an API Collection because it curates symbols.

            ## Topics
            - ``ModuleName/SomeClass``
            """),
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"])]
            ))
        ])
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "APICollection" }))
        let node = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)

        let summaries = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)
        let summary = try #require(summaries.first)

        #expect(summary.kind  == .collectionGroup, "API Collections (articles with Topics sections) should be classified as a `.collectionGroup` kind")
        #expect(summary.title == "Some API Collection")
        #expect(summary.abstract == [.text("This is an API Collection because it curates symbols.")])

        try assertRoundTripCoding(summary)
    }

    @Test
    func explicitPageKindOverridesDefaultAPICollectionKind() async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "ExplicitArticle.md", utf8Content: """
            # Explicit Article

            This would be classifies as an API Collection because it curates a symbol but it is explicitly marked as an "article" which overrides the default kind.

            @Metadata {
                @PageKind(article)
            }

            ## Topics
            - ``ModuleName/SomeClass``
            """),
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"])]
            ))
        ])

        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "ExplicitArticle" }))
        let node = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)

        let summaries = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)
        let summary = try #require(summaries.first)

        // Should be .article because of explicit @PageKind(article), not .collectionGroup
        #expect(summary.kind  == .article)
        #expect(summary.title == "Explicit Article")

        try assertRoundTripCoding(summary)
    }
    
    @Test
    func summarizeTutorialPage() async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "TableOfContents.tutorial", utf8Content: """
            @Tutorials(name: "Something") {
               @Intro(title: "Some introductory title") {
                  Some description of what this collection of tutorials teaches.

                  @Image(source: background.png)
               }

               @Volume(name: "Volume 1") {
                  Some description of what this volume teaches.
                  @Image(source: volume-1.png)

                  @Chapter(name: "Chapter 1") {
                     Some description of what this chapter teaches.
                     @Image(source: chapter-1.png)
            
                     @TutorialReference(tutorial: SomeTutorial)
                  }
               }
            }
            """),
            
            TextFile(name: "SomeTutorial.tutorial", utf8Content: """
            @Tutorial {
               @Intro(title: "Some tutorial title with emoji 💻") {
                  Some introductory description of what this tutorial teaches. 
               }
               
               @Redirected(from: "old/path/to/this/page")
               @Redirected(from: "even/older/path/to/this/page")

               @Section(title: "Some section title with emoji 💻") {
                  @ContentAndMedia {
                     Some description of what this section teaches.
                     @Image(source: section-1.png)
                  }
                  @Redirected(from: "old/path/to/this/landmark")
            
                  @Steps {}
               }
            }
            """),
            
            DataFile(name: "background.png", data: Data()),
            DataFile(name: "volume-1.png",   data: Data()),
            DataFile(name: "chapter-1.png",  data: Data()),
            DataFile(name: "section-1.png",  data: Data()),
            
            InfoPlist(displayName: "Custom Display Name", identifier: "com.test.custom-identifier"),
        ])

        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SomeTutorial" }))
        let node = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)
        
        let summaries = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)
        let pageSummary = try #require(summaries.first)
        #expect(pageSummary.title == "Some tutorial title with emoji 💻")
        #expect(pageSummary.relativePresentationURL.absoluteString == "/tutorials/custom-display-name/sometutorial")
        #expect(pageSummary.referenceURL.absoluteString == "doc://com.test.custom-identifier/tutorials/Custom-Display-Name/SomeTutorial")
        #expect(pageSummary.language == .swift)
        #expect(pageSummary.kind     == .tutorial)
        #expect(pageSummary.availableLanguages == [.swift])
        #expect(pageSummary.platforms == nil)
        #expect(pageSummary.redirects?.map(\.absoluteString) == [
            "old/path/to/this/page",
            "even/older/path/to/this/page",
        ])
        #expect(pageSummary.usr                            == nil, "Only symbols have USRs")
        #expect(pageSummary.plainTextDeclaration           == nil, "Only symbols have a plain text declaration")
        #expect(pageSummary.subheadingDeclarationFragments == nil, "Only symbols have subheading declaration fragments")
        #expect(pageSummary.navigatorDeclarationFragments  == nil, "Only symbols have navigator titles")
        #expect(pageSummary.abstract == [
            .text("Some introductory description of what this tutorial teaches.")
        ])
        #expect(pageSummary.topicImages == nil, "The tutorial page doesn't have any topic images")
        #expect(pageSummary.references  == nil, "Because the tutorial page doesn't have any topic images it also doesn't have any references")
        
        let sectionSummary = try #require(summaries.dropFirst().first)
        #expect(sectionSummary.title == "Some section title with emoji 💻")
        #expect(sectionSummary.relativePresentationURL.absoluteString == "/tutorials/custom-display-name/sometutorial#Some-section-title-with-emoji-%F0%9F%92%BB")
        #expect(sectionSummary.referenceURL.absoluteString == "doc://com.test.custom-identifier/tutorials/Custom-Display-Name/SomeTutorial#Some-section-title-with-emoji-%F0%9F%92%BB")
        #expect(sectionSummary.language == .swift)
        #expect(sectionSummary.kind     == .onPageLandmark)
        #expect(sectionSummary.availableLanguages == [.swift])
        #expect(sectionSummary.platforms == nil)
        #expect(sectionSummary.redirects == [
            URL(string: "old/path/to/this/landmark")!,
        ])
        #expect(sectionSummary.usr == nil, "Only symbols have USRs")
        #expect(sectionSummary.plainTextDeclaration == nil, "Only symbols have a plain text declaration")
        #expect(sectionSummary.subheadingDeclarationFragments == nil, "Only symbols have subheading declaration fragments")
        #expect(sectionSummary.navigatorDeclarationFragments == nil, "Only symbols have navigator titles")
        #expect(sectionSummary.abstract == [
            .text("Some description of what this section teaches."),
        ])
        #expect(sectionSummary.topicImages == nil, "Sections don't have any topic images")
        #expect(sectionSummary.references  == nil, "Because sections don't have any topic images it also doesn't have any references")
        
        try assertRoundTripCoding(summaries)
    }
}
