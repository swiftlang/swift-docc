/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section that contains an HTTP request's parameters.
public struct HTTPParametersSection {
    
    /// The list of parameters.
    public var parameters = [HTTPParameter]()
    
    /// Merge additional parameters to section.
    /// 
    /// Preserves the order and merges in documentation and symbols to any existing parameters.
    mutating public func mergeParameters(_ newParameters: [HTTPParameter]) {
        if parameters.isEmpty {
            // There are no existing parameters, so swap these in and return.
            parameters = newParameters
            return
        }
        
        // Update existing parameters with new data being passed in.
        parameters = parameters.insertAndUpdate(newParameters) { existingParameter, newParameter in
            let contents = existingParameter.contents.count > 0 ? existingParameter.contents : newParameter.contents
            let symbol = existingParameter.symbol ?? newParameter.symbol
            let source = existingParameter.source ?? newParameter.source
            let required = existingParameter.required || newParameter.required
            return HTTPParameter(name: existingParameter.name, source: source, contents: contents, symbol: symbol, required: required)
        }
    }
}

extension HTTPParameter: ListItemUpdatable {
    var listItemIdentifier: String { name }
}
