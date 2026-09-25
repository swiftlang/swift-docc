/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
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

struct LinkDestinationSummaryDecodingTests {
    
    @Test(arguments: Self.exampleSourceLanguages)
    func bothImplementationsDecodeSourceLanguagesTheSame(_ language: DocCCommon.SourceLanguage) throws {
        try assertRoundTripCoding(makeExampleSummary(language: language))
    }
    
    @Test(arguments: [
        DocumentationNode.Kind.class,
        DocumentationNode.Kind.instanceMethod,
        DocumentationNode.Kind.article,
        DocumentationNode.Kind.tutorial,
        DocumentationNode.Kind(name: "CustomSymbol",      id: "custom-symbol",     isSymbol: true),
        DocumentationNode.Kind(name: "Custom Conceptual", id: "custom-conceptual", isSymbol: false),
    ])
    func bothImplementationsDecodeKindsTheSame(_ kind: DocumentationNode.Kind) throws {
        try assertRoundTripCoding(makeExampleSummary(kind: kind))
    }
    
    
    @Test(arguments: Self.exampleInlineContent)
    func bothImplementationsDecodeAbstractsTheSame(_ abstract: LinkDestinationSummary.Abstract?) throws {
        try assertRoundTripCoding(abstract)
        try assertRoundTripCoding(makeExampleSummary(abstract: abstract))
    }
    
    @Test(arguments: [
        "Plain text title",
        nil
    ], [
        [RenderInlineContent.text("Some "), .strong(inlineContent: [.text("formatted")]), .text(" title.")],
        [],
        nil
    ])
    func bothImplementationsDecodeRenderInlineReferencesTheSame(overridingTitle: String?, overridingTitleInlineContent: [RenderInlineContent]?) throws {
        let reference = RenderInlineContent.reference(
            identifier: "some-identifier",
            isActive: true,
            overridingTitle: overridingTitle,
            overridingTitleInlineContent: overridingTitleInlineContent
        )
        try assertDecodesTheSame(reference)
    }
    
    @Test(arguments: Self.exampleAvailability)
    func bothImplementationsDecodeAvailabilityTheSame(_ availability: [AvailabilityRenderItem]?) throws {
        try assertRoundTripCoding(availability)
        
        try assertRoundTripCoding(makeExampleSummary(platforms: availability))
    }
    
    @Test(arguments: Self.exampleDeclarationFragments)
    func bothImplementationsDecodeDeclarationFragmentsTheSame(_ declaration: LinkDestinationSummary.DeclarationFragments?) throws {
        try assertRoundTripCoding(declaration)
        
        try assertRoundTripCoding(makeExampleSummary(subheadingDeclarationFragments: declaration))
        try assertRoundTripCoding(makeExampleSummary(navigatorDeclarationFragments:  declaration))
    }
    
    @Test(arguments: [
        [],
        nil,
        [TopicImage(type: .card, identifier: "some-card-id")],
        [TopicImage(type: .icon, identifier: "some-icon-id")],
        [
            TopicImage(type: .card, identifier: "some-card-id"),
            TopicImage(type: .icon, identifier: "some-icon-id"),
        ]
    ])
    func bothImplementationsDecodeTopicImagesTheSame(_ images: [TopicImage]?) throws {
        try assertRoundTripCoding(images)
        try assertRoundTripCoding(makeExampleSummary(topicImages: images))
    }
    
    // MARK: References
    
    @Test(arguments: [
        ImageReference(identifier: "some-image-id", altText: nil,             imageAsset: exampleDataAssetWithScaleVariations),
        ImageReference(identifier: "some-image-id", altText: "Some alt text", imageAsset: exampleDataAssetWithInterfaceStyleVariations),
    ])
    func bothImplementationsDecodeImageReferencesTheSame(_ reference: ImageReference) throws {
        try assertDecodesTheSame(makeExampleSummary(references: [reference]))
    }
    
    @Test(arguments: [
        VideoReference(identifier: "some-video-id", altText: nil,             videoAsset: exampleDataAssetWithScaleVariations,          poster: nil),
        VideoReference(identifier: "some-video-id", altText: "Some alt text", videoAsset: exampleDataAssetWithInterfaceStyleVariations, poster: nil),
        VideoReference(identifier: "some-video-id", altText: "Some alt text", videoAsset: exampleDataAssetWithInterfaceStyleVariations, poster: "some-image-id"),
    ])
    func bothImplementationsDecodeVideoReferencesTheSame(_ reference: VideoReference) throws {
        try assertDecodesTheSame(makeExampleSummary(references: [reference]))
    }
    
