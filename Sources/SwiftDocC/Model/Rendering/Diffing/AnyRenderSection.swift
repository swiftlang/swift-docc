/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A RenderSection value that can be diffed.
///
/// An `AnyRenderSection` value forwards difference operations to the underlying base type, each of which determine the difference differently.
struct AnyRenderSection: Equatable, Encodable, RenderJSONDiffable {
    var value: RenderSection
    
    init(_ value: RenderSection) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
    
    /// Forwards the difference methods on to the correct concrete type.
    func difference(from other: AnyRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        switch (self.value.kind, other.value.kind) {
            
        // MARK: Symbol Sections
            
        case (.attributes, .attributes):
            return (value as! AttributesRenderSection).difference(from: (other.value as! AttributesRenderSection), at: path)
        case (.discussion, .discussion), (.content, .content):
            return (value as! ContentRenderSection).difference(from: (other.value as! ContentRenderSection), at: path)
        case (.declarations, .declarations):
            return (value as! DeclarationsRenderSection).difference(from: (other.value as! DeclarationsRenderSection), at: path)
        case (.parameters, .parameters):
            return (value as! ParametersRenderSection).difference(from: (other.value as! ParametersRenderSection), at: path)
        case (.plistDetails, .plistDetails):
            return (value as! PropertyListDetailsRenderSection).difference(from: (other.value as! PropertyListDetailsRenderSection), at: path)
        case (.possibleValues, .possibleValues):
            return (value as! PossibleValuesRenderSection).difference(from: (other.value as! PossibleValuesRenderSection), at: path)
        case (.relationships, .relationships):
            return (value as! RelationshipsRenderSection).difference(from: (other.value as! RelationshipsRenderSection), at: path)
        case (.restBody, .restBody):
            return (value as! RESTBodyRenderSection).difference(from: (other.value as! RESTBodyRenderSection), at: path)
        case (.restEndpoint, .restEndpoint):
            return (value as! RESTEndpointRenderSection).difference(from: (other.value as! RESTEndpointRenderSection), at: path)
        case (.restParameters, .restParameters):
            return (value as! RESTParametersRenderSection).difference(from: (other.value as! RESTParametersRenderSection), at: path)
        case (.restResponses, .restResponses):
            return (value as! RESTResponseRenderSection).difference(from: (other.value as! RESTResponseRenderSection), at: path)
        case (.sampleDownload, .sampleDownload):
            return (value as! SampleDownloadSection).difference(from: (other.value as! SampleDownloadSection), at: path)
        case (.taskGroup, .taskGroup):
            return (value as! TaskGroupRenderSection).difference(from: (other.value as! TaskGroupRenderSection), at: path)
        case (.mentions, .mentions):
            return (value as! MentionsRenderSection).difference(from: (other.value as! MentionsRenderSection), at: path)

        // MARK: Tutorial Sections
            
        case (.intro, .intro), (.hero, .hero):
            return (value as! IntroRenderSection).difference(from: (other.value as! IntroRenderSection), at: path)
        case (.assessments, .assessments):
            return (value as! TutorialAssessmentsRenderSection).difference(from: (other.value as! TutorialAssessmentsRenderSection), at: path)
        case (.tasks, .tasks):
            return (value as! TutorialSectionsRenderSection).difference(from: (other.value as! TutorialSectionsRenderSection), at: path)
        
        // MARK: Tutorial Article Sections
            
        case (.articleBody, .articleBody):
            return (value as! TutorialArticleSection).difference(from: (other.value as! TutorialArticleSection), at: path)
            
        // MARK: Tutorials Overview Sections
            
        case (.callToAction, .callToAction):
            return (value as! CallToActionSection).difference(from: (other.value as! CallToActionSection), at: path)
        case (.contentAndMediaGroup, .contentAndMediaGroup):
            return (value as! ContentAndMediaGroupSection).difference(from: (other.value as! ContentAndMediaGroupSection), at: path)
        case (.contentAndMedia, .contentAndMedia):
            return (value as! ContentAndMediaSection).difference(from: (other.value as! ContentAndMediaSection), at: path)
        case (.resources, .resources):
            return (value as! ResourcesRenderSection).difference(from: (other.value as! ResourcesRenderSection), at: path)
        case (.volume, .volume):
            return (value as! VolumeRenderSection).difference(from: (other.value as! VolumeRenderSection), at: path)
            
        default:
            assertionFailure("Case diffing \(value) with \(other.value) is not implemented.")
            return []
        }
    }

