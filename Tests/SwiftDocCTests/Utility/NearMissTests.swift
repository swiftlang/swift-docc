/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

/// These tests are verifying the what are the best matches when comparing a collection of symbol names against an authored symbol name.
/// The tests are meant to reflect what a person would expect to be the "best" matches — to which there is no single right or wrong answer.
///
/// These tests are meant to be flexible to allow the ranking of matches to change without needing to update all the tests. In practice
/// this means that each check assert that some minimum number of 'expected' matches are returned while also allowing a number of 'accepted'
/// matches to either be returned or not to be returned.
///
/// For example, if "A" and "B" are expected matches and "C" and "D" are accepted matches then:
///  - "A, B" will pass, since all expected matches are found
///  - "A, B, C" and "A, B, C, D" will pass, since all matches are either expected or accepted
///  - "A" will fail, since it's missing an expected match
///  - "B, A" will fail since A is expected to rank higher than B
///  - "A, B, D" and "A, B, D, C" will fail since C is expected to rank higher than D
///  - "A, B, C, D, E" will fail since E is not an accepted match
///
/// If you feel that DocC is not returning the near-miss results that you expect, add a new test that uses the specific collection of symbol
/// names and the authored symbol name and assert what you think are the expected and accepted matches in that case. Then tweak the NearMiss
/// implementation so that all tests pass. This may require updating existing near miss tests. That is okay but the changes should be discussed
/// in the review to ensure that the expected and accepted values make sense to people.
///
/// > Note:
/// It's counter productive to test specific "scores" for matches. Scores have no absolute meaning and are only meant to be used as a relative
/// metric to compare matches against each other.
class NearMissTests: XCTestCase {
    
    func testSwiftArgumentParserExamples() throws {
        let argumentSubpaths = [
            // Single Arguments
            "init(help:completion:)",
            "init(help:completion:transform:)",
            "init(wrappedValue:help:completion:)",
            "init(wrappedValue:help:completion:transform:)",
            // Array Arguments
            "init(parsing:help:completion:)",
            "init(parsing:help:completion:transform:)",
            "init(wrappedValue:parsing:help:completion:)",
            "init(wrappedValue:parsing:help:completion:transform:)",
            "ArgumentArrayParsingStrategy",
            // Infrequently Used APIs
            "init(from:)",
            "wrappedValue",
            // Default Implementations
            "description"
        ]
        
        checkBestMatches(for: argumentSubpaths, against: "wrappedValue", expectedMatches: [
            // These need to be in the best matches in this order.
            "wrappedValue",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
            //
            // Most of the string doesn't match but it contains the full 'wrappedValue'.
            "init(wrappedValue:help:completion:)",
            "init(wrappedValue:parsing:help:completion:)",
            "init(wrappedValue:help:completion:transform:)",
            "init(wrappedValue:parsing:help:completion:transform:)",
        ])
        
        checkBestMatches(for: argumentSubpaths, against: "init(wrappedValue:)", expectedMatches: [
            // These need to be in the best matches in this order.
            "init(wrappedValue:help:completion:)",
            "init(wrappedValue:parsing:help:completion:)",
            "init(wrappedValue:help:completion:transform:)",
            "init(wrappedValue:parsing:help:completion:transform:)",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
            //
            // The start doesn't match.
            "wrappedValue",
            // Replacing "wrappedValue" with "from" is somewhat close.
            "init(from:)"
        ])
        
        checkBestMatches(for: argumentSubpaths, against: "init(parsing:", expectedMatches: [
            // These need to be in the best matches in this order.
            "init(parsing:help:completion:)",
            "init(parsing:help:completion:transform:)",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
            //
            // Both "init(" and "parsing:" match but not in one segment. The number of added characters is fairly high.
            "init(wrappedValue:parsing:help:completion:)",
            "init(wrappedValue:parsing:help:completion:transform:)",
        ])
        
        let flagSubpaths = [
            // Boolean Flags
            "init(wrappedValue:name:help:)",
            // Boolean Flags with Inversions
            "init(wrappedValue:name:inversion:exclusivity:help:)",
            "init(name:inversion:exclusivity:help:)",
            "FlagInversion",
            // Counted Flags
            "init(name:help:)",
            // Custom Enumerable Flags
            "init(help:)",
            "init(exclusivity:help:)",
            "init(wrappedValue:exclusivity:help:)",
            "init(wrappedValue:help:)",
            // Infrequently Used APIs
            "init(from:)",
            "wrappedValue",
            // Supporting Types
            "FlagExclusivity",
            // Default Implementations
            "description"
        ]
        
        checkBestMatches(for: flagSubpaths, against: "wrappedValue", expectedMatches: [
            // These need to be in the best matches in this order.
            "wrappedValue",
            "init(wrappedValue:help:)",
            "init(wrappedValue:name:help:)",
            "init(wrappedValue:exclusivity:help:)",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
            //
            // Most of the string doesn't match but it contains the full 'wrappedValue'.
            "init(wrappedValue:name:inversion:exclusivity:help:)",
        ])
    }
    
