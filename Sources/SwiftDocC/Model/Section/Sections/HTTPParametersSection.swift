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
        
        // Build a lookup table of the new parameters
        var newParameterLookup = [String: HTTPParameter]()
        newParameters.forEach { newParameterLookup[$0.name + "/" + $0.source] = $0 }
        parameters = parameters.map { existingParameter in
            // TODO: Allow for fuzzy matches... name matches, but one of the sources is unknown.
            let lookupKey = existingParameter.name + "/" + existingParameter.source
            if let newParameter = newParameterLookup[lookupKey] {
                let contents = existingParameter.contents.count > 0 ? existingParameter.contents : newParameter.contents
                let symbol = existingParameter.symbol != nil      ? existingParameter.symbol   : newParameter.symbol
                let required = existingParameter.required || newParameter.required
                let updatedParameter = HTTPParameter(name: existingParameter.name, source: existingParameter.source, contents: contents, symbol: symbol, required: required)
                newParameterLookup.removeValue(forKey: lookupKey)
                return updatedParameter
            }
            return existingParameter
        }
        // Are there any extra parameters that didn't match existing set?
        if newParameterLookup.count > 0 {
            // If documented parameters are in alphabetical order, merge new ones in rather than append them.
            let extraParameters = newParameters.filter { newParameterLookup[$0.name + "/" + $0.source] != nil }
            if parameters.isSortedByName && newParameters.isSortedByName {
                parameters = parameters.mergeSortedParameters(extraParameters)
            } else {
                parameters.append(contentsOf: extraParameters)
            }
        }
    }
}

extension Array where Element == HTTPParameter {
    /// Checks whether the array of HTTPParameter values are sorted alphabetically according to their `name`.
    var isSortedByName: Bool {
        if self.count < 2  { return true }
        if self.count == 2 { return (self[0].name < self[1].name) }
        return (1..<self.count).allSatisfy {
            self[$0 - 1].name < self[$0].name
        }
    }
    
    /// Merge a list of dictionary keys with the current array of sorted keys, returning a new array.
    func mergeSortedParameters(_ newParameters: [HTTPParameter]) -> [HTTPParameter] {
        var oldIndex = 0
        var newIndex = 0
        
        var mergedParameters = [HTTPParameter]()
        
        while oldIndex < self.count || newIndex < newParameters.count {
            if newIndex >= newParameters.count {
                mergedParameters.append(self[oldIndex])
                oldIndex += 1
            } else if oldIndex >= self.count {
                mergedParameters.append(newParameters[newIndex])
                newIndex += 1
            } else if self[oldIndex].name < newParameters[newIndex].name {
                mergedParameters.append(self[oldIndex])
                oldIndex += 1
            } else {
                mergedParameters.append(newParameters[newIndex])
                newIndex += 1
            }
        }
        
        return mergedParameters
    }
}
