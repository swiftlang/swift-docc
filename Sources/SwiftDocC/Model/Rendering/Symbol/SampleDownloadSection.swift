/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A section that contains download data for a sample project.
///
/// The `action` property is the reference to the file for download, e.g., `sample.zip`.
public struct SampleDownloadSection: RenderSection {
    public var kind: RenderSectionKind = .sampleDownload
    /// The call to action in the section.
    public var action: RenderInlineContent

    /// Creates a new sample project download section.
    /// - Parameter action: The call to action in the section.
    public init(action: RenderInlineContent) {
        self.action = action
    }
    
    // MARK: - Codable
    
    /// The list of keys you use to encode or decode this section.
    public enum CodingKeys: String, CodingKey {
        case kind, action
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(RenderInlineContent.self, forKey: .action)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(action, forKey: .action)
    }
}