    func testSwiftMarkdownExamples() throws {
        let markupSubpaths = [
            // Instance Properties
            "childCount",
            "children",
            "detachedFromParent",
            "indexInParent",
            "isEmpty",
            "parent",
            "range",
            "root",
            // Instance Methods
            "accept(_:)",
            "child(at:)",
            "child(through:)",
            "debugDescription(options:)",
            "format(options:)",
            "hasSameStructure(as:)",
            "isIdentical(to:)",
            "withUncheckedChildren(_:)",
        ]
        
        checkBestMatches(for: markupSubpaths, against: "child", expectedMatches: [
            // These need to be in the best matches in this order.
            "children",
            "child(at:)",
            "childCount",
            "child(through:)",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
            //
            // The start doesn't match and is most of the string.
            "withUncheckedChildren(_:)",
        ])
        
        checkBestMatches(for: markupSubpaths, against: "FromParent", expectedMatches: [
            // These need to be in the best matches in this order.
            "detachedFromParent",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
            "parent",
            "indexInParent",
        ])
        
        let markupVisitorSubpaths = [
            // Associated Types
            "Result",
            // Instance Methods
            "defaultVisit(_:)",
            "visit(_:)",
            "visitBlockDirective(_:)",
            "visitBlockQuote(_:)",
            "visitCodeBlock(_:)",
            "visitCustomBlock(_:)",
            "visitCustomInline(_:)",
            "visitDocument(_:)",
            "visitEmphasis(_:)",
            "visitHTMLBlock(_:)",
            "visitHeading(_:)",
            "visitImage(_:)",
            "visitInlineCode(_:)",
            "visitInlineHTML(_:)",
            "visitLineBreak(_:)",
            "visitLink(_:)",
            "visitListItem(_:)",
            "visitOrderedList(_:)",
            "visitParagraph(_:)",
            "visitSoftBreak(_:)",
            "visitStrikethrough(_:)",
            "visitStrong(_:)",
            "visitSymbolLink(_:)",
            "visitTable(_:)",
            "visitTableBody(_:)",
            "visitTableCell(_:)",
            "visitTableHead(_:)",
            "visitTableRow(_:)",
            "visitText(_:)",
            "visitThematicBreak(_:)",
            "visitUnorderedList(_:)",
        ]
        
        checkBestMatches(for: markupVisitorSubpaths, against: "visitTable", expectedMatches: [
            // These need to be in the best matches in this order
            "visitTable(_:)",
            "visitTableRow(_:)",
            "visitTableBody(_:)",
            "visitTableCell(_:)",
            "visitTableHead(_:)",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
            //
            // These match up to "visitT".
            "visitText(_:)",
            "visitThematicBreak(_:)",
        ])
        
        checkBestMatches(for: markupVisitorSubpaths, against: "visitBlock", expectedMatches: [
            // These need to be in the best matches in this order
            "visitBlockQuote(_:)",
            "visitBlockDirective(_:)",
            "visitCodeBlock(_:)",
            "visitHTMLBlock(_:)",
            "visitCustomBlock(_:)",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
        ])
    }
    