    static func == (lhs: AnyRenderSection, rhs: AnyRenderSection) -> Bool {
        switch (lhs.value.kind, rhs.value.kind) {
            
        // MARK: Symbol Sections
            
        case (.attributes, .attributes):
            return (lhs.value as! AttributesRenderSection) == (rhs.value as! AttributesRenderSection)
        case (.discussion, .discussion), (.content, .content):
            return (lhs.value as! ContentRenderSection) == (rhs.value as! ContentRenderSection)
        case (.declarations, .declarations):
            return (lhs.value as! DeclarationsRenderSection) == (rhs.value as! DeclarationsRenderSection)
        case (.parameters, .parameters):
            return (lhs.value as! ParametersRenderSection) == (rhs.value as! ParametersRenderSection)
        case (.plistDetails, .plistDetails):
            return (lhs.value as! PropertyListDetailsRenderSection) == (rhs.value as! PropertyListDetailsRenderSection)
        case (.possibleValues, .possibleValues):
            return (lhs.value as! PossibleValuesRenderSection) == (rhs.value as! PossibleValuesRenderSection)
        case (.relationships, .relationships):
            return (lhs.value as! RelationshipsRenderSection) == (rhs.value as! RelationshipsRenderSection)
        case (.restBody, .restBody):
            return (lhs.value as! RESTBodyRenderSection) == (rhs.value as! RESTBodyRenderSection)
        case (.restEndpoint, .restEndpoint):
            return (lhs.value as! RESTEndpointRenderSection) == (rhs.value as! RESTEndpointRenderSection)
        case (.restParameters, .restParameters):
            return (lhs.value as! RESTParametersRenderSection) == (rhs.value as! RESTParametersRenderSection)
        case (.restResponses, .restResponses):
            return (lhs.value as! RESTResponseRenderSection) == (rhs.value as! RESTResponseRenderSection)
        case (.sampleDownload, .sampleDownload):
            return (lhs.value as! SampleDownloadSection) == (rhs.value as! SampleDownloadSection)
        case (.taskGroup, .taskGroup):
            return (lhs.value as! TaskGroupRenderSection) == (rhs.value as! TaskGroupRenderSection)
        case (.mentions, .mentions):
            return (lhs.value as! MentionsRenderSection) == (rhs.value as! MentionsRenderSection)

        // MARK: Tutorial Sections
            
        case (.intro, .intro), (.hero, .hero):
            return (lhs.value as! IntroRenderSection) == (rhs.value as! IntroRenderSection)
        case (.assessments, .assessments):
            return (lhs.value as! TutorialAssessmentsRenderSection) == (rhs.value as! TutorialAssessmentsRenderSection)
        case (.tasks, .tasks):
            return (lhs.value as! TutorialSectionsRenderSection) == (rhs.value as! TutorialSectionsRenderSection)
            
        // MARK: Tutorial Article Sections
            
        case (.articleBody, .articleBody):
            return (lhs.value as! TutorialArticleSection) == (rhs.value as! TutorialArticleSection)
            
        // MARK: Tutorials Overview Sections
            
        case (.callToAction, .callToAction):
            return (lhs.value as! CallToActionSection) == (rhs.value as! CallToActionSection)
        case (.contentAndMediaGroup, .contentAndMediaGroup):
            return (lhs.value as! ContentAndMediaGroupSection) == (rhs.value as! ContentAndMediaGroupSection)
        case (.contentAndMedia, .contentAndMedia):
            return (lhs.value as! ContentAndMediaSection) == (rhs.value as! ContentAndMediaSection)
        case (.resources, .resources):
            return (lhs.value as! ResourcesRenderSection) == (rhs.value as! ResourcesRenderSection)
        case (.volume, .volume):
            return (lhs.value as! VolumeRenderSection) == (rhs.value as! VolumeRenderSection)
        
        default:
            assertionFailure("Case diffing \(lhs.value) with \(rhs.value) is not implemented.")
            return false
        }
    }
    
    func isSimilar(to other: AnyRenderSection) -> Bool {
        return self.value.kind == other.value.kind
    }
}
