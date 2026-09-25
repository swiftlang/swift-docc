/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import DocCCommon
private import struct Foundation.URL
private import struct Foundation.Data

extension LinkDestinationSummary: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 6 required properties
        var kind:                    _MaybeDecodedValue<DocumentationNode.Kind> = nil
        var language:                _MaybeDecodedValue<SourceLanguage>         = nil
        var availableLanguages:      _MaybeDecodedValue<[SourceLanguage]>       = nil
        var relativePresentationURL: _MaybeDecodedValue<URL>                    = nil
        var referenceURL:            _MaybeDecodedValue<URL>                    = nil
        var title:                   _MaybeDecodedValue<String>                 = nil
        // 10 properties with default values
        var absolutePresentationURL:        URL? = nil
        var abstract:                       Abstract?               = nil
        var platforms:                      [PlatformAvailability]? = nil
        var usr:                            String?                 = nil
        var plainTextDeclaration:           String?                 = nil
        var subheadingDeclarationFragments: DeclarationFragments?   = nil
        var navigatorDeclarationFragments:  DeclarationFragments?   = nil
        var redirects:                      [URL]?                  = nil
        var topicImages:                    [TopicImage]?           = nil
        var references:                     [any RenderReference]?  = nil
        var variants:                       [Variant]               = []
        
        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("kind") {
                kind = try decoder.decodeDocumentationNodeKind()
            }
            else if decoder.matchKey("language") {
                language = try decoder.decodeSourceLanguage()
            }
            else if decoder.matchKey("availableLanguages") {
                availableLanguages = try decoder._decodeArray { decoder throws(DecodingError) -> SourceLanguage in
                    try decoder.decodeSourceLanguage()
                }
            }
            else if decoder.matchKey("path") {
                let decodedURL = try decoder.decode(URL.self)
                (relativePresentationURL, absolutePresentationURL) = Self._checkIfDecodedURLWasAbsolute(decodedURL)
            }
            else if decoder.matchKey("referenceURL") {
                referenceURL = try decoder.decode(URL.self)
            }
            else if decoder.matchKey("title") {
                title = try decoder.decode(String.self)
            }
            else if decoder.matchKey("abstract") {
                abstract = try decoder.decode(Abstract?.self)
            }
            else if decoder.matchKey("platforms") {
                platforms = try decoder.decode([PlatformAvailability]?.self)
            }
            else if decoder.matchKey("usr\"") {
                usr = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("plainTextDeclaration") {
                plainTextDeclaration = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("fragments") {
                subheadingDeclarationFragments = try decoder.decode(DeclarationFragments?.self)
            }
            else if decoder.matchKey("navigatorFragments") {
                navigatorDeclarationFragments = try decoder.decode(DeclarationFragments?.self)
            }
            else if decoder.matchKey("redirects") {
                redirects = try decoder.decode([URL]?.self)
            }
            else if decoder.matchKey("topicImages") {
                topicImages = try decoder.decode([TopicImage]?.self)
            }
            else if decoder.matchKey("references") {
                references = try decoder._decodeArray { decoder throws(DecodingError) -> any RenderReference in
                    try decoder.decodeAnyRenderReference()
                }
            }
            else if decoder.matchKey("variants") {
                variants = try decoder.decode([Variant].self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let kind else {
            throw decoder.makeKeyNotFoundError("kind")
        }
        guard let language else {
            throw decoder.makeKeyNotFoundError("language")
        }
        guard let availableLanguages else {
            throw decoder.makeKeyNotFoundError("availableLanguages")
        }
        guard let relativePresentationURL else {
            throw decoder.makeKeyNotFoundError("relativePresentationURL")
        }
        guard let referenceURL else {
            throw decoder.makeKeyNotFoundError("referenceURL")
        }
        guard let title else {
            throw decoder.makeKeyNotFoundError("title")
        }

        self.kind                           = consume kind
        self.language                       = consume language
        self.relativePresentationURL        = consume relativePresentationURL
        self.absolutePresentationURL        = consume absolutePresentationURL
        self.referenceURL                   = consume referenceURL
        self.title                          = consume title
        self.abstract                       = consume abstract
        self.availableLanguages             = Set(consume availableLanguages)
        self.platforms                      = consume platforms
        self.usr                            = consume usr
        self.plainTextDeclaration           = consume plainTextDeclaration
        self.subheadingDeclarationFragments = consume subheadingDeclarationFragments
        self.navigatorDeclarationFragments  = consume navigatorDeclarationFragments
        self.redirects                      = consume redirects
        self.topicImages                    = consume topicImages
        self.references                     = consume references
        self.variants                       = consume variants
    }
}

extension LinkDestinationSummary.Variant: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var traits: _MaybeDecodedValue<[RenderNode.Variant.Trait]> = nil
        // 10 properties with default values
        var abstract:                       LinkDestinationSummary.Abstract??             = nil
        var kind:                           DocumentationNode.Kind?                       = nil
        var language:                       SourceLanguage?                               = nil
        var navigatorDeclarationFragments:  LinkDestinationSummary.DeclarationFragments?? = nil
        var plainTextDeclaration:           String??                                      = nil
        var relativePresentationURL:        URL?                                          = nil
        var subheadingDeclarationFragments: LinkDestinationSummary.DeclarationFragments?? = nil
        var title:                          String?                                       = nil
        var usr:                            String??                                      = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("\"traits\"", byteOffset: -1) {
                traits = try decoder.decode([RenderNode.Variant.Trait].self)
            }
            else if decoder.matchKey("kind") {
                kind = try decoder.decodeDocumentationNodeKind()
            }
            else if decoder.matchKey("language") {
                language = try decoder.decodeSourceLanguage()
            }
            else if decoder.matchKey("path") {
                relativePresentationURL = try decoder.decode(URL.self)
            }
            else if decoder.matchKey("title") {
                title = try decoder.decode(String.self)
            }
            else if decoder.matchKey("abstract") {
                abstract = try decoder.decode(LinkDestinationSummary.Abstract?.self)
            }
            else if decoder.matchKey("usr\"") {
                usr = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("plainTextDeclaration") {
                plainTextDeclaration = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("fragments") {
                subheadingDeclarationFragments = try decoder.decode(LinkDestinationSummary.DeclarationFragments?.self)
            }
            else if decoder.matchKey("navigatorFragments") {
                navigatorDeclarationFragments = try decoder.decode(LinkDestinationSummary.DeclarationFragments?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let traits else {
            throw decoder.makeKeyNotFoundError("traits")
        }

        self.init(
            traits:                         consume traits,
            kind:                           consume kind,
            language:                       consume language,
            relativePresentationURL:        consume relativePresentationURL,
            title:                          consume title,
            abstract:                       consume abstract,
            usr:                            consume usr,
            plainTextDeclaration:           consume plainTextDeclaration,
            subheadingDeclarationFragments: consume subheadingDeclarationFragments,
            navigatorDeclarationFragments:  consume navigatorDeclarationFragments
        )
    }
}

private extension FastSymbolGraphJSONDecoder {
    // `LinkDestinationSummary` decodes a `DocumentationNode.Kind` either as known ID or as a full structure.
    // We don't want most other code to have this behavior, so this is a custom private method rather than a `FastJSONDecodable` conformance.
    mutating func decodeDocumentationNodeKind() throws(DecodingError) -> DocumentationNode.Kind {
        typealias _MaybeDecodedValue = Optional
        
        guard self._isAtStartOfObject() else {
            // If the JSON value isn't an object, the link summary expects to decode it as a known `Kind` identifier.
            let kindID = try self.decode(String.self)
            guard let found = DocumentationNode.Kind.allKnownValues.first(where: { $0.id == kindID }) else {
                throw self.makeDataCorruptedError(message: "Unknown DocumentationNode.Kind identifier: '\(kindID)'.")
            }
            return found
        }
        
        // 3 required properties
        var name:     _MaybeDecodedValue<String> = nil
        var id:       _MaybeDecodedValue<String> = nil
        var isSymbol: _MaybeDecodedValue<Bool>   = nil
        
        try self.descendIntoObject()
        while try self.advanceToNextKey() {
            if self.matchKey("name") {
                name = try self.decode(String.self)
            }
            else if self.matchKey("id") {
                id = try self.decode(String.self)
            }
            else if self.matchKey("isSymbol") {
                isSymbol = try self.decode(Bool.self)
            }
            // Do nothing for all unknown keys
            else {
                try self.ignoreValue()
            }
        }
        
        // Unwrap all required properties
        guard let name else {
            throw self.makeKeyNotFoundError("name")
        }
        guard let id else {
            throw self.makeKeyNotFoundError("id")
        }
        guard let isSymbol else {
            throw self.makeKeyNotFoundError("isSymbol")
        }
        
        return .init(
            name:     consume name,
            id:       consume id,
            isSymbol: isSymbol
        )
    }
}

private extension FastSymbolGraphJSONDecoder {
    // `LinkDestinationSummary` decodes a `SourceLanguage` either as known ID or as a full structure.
    // We don't want most other code to have this behavior, so this is a custom private method rather than a `FastJSONDecodable` conformance.
    mutating func decodeSourceLanguage() throws(DecodingError) -> SourceLanguage {
        typealias _MaybeDecodedValue = Optional
        
        guard self._isAtStartOfObject() else {
            // If the JSON value isn't an object, the link summary expects to decode it as a known `SourceLanguage` identifier.
            let languageID = try self.decode(String.self)
            guard let found = SourceLanguage.knownLanguages.first(where: { $0.id == languageID }) else {
                throw self.makeDataCorruptedError(message: "Unknown SourceLanguage identifier: '\(languageID)'.")
            }
            return found
        }
        
        // 2 required properties
        var name:     _MaybeDecodedValue<String> = nil
        var id:       _MaybeDecodedValue<String> = nil
        // 2 properties with default values
        var idAliases:            [String] = []
        var linkDisambiguationID: String?  = nil
        
        try self.descendIntoObject()
        while try self.advanceToNextKey() {
            if self.matchKey("name") {
                name = try self.decode(String.self)
            }
            else if self.matchKey("idAliases") {
                idAliases = try self.decode([String].self)
            }
            else if self.matchKey("id") {
                id = try self.decode(String.self)
            }
            else if self.matchKey("linkDisambiguationID") {
                linkDisambiguationID = try self.decode(String.self)
            }
            // Do nothing for all unknown keys
            else {
                try self.ignoreValue()
            }
        }
        
        // Unwrap all required properties
        guard let name else {
            throw self.makeKeyNotFoundError("name")
        }
        guard let id else {
            throw self.makeKeyNotFoundError("id")
        }
        
        return .init(
            name:                 consume name,
            id:                   consume id,
            idAliases:            consume idAliases,
            linkDisambiguationID: consume linkDisambiguationID
        )
    }
}

extension RenderInlineContent: FastJSONDecodable {
    private enum InlineType: String, FastJSONDecodable {
        case codeVoice, emphasis, strong, image, reference, text, newTerm, inlineHead, `subscript`, superscript, strikethrough
        
        init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
            let rawValue = try decoder.decode(String.self)
            guard let decoded = Self(rawValue: rawValue) else {
                throw decoder.makeDataCorruptedError(message: "Unknown RenderInlineContent type: '\(rawValue)'")
            }
            self = decoded
        }
    }
    
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional
        
        // This `RenderInlineContent` can be one of many types of inline content.
        // Because we cannot guarantee the order that the keys appear in the data,
        // we decode any relevant value that we encounter and construct the inline content based on its `type` after all fields have been decoded.
        
        // 1 required property for all types of inline content
        var type: _MaybeDecodedValue<InlineType> = nil
        // 5 required properties for different types of inline content
        var code:          _MaybeDecodedValue<String>                    = nil
        var identifier:    _MaybeDecodedValue<RenderReferenceIdentifier> = nil
        var inlineContent: _MaybeDecodedValue<[RenderInlineContent]>     = nil
        var isActive:      _MaybeDecodedValue<Bool>                      = nil
        var text:          _MaybeDecodedValue<String>                    = nil
        // 3 properties with default values for different types of inline content
        var metadata:                     RenderContentMetadata? = nil
        var overridingTitle:              String?                = nil
        var overridingTitleInlineContent: [RenderInlineContent]? = nil
        
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("type") {
                type = try decoder.decode(InlineType.self)
            }
            else if decoder.matchKey("code") {
                code = try decoder.decode(String.self)
            }
            else if decoder.matchKey("text") {
                text = try decoder.decode(String.self)
            }
            else if decoder.matchKey("inlineContent") {
                inlineContent = try decoder.decode([RenderInlineContent].self)
            }
            else if decoder.matchKey("identifier") {
                identifier = try decoder.decode(RenderReferenceIdentifier.self)
            }
            else if decoder.matchKey("metadata") {
                metadata = try decoder.decode(RenderContentMetadata.self)
            }
            else if decoder.matchKey("isActive") {
                isActive = try decoder.decode(Bool.self)
            }
            else if decoder.matchKey("overridingTitleInlineContent") {
                overridingTitleInlineContent = try decoder.decode([RenderInlineContent].self)
            }
            else if decoder.matchKey("overridingTitle") {
                overridingTitle = try decoder.decode(String.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }
        
        // Unwrap all required properties
        guard let type else {
            throw decoder.makeKeyNotFoundError("type")
        }
        
        switch type {
        case .codeVoice:
            guard let code else {
                throw decoder.makeKeyNotFoundError("code")
            }
            self = .codeVoice(code: consume code)
        case .emphasis:
            guard let inlineContent else {
                throw decoder.makeKeyNotFoundError("inlineContent")
            }
            self = .emphasis(inlineContent: consume inlineContent)
        case .strong:
            guard let inlineContent else {
                throw decoder.makeKeyNotFoundError("inlineContent")
            }
            self = .strong(inlineContent: consume inlineContent)
        case .image:
            guard let identifier else {
                throw decoder.makeKeyNotFoundError("identifier")
            }
            self = .image(identifier: identifier, metadata: metadata)
            
        case .reference:
            guard let identifier else {
                throw decoder.makeKeyNotFoundError("identifier")
            }
            guard let isActive else {
                throw decoder.makeKeyNotFoundError("isActive")
            }
            if let overridingTitle, overridingTitleInlineContent == nil {
                overridingTitleInlineContent = [.text(overridingTitle)]
            }
            else if let overridingTitleInlineContent, overridingTitle == nil {
                overridingTitle = overridingTitleInlineContent.plainText
            }
            self = .reference(
                identifier:                   identifier,
                isActive:                     isActive,
                overridingTitle:              consume overridingTitle,
                overridingTitleInlineContent: consume overridingTitleInlineContent
            )
        case .text:
            guard let text else {
                throw decoder.makeKeyNotFoundError("text")
            }
            self = .text(consume text)
        case .newTerm:
            guard let inlineContent else {
                throw decoder.makeKeyNotFoundError("inlineContent")
            }
            self = .newTerm(inlineContent: consume inlineContent)
        case .inlineHead:
            guard let inlineContent else {
                throw decoder.makeKeyNotFoundError("inlineContent")
            }
            self = .inlineHead(inlineContent: consume inlineContent)
        case .subscript:
            guard let inlineContent else {
                throw decoder.makeKeyNotFoundError("inlineContent")
            }
            self = .subscript(inlineContent: consume inlineContent)
        case .superscript:
            guard let inlineContent else {
                throw decoder.makeKeyNotFoundError("inlineContent")
            }
            self = .superscript(inlineContent: consume inlineContent)
        case .strikethrough:
            guard let inlineContent else {
                throw decoder.makeKeyNotFoundError("inlineContent")
            }
            self = .strikethrough(inlineContent: consume inlineContent)
        }
    }
}

extension RenderReferenceIdentifier: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let rawValue = try decoder.decode(String.self)
        self = .init(consume rawValue)
    }
}

extension RenderContentMetadata: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        var anchor:      String?                = nil
        var title:       String?                = nil
        var abstract:    [RenderInlineContent]? = nil
        var deviceFrame: String?                = nil
        
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("\"anchor\"", byteOffset: -1) {
                anchor = try decoder.decode(String.self)
            }
            else if decoder.matchKey("title") {
                title = try decoder.decode(String.self)
            }
            else if decoder.matchKey("abstract") {
                abstract = try decoder.decode([RenderInlineContent].self)
            }
            else if decoder.matchKey("deviceFrame") {
                deviceFrame = try decoder.decode(String.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }
        
        self.init(
            anchor:      consume anchor,
            title:       consume title,
            abstract:    consume abstract,
            deviceFrame: consume deviceFrame
        )
    }
}

