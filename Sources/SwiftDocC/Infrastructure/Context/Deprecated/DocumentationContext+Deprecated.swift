/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DocumentationContext {
    
    @available(*, deprecated, renamed: "configuration.externalMetadata", message: "Use 'configuration.externalMetadata' instead. This deprecated API will be removed after Swift 6.2 is released.")
    public var externalMetadata: ExternalMetadata {
        get { configuration.externalMetadata }
        set { configuration.externalMetadata = newValue }
    }
    
    @available(*, deprecated, renamed: "configuration.externalDocumentationConfiguration.sources", message: "Use 'configuration.externalDocumentationConfiguration.sources' instead. This deprecated API will be removed after Swift 6.2 is released.")
    public var externalDocumentationSources: [BundleIdentifier: any ExternalDocumentationSource] {
        get {
            var result = [BundleIdentifier: any ExternalDocumentationSource]()
            for (key, value) in configuration.externalDocumentationConfiguration.sources {
                result[key.rawValue] = value
            }
            return result
        }
        set {
            configuration.externalDocumentationConfiguration.sources.removeAll()
            for (key, value) in newValue {
                configuration.externalDocumentationConfiguration.sources[.init(rawValue: key)] = value
            }
        }
    }
    
    @available(*, deprecated, renamed: "configuration.externalDocumentationConfiguration.globalSymbolResolver", message: "Use 'configuration.externalDocumentationConfiguration.globalSymbolResolver' instead. This deprecated API will be removed after Swift 6.2 is released.")
    public var globalExternalSymbolResolver: (any GlobalExternalSymbolResolver)? {
        get { configuration.externalDocumentationConfiguration.globalSymbolResolver }
        set { configuration.externalDocumentationConfiguration.globalSymbolResolver = newValue }
    }
    
    @available(*, deprecated, renamed: "configuration.experimentalCoverageConfiguration.shouldStoreManuallyCuratedReferences", message: "Use 'configuration.experimentalCoverageConfiguration.shouldStoreManuallyCuratedReferences' instead. This deprecated API will be removed after Swift 6.2 is released.")
    public var shouldStoreManuallyCuratedReferences: Bool {
        get { configuration.experimentalCoverageConfiguration.shouldStoreManuallyCuratedReferences }
        set { configuration.experimentalCoverageConfiguration.shouldStoreManuallyCuratedReferences = newValue }
    }
}