    func testSwiftDocCExamples() throws {
        // This list is a good enough snapshot. It doesn't need to be kept up-to-date.
        let allTopLevelSwiftDocCSymbols = [
            "AbsoluteSymbolLink", "AbstractContainsFormattedTextOnly", "AbstractSection", "AnchorSection", "AnyChecker", "AnyCodable", "AnyLink", "AnyMetadata", "Article", "Assessments", "AssetReference", "AttributedCodeListing", "AttributesRenderSection", "AutomaticCuration", "AutomaticSeeAlso", "AutomaticTitleHeading", "AvailabilityIndex", "AvailabilityRenderItem", "BasicDiagnostic", "Benchmark", "benchmark(add:benchmarkLog:)", "benchmark(begin:benchmarkLog:)", "benchmark(end:benchmarkLog:)", "benchmark(wrap:benchmarkLog:body:)", "BenchmarkBlockMetric", "BenchmarkMetric", "BenchmarkResult", "BenchmarkResults", "BuildMetadata", "BundleData", "BundleDiscoveryOptions", "BundleIdentifier", "CallToActionSection", "Chapter", "Checker", "Checksum", "ChildDirective", "ChildMarkup", "Choice", "CodableContentSection", "Code", "CodeColors", "CodeColorsPreferenceKey", "CodeExample", "Comment", "CommunicationBridge", "CommunicationBridgeError", "CompositeChecker", "ConformanceSection", "ContentAndMedia", "ContentAndMediaGroupSection", "ContentAndMediaSection", "ContentLayout", "ContentRenderSection", "Converter", "ConvertOutputConsumer", "ConvertRequest", "ConvertRequestContextWrapper", "ConvertResponse", "ConvertService", "ConvertServiceError", "CoverageDataEntry", "CursorRange", "CustomMetadata", "DataAsset", "DataTraitCollection", "DeclarationRenderSection", "DeclarationsRenderSection", "DefaultAvailability", "DefaultImplementationsSection", "DeprecatedSection", "DeprecationSummary", "DescribedError", "Diagnostic", "DiagnosticConsoleWriter", "DiagnosticConsumer", "DiagnosticEngine", "DiagnosticFormattingConsumer", "DiagnosticFormattingOptions", "DiagnosticNote", "DiagnosticSeverity", "DiffAvailability", "DirectiveArgumentWrapped", "DirectiveConvertible", "DiscussionSection", "DisplayName", "DocCSymbolRepresentable", "DocumentationBundle", "DocumentationBundleFileTypes", "DocumentationContentRenderer", "DocumentationContext", "DocumentationContextConverter", "DocumentationContextDataProvider", "DocumentationContextDataProviderDelegate", "DocumentationConverter", "DocumentationConverterProtocol", "DocumentationCoverageLevel", "DocumentationCoverageOptions", "DocumentationNode", "DocumentationNodeConverter", "DocumentationSchemeHandler", "DocumentationServer", "DocumentationServerError", "DocumentationServerProtocol", "DocumentationService", "DocumentationWorkspace", "DownloadReference", "DuplicateTopicsSections", "DynamicallyIdentifiableMetric", "EnglishLanguage", "ErrorsEncountered", "ErrorWithProblems", "ExternalIdentifier", "ExternalMetadata", "ExternalReferenceResolver", "ExternalSymbolResolver", "FallbackAssetResolver", "FallbackReferenceResolver", "FeatureFlags", "FileReference", "FileServer", "FileServerProvider", "FileSystemProvider", "FileSystemRenderNodeProvider", "FileSystemServerProvider", "FileTypeReference", "FSNode", "GeneratedDataProvider", "GroupedSection", "ImageMedia", "ImageReference", "Implementation", "ImplementationsGroup", "Indexable", "IndexingError", "IndexingRecord", "InterfaceLanguage", "Intro", "IntroRenderSection", "InvalidAdditionalTitle", "JSONPatch", "JSONPatchOperation", "JSONPointer", "Justification", "Landmark", "Layout", "LineHighlighter", "LinkDestinationSummary", "LinkReference", "Links", "LMDBData", "LogHandle", "MarkupContainer", "MarkupConvertible", "MarkupLayout", "Media", "MediaReference", "MemoryFileServerProvider", "Message", "MessageType", "Metadata", "MetricValue", "MissingAbstract", "MultipleChoice", "NativeLanguage", "NavigatorIndex", "NavigatorItem", "NavigatorTree", "NodeURLGenerator", "NonInclusiveLanguageChecker", "NonOverviewHeadingChecker", "Options", "OutOfProcessReferenceResolver", "PageImage", "Parameter", "ParameterRenderSection", "ParametersRenderSection", "ParametersSection", "Platform", "PlatformName", "PlatformVersion", "PossibleValuesRenderSection", "PresentationURLGenerator", "PrintCursor", "Problem", "PropertiesRenderSection", "Redirect", "Relationship", "RelationshipsGroup", "RelationshipsRenderSection", "RelationshipsSection", "RemoveAutomaticallyCuratedSeeAlsoSectionsTransformation", "RemoveHierarchyTransformation", "RemoveUnusedReferencesTransformation", "RenderAttribute", "RenderBlockContent", "RenderContentMetadata", "RenderContext", "RenderHierarchy", "RenderHierarchyChapter", "RenderHierarchyLandmark", "RenderHierarchyTutorial", "RenderIndex", "RenderInlineContent", "RenderJSONDecoder", "RenderJSONEncoder", "RenderMetadata", "RenderNode", "RenderNodeDataExtractor", "RenderNodeProvider", "RenderNodeTransformation", "RenderNodeTransformationComposition", "RenderNodeTransformationContext", "RenderNodeTransformer", "RenderNodeTransforming", "RenderNodeTranslator", "RenderProperty", "RenderReference", "RenderReferenceCache", "RenderReferenceDependencies", "RenderReferenceIdentifier", "RenderReferenceStore", "RenderReferenceType", "RenderRelationshipsGroup", "RenderSection", "RenderSectionKind", "RenderTile", "RenderTree", "Replacement", "ResourceReference", "Resources", "ResourcesRenderSection", "RESTEndpointRenderSection", "Return", "ReturnsSection", "Row", "SampleDownloadSection", "Section", "SeeAlsoInTopicsHeadingChecker", "SeeAlsoSection", "Semantic", "SemanticAnalysis", "SemanticVersion", "SemanticVisitor", "SemanticWalker", "Serializable", "shouldPrettyPrintOutputJSON", "SimpleTag", "Small", "Snippet", "Solution", "SourceRepository", "SRGBColor", "Stack", "Step", "Steps", "Symbol", "SymbolReference", "Synchronized", "TabNavigator", "TaskGroup", "TaskGroupRenderSection", "Technology", "TechnologyBound", "TextIndexing", "Throw", "Tile", "TitleStyle", "TopicImage", "TopicReference", "TopicReferenceSchemeHandler", "TopicRenderReference", "TopicsSection", "TopicsSectionWithoutSubheading", "TopicsVisualStyle", "Tutorial", "TutorialArticle", "TutorialArticleSection", "TutorialAssessmentsRenderSection", "TutorialReference", "TutorialSection", "TutorialSectionsRenderSection", "TypeDetails", "UnresolvedCodeListingReference", "UnresolvedRenderReference", "URLReference", "ValidatedURL", "VariantCollection", "VariantContainer", "VariantOverride", "VariantOverrides", "VariantPatchOperation", "VideoMedia", "VideoReference", "Volume", "VolumeRenderSection", "WebKitCommunicationBridge", "XcodeRequirement", "XcodeRequirementReference"
        ]
        
        checkBestMatches(for: allTopLevelSwiftDocCSymbols, against: "DocumentationConte", expectedMatches: [
            // These need to be in the best matches in this order
            "DocumentationContext",
            "DocumentationContentRenderer",
            "DocumentationContextConverter",
            "DocumentationContextDataProvider",
            "DocumentationContextDataProviderDelegate",
            "DocumentationConverter",
            "DocumentationConverterProtocol",
            "DocumentationCoverageLevel",
            "DocumentationCoverageOptions",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
            
            // "Converter" and "Cont" is somewhat close.
            "DocumentationNodeConverter",
            // These (and more) have the "Documentation" prefix but doesn't match "Cont".
            "DocumentationNode",
            "DocumentationBundle",
            "DocumentationServer",
            "DocumentationService",
            "DocumentationWorkspace",
        ])
        
        checkBestMatches(for: allTopLevelSwiftDocCSymbols, against: "Convert", expectedMatches: [
            // These need to be in the best matches in this order.
            "Converter",
            "ConvertRequest",
            "ConvertService",
            "ConvertResponse",
            "ConvertServiceError",
            "ConvertOutputConsumer",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
            //
            // Most of the string doesn't match.
            "ConvertRequestContextWrapper",
            // Start doesn't match.
            "MarkupConvertible"
        ])
        
        checkBestMatches(for: allTopLevelSwiftDocCSymbols, against: "RenderJSONCoder", expectedMatches: [
            // These need to be in the best matches in this order
            "RenderJSONDecoder",
            "RenderJSONEncoder",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
            //
            // "Node" is somewhat close to "Coder".
            "RenderNode",
            "RenderNodeProvider",
            "RenderNodeTranslator",
            "RenderNodeTransformer",
            "RenderNodeTransforming",
        ])
        
        checkBestMatches(for: allTopLevelSwiftDocCSymbols, against: "Diagnostic", expectedMatches: [
            // These need to be in the best matches in this order.
            "Diagnostic",
            "DiagnosticNote",
            "DiagnosticEngine",
            "DiagnosticConsumer",
            "DiagnosticSeverity",
        ], acceptedMatches: [
            // These don't need to be in the best matches but it's acceptable if they are.
            //
            // Most of the string doesn't match.
            "DiagnosticConsoleWriter",
            "DiagnosticFormattingOptions",
            "DiagnosticFormattingConsumer",
            // Start doesn't match.
            "BasicDiagnostic",
        ])
    }
    