extension LinkDestinationSummary.PlatformAvailability: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        // 9 properties with default values
        var name:         String? = nil
        var introducedAt: String? = nil
        var deprecatedAt: String? = nil
        var obsoletedAt:  String? = nil
        var message:      String? = nil
        var renamed:      String? = nil
        var deprecated:   Bool    = false
        var unavailable:  Bool    = false
        var beta:         Bool    = false
        
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("name") {
                name = try decoder.decode(String.self)
            }
            else if decoder.matchKey("introducedAt") {
                introducedAt = try decoder.decode(String.self)
            }
            else if decoder.matchKey("deprecatedAt") {
                deprecatedAt = try decoder.decode(String.self)
            }
            else if decoder.matchKey("obsoletedAt") {
                obsoletedAt = try decoder.decode(String.self)
            }
            else if decoder.matchKey("message\"") {
                message = try decoder.decode(String.self)
            }
            else if decoder.matchKey("renamed\"") {
                renamed = try decoder.decode(String.self)
            }
            else if decoder.matchKey("deprecated") {
                deprecated = try decoder.decode(Bool.self)
            }
            else if decoder.matchKey("unavailable") {
                unavailable = try decoder.decode(Bool.self)
            }
            else if decoder.matchKey("beta") {
                beta = try decoder.decode(Bool.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }
        
        self.init(
            name:                       consume name,
            introduced:                 consume introducedAt,
            deprecated:                 consume deprecatedAt,
            obsoleted:                  consume obsoletedAt,
            message:                    consume message,
            renamed:                    consume renamed,
            unconditionallyDeprecated:  deprecated,
            unconditionallyUnavailable: unavailable,
            isBeta:                     beta
        )
    }
}