    @Test(arguments: [
        FileReference(identifier: "some-file-id", fileName: "SomeFileName", fileType: "some-file-type", syntax: "some-syntax", content: [], highlights: []),
        FileReference(identifier: "some-file-id", fileName: "SomeFileName", fileType: "some-file-type", syntax: "some-syntax", content: [
            "First", "Second", "Third"
        ], highlights: []),
        FileReference(identifier: "some-file-id", fileName: "SomeFileName", fileType: "some-file-type", syntax: "some-syntax", content: [
            "First", "Second", "Third"
        ], highlights: [
            .init(line: 0),
            .init(line: 1, start: 5,   length: nil),
            .init(line: 2, start: 5,   length: 2),
            .init(line: 2, start: nil, length: 2),
        ]),
    ])
    func bothImplementationsDecodeFileReferencesTheSame(_ reference: FileReference) throws {
        try assertRoundTripCoding(makeExampleSummary(references: [reference]))
    }
    
    @Test(arguments: [
        DownloadReference(identifier: "some-download-id", verbatimURL: URL(string: "http://example.com")!, checksum: nil),
        DownloadReference(identifier: "some-download-id", verbatimURL: URL(string: "http://example.com")!, checksum: "abc123"),
        DownloadReference(identifier: "some-download-id", renderURL:   URL(string: "/path/to/some-file")!, checksum: nil),
        DownloadReference(identifier: "some-download-id", renderURL:   URL(string: "/path/to/some-file")!, checksum: "abc123"),
    ])
    func bothImplementationsDecodeDownloadReferencesTheSame(_ reference: DownloadReference) throws {
        try assertDecodesTheSame(makeExampleSummary(references: [reference]))
    }
    
    @Test(arguments: Self.exampleInlineContent)
    func bothImplementationsDecodeLinkReferencesTheSame(_ inlineContent: [RenderInlineContent]?) throws {
        let reference = LinkReference(identifier: "plain-title", title: "Plain text title", titleInlineContent: inlineContent, url: "http://example.com")
        try assertRoundTripCoding(makeExampleSummary(references: [reference]))
    }
    
    @Test
    func bothImplementationsDecodeMiscellaneousReferencesTheSame() throws {
        try assertRoundTripCoding(makeExampleSummary(references: [
            FileTypeReference(identifier: "some-file-type-id", displayName: "Some display name", iconBase64: Data("Some icon".utf8).base64EncodedData()),
            XcodeRequirementReference(identifier: "some-xcode-id", title: "Some requirement title", url: URL(string: "http://example.com")!),
            UnresolvedRenderReference(identifier: "some-unresolved-reference", title: "Some title"),
        ]))
    }
     
    @Test(
        arguments: [
            TopicRenderReference(
                identifier: "minimal-info",
                title: "Minimal non-symbol info",
                abstract: [],
                url: "doc://com.example/documentation/Something/SomeArticle",
                kind: .article,
                defaultImplementationCount: nil,
                propertyListKeyNames: nil
            ),
            
            TopicRenderReference(
                identifier: "all-info",
                title: "An unrealistic mix of all information",
                abstract: Self.exampleInlineContent.last!!,
                url: "doc://com.example/documentation/Something/SomeSymbol",
                kind: .symbol,
                required: true,
                role: "some-role",
                fragments: [
                    .init(text: "func",        kind: .keyword),
                    .init(text: " ",           kind: .text),
                    .init(text: "doSomething", kind: .identifier,     highlight: .changed),
                    .init(text: "() -> ",      kind: .text),
                    .init(text: "Int",         kind: .typeIdentifier, preciseIdentifier: "s:Si"),
                ],
                navigatorTitle: [
                    .init(text: "func",        kind: .keyword),
                    .init(text: " ",           kind: .text),
                    .init(text: "doSomething", kind: .identifier),
                    .init(text: "()",          kind: .text),
                ],
                estimatedTime: "1h2m3s",
                conformance: ConformanceSection(
                    constraints: [
                        .codeVoice(code: "Self"),
                        .text(" confroms to "),
                        .codeVoice(code: "Copyable"),
                    ],
                    availabilityPrefix: [.text("Available when")],
                    conformancePrefix:  [.text("Conforms when")]
                ),
                isBeta: true,
                isDeprecated: true,
                defaultImplementationCount: 3,
                propertyListKeyNames: .init(
                    titleStyle: .useDisplayName,
                    rawKey: "some-plist-raw-key",
                    displayName: "Some Property List Key Display Name"
                ),
                tags: [
                    .spi,
                    .init(type: "some-custom-tag", text: "Some custom tag")
                ],
                images: [
                    .init(type: .card, identifier: "some-card-id"),
                    .init(type: .icon, identifier: "some-icon-id"),
                ]
            )
        ]
    )
    func bothImplementationsDecodeTopicRenderReferencesTheSame(_ reference: TopicRenderReference) throws {
        try assertDecodesTheSame(makeExampleSummary(references: [reference]))
    }
    
