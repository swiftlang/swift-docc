/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public protocol RenderSection: Codable, TextIndexing {
    var kind: RenderSectionKind { get }
}

public enum RenderSectionKind: String, Codable {
    // Article render sections
    case hero, intro, tasks, assessments, volume, contentAndMedia, contentAndMediaGroup, callToAction, tile, articleBody, resources
    
    // Symbol render sections
    case discussion, content, taskGroup, relationships, declarations, parameters, sampleDownload, row

    // Rest symbol sections
    case restParameters, restResponses, restBody, restEndpoint, properties

    // Plist
    case plistDetails = "details", attributes, possibleValues
}
