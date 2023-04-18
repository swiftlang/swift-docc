/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section that contains an HTTP request's responses.
public struct HTTPResponsesSection {
    public static var title: String {
        return "Response Codes"
    }
    
    /// The list of responses.
    public var responses = [HTTPResponse]()
    
    /// Merge additional responses to section.
    /// 
    /// Preserves the order and merges in documentation and symbols to any existing responses.
    mutating public func mergeResponses(_ newResponses: [HTTPResponse]) {
        if responses.isEmpty {
            // There are no existing keys, so swap these in and return.
            responses = newResponses
            return
        }
        
        // Update existing responses with new data being passed in.
        responses = responses.insertAndUpdate(newResponses) { existingResponse, newResponse in
            let contents = existingResponse.contents.count > 0 ? existingResponse.contents : newResponse.contents
            let symbol = existingResponse.symbol ?? newResponse.symbol
            let reason = existingResponse.reason ?? newResponse.reason
            let mediaType = existingResponse.mediaType ?? newResponse.mediaType
            return HTTPResponse(statusCode: existingResponse.statusCode, reason: reason, mediaType: mediaType, contents: contents, symbol: symbol)
        }
    }
}

extension HTTPResponse: ListItemUpdatable {
    var listItemIdentifier: UInt { statusCode }
}