    @Test(arguments: [
        RenderNode.Kind.symbol,
        RenderNode.Kind.article,
        RenderNode.Kind.tutorial,
        RenderNode.Kind.section,
        RenderNode.Kind.overview,
    ])
    func bothImplementationsDecodeRenderNodeKindTheSame(_ kind: RenderNode.Kind) throws {
        try assertRoundTripCoding(kind)
    }
    
    @Test(arguments: [
        RenderNode.Tag.spi,
        RenderNode.Tag(type: "some-custom-tag", text: "Some custom tag")
    ])
    func bothImplementationsDecodeRenderNodeKindTheSame(_ tag: RenderNode.Tag) throws {
        try assertRoundTripCoding(tag)
    }
    
    @Test(arguments: Self.exampleInlineContent)
    func bothImplementationsDecodeConformanceSectionTheSame(_ inlineContent: [RenderInlineContent]?) throws {
        if let inlineContent {
            var section = ConformanceSection(
                constraints: inlineContent,
                availabilityPrefix: [.text("Available when")],
                conformancePrefix:  [.text("Conforms when")]
            )
            try assertRoundTripCoding(section)
            
            section.availabilityPrefix = inlineContent
            try assertRoundTripCoding(section)
            
            section.conformancePrefix = inlineContent
            try assertRoundTripCoding(section)
        }
    }
    
    @Test(arguments: [nil, "some-plist-raw-key"], [nil, "Some Property List Key Display Name"])
    func bothImplementationsDecodePropertyListKeyNamesTheSame(rawKey: String?, displayName: String?) throws {
        // Parameterized tests only support combinations of 2 parameters
        for style in [PropertyListTitleStyle.useDisplayName, .useRawKey, nil] {
            // PropertyListKeyNames itself isn't decodable but is constructed from decoding TopicRenderReference information
            let reference = TopicRenderReference(
                identifier: "minimal-info",
                title: "Minimal non-symbol info",
                abstract: [],
                url: "doc://com.example/documentation/Something/SomeArticle",
                kind: .article,
                defaultImplementationCount: nil,
                propertyListKeyNames: .init(titleStyle: style, rawKey: rawKey, displayName: displayName)
            )
            if style == nil, rawKey == nil, displayName == nil {
                // The encoder doesn't include the `propertyListKeyNames` if all its properties are empty.
                try assertDecodesTheSame(makeExampleSummary(references: [reference]))
            } else {
                try assertRoundTripCoding(makeExampleSummary(references: [reference]))
            }
        }
    }
    