    func checkBestMatches(
        for possibilities: [String],
        against authored: String,
        expectedMatches: [String],
        acceptedMatches: [String] = [],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let matches = NearMiss.bestMatches(for: possibilities, against: authored)

        let matchesPrefix = Array(matches.prefix(expectedMatches.count))
        XCTAssertEqual(matchesPrefix, expectedMatches, """
            Best matches should contain all expected values in the expected order:
            First \(matchesPrefix.count) found matches:
                \(matchesPrefix.joined(separator: "\n    "))
            
            Expected matches:
                \(expectedMatches.joined(separator: "\n    "))
            
            Differences:
            \(matchesPrefix.difference(from: expectedMatches).inferringMoves().diffDump)
            """, file: file, line: line)
        
        let matchesSuffix = Array(matches.dropFirst(expectedMatches.count))
        
        var filteredAcceptedMatches = acceptedMatches
        
        for change in matchesSuffix.difference(from: acceptedMatches) {
            if case .remove(let offset, _, _) = change {
                // Accepted matches doesn't need to be in the best matches list.
                filteredAcceptedMatches.remove(at: offset)
            }
            // Any insertion is an unexpected match. Do nothing, it will be verified below.
        }
        
        XCTAssertEqual(matchesSuffix, filteredAcceptedMatches, """
            Best matches should have accepted matches in the expected order (if at all):
            Found matches \(matchesPrefix.count) and later:
                \(matchesSuffix.joined(separator: "\n    "))
            
            Accepted matches:
                \(acceptedMatches.joined(separator: "\n    "))
            
            Unexpected matches:
            \(matchesSuffix.difference(from: filteredAcceptedMatches).inferringMoves().diffDump)
            """, file: file, line: line)
    }
}
