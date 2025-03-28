/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

public struct MentionsRenderSection: RenderSection, Codable, Equatable {
    public var kind: RenderSectionKind = .mentions
    public var mentions: [URL]

    public init(mentions: [URL]) {
        self.mentions = mentions
    }
}

extension MentionsRenderSection: TextIndexing {
    public var headings: [String] {
        return []
    }

    public func rawIndexableTextContent(references: [String : any RenderReference]) -> String {
        return ""
    }
}

// Diffable conformance
extension MentionsRenderSection: RenderJSONDiffable {
    /// Returns the differences between this MentionsRenderSection and the given one.
    func difference(from other: MentionsRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.mentions, forKey: CodingKeys.mentions)

        return diffBuilder.differences
    }

    /// Returns if this DeclarationsRenderSection is similar enough to the given one.
    func isSimilar(to other: MentionsRenderSection) -> Bool {
        return self.mentions == other.mentions
    }
}
