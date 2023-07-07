/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Translates a symbol's response into a render node's response section.
struct HTTPResponsesSectionTranslator: RenderSectionTranslator {
    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>? {
        translateSectionToVariantCollection(
            documentationDataVariants: symbol.httpResponsesSectionVariants
        ) { _, httpResponsesSection in
            // Filter out responses that aren't backed by a symbol
            let filteredResponses = httpResponsesSection.responses.filter { $0.symbol != nil }
            
            if filteredResponses.isEmpty { return nil }
            
            return RESTResponseRenderSection(
                title: HTTPResponsesSection.title,
                items: filteredResponses.map { translateResponse($0, &renderNodeTranslator) }
            )
        }
    }
    
    func translateResponse(_ response: HTTPResponse, _ renderNodeTranslator: inout RenderNodeTranslator) -> RESTResponse {
        let responseContent = renderNodeTranslator.visitMarkupContainer(
            MarkupContainer(response.contents)
        ) as! [RenderBlockContent]
        
        var renderedTokens: [DeclarationRenderSection.Token]? = nil
        
        if let responseSymbol = response.symbol {
            
            // Convert the dictionary key's declaration into section tokens
            if let fragments = responseSymbol.declarationFragments {
                renderedTokens = fragments.map { token -> DeclarationRenderSection.Token in
                    
                    // Create a reference if one found
                    var reference: ResolvedTopicReference?
                    if let preciseIdentifier = token.preciseIdentifier,
                       let resolved = renderNodeTranslator.context.symbolIndex[preciseIdentifier] {
                        reference = resolved
                        
                        // Add relationship to render references
                        renderNodeTranslator.collectedTopicReferences.append(resolved)
                    }
                    
                    // Add the declaration token
                    return DeclarationRenderSection.Token(fragment: token, identifier: reference?.absoluteString)
                }
            }
        }
        
        return RESTResponse(
            status: response.statusCode,
            reason: response.reason ?? Self.reasonForStatusCode[response.statusCode],
            mimeType: response.mediaType,
            type: renderedTokens ?? [],
            content: responseContent
        )
    }
    
    // Default reason strings in case one not explicitly set.
    static let reasonForStatusCode: [UInt: String] = [
        100: "Continue",
        101: "Switching Protocols",
        200: "OK",
        201: "Created",
        202: "Accepted",
        203: "Non-Authoritative Information",
        204: "No Content",
        205: "Reset Content",
        206: "Partial Content",
        300: "Multiple Choices",
        301: "Moved Permanently",
        302: "Found",
        303: "See Other",
        304: "Not Modified",
        305: "Use Proxy",
        307: "Temporary Redirect",
        400: "Bad Request",
        401: "Unauthorized",
        402: "Payment Required",
        403: "Forbidden",
        404: "Not Found",
        405: "Method Not Allowed",
        406: "Not Acceptable",
        407: "Proxy Authentication Required",
        408: "Request Time-out",
        409: "Conflict",
        410: "Gone",
        411: "Length Required",
        412: "Precondition Failed",
        413: "Request Entity Too Large",
        414: "Request-URI Too Large",
        415: "Unsupported Media Type",
        416: "Requested range not satisfiable",
        417: "Expectation Failed",
        500: "Internal Server Error",
        501: "Not Implemented",
        502: "Bad Gateway",
        503: "Service Unavailable",
        504: "Gateway Time-out",
        505: "HTTP Version not supported"
    ]
}
