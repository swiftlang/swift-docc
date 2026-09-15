/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

private import Foundation
private import SymbolKit

// MARK: Decoding conformances

extension SymbolGraph: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 4 required properties
        var metadata:      _MaybeDecodedValue<Metadata>       = nil
        var module:        _MaybeDecodedValue<Module>         = nil
        var symbols:       _MaybeDecodedValue<[Symbol]>       = nil
        var relationships: _MaybeDecodedValue<[Relationship]> = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("metadata") {
                metadata = try decoder.decode(Metadata.self)
            }
            else if decoder.matchKey("symbols\"") {
                symbols = try decoder.decode([Symbol].self)
            }
            else if decoder.matchKey("\"module\"", byteOffset: -1) {
                module = try decoder.decode(Module.self)
            }
            else if decoder.matchKey("relationships") {
                relationships = try decoder.decode([Relationship].self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let metadata else {
            throw decoder.makeKeyNotFoundError("metadata")
        }
        guard let module else {
            throw decoder.makeKeyNotFoundError("module")
        }
        guard let symbols else {
            throw decoder.makeKeyNotFoundError("symbols")
        }
        guard let relationships else {
            throw decoder.makeKeyNotFoundError("relationships")
        }

        self.init(
            metadata:      consume metadata,
            module:        consume module,
            symbols:       consume symbols,
            relationships: consume relationships
        )
    }
}

extension SymbolGraph.Metadata: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 2 required properties
        var formatVersion: _MaybeDecodedValue<SymbolGraph.SemanticVersion> = nil
        var generator:     _MaybeDecodedValue<String>                      = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("generator") {
                generator = try decoder.decode(String.self)
            }
            else if decoder.matchKey("formatVersion") {
                formatVersion = try decoder.decode(SymbolGraph.SemanticVersion.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let formatVersion else {
            throw decoder.makeKeyNotFoundError("formatVersion")
        }
        guard let generator else {
            throw decoder.makeKeyNotFoundError("generator")
        }

        self.init(
            formatVersion: consume formatVersion,
            generator:     consume generator
        )
    }
}

