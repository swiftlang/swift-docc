/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension IntroRenderSection {
    public var headings: [String] {
        // An Intro's title becomes the top-level page's title, so it doesn't need to be included as a heading here. It doesn't get its own index record.
        return content.headings
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return content.rawIndexableTextContent(references: references)
    }
}

extension VolumeRenderSection {
    public var headings: [String] {
        return name.map { [$0] } ?? [] +
            (content.map { $0.headings } ?? []) +
            chapters.headings
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return content.map { $0.rawIndexableTextContent(references: references) } ?? ""
    }
}

extension ResourcesRenderSection {
    public var headings: [String] {
        return tiles.headings
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return content.rawIndexableTextContent(references: references)
    }
}

extension RenderTile {
    public var headings: [String] {
        return [title] +
            content.headings
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return content.rawIndexableTextContent(references: references)
    }
}

extension CallToActionSection {
    public var headings: [String] {
        // A call-to-action's title is effectively an H2 on the page. It doesn't get its own index record.
        return [title]
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return abstract.rawIndexableTextContent(references: references)
    }
}

extension ContentAndMediaGroupSection {
    public var headings: [String] {
        return sections.headings
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return sections.map { $0.rawIndexableTextContent(references: references) }.joined(separator: " ")
    }
}

extension ContentAndMediaSection {
    public var headings: [String] {
        // A ContentAndMedia's title is effectively an H2 on the page. It doesn't get its own index record.
        return (title.map { [$0] } ?? []) + content.headings
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return content.rawIndexableTextContent(references: references)
    }
}

extension TutorialAssessmentsRenderSection {
    public var headings: [String] {
        return assessments.headings
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return assessments.map { $0.rawIndexableTextContent(references: references) }.joined(separator: " ")
    }
}

extension TutorialAssessmentsRenderSection.Assessment {
    public var headings: [String] {
        // An assessment's title effectively becomes an H2 on the page. It doesn't get its own index record.
        // Title content shouldn't have references, so none need to be inlined, hence the empty references dictionary here.
        return [title.rawIndexableTextContent(references: [:])]
            + (self.content?.headings ?? [])
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return content.map {
            $0.rawIndexableTextContent(references: references)
        } ?? ""
    }
}

extension TutorialSectionsRenderSection {
    public var headings: [String] {
        return tasks.headings
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return tasks.map { $0.rawIndexableTextContent(references: references) }.joined(separator: " ")
    }
}

extension TutorialSectionsRenderSection.Section {
    public var headings: [String] {
        return contentSection.headings +
            stepsSection.flatMap { $0.headings }
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return contentSection.rawIndexableTextContent(references: references) + " " +
        stepsSection.map { $0.rawIndexableTextContent(references: references) }.joined(separator: " ")
    }
}

extension TutorialArticleSection {
    public var headings: [String] {
        return content.headings
    }
    
    public func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return content.rawIndexableTextContent(references: references)
    }
}

extension ContentRenderSection {
    public var headings: [String] {
        return content.headings
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return content.rawIndexableTextContent(references: references)
    }
}

extension ParametersRenderSection {
    public var headings: [String] {
        return parameters.flatMap {
            return $0.headings
        }
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return parameters.map {
            return $0.rawIndexableTextContent(references: references)
        }.joined(separator: " ")
    }
}

extension ParameterRenderSection {
    public var headings: [String] {
        return content.headings
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return content.rawIndexableTextContent(references: references)
    }
}

extension RelationshipsRenderSection {
    public var headings: [String] {
        return [title]
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return title
    }
}

extension TaskGroupRenderSection {
    public var headings: [String] {
        guard let title = title else { return [] }
        return [title]
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return title ?? ""
    }
}

extension RESTParametersRenderSection {
    public var headings: [String] {
        return items.flatMap {
            return $0.headings
        }
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return items.map {
            return $0.rawIndexableTextContent(references: references)
        }.joined(separator: " ")
    }
}

extension RenderProperty {
    public var headings: [String] {
        return [name]
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return content?.map {
            return $0.rawIndexableTextContent(references: references)
        }.joined(separator: " ") ?? ""
    }
}

extension RESTResponse {
    public var headings: [String] {
        return reason.map({ [$0] }) ?? []
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return content?.map {
            return $0.rawIndexableTextContent(references: references)
        }.joined(separator: " ") ?? ""
    }
}

extension RESTResponseRenderSection {
    public var headings: [String] {
        return items.flatMap {
            return $0.headings
        }
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return items.map {
            return $0.rawIndexableTextContent(references: references)
        }.joined(separator: " ")
    }
}

extension RESTEndpointRenderSection {
    public var headings: [String] {
        return [title]
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return title
    }
}

extension RESTBodyRenderSection {
    public var headings: [String] {
        return [title] + (parameters?.flatMap {
            return $0.headings
        } ?? [])
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        let contentText = (content?.map {
            return $0.rawIndexableTextContent(references: references)
        }.joined(separator: " ")) ?? ""

        let parametersText = (parameters?.map {
            return $0.rawIndexableTextContent(references: references)
        }.joined(separator: " ")) ?? ""

        return contentText + " " + parametersText
    }
}

extension PropertiesRenderSection {
    public var headings: [String] {
        return items.flatMap {
            return $0.headings
        }
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return items.map {
            return $0.rawIndexableTextContent(references: references)
        }.joined(separator: " ")
    }
}

extension RenderAttribute {
    public var headings: [String] {
        return [title]
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        switch self {
        case .default(let value): return value
        case .maximum(let value): return value
        case .maximumExclusive(let value): return value
        case .minimum(let value): return value
        case .minimumExclusive(let value): return value
        case .allowedValues(let values): return values.joined(separator: " ")
        case .allowedTypes(let values): return values.map { return $0.map { $0.text }.joined() }.joined(separator: " ")
        }
    }
}

extension AttributesRenderSection {
    public var headings: [String] {
        return attributes?.flatMap {
            return $0.headings
        } ?? []
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return attributes?.map {
            return $0.rawIndexableTextContent(references: references)
        }.joined(separator: " ") ?? ""
    }
}

extension PlistDetailsRenderSection {
    public var headings: [String] {
        if let ideTitle = details.ideTitle {
            return [details.name, ideTitle]
        } else {
            return [details.name]
        }
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return [details.name, details.ideTitle ?? ""].joined(separator: " ")
    }
}

extension PossibleValuesRenderSection {
    public var headings: [String] {
        return []
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return values.map { namedValue -> String in
            let content = namedValue.content?.rawIndexableTextContent(references: references) ?? ""
            return namedValue.name + " " + content
        }.joined(separator: " ")
    }
}

extension SampleDownloadSection {
    public var headings: [String] {
        return []
    }
    
    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        return ""
    }
}

extension Sequence where Element == ContentLayout {
    func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return map { layout -> String in
            switch layout {
            case .fullWidth(let content):
                return content.rawIndexableTextContent(references: references)
            case .contentAndMedia(let content):
                return content.rawIndexableTextContent(references: references)
            case .columns(let content):
                return content.map { $0.rawIndexableTextContent(references: references) }.joined(separator: " ")
            }
        }.joined(separator: " ")
    }
    
    var headings: [String] {
        return flatMap { layout -> [String] in
            switch layout {
            case .fullWidth(let content):
                return content.headings
            case .contentAndMedia(let content):
                return content.headings
            case .columns(let content):
                return content.headings
            }
        }
    }
}
