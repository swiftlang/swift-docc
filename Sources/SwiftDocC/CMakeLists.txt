#[[
This source file is part of the Swift open source project

Copyright © 2014 - 2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(SwiftDocC
  Benchmark/Benchmark.swift
  Benchmark/BenchmarkResults.swift
  Benchmark/Metrics.swift
  Benchmark/Metrics/Duration.swift
  Benchmark/Metrics/ExternalTopicsHash.swift
  Benchmark/Metrics/OutputSize.swift
  Benchmark/Metrics/PeakMemory.swift
  Benchmark/Metrics/TopicAnchorHash.swift
  Benchmark/Metrics/TopicGraphHash.swift
  "Catalog Processing/GeneratedCurationWriter.swift"
  Checker/Checker.swift
  Checker/Checkers/AbstractContainsFormattedTextOnly.swift
  Checker/Checkers/DuplicateTopicsSection.swift
  Checker/Checkers/InvalidAdditionalTitle.swift
  Checker/Checkers/InvalidCodeBlockOption.swift
  Checker/Checkers/MissingAbstract.swift
  Checker/Checkers/NonInclusiveLanguageChecker.swift
  Checker/Checkers/NonOverviewHeadingChecker.swift
  Checker/Checkers/SeeAlsoInTopicsHeadingChecker.swift
  Converter/DocumentationContextConverter.swift
  Converter/DocumentationNodeConverter.swift
  Converter/RenderNode+Coding.swift
  Converter/Rewriter/RemoveHierarchyTransformation.swift
  Converter/Rewriter/RemoveUnusedReferencesTransformation.swift
  Converter/Rewriter/RenderNodeTransformationComposition.swift
  Converter/Rewriter/RenderNodeTransformationContext.swift
  Converter/Rewriter/RenderNodeTransformer.swift
  Converter/Rewriter/RenderNodeTransforming.swift
  Converter/TopicRenderReferenceEncoder.swift
  Coverage/DocumentationCoverageOptions.swift
  DocumentationService/Convert/ConvertService+DataProvider.swift
  DocumentationService/Convert/ConvertService.swift
  "DocumentationService/Convert/Fallback Link Resolution/ConvertServiceFallbackResolver.swift"
  "DocumentationService/Convert/Symbol Link Resolution/LinkCompletionTools.swift"
  DocumentationService/DocumentationServer+createDefaultServer.swift
  DocumentationService/ExternalReferenceResolverServiceClient.swift
  DocumentationService/Models/DocumentationServer+Message.swift
  DocumentationService/Models/DocumentationServer+MessageType.swift
  DocumentationService/Models/DocumentationServer.swift
  DocumentationService/Models/DocumentationServerError.swift
  DocumentationService/Models/DocumentationServerProtocol.swift
  DocumentationService/Models/DocumentationService.swift
  DocumentationService/Models/Services/Convert/ConvertRequest.swift
  DocumentationService/Models/Services/Convert/ConvertRequestContextWrapper.swift
  DocumentationService/Models/Services/Convert/ConvertResponse.swift
  DocumentationService/Models/Services/Convert/ConvertServiceError.swift
  Indexing/Indexable.swift
  Indexing/IndexingError.swift
  Indexing/IndexingRecord.swift
  Indexing/Navigator/AvailabilityIndex+Ext.swift
  Indexing/Navigator/AvailabilityIndex.swift
  Indexing/Navigator/NavigatorIndex.swift
  Indexing/Navigator/NavigatorItem.swift
  Indexing/Navigator/NavigatorTree.swift
  Indexing/Navigator/RenderNode+NavigatorIndex.swift
  Indexing/RenderBlockContent+TextIndexing.swift
  Indexing/RenderIndexJSON/RenderIndex.swift
  Indexing/RenderInlineContent+TextIndexing.swift
  Indexing/RenderNode+Indexable.swift
  Indexing/RenderNode+Relationships.swift
  Indexing/RenderSection+TextIndexing.swift
  Indexing/TutorialSectionsRenderSection+Indexable.swift
  "Infrastructure/Bundle Assets/BundleData.swift"
  "Infrastructure/Bundle Assets/DataAssetManager.swift"
  "Infrastructure/Bundle Assets/SVGIDExtractor.swift"
  "Infrastructure/Communication/Code colors/CodeColors.swift"
  "Infrastructure/Communication/Code colors/CodeColorsPreferenceKey.swift"
  "Infrastructure/Communication/Code colors/SRGBColor.swift"
  Infrastructure/Communication/CommunicationBridge.swift
  Infrastructure/Communication/Foundation/AnyCodable.swift
  Infrastructure/Communication/Foundation/JSON.swift
  Infrastructure/Communication/Message+Codable.swift
  Infrastructure/Communication/Message.swift
  Infrastructure/Communication/MessageType.swift
  Infrastructure/Communication/WebKitCommunicationBridge.swift
  Infrastructure/ContentCache.swift
  Infrastructure/Context/DocumentationContext+Configuration.swift
  Infrastructure/ConvertActionConverter.swift
  Infrastructure/ConvertOutputConsumer.swift
  Infrastructure/CoverageDataEntry.swift
  Infrastructure/Diagnostics/ANSIAnnotation.swift
  Infrastructure/Diagnostics/Diagnostic.swift
  Infrastructure/Diagnostics/DiagnosticConsoleWriter.swift
  Infrastructure/Diagnostics/DiagnosticConsumer.swift
  Infrastructure/Diagnostics/DiagnosticEngine.swift
  Infrastructure/Diagnostics/DiagnosticFile.swift
  Infrastructure/Diagnostics/DiagnosticFileWriter.swift
  Infrastructure/Diagnostics/DiagnosticFormattingOptions.swift
  Infrastructure/Diagnostics/DiagnosticNote.swift
  Infrastructure/Diagnostics/DiagnosticSeverity.swift
  Infrastructure/Diagnostics/ParseDirectiveArguments.swift
  Infrastructure/Diagnostics/Problem.swift
  Infrastructure/Diagnostics/Replacement.swift
  Infrastructure/Diagnostics/Solution.swift
  Infrastructure/Diagnostics/SourcePosition.swift
  Infrastructure/Diagnostics/TerminalHelper.swift
  Infrastructure/DocumentationBundle+Identifier.swift
  Infrastructure/DocumentationBundle.swift
  Infrastructure/DocumentationBundleFileTypes.swift
  Infrastructure/DocumentationContext+Breadcrumbs.swift
  Infrastructure/DocumentationContext.swift
  Infrastructure/DocumentationCurator.swift
  Infrastructure/Extensions/KindIdentifier+Curation.swift
  Infrastructure/Extensions/SymbolGraph.Symbol.Location+URL.swift
  "Infrastructure/External Data/ExternalDocumentationSource.swift"
  "Infrastructure/External Data/ExternalMetadata.swift"
  "Infrastructure/External Data/GlobalExternalSymbolResolver.swift"
  "Infrastructure/External Data/OutOfProcessReferenceResolver+Communication.swift"
  "Infrastructure/External Data/OutOfProcessReferenceResolver+DeprecatedCommunication.swift"
  "Infrastructure/External Data/OutOfProcessReferenceResolver.swift"
  "Infrastructure/Input Discovery/DataProvider.swift"
  "Infrastructure/Input Discovery/DocumentationInputsProvider.swift"
  "Infrastructure/Link Resolution/ExternalPathHierarchyResolver.swift"
  "Infrastructure/Link Resolution/LinkResolver+NavigatorIndex.swift"
  "Infrastructure/Link Resolution/LinkResolver.swift"
  "Infrastructure/Link Resolution/PathHierarchy+DisambiguatedPaths.swift"
  "Infrastructure/Link Resolution/PathHierarchy+Dump.swift"
  "Infrastructure/Link Resolution/PathHierarchy+Error.swift"
  "Infrastructure/Link Resolution/PathHierarchy+Find.swift"
  "Infrastructure/Link Resolution/PathHierarchy+PathComponent.swift"
  "Infrastructure/Link Resolution/PathHierarchy+Serialization.swift"
  "Infrastructure/Link Resolution/PathHierarchy+TypeSignature.swift"
  "Infrastructure/Link Resolution/PathHierarchy+TypeSignatureDisambiguation.swift"
  "Infrastructure/Link Resolution/PathHierarchy.swift"
  "Infrastructure/Link Resolution/PathHierarchyBasedLinkResolver+Breadcrumbs.swift"
  "Infrastructure/Link Resolution/PathHierarchyBasedLinkResolver+Overloads.swift"
  "Infrastructure/Link Resolution/PathHierarchyBasedLinkResolver.swift"
  "Infrastructure/Link Resolution/SnippetResolver.swift"
  Infrastructure/NodeURLGenerator.swift
  "Infrastructure/Symbol Graph/AccessControl+Comparable.swift"
  "Infrastructure/Symbol Graph/ExtendedTypeFormatExtension.swift"
  "Infrastructure/Symbol Graph/ExtendedTypeFormatTransformation.swift"
  "Infrastructure/Symbol Graph/GeneratedDocumentationTopics.swift"
  "Infrastructure/Symbol Graph/ResolvedTopicReference+Symbol.swift"
  "Infrastructure/Symbol Graph/SymbolGraphLoader.swift"
  "Infrastructure/Symbol Graph/SymbolGraphRelationshipsBuilder.swift"
  "Infrastructure/Symbol Graph/SymbolReference.swift"
  "Infrastructure/Symbol Graph/UnresolvedTopicReference+Symbol.swift"
  "Infrastructure/Topic Graph/AutomaticCuration.swift"
  "Infrastructure/Topic Graph/TopicGraph.swift"
  Infrastructure/Workspace/DefaultAvailability.swift
  Infrastructure/Workspace/DocumentationBundle+Info.swift
  Infrastructure/Workspace/DocumentationWorkspaceDataProvider.swift
  Infrastructure/Workspace/FeatureFlags+Info.swift
  LinkTargets/LinkDestinationSummary.swift
  Model/AnchorSection.swift
  Model/AvailabilityParser.swift
  Model/BuildMetadata.swift
  Model/DocumentationMarkup.swift
  Model/DocumentationNode.swift
  Model/Identifier.swift
  Model/Kind.swift
  Model/MarkdownOutput/Translation/MarkdownOutputSemanticVisitor.swift
  Model/MarkdownOutput/Translation/MarkdownOutputMarkdownWalker.swift
  Model/Markup+parsing.swift
  Model/Name.swift
  Model/ParametersAndReturnValidator.swift
  Model/Rendering/Content/Extensions/RenderTermLists.swift
  Model/Rendering/Content/RenderBlockContent+Capitalization.swift
  Model/Rendering/Content/RenderBlockContent.swift
  Model/Rendering/Content/RenderContentMetadata.swift
  Model/Rendering/Content/RenderInlineContent.swift
  Model/Rendering/Diffing/AnyRenderReference.swift
  Model/Rendering/Diffing/AnyRenderSection.swift
  Model/Rendering/Diffing/DifferenceBuilder.swift
  Model/Rendering/Diffing/Differences.swift
  Model/Rendering/Diffing/RenderNode+Diffable.swift
  Model/Rendering/DocumentationContentRenderer.swift
  Model/Rendering/HTML/HTMLContentConsumer.swift
  Model/Rendering/HTML/HTMLRenderer.swift
  Model/Rendering/LinkTitleResolver.swift
  "Model/Rendering/Navigation Tree/RenderHierarchy.swift"
  "Model/Rendering/Navigation Tree/RenderHierarchyChapter.swift"
  "Model/Rendering/Navigation Tree/RenderHierarchyLandmark.swift"
  "Model/Rendering/Navigation Tree/RenderHierarchyTranslator.swift"
  "Model/Rendering/Navigation Tree/RenderHierarchyTutorial.swift"
  "Model/Rendering/Navigation Tree/RenderReferenceHierarchy.swift"
  "Model/Rendering/Navigation Tree/RenderTutorialsHierarchy.swift"
  Model/Rendering/PresentationURLGenerator.swift
  Model/Rendering/References/AssetReferences.swift
  Model/Rendering/References/FileReference.swift
  Model/Rendering/References/ImageReference.swift
  Model/Rendering/References/LinkReference.swift
  Model/Rendering/References/MediaReference.swift
  Model/Rendering/References/RenderReference.swift
  Model/Rendering/References/TopicColor.swift
  Model/Rendering/References/TopicImage.swift
  Model/Rendering/References/TopicRenderReference.swift
  Model/Rendering/References/UnresolvedReference.swift
  Model/Rendering/References/VideoReference.swift
  Model/Rendering/RenderContentCompiler.swift
  Model/Rendering/RenderContentConvertible.swift
  Model/Rendering/RenderContext.swift
  Model/Rendering/RenderNode.Tag.swift
  Model/Rendering/RenderNode.swift
  Model/Rendering/RenderNodeTranslator.swift
  Model/Rendering/RenderNodeVariant.swift
  Model/Rendering/RenderNode/AnyMetadata.swift
  Model/Rendering/RenderNode/CodableContentSection.swift
  Model/Rendering/RenderNode/CodableRenderReference.swift
  Model/Rendering/RenderNode/CodableRenderSection.swift
  Model/Rendering/RenderNode/RenderMetadata.swift
  Model/Rendering/RenderNode/RenderNode+Codable.swift
  Model/Rendering/RenderReferenceStore.swift
  Model/Rendering/RenderSection.swift
  Model/Rendering/RenderSectionTranslator/AttributesSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/DeclarationsSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/DictionaryKeysSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/DiscussionSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/HTTPBodySectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/HTTPEndpointSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/HTTPParametersSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/HTTPResponsesSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/MentionsSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/ParametersSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/PlistDetailsSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/PossibleValuesSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/RenderSectionTranslator.swift
  Model/Rendering/RenderSectionTranslator/ReturnsSectionTranslator.swift
  Model/Rendering/SemanticVersion.swift
  Model/Rendering/Symbol/AttributesRenderSection.swift
  Model/Rendering/Symbol/AvailabilityRenderMetadataItem.swift
  Model/Rendering/Symbol/AvailabilitySortOrder.swift
  Model/Rendering/Symbol/ConformanceSection.swift
  Model/Rendering/Symbol/ContentRenderSection.swift
  Model/Rendering/Symbol/DeclarationRenderSection+SymbolGraph.swift
  Model/Rendering/Symbol/DeclarationsRenderSection.swift
  Model/Rendering/Symbol/DiffAvailability.swift
  Model/Rendering/Symbol/MentionsRenderSection.swift
  Model/Rendering/Symbol/ParameterRenderSection.swift
  Model/Rendering/Symbol/PossibleValuesRenderSection.swift
  Model/Rendering/Symbol/PropertiesRenderSection.swift
  Model/Rendering/Symbol/PropertyListDetailsRenderSection.swift
  Model/Rendering/Symbol/RESTBodyRenderSection.swift
  Model/Rendering/Symbol/RESTEndpointRenderSection.swift
  Model/Rendering/Symbol/RESTExampleRenderSection.swift
  Model/Rendering/Symbol/RESTParametersRenderSection.swift
  Model/Rendering/Symbol/RESTResponseRenderSection.swift
  Model/Rendering/Symbol/RelationshipsRenderSection.swift
  Model/Rendering/Symbol/SampleDownloadSection.swift
  Model/Rendering/Symbol/TaskGroupRenderSection.swift
  Model/Rendering/TopicsSectionStyle.swift
  "Model/Rendering/Tutorial Article/TutorialArticleSection.swift"
  Model/Rendering/Tutorial/LineHighlighter.swift
  Model/Rendering/Tutorial/References/DownloadReference.swift
  Model/Rendering/Tutorial/References/XcodeRequirementReference.swift
  Model/Rendering/Tutorial/Sections/IntroRenderSection.swift
  Model/Rendering/Tutorial/Sections/TutorialAssessmentsRenderSection.swift
  Model/Rendering/Tutorial/Sections/TutorialSectionsRenderSection.swift
  "Model/Rendering/Tutorials Overview/Resources/RenderTile.swift"
  "Model/Rendering/Tutorials Overview/Sections/CallToActionSection.swift"
  "Model/Rendering/Tutorials Overview/Sections/ContentAndMediaGroupSection.swift"
  "Model/Rendering/Tutorials Overview/Sections/ContentAndMediaSection.swift"
  "Model/Rendering/Tutorials Overview/Sections/ResourcesRenderSection.swift"
  "Model/Rendering/Tutorials Overview/Sections/VolumeRenderSection.swift"
  Model/Rendering/Variants/JSONPatchApplier.swift
  Model/Rendering/Variants/JSONPatchOperation.swift
  Model/Rendering/Variants/JSONPointer.swift
  Model/Rendering/Variants/PatchOperation.swift
  Model/Rendering/Variants/RenderNodeVariantOverridesApplier.swift
  Model/Rendering/Variants/VariantCollection+Coding.swift
  Model/Rendering/Variants/VariantCollection+Symbol.swift
  Model/Rendering/Variants/VariantCollection+Variant.swift
  Model/Rendering/Variants/VariantCollection.swift
  Model/Rendering/Variants/VariantContainer.swift
  Model/Rendering/Variants/VariantOverride.swift
  Model/Rendering/Variants/VariantOverrides.swift
  Model/Rendering/Variants/VariantPatchOperation.swift
  Model/Section/Section.swift
  Model/Section/Sections/Abstract.swift
  Model/Section/Sections/AutomaticTaskGroupSection.swift
  Model/Section/Sections/DefaultImplementations.swift
  Model/Section/Sections/DeprecatedSection.swift
  Model/Section/Sections/DictionaryKeysSection.swift
  Model/Section/Sections/Discussion.swift
  Model/Section/Sections/GroupedSection.swift
  Model/Section/Sections/HTTPBodySection.swift
  Model/Section/Sections/HTTPEndpointSection.swift
  Model/Section/Sections/HTTPParametersSection.swift
  Model/Section/Sections/HTTPResponsesSection.swift
  Model/Section/Sections/ParametersSection.swift
  Model/Section/Sections/PropertyListPossibleValuesSection.swift
  Model/Section/Sections/Relationships.swift
  Model/Section/Sections/ReturnsSection.swift
  Model/Section/Sections/SeeAlso.swift
  Model/Section/Sections/Topics.swift
  Model/Semantics/DictionaryKey.swift
  Model/Semantics/HTTPBody.swift
  Model/Semantics/HTTPParameter.swift
  Model/Semantics/HTTPResponse.swift
  Model/Semantics/LegacyTag.swift
  Model/Semantics/Parameter.swift
  Model/Semantics/Return.swift
  Model/Semantics/Throw.swift
  Model/TaskGroup.swift
  Semantics/Abstracted.swift
  Semantics/Article/Article.swift
  Semantics/Article/ArticleSymbolMentions.swift
  Semantics/Article/MarkupConvertible.swift
  Semantics/Comment.swift
  Semantics/ContentAndMedia.swift
  Semantics/DirectiveConvertable.swift
  Semantics/DirectiveInfrastructure/AutomaticDirectiveConvertible.swift
  Semantics/DirectiveInfrastructure/ChildDirectiveWrapper.swift
  Semantics/DirectiveInfrastructure/ChildMarkdownWrapper.swift
  Semantics/DirectiveInfrastructure/DirectiveArgumentValueConvertible.swift
  Semantics/DirectiveInfrastructure/DirectiveArgumentWrapper.swift
  Semantics/DirectiveInfrastructure/DirectiveIndex.swift
  Semantics/DirectiveInfrastructure/DirectiveMirror.swift
  Semantics/DirectiveInfrastructure/MarkupContaining.swift
  Semantics/DirectiveParser.swift
  Semantics/ExternalLinks/ExternalMarkupReferenceWalker.swift
  Semantics/ExternalLinks/ExternalReferenceWalker.swift
  "Semantics/General Purpose Analyses/DeprecatedArgument.swift"
  "Semantics/General Purpose Analyses/Extract.swift"
  "Semantics/General Purpose Analyses/HasArgumentOfType.swift"
  "Semantics/General Purpose Analyses/HasAtLeastOne.swift"
  "Semantics/General Purpose Analyses/HasAtMostOne.swift"
  "Semantics/General Purpose Analyses/HasContent.swift"
  "Semantics/General Purpose Analyses/HasExactlyOne.swift"
  "Semantics/General Purpose Analyses/HasOnlyKnownArguments.swift"
  "Semantics/General Purpose Analyses/HasOnlyKnownDirectives.swift"
  "Semantics/General Purpose Analyses/HasOnlySequentialHeadings.swift"
  Semantics/Graph/SymbolKind.Swift.swift
  Semantics/Intro.swift
  Semantics/Landmark.swift
  Semantics/Layout.swift
  Semantics/MarkupContainer.swift
  Semantics/MarkupReferenceResolver.swift
  Semantics/Media/ImageMedia.swift
  Semantics/Media/Media.swift
  Semantics/Media/VideoMedia.swift
  Semantics/Metadata/AlternateRepresentation.swift
  Semantics/Metadata/Availability.swift
  Semantics/Metadata/CallToAction.swift
  Semantics/Metadata/CustomMetadata.swift
  Semantics/Metadata/DisplayName.swift
  Semantics/Metadata/DocumentationExtension.swift
  Semantics/Metadata/Metadata.swift
  Semantics/Metadata/PageColor.swift
  Semantics/Metadata/PageImage.swift
  Semantics/Metadata/PageKind.swift
  Semantics/Metadata/SupportedLanguage.swift
  Semantics/Metadata/TechnologyRoot.swift
  Semantics/Metadata/TitleHeading.swift
  Semantics/Options/AutomaticArticleSubheading.swift
  Semantics/Options/AutomaticSeeAlso.swift
  Semantics/Options/AutomaticTitleHeading.swift
  Semantics/Options/Options.swift
  Semantics/Options/TopicsVisualStyle.swift
  Semantics/Redirect.swift
  Semantics/Redirected.swift
  Semantics/ReferenceResolver.swift
  Semantics/Reference/Links.swift
  Semantics/Reference/Row.swift
  Semantics/Reference/Small.swift
  Semantics/Reference/TabNavigator.swift
  Semantics/Semantic.swift
  Semantics/SemanticAnalyzer.swift
  Semantics/Snippets/Snippet.swift
  Semantics/Symbol/DeprecationSummary.swift
  Semantics/Symbol/DocumentationDataVariants+SymbolGraphSymbol.swift
  Semantics/Symbol/DocumentationDataVariants.swift
  Semantics/Symbol/PlatformName.swift
  Semantics/Symbol/Relationship.swift
  Semantics/Symbol/Symbol.swift
  Semantics/Symbol/UnifiedSymbol+Extensions.swift
  Semantics/Technology/Resources/Resources.swift
  Semantics/Technology/Resources/Tile.swift
  Semantics/Technology/TutorialTableOfContents.swift
  Semantics/Technology/Volume/Chapter/Chapter.swift
  Semantics/Technology/Volume/Chapter/TutorialReference.swift
  Semantics/Technology/Volume/Volume.swift
  Semantics/Timed.swift
  Semantics/Titled.swift
  Semantics/TutorialArticle/Stack.swift
  Semantics/TutorialArticle/TutorialArticle.swift
  Semantics/Tutorial/Assessments/Assessments.swift
  "Semantics/Tutorial/Assessments/Multiple Choice/Choice/Choice.swift"
  "Semantics/Tutorial/Assessments/Multiple Choice/Choice/Justification.swift"
  "Semantics/Tutorial/Assessments/Multiple Choice/MultipleChoice.swift"
  Semantics/Tutorial/Tasks/Steps/Code.swift
  Semantics/Tutorial/Tasks/Steps/Step.swift
  Semantics/Tutorial/Tasks/Steps/Steps.swift
  Semantics/Tutorial/Tasks/TutorialSection.swift
  Semantics/Tutorial/Tutorial.swift
  Semantics/Tutorial/XcodeRequirement.swift
  Semantics/Visitor/SemanticVisitor.swift
  Semantics/Walker/SemanticWalker.swift
  Semantics/Walker/Walkers/SemanticTreeDumper.swift
  Servers/DocumentationSchemeHandler.swift
  Servers/FileServer.swift
  SourceRepository/SourceRepository.swift
  SwiftDocCMarkdownOutput/MarkdownOutputManifest.swift
  SwiftDocCMarkdownOutput/MarkdownOutputNode.swift
  Utility/Checksum.swift
  Utility/Collection+ConcurrentPerform.swift
  Utility/CollectionChanges.swift
  Utility/CommonTypeExports.swift
  Utility/DataStructures/BidirectionalMap.swift
  Utility/DataStructures/GroupedSequence.swift
  Utility/DispatchGroup+Async.swift
  Utility/Errors/DescribedError.swift
  Utility/Errors/ErrorWithProblems.swift
  Utility/ExternalIdentifier.swift
  Utility/FeatureFlags.swift
  Utility/FileManagerProtocol+FilesSequence.swift
  Utility/FileManagerProtocol.swift
  Utility/FoundationExtensions/Array+baseType.swift
  Utility/FoundationExtensions/AutoreleasepoolShim.swift
  Utility/FoundationExtensions/CharacterSet.swift
  Utility/FoundationExtensions/Collection+indexed.swift
  Utility/FoundationExtensions/Dictionary+TypedValues.swift
  Utility/FoundationExtensions/NoOpSignposterShim.swift
  Utility/FoundationExtensions/Optional+baseType.swift
  Utility/FoundationExtensions/PlainTextShim.swift
  Utility/FoundationExtensions/RangeReplaceableCollection+Group.swift
  Utility/FoundationExtensions/SendableMetatypeShim.swift
  Utility/FoundationExtensions/Sequence+Categorize.swift
  Utility/FoundationExtensions/Sequence+FirstMap.swift
  Utility/FoundationExtensions/Sequence+RenderBlockContentElemenet.swift
  Utility/FoundationExtensions/SortByKeyPath.swift
  Utility/FoundationExtensions/String+Capitalization.swift
  Utility/FoundationExtensions/String+Hashing.swift
  Utility/FoundationExtensions/String+Path.swift
  Utility/FoundationExtensions/String+SingleQuoted.swift
  Utility/FoundationExtensions/String+Splitting.swift
  Utility/FoundationExtensions/String+Whitespace.swift
  Utility/FoundationExtensions/StringCollection+List.swift
  Utility/FoundationExtensions/URL+IsAbsoluteWebURL.swift
  Utility/FoundationExtensions/URL+Relative.swift
  Utility/FoundationExtensions/URL+WithFragment.swift
  Utility/FoundationExtensions/URL+WithoutHostAndPortAndScheme.swift
  Utility/Graphs/DirectedGraph+Cycles.swift
  Utility/Graphs/DirectedGraph+Paths.swift
  Utility/Graphs/DirectedGraph+Traversal.swift
  Utility/Graphs/DirectedGraph.swift
  Utility/LMDB/LMDB+Database.swift
  Utility/LMDB/LMDB+Environment.swift
  Utility/LMDB/LMDB+Error.swift
  Utility/LMDB/LMDB+Transaction.swift
  Utility/LMDB/LMDB.swift
  Utility/Language/EnglishLanguage.swift
  Utility/Language/NativeLanguage.swift
  Utility/ListItemUpdatable.swift
  Utility/LogHandle.swift
  Utility/MarkupExtensions/AnyLink.swift
  Utility/MarkupExtensions/BlockDirectiveExtensions.swift
  Utility/MarkupExtensions/DocumentExtensions.swift
  Utility/MarkupExtensions/Heading+StartsWithAnyLink.swift
  Utility/MarkupExtensions/ImageExtensions.swift
  Utility/MarkupExtensions/ListItemExtractor.swift
  Utility/MarkupExtensions/MarkupChildrenExtensions.swift
  Utility/MarkupExtensions/SourceRangeExtensions.swift
  Utility/NearMiss.swift
  Utility/RenderNodeDataExtractor.swift
  Utility/SemanticVersion+Comparable.swift
  Utility/SymbolGraphAvailability+Filter.swift
  Utility/Synchronization.swift
  Utility/ValidatedURL.swift
  Utility/Version.swift)
target_link_libraries(SwiftDocC PRIVATE
  DocCCommon)
target_link_libraries(SwiftDocC PRIVATE
  DocCHTML)
target_link_libraries(SwiftDocC PUBLIC
  SwiftMarkdown::Markdown
  DocC::SymbolKit
  LMDB::CLMDB
  Crypto)
# FIXME(compnerd) workaround leaking dependencies
target_link_libraries(SwiftDocC PUBLIC
  libcmark-gfm
  libcmark-gfm-extensions)

set_target_properties(SwiftDocC PROPERTIES
  Swift_LANGUAGE_VERSION 5)

if(BUILD_SHARED_LIBS)
  install(TARGETS SwiftDocC
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()