extension SymbolGraph.SemanticVersion: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var major: _MaybeDecodedValue<Int> = nil
        // 4 properties with default values
        var minor:         Int     = 0
        var patch:         Int     = 0
        var prerelease:    String? = nil
        var buildMetadata: String? = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("major") {
                major = try decoder.decode(Int.self)
            }
            else if decoder.matchKey("minor") {
                minor = try decoder.decode(Int.self)
            }
            else if decoder.matchKey("patch") {
                patch = try decoder.decode(Int.self)
            }
            else if decoder.matchKey("prerelease") {
                prerelease = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("buildMetadata") {
                buildMetadata = try decoder.decode(String?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap the required property
        guard let major else {
            throw decoder.makeKeyNotFoundError("major")
        }

        self.init(
            major:         major,
            minor:         minor,
            patch:         patch,
            prerelease:    consume prerelease,
            buildMetadata: consume buildMetadata
        )
    }
}

extension SymbolGraph.Module: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 2 required properties
        var name:     _MaybeDecodedValue<String>               = nil
        var platform: _MaybeDecodedValue<SymbolGraph.Platform> = nil
        // 3 properties with default values
        var version:    SymbolGraph.SemanticVersion? = nil
        var bystanders: [String]?                    = nil
        var isVirtual:  Bool                         = false

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("name") {
                name = try decoder.decode(String.self)
            }
            else if decoder.matchKey("platform") {
                platform = try decoder.decode(SymbolGraph.Platform.self)
            }
            else if decoder.matchKey("version\"") {
                version = try decoder.decode(SymbolGraph.SemanticVersion?.self)
            }
            else if decoder.matchKey("isVirtual") {
                isVirtual = try decoder.decode(Bool.self)
            }
            else if decoder.matchKey("bystanders") {
                bystanders = try decoder.decode([String]?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let name else {
            throw decoder.makeKeyNotFoundError("name")
        }
        guard let platform else {
            throw decoder.makeKeyNotFoundError("platform")
        }

        self.init(
            name:       consume name,
            platform:   consume platform,
            version:    consume version,
            bystanders: consume bystanders,
            isVirtual:  isVirtual
        )
    }
}

extension SymbolGraph.Platform: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        // 4 properties with default values
        var architecture:    String?                      = nil
        var vendor:          String?                      = nil
        var operatingSystem: SymbolGraph.OperatingSystem? = nil
        var environment:     String?                      = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("\"vendor\"", byteOffset: -1) {
                vendor = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("architecture") {
                architecture = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("environment") {
                environment = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("operatingSystem") {
                operatingSystem = try decoder.decode(SymbolGraph.OperatingSystem?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // No required properties to unwrap

        self.init(
            architecture:    consume architecture,
            vendor:          consume vendor,
            operatingSystem: consume operatingSystem,
            environment:     consume environment
        )
    }
}

extension SymbolGraph.OperatingSystem: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var name: _MaybeDecodedValue<String> = nil
        // 1 property with a default value
        var minimumVersion: SymbolGraph.SemanticVersion? = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("name") {
                name = try decoder.decode(String.self)
            }
            else if decoder.matchKey("minimumVersion") {
                minimumVersion = try decoder.decode(SymbolGraph.SemanticVersion?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap the required property
        guard let name else {
            throw decoder.makeKeyNotFoundError("name")
        }

        self.init(
            name:           consume name,
            minimumVersion: consume minimumVersion
        )
    }
}

extension SymbolGraph.Relationship: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 3 required properties
        var source: _MaybeDecodedValue<String> = nil
        var target: _MaybeDecodedValue<String> = nil
        var kind:   _MaybeDecodedValue<Kind>   = nil
        // 1 property with a default value
        var targetFallback: String? = nil
        
        var mixins: [String: any Mixin] = [:]

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            // kind
            if decoder.matchKey("kind") {
                kind = try decoder.decode(Kind.self)
            }
            // source (decoded as "source"")
            else if decoder.matchKey("\"source\"", byteOffset: -1) {
                source = try decoder.decode(String.self)
            }
            // target (decoded as "target"")
            else if decoder.matchKey("\"target\"", byteOffset: -1) {
                target = try decoder.decode(String.self)
            }
            // sourceOrigin
            else if decoder.matchKey("sourceOrigin") {
                mixins["sourceOrigin"] = try decoder.decode(SourceOrigin.self)
            }
            // swiftConstraints
            else if decoder.matchKey("swiftConstraints") {
                let decoded = try decoder.decode([SymbolGraph.Symbol.Swift.GenericConstraint].self)
                mixins["swiftConstraints"] = SymbolGraph.Relationship.Swift.GenericConstraints(constraints: consume decoded)
            }
            // targetFallback
            else if decoder.matchKey("targetFallback") {
                targetFallback = try decoder.decode(String?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let source else {
            throw decoder.makeKeyNotFoundError("source")
        }
        guard let target else {
            throw decoder.makeKeyNotFoundError("target")
        }
        guard let kind else {
            throw decoder.makeKeyNotFoundError("kind")
        }
        
        self.init(
            source:         consume source,
            target:         consume target,
            kind:           consume kind,
            targetFallback: consume targetFallback
        )
        self.mixins = consume mixins
    }
}

extension SymbolGraph.Relationship.Kind: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let rawValue = try decoder.decode(RawValue.self)
        self = .init(rawValue: consume rawValue)
    }
}

extension SymbolGraph.Relationship.SourceOrigin: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 2 required properties
        var identifier:  _MaybeDecodedValue<String> = nil
        var displayName: _MaybeDecodedValue<String> = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("identifier") {
                identifier = try decoder.decode(String.self)
            }
            else if decoder.matchKey("displayName") {
                displayName = try decoder.decode(String.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let identifier else {
            throw decoder.makeKeyNotFoundError("identifier")
        }
        guard let displayName else {
            throw decoder.makeKeyNotFoundError("displayName")
        }

        self.init(
            identifier:  consume identifier,
            displayName: consume displayName
        )
    }
}

extension SymbolGraph.Symbol: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 5 required properties to decode
        var identifier:     _MaybeDecodedValue<Identifier>    = nil
        var kind:           _MaybeDecodedValue<Kind>          = nil
        var pathComponents: _MaybeDecodedValue<[String]>      = nil
        var names:          _MaybeDecodedValue<Names>         = nil
        var accessLevel:    _MaybeDecodedValue<AccessControl> = nil
        // 3 properties with default values
        var type:       String?               = nil
        var docComment: SymbolGraph.LineList? = nil
        var isVirtual:  Bool                  = false
        
        var mixins: [String: any Mixin] = [:]

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            // Dedicated properties
            if decoder.matchKey("kind") {
                kind = try decoder.decode(Kind.self)
            }
            else if decoder.matchKey("pathComponents") {
                pathComponents = try decoder.decode([String].self)
            }
            else if decoder.matchKey("docComment") {
                docComment = try decoder.decode(SymbolGraph.LineList?.self)
            }
            else if decoder.matchKey("identifier") {
                identifier = try decoder.decode(Identifier.self)
            }
            else if decoder.matchKey("accessLevel") {
                accessLevel = try decoder.decode(AccessControl.self)
            }
            else if decoder.matchKey("isVirtual") {
                isVirtual = try decoder.decode(Bool.self)
            }
            else if decoder.matchKey("names") {
                names = try decoder.decode(Names.self)
            }
            else if decoder.matchKey("type\"") {
                type = try decoder.decode(String?.self)
            }
            // Mixins
            else if decoder.matchKey("location") {
                mixins["location"] = try decoder.decode(Location.self)
            }
            else if decoder.matchKey("isReadOnly") {
                let decoded = try decoder.decode(Bool.self)
                mixins["isReadOnly"] = Mutability(isReadOnly: decoded)
            }
            else if decoder.matchKey("availability") {
                let decoded = try decoder.decode([Availability.AvailabilityItem].self)
                mixins["availability"] = Availability(availability: consume decoded)
            }
            else if decoder.matchKey("declarationFragments") {
                let decoded = try decoder.decode([DeclarationFragments.Fragment].self)
                mixins["declarationFragments"] = DeclarationFragments(declarationFragments: consume decoded)
            }
            else if decoder.matchKey("functionSignature") {
                mixins["functionSignature"] = try decoder.decode(FunctionSignature.self)
            }
            else if decoder.matchKey("alternateSymbols") {
                mixins["alternateSymbols"] = try decoder.decode(AlternateSymbols.self)
            }
            else if decoder.matchKey("swiftGenerics") {
                mixins["swiftGenerics"] = try decoder.decode(Swift.Generics.self)
            }
            else if decoder.matchKey("swiftExtension") {
                mixins["swiftExtension"] = try decoder.decode(Swift.Extension.self)
            }
            else if decoder.matchKey("alternateDeclarations") {
                let decoded = try decoder.decode([DeclarationFragments].self)
                // Special case to match SymbolKit. Alternate _declarations_ are decoded as alternate _symbols_.
                var alternate = AlternateSymbols(alternateSymbols: [])
                for fragments in decoded {
                    alternate.alternateSymbols.append(.init(declarationFragments: consume fragments))
                }
                mixins["alternateSymbols"] = alternate
            }
            else if decoder.matchKey("spi\"") {
                let decoded = try decoder.decode(Bool.self)
                mixins["spi"] = SPI(isSPI: decoded)
            }
            else if decoder.matchKey("overloadData") {
                mixins["overloadData"] = try decoder.decode(OverloadData.self)
            }
            else if decoder.matchKey("snippet\"") {
                mixins["snippet"] = try decoder.decode(Snippet.self)
            }
            else if decoder.matchKey("plistDetails") {
                mixins["plistDetails"] = try decoder.decode(PlistDetails.self)
            }
            else if decoder.matchKey("httpEndpoint") {
                mixins["httpEndpoint"] = try decoder.decode(HTTP.Endpoint.self)
            }
            else if decoder.matchKey("httpParameterSource") {
                let decoded = try decoder.decode(String.self)
                mixins["httpParameterSource"] = HTTP.ParameterSource(consume decoded)
            }
            else if decoder.matchKey("httpMediaType") {
                let decoded = try decoder.decode(String.self)
                mixins["httpMediaType"] = HTTP.MediaType(consume decoded)
            }
            else if decoder.matchKey("minimum\"") {
                let decoded = try decoder.decode(SymbolGraph.AnyNumber.self)
                mixins["minimum"] = Minimum(consume decoded)
            }
            else if decoder.matchKey("maximum\"") {
                let decoded = try decoder.decode(SymbolGraph.AnyNumber.self)
                mixins["maximum"] = Maximum(consume decoded)
            }
            else if decoder.matchKey("minimumExclusive") {
                let decoded = try decoder.decode(SymbolGraph.AnyNumber.self)
                mixins["minimumExclusive"] = MinimumExclusive(consume decoded)
            }
            else if decoder.matchKey("maximumExclusive") {
                let decoded = try decoder.decode(SymbolGraph.AnyNumber.self)
                mixins["maximumExclusive"] = MaximumExclusive(consume decoded)
            }
            else if decoder.matchKey("minimumLength") {
                let decoded = try decoder.decode(Int.self)
                mixins["minimumLength"] = MinimumLength(decoded)
            }
            else if decoder.matchKey("maximumLength") {
                let decoded = try decoder.decode(Int.self)
                mixins["maximumLength"] = MaximumLength(decoded)
            }
            else if decoder.matchKey("allowedValues") {
                let decoded = try decoder.decode([SymbolGraph.AnyScalar].self)
                mixins["allowedValues"] = AllowedValues(consume decoded)
            }
            else if decoder.matchKey("default\"") {
                let decoded = try decoder.decode(SymbolGraph.AnyScalar.self)
                mixins["default"] = DefaultValue(consume decoded)
            }
            else if decoder.matchKey("typeDetails") {
                let decoded = try decoder.decode([TypeDetail].self)
                mixins["typeDetails"] = TypeDetails(consume decoded)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let identifier else {
            throw decoder.makeKeyNotFoundError("identifier")
        }
        guard let kind else {
            throw decoder.makeKeyNotFoundError("kind")
        }
        guard let pathComponents else {
            throw decoder.makeKeyNotFoundError("pathComponents")
        }
        guard let names else {
            throw decoder.makeKeyNotFoundError("names")
        }
        guard let accessLevel else {
            throw decoder.makeKeyNotFoundError("accessLevel")
        }
                
        self.init(
            identifier:     consume identifier,
            names:          consume names,
            pathComponents: consume pathComponents,
            docComment:     consume docComment,
            accessLevel:    consume accessLevel,
            kind:           consume kind,
            mixins:         consume mixins,
            isVirtual:      isVirtual
        )
        self.type = consume type
    }
}

extension SymbolGraph.Symbol.Identifier: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 2 required properties
        var precise:           _MaybeDecodedValue<String> = nil
        var interfaceLanguage: _MaybeDecodedValue<String> = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("precise\"") {
                precise = try decoder.decode(String.self)
            }
            else if decoder.matchKey("interfaceLanguage") {
                interfaceLanguage = try decoder.decode(String.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let precise else {
            throw decoder.makeKeyNotFoundError("precise")
        }
        guard let interfaceLanguage else {
            throw decoder.makeKeyNotFoundError("interfaceLanguage")
        }

        self.init(
            precise:           consume precise,
            interfaceLanguage: consume interfaceLanguage
        )
    }
}

extension SymbolGraph.Symbol.Kind: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 2 required properties
        var identifier:  _MaybeDecodedValue<String> = nil
        var displayName: _MaybeDecodedValue<String> = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("identifier") {
                identifier = try decoder.decode(String.self)
            }
            else if decoder.matchKey("displayName") {
                displayName = try decoder.decode(String.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let identifier else {
            throw decoder.makeKeyNotFoundError("identifier")
        }
        guard let displayName else {
            throw decoder.makeKeyNotFoundError("displayName")
        }
        
        self.init(
            rawIdentifier: consume identifier,
            displayName:   consume displayName
        )
    }
}

extension SymbolGraph.Symbol.KindIdentifier: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let rawValue = try decoder.decode(String.self)
        self = .init(identifier: consume rawValue)
    }
}