extension DeclarationRenderSection.Token: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 2 required properties
        var text: _MaybeDecodedValue<String> = nil
        var kind: _MaybeDecodedValue<Kind>   = nil

        // 3 properties with default values
        var identifier:        String?
        var preciseIdentifier: String?
        var highlight:         Highlight?
        
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("text") {
                text = try decoder.decode(String.self)
            }
            else if decoder.matchKey("kind") {
                kind = try decoder.decode(Kind.self)
            }
            else if decoder.matchKey("identifier") {
                identifier = try decoder.decode(String.self)
            }
            else if decoder.matchKey("preciseIdentifier") {
                preciseIdentifier = try decoder.decode(String.self)
            }
            else if decoder.matchKey("highlight") {
                highlight = try decoder.decode(Highlight.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }
        
        // Unwrap all required properties
        guard let text else {
            throw decoder.makeKeyNotFoundError("text")
        }
        guard let kind else {
            throw decoder.makeKeyNotFoundError("kind")
        }
        
        self.init(
            text:              consume text,
            kind:              consume kind,
            identifier:        consume identifier,
            preciseIdentifier: consume preciseIdentifier,
            highlight:         consume highlight
        )
    }
}

extension DeclarationRenderSection.Token.Kind: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let rawValue = try decoder.decode(String.self)
        guard let decoded = Self(rawValue: rawValue) else {
            throw decoder.makeDataCorruptedError(message: "Unknown DeclarationRenderSection.Token.Kind value: '\(rawValue)'")
        }
        self = decoded
    }
}

