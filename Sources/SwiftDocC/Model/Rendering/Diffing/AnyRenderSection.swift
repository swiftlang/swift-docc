/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A RenderSection value that can be diffed.
///
/// An `AnyRenderSection` value forwards difference operations to the underlying base type, each of which determine the difference differently.
public struct AnyRenderSection: Equatable, Encodable, Diffable {
    
    // This forwards the difference methods on to the correct concrete type.
    func difference(from other: AnyRenderSection, at path: Path) -> Differences {
        switch (self.value.kind, other.value.kind) {
        case (.intro, .intro), (.hero, .hero):
            return (value as! IntroRenderSection).difference(from: (other.value as! IntroRenderSection), at: path)
//        case (.contentAndMedia, .contentAndMedia):
//            return (value as! ContentAndMediaSection).difference(from: (other.value as! ContentAndMediaSection), at: path)
//        case (.contentAndMediaGroup, .contentAndMediaGroup):
//            return (value as! ContentAndMediaGroupSection).difference(from: (other.value as! ContentAndMediaGroupSection), at: path)
//        case (.callToAction, .callToAction):
//            return (value as! CallToActionSection).difference(from: (other.value as! CallToActionSection), at: path)
//        case (.resources, .resources):
//            return (value as! ResourcesRenderSection).difference(from: (other.value as! ResourcesRenderSection), at: path)
        case (.declarations, .declarations):
            return (value as! DeclarationsRenderSection).difference(from: (other.value as! DeclarationsRenderSection), at: path)
        case (.discussion, .discussion), (.content, .content):
            return (value as! ContentRenderSection).difference(from: (other.value as! ContentRenderSection), at: path)
        case (.taskGroup, .taskGroup):
            return (value as! TaskGroupRenderSection).difference(from: (other.value as! TaskGroupRenderSection), at: path)
//        case (.relationships, .relationships):
//            return (value as! RelationshipsRenderSection).difference(from: (other.value as! RelationshipsRenderSection), at: path)
//        case (.parameters, .parameters):
//            return (value as! ParametersRenderSection).difference(from: (other.value as! ParametersRenderSection), at: path)
        default:
            return []
        }
    }
    
    public static func == (lhs: AnyRenderSection, rhs: AnyRenderSection) -> Bool {
        switch (lhs.value.kind, rhs.value.kind) {
        case (.intro, .intro), (.hero, .hero):
            return (lhs.value as! IntroRenderSection) == (rhs.value as! IntroRenderSection)
        case (.tasks, .tasks):
            return (lhs.value as! TutorialSectionsRenderSection) == (rhs.value as! TutorialSectionsRenderSection)
        case (.assessments, .assessments):
            return (lhs.value as! TutorialAssessmentsRenderSection) == (rhs.value as! TutorialAssessmentsRenderSection)
        case (.volume, .volume):
            return (lhs.value as! VolumeRenderSection) == (rhs.value as! VolumeRenderSection)
        case (.contentAndMedia, .contentAndMedia):
            return (lhs.value as! ContentAndMediaSection) == (rhs.value as! ContentAndMediaSection)
        case (.contentAndMediaGroup, .contentAndMediaGroup):
            return (lhs.value as! ContentAndMediaGroupSection) == (rhs.value as! ContentAndMediaGroupSection)
        case (.callToAction, .callToAction):
            return (lhs.value as! CallToActionSection) == (rhs.value as! CallToActionSection)
        case (.articleBody, .articleBody):
            return (lhs.value as! TutorialArticleSection) == (rhs.value as! TutorialArticleSection)
        case (.resources, .resources):
            return (lhs.value as! ResourcesRenderSection) == (rhs.value as! ResourcesRenderSection)
        case (.declarations, .declarations):
            return (lhs.value as! DeclarationsRenderSection) == (rhs.value as! DeclarationsRenderSection)
        case (.discussion, .discussion):
            return (lhs.value as! ContentRenderSection) == (rhs.value as! ContentRenderSection)
        case (.content, .content):
            return (lhs.value as! ContentRenderSection) == (rhs.value as! ContentRenderSection)
        case (.taskGroup, .taskGroup):
            return (lhs.value as! TaskGroupRenderSection) == (rhs.value as! TaskGroupRenderSection)
        case (.relationships, .relationships):
            return (lhs.value as! RelationshipsRenderSection) == (rhs.value as! RelationshipsRenderSection)
        case (.parameters, .parameters):
            return (lhs.value as! ParametersRenderSection) == (rhs.value as! ParametersRenderSection)
        case (.sampleDownload, .sampleDownload):
            return (lhs.value as! SampleDownloadSection) == (rhs.value as! SampleDownloadSection)
        default:
            return false
        }
    }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }

    public var value: RenderSection
    init(_ value: RenderSection) { self.value = value }
    
    public func isSimilar(to other: AnyRenderSection) -> Bool {
        return value.kind == other.value.kind
    }
}