extension SymbolGraph.Symbol.Names: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var title: _MaybeDecodedValue<String> = nil
        // 3 properties with default values
        var navigator:  [SymbolGraph.Symbol.DeclarationFragments.Fragment]? = nil
        var subHeading: [SymbolGraph.Symbol.DeclarationFragments.Fragment]? = nil
        var prose:      String?                                             = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("title") {
                title = try decoder.decode(String.self)
            }
            else if decoder.matchKey("navigator") {
                navigator = try decoder.decode([SymbolGraph.Symbol.DeclarationFragments.Fragment]?.self)
            }
            else if decoder.matchKey("subHeading") {
                subHeading = try decoder.decode([SymbolGraph.Symbol.DeclarationFragments.Fragment]?.self)
            }
            else if decoder.matchKey("prose") {
                prose = try decoder.decode(String?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap the required property
        guard let title else {
            throw decoder.makeKeyNotFoundError("title")
        }

        self.init(
            title:      consume title,
            navigator:  consume navigator,
            subHeading: consume subHeading,
            prose:      consume prose
        )
    }
}

extension SymbolGraph.Symbol.DeclarationFragments: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        self.init(declarationFragments: try decoder.decode([Fragment].self))
    }
}

extension SymbolGraph.Symbol.DeclarationFragments.Fragment: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 2 required properties
        var kind:     _MaybeDecodedValue<Kind>   = nil
        var spelling: _MaybeDecodedValue<String> = nil
        // 1 property with a default values
        var preciseIdentifier: String? = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("kind") {
                kind = try decoder.decode(Kind.self)
            }
            else if decoder.matchKey("spelling") {
                spelling = try decoder.decode(String.self)
            }
            else if decoder.matchKey("preciseIdentifier") {
                preciseIdentifier = try decoder.decode(String?.self)
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
        guard let spelling else {
            throw decoder.makeKeyNotFoundError("spelling")
        }

        self.init(
            kind:              consume kind,
            spelling:          consume spelling,
            preciseIdentifier: consume preciseIdentifier
        )
    }
}