extension DeclarationRenderSection.Token.Highlight: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let rawValue = try decoder.decode(String.self)
        guard let decoded = Self(rawValue: rawValue) else {
            throw decoder.makeDataCorruptedError(message: "Unknown DeclarationRenderSection.Token.Highlight value: '\(rawValue)'")
        }
        self = decoded
    }
}

extension TopicImage: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 2 required properties
        var type:       _MaybeDecodedValue<TopicImageType>            = nil
        var identifier: _MaybeDecodedValue<RenderReferenceIdentifier> = nil

        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("type") {
                type = try decoder.decode(TopicImageType.self)
            }
            else if decoder.matchKey("identifier") {
                identifier = try decoder.decode(RenderReferenceIdentifier.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let type else {
            throw decoder.makeKeyNotFoundError("type")
        }
        guard let identifier else {
            throw decoder.makeKeyNotFoundError("identifier")
        }

        self.init(
            type:       consume type,
            identifier: consume identifier
        )
    }
}

extension TopicImage.TopicImageType: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let rawValue = try decoder.decode(String.self)
        guard let decoded = Self(rawValue: rawValue) else {
            throw decoder.makeDataCorruptedError(message: "Unknown TopicImage.TopicImageType value: '\(rawValue)'")
        }
        self = decoded
    }
}

