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
        
        // Build a lookup table of the new responses
        var newResponsesLookup : Dictionary<String, HTTPResponse> = [:]
        newResponses.forEach { newResponsesLookup["\($0.statusCode)/\($0.mediaType)"] = $0 }
        responses = responses.map { existingResponse in
            // TODO: Allow for fuzzy matches... statusCode matches, but one of the mediaTypes is unknown.
            let lookupKey = "\(existingResponse.statusCode)/\(existingResponse.mediaType)"
            if let newResponse = newResponsesLookup[lookupKey] {
                let contents = existingResponse.contents.count > 0 ? existingResponse.contents : newResponse.contents
                let symbol = existingResponse.symbol != nil ? existingResponse.symbol : newResponse.symbol
                let reason = existingResponse.reason != nil ? existingResponse.reason : newResponse.reason
                let updatedResponse = HTTPResponse(statusCode: existingResponse.statusCode, reason: reason, mediaType: existingResponse.mediaType, contents: contents, symbol: symbol)
                newResponsesLookup.removeValue(forKey: lookupKey)
                return updatedResponse
            }
            return existingResponse
        }
        // Are there any extra responses that didn't match existing set?
        if newResponsesLookup.count > 0 {
            // If documented keys are in alphabetical order, merge new ones in rather than append them.
            let extraResponses = newResponses.filter { newResponsesLookup["\($0.statusCode)/\($0.mediaType)"] != nil }
            if responses.isSortedByCode && newResponses.isSortedByCode {
                responses = responses.mergeSortedResponses(extraResponses)
            } else {
                responses.append(contentsOf: extraResponses)
            }
        }
    }
}

extension Array where Element == HTTPResponse {
    /// Checks whether the array of response values are sorted alphabetically according to their `statusCode`.
    var isSortedByCode: Bool {
        if self.count < 2  { return true }
        if self.count == 2 { return (self[0].statusCode < self[1].statusCode) }
        return (1..<self.count).allSatisfy {
            self[$0 - 1].statusCode < self[$0].statusCode
        }
    }
    
    /// Merge a list of responses with the current array of sorted responses, returning a new array.
    func mergeSortedResponses(_ newResponses: [HTTPResponse]) -> [HTTPResponse] {
        var oldIndex = 0
        var newIndex = 0
        
        var mergedResponses = [HTTPResponse]()
        
        while oldIndex < self.count || newIndex < newResponses.count {
            if newIndex >= newResponses.count {
                mergedResponses.append(self[oldIndex])
                oldIndex += 1
            } else if oldIndex >= self.count {
                mergedResponses.append(newResponses[newIndex])
                newIndex += 1
            } else if self[oldIndex].statusCode < newResponses[newIndex].statusCode {
                mergedResponses.append(self[oldIndex])
                oldIndex += 1
            } else {
                mergedResponses.append(newResponses[newIndex])
                newIndex += 1
            }
        }
        
        return mergedResponses
    }
}