extension SymbolGraph.Symbol.DeclarationFragments.Fragment.Kind: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let rawValue = try decoder.decode(String.self)
        self = .init(rawValue: consume rawValue)!
    }
}

extension SymbolGraph.LineList: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var lines: _MaybeDecodedValue<[Line]> = nil
        // 2 properties with default values
        var uri:        String? = nil
        var moduleName: String? = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("uri\"") {
                uri = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("lines") {
                lines = try decoder.decode([Line].self)
            }
            else if decoder.matchKey("\"module\"", byteOffset: -1) {
                moduleName = try decoder.decode(String?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap the required property
        guard let lines else {
            throw decoder.makeKeyNotFoundError("lines")
        }
        
        self.init(
            consume lines,
            uri:        consume uri,
            moduleName: consume moduleName
        )
    }
}

extension SymbolGraph.LineList.Line: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var text: _MaybeDecodedValue<String> = nil
        // 1 property with a default value
        var range: SymbolGraph.LineList.SourceRange? = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("text") {
                text = try decoder.decode(String.self)
            }
            else if decoder.matchKey("range") {
                range = try decoder.decode(SymbolGraph.LineList.SourceRange?.self)
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
        
        self.init(
            text:  consume text,
            range: consume range
        )
    }
}

extension SymbolGraph.LineList.SourceRange: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // The 2 "uninitialized" properties to decode
        var start: _MaybeDecodedValue<Position> = nil
        var end:   _MaybeDecodedValue<Position> = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("end\"") {
                end = try decoder.decode(Position.self)
            }
            else if decoder.matchKey("start") {
                start = try decoder.decode(Position.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let start else {
            throw decoder.makeKeyNotFoundError("start")
        }
        guard let end else {
            throw decoder.makeKeyNotFoundError("end")
        }

        self.init(
            start: consume start,
            end:   consume end
        )
    }
}