// We cannot extend another protocol to add this conformance
private extension FastSymbolGraphJSONDecoder {
    mutating func decodeAnyRenderReference() throws(DecodingError) -> any RenderReference {
        typealias _MaybeDecodedValue = Optional
        
        // An `any RenderReference` value can be one of many types.
        // Because we cannot guarantee the order that the keys appear in the data,
        // we decode any relevant value that we encounter and construct the inline content based on its `type` after all fields have been decoded.
        
        // 2 required properties for all types of inline content
        var identifier: _MaybeDecodedValue<RenderReferenceIdentifier> = nil
        var type:       _MaybeDecodedValue<RenderReferenceType>       = nil
        
        // 8 required properties for different types of render references
        var content:     _MaybeDecodedValue<[String]>  = nil
        var displayName: _MaybeDecodedValue<String>    = nil
        var fileName:    _MaybeDecodedValue<String>    = nil
        var fileType:    _MaybeDecodedValue<String>    = nil
        var iconBase64:  _MaybeDecodedValue<Data>      = nil
        var syntax:      _MaybeDecodedValue<String>    = nil
        var title:       _MaybeDecodedValue<String>    = nil
        var url:         _MaybeDecodedValue<URL>       = nil
        // 22 properties with default values for different types of render references
        var abstract:                   [RenderInlineContent]             = []
        var alt:                        String?                           = nil
        var checksum:                   String?                           = nil
        var conformance:                ConformanceSection?               = nil
        var defaultImplementationCount: Int?                              = nil
        var estimatedTime:              String?                           = nil
        var fragments:                  [DeclarationRenderSection.Token]? = nil
        var highlights:                 [LineHighlighter.Highlight]       = []
        var images:                     [TopicImage]                      = []
        var isBeta:                     Bool                              = false
        var isDeprecated:               Bool                              = false
        var kind:                       RenderNode.Kind                   = .tutorial
        var navigatorTitle:             [DeclarationRenderSection.Token]? = nil
        var poster:                     RenderReferenceIdentifier?        = nil
        var propertyListDisplayName:    String?                           = nil
        var propertyListRawKey:         String?                           = nil
        var propertyListTitleStyle:     PropertyListTitleStyle?           = nil
        var required:                   Bool                              = false
        var role:                       String?                           = nil
        var tags:                       [RenderNode.Tag]?                 = nil
        var titleInlineContent:         [RenderInlineContent]?            = nil
        var variants:                   [ImageReference.VariantProxy]     = []

        try self.descendIntoObject()
        while try self.advanceToNextKey() {
            if self.matchKey("type") {
                type = try self.decode(RenderReferenceType.self)
            }
            else if self.matchKey("identifier") {
                identifier = try self.decode(RenderReferenceIdentifier.self)
            }
            else if self.matchKey("variants") {
                variants = try self.decode([ImageReference.VariantProxy].self)
            }
            else if self.matchKey("content\"") {
                content = try self.decode([String].self)
            }
            else if self.matchKey("displayName") {
                displayName = try self.decode(String.self)
            }
            else if self.matchKey("fileName") {
                fileName = try self.decode(String.self)
            }
            else if self.matchKey("fileType") {
                fileType = try self.decode(String.self)
            }
            else if self.matchKey("iconBase64") {
                let decoded = try self.decode(String.self)
                guard let encodedData = Data(base64Encoded: decoded, options: []) else {
                    throw self.makeDataCorruptedError(message: "Decoded string is not Base-64 encoded")
                }
                iconBase64 = encodedData
            }
            else if self.matchKey("\"syntax\"", byteOffset: -1) {
                syntax = try self.decode(String.self)
            }
            else if self.matchKey("titleInlineContent") {
                titleInlineContent = try self.decode([RenderInlineContent].self)
            }
            else if self.matchKey("titleStyle") {
                propertyListTitleStyle = try self.decode(PropertyListTitleStyle.self)
            }
            else if self.matchKey("title") {
                title = try self.decode(String.self)
            }
            else if self.matchKey("url\"") {
                url = try self.decode(URL.self)
            }
            else if self.matchKey("alt\"") {
                alt = try self.decode(String?.self)
            }
            else if self.matchKey("checksum") {
                checksum = try self.decode(String?.self)
            }
            else if self.matchKey("highlights") {
                highlights = try self.decode([LineHighlighter.Highlight].self)
            }
            else if self.matchKey("\"poster\"", byteOffset: -1) {
                poster = try self.decode(RenderReferenceIdentifier?.self)
            }
            else if self.matchKey("abstract") {
                abstract = try self.decode([RenderInlineContent].self)
            }
            else if self.matchKey("conformance") {
                conformance = try self.decode(ConformanceSection.self)
            }
            else if self.matchKey("defaultImplementations") {
                defaultImplementationCount = try self.decode(Int.self)
            }
            else if self.matchKey("estimatedTime") {
                estimatedTime = try self.decode(String.self)
            }
            else if self.matchKey("fragments") {
                fragments = try self.decode([DeclarationRenderSection.Token].self)
            }
            else if self.matchKey("\"images\"", byteOffset: -1) {
                images = try self.decode([TopicImage].self)
            }
            else if self.matchKey("beta") {
                isBeta = try self.decode(Bool.self)
            }
            else if self.matchKey("deprecated") {
                isDeprecated = try self.decode(Bool.self)
            }
            else if self.matchKey("kind") {
                kind = try self.decode(RenderNode.Kind.self)
            }
            else if self.matchKey("navigatorTitle") {
                navigatorTitle = try self.decode([DeclarationRenderSection.Token].self)
            }
            else if self.matchKey("ideTitle") {
                propertyListDisplayName = try self.decode(String.self)
            }
            else if self.matchKey("name") {
                propertyListRawKey = try self.decode(String.self)
            }
            else if self.matchKey("required") {
                required = try self.decode(Bool.self)
            }
            else if self.matchKey("role") {
                role = try self.decode(String.self)
            }
            else if self.matchKey("tags") {
                tags = try self.decode([RenderNode.Tag].self)
            }
            // Do nothing for all unknown keys
            else {
                try self.ignoreValue()
            }
        }
        
        // Unwrap all required properties for all reference types
        guard let type else {
            throw self.makeKeyNotFoundError("type")
        }
        guard let identifier else {
            throw self.makeKeyNotFoundError("identifier")
        }
        
        switch type {
        case .image:
            var asset = DataAsset()
            for variant in variants {
                asset.register(variant.url, with: DataTraitCollection(from: variant.traits), metadata: .init(svgID: variant.svgID))
            }
            return ImageReference(
                identifier: consume identifier,
                altText:    consume alt,
                imageAsset: consume asset
            )
        case .video:
            var asset = DataAsset()
            for variant in variants {
                asset.register(variant.url, with: DataTraitCollection(from: variant.traits), metadata: .init(svgID: variant.svgID))
            }
            return VideoReference(
                identifier: consume identifier,
                altText:    consume alt,
                videoAsset: consume asset,
                poster:     consume poster
            )
        case .file:
            guard let fileName else {
                throw self.makeKeyNotFoundError("fileName")
            }
            guard let fileType else {
                throw self.makeKeyNotFoundError("fileType")
            }
            guard let syntax else {
                throw self.makeKeyNotFoundError("syntax")
            }
            guard let content else {
                throw self.makeKeyNotFoundError("content")
            }
            return FileReference(
                identifier: consume identifier,
                fileName:   consume fileName,
                fileType:   consume fileType,
                syntax:     consume syntax,
                content:    consume content,
                highlights: consume highlights
            )
        case .fileType:
            guard let displayName else {
                throw self.makeKeyNotFoundError("displayName")
            }
            guard let iconBase64 else {
                throw self.makeKeyNotFoundError("iconBase64")
            }
            return FileTypeReference(
                identifier:  consume identifier,
                displayName: consume displayName,
                iconBase64:  consume iconBase64
            )
        case .xcodeRequirement:
            guard let title else {
                throw self.makeKeyNotFoundError("title")
            }
            guard let url else {
                throw self.makeKeyNotFoundError("url")
            }
            return XcodeRequirementReference(
                identifier: consume identifier,
                title:      consume title,
                url:        consume url
            )
        case .topic, .section:
            guard let title else {
                throw self.makeKeyNotFoundError("title")
            }
            guard let url else {
                throw self.makeKeyNotFoundError("url")
            }
            
            let propertyListKeyNames: TopicRenderReference.PropertyListKeyNames? =
            if propertyListRawKey != nil || propertyListTitleStyle != nil || propertyListDisplayName != nil {
                .init(
                    titleStyle: propertyListTitleStyle,
                    rawKey: propertyListRawKey,
                    displayName: propertyListDisplayName
                )
            } else {
                nil
            }
            
            return TopicRenderReference(
                identifier:                 consume identifier,
                title:                      consume title,
                abstract:                   consume abstract,
                url:                        url.absoluteString,
                kind:                       consume kind,
                required:                   required,
                role:                       consume role,
                fragments:                  consume fragments,
                navigatorTitle:             consume navigatorTitle,
                estimatedTime:              consume estimatedTime,
                conformance:                consume conformance,
                isBeta:                     isBeta,
                isDeprecated:               isDeprecated,
                defaultImplementationCount: defaultImplementationCount,
                propertyListKeyNames:       consume propertyListKeyNames,
                tags:                       consume tags,
                images:                     consume images
            )
            
        case .download, .externalLocation:
            guard let url else {
                throw self.makeKeyNotFoundError("url")
            }
            return DownloadReference(
                identifier:  consume identifier,
                verbatimURL: consume url,
                checksum:    consume checksum
            )
        case .link:
            guard let url else {
                throw self.makeKeyNotFoundError("url")
            }
            let plainTitle: String
            let formattedTitle: [RenderInlineContent]
            if let title {
                plainTitle     = title
                formattedTitle = titleInlineContent ?? [.text(title)]
            } else if let titleInlineContent {
                plainTitle     = titleInlineContent.plainText
                formattedTitle = titleInlineContent
            } else {
                throw self.makeKeyNotFoundError("title")
            }
            return LinkReference(
                identifier:         consume identifier,
                title:              consume plainTitle,
                titleInlineContent: consume formattedTitle,
                url:                url.absoluteString
            )
        case .unresolvable:
            guard let title else {
                throw self.makeKeyNotFoundError("title")
            }
            return UnresolvedRenderReference(
                identifier: consume identifier,
                title:      consume title
            )
        }
    }
}

