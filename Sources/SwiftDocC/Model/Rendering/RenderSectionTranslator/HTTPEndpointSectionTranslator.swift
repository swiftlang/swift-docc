/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Translates a symbol's endpoints into a render node's URL section.
struct HTTPEndpointSectionTranslator: RenderSectionTranslator {
    let endpointType: RESTEndpointType
    
    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>? {
        // Check if there is any endpoint available
        guard !symbol.httpEndpointSectionVariants.isEmpty else { return nil }
        
        return translateSectionToVariantCollection(
            documentationDataVariants: symbol.httpEndpointSectionVariants
        ) { _, section in
            let endpointURL: URL
            
            if endpointType == .production {
                endpointURL = section.endpoint.baseURL
            } else if let sandboxURL = section.endpoint.sandboxURL {
                endpointURL = sandboxURL
            } else {
                return nil
            }
            
            return RESTEndpointRenderSection(
                title: (endpointType == .production ? "URL" : "Sandbox URL"),
                tokens: Self.tokensFor(method: section.endpoint.method, baseURL: endpointURL, path: section.endpoint.path)
            )
        }
    }
    
    // Generate DeclarationFragments from endpoint data.
    static func tokensFor(method: String, baseURL: URL?, path: String) -> [RESTEndpointRenderSection.Token] {
        var fragments : [RESTEndpointRenderSection.Token] = [] 
        // Operation type
        
        fragments.append(RESTEndpointRenderSection.Token(kind: .method, text: method))
        fragments.append(RESTEndpointRenderSection.Token(kind: .text, text: " "))
        if let base = baseURL {
            let cleanBase = base.absoluteString.appendingTrailingSlash
            fragments.append(RESTEndpointRenderSection.Token(kind: .baseURL, text: cleanBase))
        }
        
        let cleanPath = path.removingLeadingSlash
        
        var searchRange = cleanPath.startIndex..<cleanPath.endIndex
        while true {
            if let range = cleanPath.range(of: "\\{\\w+\\}", options: .regularExpression, range: searchRange, locale: nil) {
                if cleanPath.startIndex < range.lowerBound {
                    fragments.append(RESTEndpointRenderSection.Token(kind: .path, text: String(cleanPath[searchRange.lowerBound..<range.lowerBound])))
                }
                fragments.append(RESTEndpointRenderSection.Token(kind: .parameter, text: String(cleanPath[range])))
                searchRange = range.upperBound..<cleanPath.endIndex
                // Make sure there is more content to search
                if searchRange.lowerBound >= cleanPath.endIndex {
                    break
                }
            } else {
                // Save off the remainder of the path
                fragments.append(RESTEndpointRenderSection.Token(kind: .path, text: String(cleanPath[searchRange])))
                break
            }
        }
        
        return fragments
    }
}