extension SymbolGraph.LineList.SourceRange.Position: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // The 2 "uninitialized" properties to decode
        var line:      _MaybeDecodedValue<Int> = nil
        var character: _MaybeDecodedValue<Int> = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("line") {
                line = try decoder.decode(Int.self)
            }
            else if decoder.matchKey("character") {
                character = try decoder.decode(Int.self)
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
        guard let character else {
            throw decoder.makeKeyNotFoundError("character")
        }

        self.init(
            line:      line,
            character: character
        )
    }
}

extension SymbolGraph.Symbol.AccessControl: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let rawValue = try decoder.decode(String.self)
        self = .init(rawValue: consume rawValue)
    }
}

extension SymbolGraph.Symbol.Availability.AvailabilityItem: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        // 9 properties with default values
        var domain:                       SymbolGraph.Symbol.Availability.Domain? = nil
        var introducedVersion:            SymbolGraph.SemanticVersion?            = nil
        var deprecatedVersion:            SymbolGraph.SemanticVersion?            = nil
        var obsoletedVersion:             SymbolGraph.SemanticVersion?            = nil
        var message:                      String?                                 = nil
        var renamed:                      String?                                 = nil
        var isUnconditionallyDeprecated:  Bool                                    = false
        var isUnconditionallyUnavailable: Bool                                    = false
        var willEventuallyBeDeprecated:   Bool                                    = false

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("message\"") {
                message = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("renamed\"") {
                renamed = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("\"domain\"", byteOffset: -1) {
                let decoded = try decoder.decode(String?.self)
                // March the availability item's custom decoding logic for domains.
                if let decoded, decoded != "*" {
                    domain = .init(rawValue: consume decoded)
                } else {
                    domain = nil
                }
            }
            else if decoder.matchKey("obsoleted") {
                obsoletedVersion = try decoder.decode(SymbolGraph.SemanticVersion?.self)
            }
            else if decoder.matchKey("deprecated") {
                deprecatedVersion = try decoder.decode(SymbolGraph.SemanticVersion?.self)
            }
            else if decoder.matchKey("introduced") {
                introducedVersion = try decoder.decode(SymbolGraph.SemanticVersion?.self)
            }
            else if decoder.matchKey("willEventuallyBeDeprecated") {
                willEventuallyBeDeprecated = try decoder.decode(Bool.self)
            }
            else if decoder.matchKey("isUnconditionallyDeprecated") {
                isUnconditionallyDeprecated = try decoder.decode(Bool.self)
            }
            else if decoder.matchKey("isUnconditionallyUnavailable") {
                isUnconditionallyUnavailable = try decoder.decode(Bool.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // No required properties to unwrap

        self.init(
            domain:                       consume domain,
            introducedVersion:            consume introducedVersion,
            deprecatedVersion:            consume deprecatedVersion,
            obsoletedVersion:             consume obsoletedVersion,
            message:                      consume message,
            renamed:                      consume renamed,
            isUnconditionallyDeprecated:  isUnconditionallyDeprecated,
            isUnconditionallyUnavailable: isUnconditionallyUnavailable,
            willEventuallyBeDeprecated:   willEventuallyBeDeprecated
        )
    }
}

extension SymbolGraph.Symbol.FunctionSignature: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        // 2 properties with default values
        var parameters: [FunctionParameter]                                = []
        var returns:    [SymbolGraph.Symbol.DeclarationFragments.Fragment] = []

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("returns\"") {
                returns = try decoder.decode([SymbolGraph.Symbol.DeclarationFragments.Fragment].self)
            }
            else if decoder.matchKey("parameters") {
                parameters = try decoder.decode([FunctionParameter].self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // No required properties to unwrap

        self.init(
            parameters: consume parameters,
            returns:    consume returns
        )
    }
}

extension SymbolGraph.Symbol.FunctionSignature.FunctionParameter: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var name: _MaybeDecodedValue<String> = nil
        // 4 properties with default values
        var externalName:         String?                                            = nil
        var internalName:         String?                                            = nil
        var declarationFragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment] = []
        var children:             [Self]                                             = []

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("name") {
                name = try decoder.decode(String.self)
            }
            else if decoder.matchKey("children") {
                children = try decoder.decode([Self].self)
            }
            else if decoder.matchKey("externalName") {
                externalName = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("internalName") {
                internalName = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("declarationFragments") {
                declarationFragments = try decoder.decode([SymbolGraph.Symbol.DeclarationFragments.Fragment].self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let name else {
            throw decoder.makeKeyNotFoundError("name")
        }
            
        if let internalName {
            self.init(
                name:                 consume internalName,
                externalName:         consume name,
                declarationFragments: consume declarationFragments,
                children:             consume children
            )
        } else {
            self.init(
                name:                 consume name,
                externalName:         consume externalName,
                declarationFragments: consume declarationFragments,
                children:             consume children
            )
        }
    }
}

extension SymbolGraph.Symbol.Location: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 2 required properties
        var uri:      _MaybeDecodedValue<String>                                    = nil
        var position: _MaybeDecodedValue<SymbolGraph.LineList.SourceRange.Position> = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("position") {
                position = try decoder.decode(SymbolGraph.LineList.SourceRange.Position.self)
            }
            else if decoder.matchKey("uri\"") {
                uri = try decoder.decode(String.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let uri else {
            throw decoder.makeKeyNotFoundError("uri")
        }
        guard let position else {
            throw decoder.makeKeyNotFoundError("position")
        }

        self.init(
            uri:      consume uri,
            position: consume position
        )
    }
}

extension SymbolGraph.Symbol.Swift.Extension: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var extendedModule: _MaybeDecodedValue<String> = nil
        // 2 properties with default values
        var typeKind:    SymbolGraph.Symbol.KindIdentifier?           = nil
        var constraints: [SymbolGraph.Symbol.Swift.GenericConstraint] = []

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("typeKind") {
                typeKind = try decoder.decode(SymbolGraph.Symbol.KindIdentifier?.self)
            }
            else if decoder.matchKey("extendedModule") {
                extendedModule = try decoder.decode(String.self)
            }
            else if decoder.matchKey("constraints") {
                constraints = try decoder.decode([SymbolGraph.Symbol.Swift.GenericConstraint].self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap the required property
        guard let extendedModule else {
            throw decoder.makeKeyNotFoundError("extendedModule")
        }

        self.init(
            extendedModule: consume extendedModule,
            typeKind:       consume typeKind,
            constraints:    consume constraints
        )
    }
}

extension SymbolGraph.Symbol.Swift.GenericConstraint: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // The 3 "uninitialized" properties to decode
        var kind:          _MaybeDecodedValue<Kind>   = nil
        var leftTypeName:  _MaybeDecodedValue<String> = nil
        var rightTypeName: _MaybeDecodedValue<String> = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("kind") {
                kind = try decoder.decode(Kind.self)
            }
            else if decoder.matchKey("lhs\"") {
                leftTypeName = try decoder.decode(String.self)
            }
            else if decoder.matchKey("rhs\"") {
                rightTypeName = try decoder.decode(String.self)
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
        guard let leftTypeName else {
            throw decoder.makeKeyNotFoundError("lhs")
        }
        guard let rightTypeName else {
            throw decoder.makeKeyNotFoundError("rhs")
        }

        self.init(
            kind:          consume kind,
            leftTypeName:  consume leftTypeName,
            rightTypeName: consume rightTypeName
        )
    }
}

extension SymbolGraph.Symbol.Swift.GenericConstraint.Kind: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let rawValue = try decoder.decode(String.self)
        self = .init(rawValue: consume rawValue)!
    }
}

