#[[
This source file is part of the swift-format open source project

Copyright (c) 2024 Apple Inc. and the DocC project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(SwiftDocCUtilities STATIC
  Action/Action.swift
  Action/ActionResult.swift
  Action/Actions/Action+MoveOutput.swift
  Action/Actions/Convert/ConvertAction.swift
  Action/Actions/Convert/ConvertFileWritingConsumer.swift
  Action/Actions/Convert/CoverageDataEntry+generateSummary.swift
  Action/Actions/Convert/Indexer.swift
  Action/Actions/Convert/JSONEncodingRenderNodeWriter.swift
  Action/Actions/CoverageAction.swift
  Action/Actions/EmitGeneratedCurationAction.swift
  Action/Actions/IndexAction.swift
  Action/Actions/Init/CatalogTemplate.swift
  Action/Actions/Init/CatalogTemplateKind.swift
  Action/Actions/Init/InitAction.swift
  Action/Actions/Merge/MergeAction.swift
  Action/Actions/Merge/MergeAction+SynthesizedLandingPage.swift
  Action/Actions/PreviewAction.swift
  Action/Actions/TransformForStaticHostingAction.swift
  ArgumentParsing/ActionExtensions/Action+performAndHandleResult.swift
  ArgumentParsing/ActionExtensions/ConvertAction+CommandInitialization.swift
  ArgumentParsing/ActionExtensions/EmitGeneratedCurationAction+CommandInitialization.swift
  ArgumentParsing/ActionExtensions/IndexAction+CommandInitialization.swift
  ArgumentParsing/ActionExtensions/InitAction+CommandInitialization.swift
  ArgumentParsing/ActionExtensions/PreviewAction+CommandInitialization.swift
  ArgumentParsing/ActionExtensions/TransformForStaticHostingAction+CommandInitialization.swift
  ArgumentParsing/ArgumentValidation/URLArgumentValidator.swift
  ArgumentParsing/Options/DirectoryPathOption.swift
  ArgumentParsing/Options/DocumentationArchiveOption.swift
  ArgumentParsing/Options/DocumentationBundleOption.swift
  ArgumentParsing/Options/DocumentationCoverageOptionsArgument.swift
  ArgumentParsing/Options/InitOptions.swift
  ArgumentParsing/Options/OutOfProcessLinkResolverOption.swift
  ArgumentParsing/Options/PreviewOptions.swift
  "ArgumentParsing/Options/Source Repository/SourceRepositoryArguments.swift"
  ArgumentParsing/Options/TemplateOption.swift
  ArgumentParsing/Subcommands/Convert.swift
  ArgumentParsing/Subcommands/EmitGeneratedCuration.swift
  ArgumentParsing/Subcommands/Index.swift
  ArgumentParsing/Subcommands/Init.swift
  ArgumentParsing/Subcommands/Merge.swift
  ArgumentParsing/Subcommands/Preview.swift
  ArgumentParsing/Subcommands/ProcessArchive.swift
  ArgumentParsing/Subcommands/ProcessCatalog.swift
  ArgumentParsing/Subcommands/TransformForStaticHosting.swift
  Docc.swift
  PreviewServer/PreviewHTTPHandler.swift
  PreviewServer/PreviewServer.swift
  PreviewServer/RequestHandler/DefaultRequestHandler.swift
  PreviewServer/RequestHandler/ErrorRequestHandler.swift
  PreviewServer/RequestHandler/FileRequestHandler.swift
  PreviewServer/RequestHandler/HTTPResponseHead+FromRequest.swift
  PreviewServer/RequestHandler/RequestHandlerFactory.swift
  Transformers/StaticHostableTransformer.swift
  Utility/DirectoryMonitor.swift
  Utility/FoundationExtensions/Sequence+Unique.swift
  Utility/FoundationExtensions/String+Path.swift
  Utility/FoundationExtensions/URL+IsAbsoluteWebURL.swift
  Utility/FoundationExtensions/URL+Relative.swift
  Utility/PlatformArgumentParser.swift
  Utility/Signal.swift
  Utility/Throttle.swift)
target_link_libraries(SwiftDocCUtilities PUBLIC
  ArgumentParser
  SwiftDocC)