    @Test(arguments: [
        exampleDataAssetWithScaleVariations,
        exampleDataAssetWithInterfaceStyleVariations,
        DataAsset(
            variants: [
                DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard): URL(string: "/path/to/some-image.png")!,
            ],
            metadata: [
                URL(string: "/path/to/some-image.png")!: DataAsset.Metadata(svgID: nil), // No SVG ID for .png files
            ],
            context: .download
        )
    ])
    func bothImplementationsDecodeDataAssetsTheSame(_ asset: DataAsset) throws {
        try assertRoundTripCoding(asset)
    }
    
    // MARK: Example data
    
    private static let exampleSourceLanguages: [DocCCommon.SourceLanguage] = [
        .swift,
        .init(name: "FirstCustom"),
        .init(name: "SecondCustom", id: "second-custom", idAliases: ["secondCustom"], linkDisambiguationID: "second"),
        .objectiveC,
    ]
    
    private static let exampleInlineContent: [[RenderInlineContent]?] = [
        [.text("Some plain text abstract.")],
        nil,
        [],
        [
            .text("Some "),
            .strong(inlineContent: [
                .text("strong"),
            ]),
            .text(" and "),
            .emphasis(inlineContent: [
                .text("emphasized"),
            ]),
            .text(" abstract."),
        ],
        // Other formatted text
        [.codeVoice(code: "func doSomething() {}")],
        [.newTerm(inlineContent: [
            .text("Some new term")
        ])],
        [.inlineHead(inlineContent: [
            .text("Some inline heading")
        ])],
        [.subscript(inlineContent: [
            .text("Some subscript content")
        ])],
        [.superscript(inlineContent: [
            .text("Some superscript content")
        ])],
        [.strikethrough(inlineContent: [
            .text("Some strikethrough content")
        ])],
        // Images
        [.image(identifier: "some-image-without-metadata", metadata: nil)],
        [.image(
            identifier: "some-image-empty-metadata",
            metadata: .init(anchor: nil, title: nil, abstract: nil, deviceFrame: nil)
        )],
        [.image(
            identifier: "some-image-with-metadata",
            metadata: .init(
                anchor: "some-anchor-id",
                title: "Some image title",
                abstract: [.text("Some image abstract")],
                deviceFrame: "some-device-frame-id"
            )
        )],
        // References
        [.reference(identifier: "some-inactive-link-id", isActive: false, overridingTitle: nil, overridingTitleInlineContent: nil)],
        [.reference(identifier: "some-active-link-id",   isActive: true,  overridingTitle: nil, overridingTitleInlineContent: nil)],
        
        // If the reference only has _one_ of `overridingTitle` and `overridingTitleInlineContent` it doesn't decode the same as the original. Test that decoding separately
        [.reference(identifier: "some-link-with-both-titles-id", isActive: true, overridingTitle: "Plain text title", overridingTitleInlineContent: [.text("Some "), .strong(inlineContent: [.text("formatted")]), .text(" title.")])],
    ]
    
    private static let exampleAvailability: [[AvailabilityRenderItem]?] = [
        [],
        nil,
        [AvailabilityRenderItem(name: nil, introduced: nil, isBeta: false)],
        [AvailabilityRenderItem(name: "SomePlatform", introduced: "1.2.3",  isBeta: true)],
        [
            AvailabilityRenderItem(name: "First",  introduced: nil,      isBeta: false),
            AvailabilityRenderItem(name: "Second", introduced: "1.2.3",  isBeta: true),
            AvailabilityRenderItem(name: "Third",  introduced: "1.2.3", deprecated: "3.4.5", isBeta: false),
            AvailabilityRenderItem(name: "Fourth", introduced: nil,     deprecated: "3.4.5", isBeta: false),
        ],
        [
            AvailabilityRenderItem(name: "First",  introduced: "1.2.3", deprecated: "3.4.5", obsoleted: "6.7.8", isBeta: false),
            AvailabilityRenderItem(name: "Second", introduced: "1.2.3", deprecated: nil,     obsoleted: "6.7.8", isBeta: false),
            AvailabilityRenderItem(name: "Third",  introduced: nil,     deprecated: "3.4.5", obsoleted: "6.7.8", isBeta: false),
            AvailabilityRenderItem(name: "Fourth", introduced: nil,     deprecated: nil,     obsoleted: "6.7.8", isBeta: false),
        ],
        [
            AvailabilityRenderItem(name: "First",  introduced: nil, unconditionallyDeprecated: true,  unconditionallyUnavailable: true,  isBeta: false),
            AvailabilityRenderItem(name: "Second", introduced: nil, unconditionallyDeprecated: true,  unconditionallyUnavailable: false, isBeta: false),
            AvailabilityRenderItem(name: "Third",  introduced: nil, unconditionallyDeprecated: false, unconditionallyUnavailable: true,  isBeta: false),
        ]
    ]
    
    private static let exampleDeclarationFragments: [LinkDestinationSummary.DeclarationFragments?] = [
        [],
        nil,
        [.init(text: "SomeAttribute",        kind: .attribute,        identifier: nil, preciseIdentifier: nil, highlight: nil)],
        [.init(text: "SomeExternalParam",    kind: .externalParam,    identifier: nil, preciseIdentifier: nil, highlight: nil)],
        [.init(text: "SomeGenericParameter", kind: .genericParameter, identifier: nil, preciseIdentifier: nil, highlight: nil)],
        [.init(text: "SomeIdentifier",       kind: .identifier,       identifier: nil, preciseIdentifier: nil, highlight: nil)],
        [.init(text: "SomeInternalParam",    kind: .internalParam,    identifier: nil, preciseIdentifier: nil, highlight: nil)],
        [.init(text: "SomeKeyword",          kind: .keyword,          identifier: nil, preciseIdentifier: nil, highlight: nil)],
        [.init(text: "SomeLabel",            kind: .label,            identifier: nil, preciseIdentifier: nil, highlight: nil)],
        [.init(text: "SomeNumber",           kind: .number,           identifier: nil, preciseIdentifier: nil, highlight: nil)],
        [.init(text: "SomeString",           kind: .string,           identifier: nil, preciseIdentifier: nil, highlight: nil)],
        [.init(text: "SomeText",             kind: .text,             identifier: nil, preciseIdentifier: nil, highlight: nil)],
        [.init(text: "SomeTypeIdentifier",   kind: .typeIdentifier,   identifier: nil, preciseIdentifier: nil, highlight: nil)],
        [
            .init(text: "with-id",         kind: .identifier, identifier: "some-id", preciseIdentifier: nil,               highlight: nil),
            .init(text: "with-precise-id", kind: .identifier, identifier: nil,       preciseIdentifier: "some-precise-id", highlight: nil),
            .init(text: "with-both-ids",   kind: .identifier, identifier: "some-id", preciseIdentifier: "some-precise-id", highlight: nil),
        ],
        [
            .init(text: "before",      kind: .identifier, identifier: nil, preciseIdentifier: nil, highlight: nil),
            .init(text: "highlighted", kind: .identifier, identifier: nil, preciseIdentifier: nil, highlight: .changed),
            .init(text: "after",       kind: .identifier, identifier: nil, preciseIdentifier: nil, highlight: nil),
        ],
    ]
    
    private static let exampleDataAssetWithScaleVariations: DataAsset = {
        let urls = (1...3).map { URL(string: "/path/to/some-image-\($0).png")! }
        return DataAsset(
            variants: [
                DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard): urls[0],
                DataTraitCollection(userInterfaceStyle: .light, displayScale: .double):   urls[1],
                DataTraitCollection(userInterfaceStyle: .light, displayScale: .triple):   urls[2],
            ],
            metadata: [
                urls[0]: DataAsset.Metadata(svgID: nil), // No SVG ID for .png files
                urls[1]: DataAsset.Metadata(svgID: nil),
                urls[2]: DataAsset.Metadata(svgID: nil),
            ],
            context: .display
        )
    }()
    
    private static let exampleDataAssetWithInterfaceStyleVariations: DataAsset = {
        let urls = (1...3).map { URL(string: "/path/to/some-image-\($0).svg")! }
        return DataAsset(
            variants: [
                DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): urls[0],
                DataTraitCollection(userInterfaceStyle: .dark,  displayScale: .double): urls[1],
            ],
            metadata: [
                urls[0]: DataAsset.Metadata(svgID: "some-id"),
                urls[1]: DataAsset.Metadata(svgID: "some-id"),
            ],
            context: .display
        )
    }()
    
    private func makeExampleSummary(
        kind: DocumentationNode.Kind = .class,
        language: SourceLanguage = .swift,
        title: String = "SomeClass",
        abstract: LinkDestinationSummary.Abstract? = nil,
        availableLanguages: Set<SourceLanguage> = Set(Self.exampleSourceLanguages),
        platforms: [LinkDestinationSummary.PlatformAvailability]? = nil,
        usr: String? = nil,
        plainTextDeclaration: String? = nil,
        subheadingDeclarationFragments: LinkDestinationSummary.DeclarationFragments? = nil,
        navigatorDeclarationFragments: LinkDestinationSummary.DeclarationFragments? = nil,
        redirects: [URL]? = nil,
        topicImages: [TopicImage]? = nil,
        references: [any RenderReference]? = nil,
        variants: [LinkDestinationSummary.Variant] = []
    ) -> LinkDestinationSummary {
        let referenceURL = ResolvedTopicReference(bundleID: "com.example", path: "/documentation/ModuleName/SomeClass", sourceLanguage: language).url
        return LinkDestinationSummary(
            kind: kind,
            language: language,
            relativePresentationURL: referenceURL.withoutHostAndPortAndScheme(),
            referenceURL: referenceURL,
            title: title,
            abstract: abstract,
            availableLanguages: availableLanguages,
            platforms: platforms,
            usr: usr,
            plainTextDeclaration: plainTextDeclaration,
            subheadingDeclarationFragments: subheadingDeclarationFragments,
            navigatorDeclarationFragments: navigatorDeclarationFragments,
            redirects: redirects,
            topicImages: topicImages,
            references: references,
            variants: variants
        )
    }
}

private func assertDecodesTheSame<Value: Equatable & Codable & FastJSONDecodable>(_ value: Value, sourceLocation: SourceLocation = #_sourceLocation) throws {
    let encoded = try JSONEncoder().encode(value)

    let decoded = try JSONDecoder().decode(Value.self, from: encoded)
    let fastDecoded = try FastSymbolGraphJSONDecoder.decode(Value.self, from: encoded)
    #expect(decoded == fastDecoded, sourceLocation: sourceLocation)
}

extension RenderReferenceIdentifier: ExpressibleByStringLiteral {
    init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}