extension SymbolGraph.Symbol.Swift.Generics: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        // 2 properties with default values
        var parameters:  [SymbolGraph.Symbol.Swift.GenericParameter]  = []
        var constraints: [SymbolGraph.Symbol.Swift.GenericConstraint] = []

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("parameters") {
                parameters = try decoder.decode([SymbolGraph.Symbol.Swift.GenericParameter].self)
            }
            else if decoder.matchKey("constraints") {
                constraints = try decoder.decode([SymbolGraph.Symbol.Swift.GenericConstraint].self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // No required properties to unwrap

        self.init(
            parameters:  consume parameters,
            constraints: consume constraints
        )
    }
}

extension SymbolGraph.Symbol.Swift.GenericParameter: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 3 required properties
        var name:  _MaybeDecodedValue<String> = nil
        var index: _MaybeDecodedValue<Int>    = nil
        var depth: _MaybeDecodedValue<Int>    = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("name") {
                name = try decoder.decode(String.self)
            }
            else if decoder.matchKey("depth") {
                depth = try decoder.decode(Int.self)
            }
            else if decoder.matchKey("index") {
                index = try decoder.decode(Int.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let name else {
            throw decoder.makeKeyNotFoundError("name")
        }
        guard let index else {
            throw decoder.makeKeyNotFoundError("index")
        }
        guard let depth else {
            throw decoder.makeKeyNotFoundError("depth")
        }

        self.init(
            name:  consume name,
            index: index,
            depth: depth
        )
    }
}