extension RenderReferenceType: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let rawValue = try decoder.decode(String.self)
        guard let decoded = Self(rawValue: rawValue) else {
            throw decoder.makeDataCorruptedError(message: "Unknown RenderReferenceType value: '\(rawValue)'")
        }
        self = decoded
    }
}

extension ConformanceSection: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var constraints: _MaybeDecodedValue<[RenderInlineContent]> = nil

        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("constraints") {
                constraints = try decoder.decode([RenderInlineContent].self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let constraints else {
            throw decoder.makeKeyNotFoundError("constraints")
        }

        self.init(constraints: consume constraints)
    }
}

extension LineHighlighter.Highlight: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var line: _MaybeDecodedValue<Int> = nil
        // 2 properties with default values
        var start:  Int? = nil
        var length: Int? = nil

        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("line") {
                line = try decoder.decode(Int.self)
            }
            else if decoder.matchKey("start") {
                start = try decoder.decode(Int.self)
            }
            else if decoder.matchKey("\"length\"", byteOffset: -1) {
                length = try decoder.decode(Int.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let line else {
            throw decoder.makeKeyNotFoundError("line")
        }

        self.init(
            line:   line,
            start:  start,
            length: length
        )
    }
}

extension RenderNode.Kind: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        switch try decoder.decode(String.self) {
            case "symbol":
                self = .symbol
            case "article":
                self = .article
            case "tutorial", "project":
                self = .tutorial
            case "section":
                self = .section
            case "overview":
                self = .overview
            case let unknown:
                throw decoder.makeDataCorruptedError(message: "Unknown RenderNode.Kind value: '\(unknown)'")
        }
    }
}

