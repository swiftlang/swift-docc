/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A Codable container for sections within a Tutorial page.
struct CodableRenderSection: Codable {
    var section: RenderSection
    
    init(_ section: RenderSection) {
        self.section = section
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(RenderSectionKind.self, forKey: .kind)
        
        switch kind {
        case .hero, .intro:
            section = try IntroRenderSection(from: decoder)
        case .tasks:
            section = try TutorialSectionsRenderSection(from: decoder)
        case .assessments:
            section = try TutorialAssessmentsRenderSection(from: decoder)
        case .volume:
            section = try VolumeRenderSection(from: decoder)
        case .contentAndMedia:
            section = try ContentAndMediaSection(from: decoder)
        case .contentAndMediaGroup:
            section = try ContentAndMediaGroupSection(from: decoder)
        case .callToAction:
            section = try CallToActionSection(from: decoder)
        case .articleBody:
            section = try TutorialArticleSection(from: decoder)
        case .resources:
            section = try ResourcesRenderSection(from: decoder)
        default: fatalError()
        }
    }
    
    private enum CodingKeys: CodingKey {
        case kind
    }
    
    func encode(to encoder: Encoder) throws {
        try section.encode(to: encoder)
    }
}