extension SymbolGraph.Symbol.AlternateSymbols: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var alternateSymbols: _MaybeDecodedValue<[AlternateSymbol]> = nil

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            // alternateSymbols
            if decoder.matchKey("alternateSymbols") {
                alternateSymbols = try decoder.decode([AlternateSymbol].self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap the required property
        guard let alternateSymbols else {
            throw decoder.makeKeyNotFoundError("alternateSymbols")
        }

        self.init(
            alternateSymbols: consume alternateSymbols
        )
    }
}

extension SymbolGraph.Symbol.AlternateSymbols.AlternateSymbol: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        // 1 property with a default value
        var docComment: SymbolGraph.LineList? = nil
        
        var mixins: [String: any Mixin] = [:]

        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("docComment") {
                docComment = try decoder.decode(SymbolGraph.LineList?.self)
            }
            else if decoder.matchKey("functionSignature") {
                mixins["functionSignature"] = try decoder.decode(SymbolGraph.Symbol.FunctionSignature.self)
            }
            else if decoder.matchKey("declarationFragments") {
                let decoded = try decoder.decode([SymbolGraph.Symbol.DeclarationFragments.Fragment].self)
                mixins["declarationFragments"] = SymbolGraph.Symbol.DeclarationFragments(declarationFragments: consume decoded)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // No required properties to unwrap
        
        self.init(
            docComment: consume docComment,
            mixins:     consume mixins
        )
    }
}