extension PropertyListTitleStyle: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let rawValue = try decoder.decode(String.self)
        guard let decoded = Self(rawValue: rawValue) else {
            throw decoder.makeDataCorruptedError(message: "Unknown PropertyListTitleStyle value: '\(rawValue)'")
        }
        self = decoded
    }
}

extension RenderNode.Tag: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 2 required property
        var type: _MaybeDecodedValue<String> = nil
        var text: _MaybeDecodedValue<String> = nil

        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("type") {
                type = try decoder.decode(String.self)
            }
            else if decoder.matchKey("text") {
                text = try decoder.decode(String.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let type else {
            throw decoder.makeKeyNotFoundError("type")
        }
        guard let text else {
            throw decoder.makeKeyNotFoundError("text")
        }

        self.init(
            type: consume type,
            text: consume text
        )
    }
}


extension RenderNode.Variant.Trait: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var interfaceLanguage: _MaybeDecodedValue<String> = nil

        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("interfaceLanguage") {
                interfaceLanguage = try decoder.decode(String.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let interfaceLanguage else {
            throw decoder.makeKeyNotFoundError("interfaceLanguage")
        }
        
        self = .interfaceLanguage(interfaceLanguage)
    }
}

extension ImageReference.VariantProxy: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 2 required properties
        var url:    _MaybeDecodedValue<URL>      = nil
        var traits: _MaybeDecodedValue<[String]> = nil
        // 1 property with a default value
        var svgID: String? = nil

        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("url\"") {
                url = try decoder.decode(URL.self)
            }
            else if decoder.matchKey("\"traits\"", byteOffset: -1) {
                traits = try decoder.decode([String].self)
            }
            else if decoder.matchKey("svgID") {
                svgID = try decoder.decode(String.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let url else {
            throw decoder.makeKeyNotFoundError("url")
        }
        guard let traits else {
            throw decoder.makeKeyNotFoundError("traits")
        }
        
        self.init(
            url:    consume url,
            traits: .init(from: consume traits),
            svgID:  consume svgID
        )
    }
}
