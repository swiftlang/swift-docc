/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import DocCCommon

extension OutOfProcessReferenceResolver.ResponseV2: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        // The kind of response depends on what information we decode.
        var identifier:   String?                                     = nil
        var capabilities: OutOfProcessReferenceResolver.Capabilities? = nil
        var failure:      DiagnosticInformation?                      = nil
        var resolved:     LinkDestinationSummary?                     = nil
        
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("identifier") {
                identifier = try decoder.decode(String.self)
            }
            else if decoder.matchKey("capabilities") {
                capabilities = try decoder.decode(OutOfProcessReferenceResolver.Capabilities.self)
            }
            else if decoder.matchKey("failure\"") {
                failure = try decoder.decode(DiagnosticInformation.self)
            }
            else if decoder.matchKey("resolved") {
                resolved = try decoder.decode(LinkDestinationSummary.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        if let resolved {
            self = .resolved(resolved)
        }
        else if let failure {
            self = .failure(failure)
        }
        else {
            guard let identifier else {
                throw decoder.makeKeyNotFoundError("identifier")
            }
            guard let capabilities else {
                throw decoder.makeKeyNotFoundError("capabilities")
            }
            self = .identifierAndCapabilities(.init(rawValue: identifier), capabilities)
        }
    }
}

extension OutOfProcessReferenceResolver.Capabilities: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let decoded = try decoder.decode(Int.self)
        self.init(rawValue: decoded)
    }
}

extension OutOfProcessReferenceResolver.ResponseV2.DiagnosticInformation: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var summary: _MaybeDecodedValue<String> = nil
        // 1 property with a default value
        var solutions: [Solution]? = nil
        
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("summary\"") {
                summary = try decoder.decode(String.self)
            }
            else if decoder.matchKey("solutions") {
                solutions = try decoder.decode([Solution]?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let summary else {
            throw decoder.makeKeyNotFoundError("summary")
        }
        
        self.init(
            summary:   consume summary,
            solutions: consume solutions
        )
    }
}

extension OutOfProcessReferenceResolver.ResponseV2.DiagnosticInformation.Solution: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        typealias _MaybeDecodedValue = Optional

        // 1 required property
        var summary: _MaybeDecodedValue<String> = nil
        // 1 property with a default value
        var replacement: String? = nil
        
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("summary\"") {
                summary = try decoder.decode(String.self)
            }
            else if decoder.matchKey("replacement") {
                replacement = try decoder.decode(String?.self)
            }
            // Do nothing for all unknown keys
            else {
                try decoder.ignoreValue()
            }
        }

        // Unwrap all required properties
        guard let summary else {
            throw decoder.makeKeyNotFoundError("summary")
        }
        
        self.init(
            summary:     consume summary,
            replacement: consume replacement
        )
    }
}