extension SymbolGraph.Symbol.OverloadData: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional
        
        // 2 required properties
        var overloadGroupIdentifier: _MaybeDecodedValue<String> = nil
        var overloadGroupIndex:      _MaybeDecodedValue<Int>    = nil
        
        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("overloadGroupIdentifier") {
                overloadGroupIdentifier = try decoder.decode(String.self)
            }
            else if decoder.matchKey("overloadGroupIndex") {
                overloadGroupIndex = try decoder.decode(Int.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }
        
        // Unwrap all required properties
        guard let overloadGroupIdentifier else {
            throw decoder.makeKeyNotFoundError("overloadGroupIdentifier")
        }
        guard let overloadGroupIndex else {
            throw decoder.makeKeyNotFoundError("overloadGroupIndex")
        }
        
        self.init(
            overloadGroupIdentifier: consume overloadGroupIdentifier,
            overloadGroupIndex:      overloadGroupIndex
        )
    }
}

extension SymbolGraph.Symbol.Snippet: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional
        
        // 1 required property
        var lines: _MaybeDecodedValue<[String]> = nil
        // 2 properties with default values
        var language: String?              = nil
        var slices:   [String: Range<Int>] = [:]
        
        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("lines") {
                lines = try decoder.decode([String].self)
            }
            else if decoder.matchKey("language") {
                language = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("\"slices\"", byteOffset: -1) {
                slices = try decoder.decode([String: Range<Int>].self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }
        
        // Unwrap the required property
        guard let lines else {
            throw decoder.makeKeyNotFoundError("lines")
        }
        
        self.init(
            language: consume language,
            lines:    consume lines,
            slices:   consume slices
        )
    }
}

extension SymbolGraph.Symbol.PlistDetails: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional
        
        // 1 required property
        var rawKey: _MaybeDecodedValue<String> = nil
        // 3 properties with default values
        var customTitle: String? = nil
        var baseType:    String? = nil
        var arrayMode:   Bool?   = nil
        
        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("\"rawKey\"", byteOffset: -1) {
                rawKey = try decoder.decode(String.self)
            }
            else if decoder.matchKey("customTitle") {
                customTitle = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("baseType") {
                baseType = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("arrayMode") {
                arrayMode = try decoder.decode(Bool?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }
        
        // Unwrap the required property
        guard let rawKey else {
            throw decoder.makeKeyNotFoundError("rawKey")
        }
        
        self.init(
            rawKey:      consume rawKey,
            customTitle: consume customTitle,
            baseType:    consume baseType,
            arrayMode:   arrayMode
        )
    }
}

extension SymbolGraph.Symbol.HTTP.Endpoint: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional
        
        // 3 required properties
        var method:  _MaybeDecodedValue<String> = nil
        var baseURL: _MaybeDecodedValue<URL>    = nil
        var path:    _MaybeDecodedValue<String> = nil
        // 1 property with a default value
        var sandboxURL: URL? = nil
        
        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("path") {
                path = try decoder.decode(String.self)
            }
            else if decoder.matchKey("baseURL\"") {
                baseURL = try decoder.decode(URL.self)
            }
            else if decoder.matchKey("\"method\"", byteOffset: -1) {
                method = try decoder.decode(String.self)
            }
            else if decoder.matchKey("sandboxURL") {
                sandboxURL = try decoder.decode(URL?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }
        
        // Unwrap the required property
        guard let method else {
            throw decoder.makeKeyNotFoundError("method")
        }
        guard let baseURL else {
            throw decoder.makeKeyNotFoundError("baseURL")
        }
        guard let path else {
            throw decoder.makeKeyNotFoundError("path")
        }
        
        self.init(
            method:     consume method,
            baseURL:    consume baseURL,
            sandboxURL: consume sandboxURL,
            path:       consume path
        )
    }
}

extension SymbolGraph.Symbol.TypeDetail: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        // 3 property with default values
        var fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]? = nil
        var baseType:  String?                                             = nil
        var arrayMode: Bool?                                               = nil
        
        // Decode each field of this JSON object in the order they appear in the data
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("baseType") {
                baseType = try decoder.decode(String?.self)
            }
            else if decoder.matchKey("fragments") {
                fragments = try decoder.decode([SymbolGraph.Symbol.DeclarationFragments.Fragment]?.self)
            }
            else if decoder.matchKey("arrayMode") {
                arrayMode = try decoder.decode(Bool?.self)
            }
            
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }
        
        // No required property to unwrap
        
        self.init(
            fragments: consume fragments,
            baseType:  consume baseType,
            arrayMode: arrayMode
        )
    }
}
