/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/**
 Extracts metadata from a render node.

 The `RenderNodeDataExtractor` extracts information from a RenderNode JSON file that can't be decoded using JSONDecoder.
 This happens if the JSON has a different schema than the one supported by the current version.
 */
public final class RenderNodeDataExtractor {
    /// The render node as a dictionary value.
    let json: JSON
    
    /// Initialize the extractor with the JSON data.
    public init(with data: Data) throws {
        json = try JSONDecoder().decode(JSON.self, from: data)
    }
    
    // MARK: - Data extractors
    
    /// Returns the URL and checksum of the project files, if existing.
    public var projectFiles: (url: URL, checksum: String)? {
        
        let projectName: String
        
        if json["metadata"]?["role"]?.string == "sampleCode" {
            guard let sampleCodeProject = json["sampleCodeDownload"]?["action"]?["identifier"]?.string else {
                return nil
            }
            projectName = sampleCodeProject
        } else {
            guard let tutorialProject = json["sections"]?[0]?["projectFiles"]?.string else {
                return nil
            }
            projectName = tutorialProject
        }
        
        guard let stringURL = json["references"]?[projectName]?["url"]?.string else {
            return nil
        }
        guard let checksum = json["references"]?[projectName]?["checksum"]?.string else {
            return nil
        }
        guard let url = URL(string: stringURL) else {
            return nil
        }
        
        return (url: url, checksum: checksum)
    }
    
    /// Returns the metadata, if available, inside a RenderNode JSON.
    func metadata(for key: String) -> String? {
        return json["metadata"]?[key]?.string
    }
}

