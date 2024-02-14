/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

private struct DeprecatedAPIError: DescribedError {
    var apiName: String
    init(apiName: String = #function) {
        self.apiName = apiName
    }
    
    var errorDescription: String {
        return "\(apiName.singleQuoted) is deprecated and is no longer used."
    }
}

// MARK: External Symbol Resolver

@available(*, deprecated, renamed: "GlobalExternalSymbolResolver", message: "Use 'GlobalExternalSymbolResolver' instead. This deprecated API will be removed after 5.11 is released")
public protocol ExternalSymbolResolver {
    func symbolEntity(withPreciseIdentifier preciseIdentifier: String) throws -> DocumentationNode
    func urlForResolvedSymbol(reference: ResolvedTopicReference) -> URL?
    func preciseIdentifier(forExternalSymbolReference reference: TopicReference) -> String?
}

@available(*, deprecated)
extension OutOfProcessReferenceResolver: ExternalSymbolResolver {
    @_disfavoredOverload
    public func symbolEntity(withPreciseIdentifier _: String) throws -> DocumentationNode {
        assertionFailure("\(#function) is deprecated and is no longer used.")
        throw DeprecatedAPIError()
    }
    public func preciseIdentifier(forExternalSymbolReference _: TopicReference) -> String? {
        assertionFailure("\(#function) is deprecated and is no longer used.")
        return nil
    }
    public func urlForResolvedSymbol(reference _: ResolvedTopicReference) -> URL? {
        assertionFailure("\(#function) is deprecated and is no longer used.")
        return nil
    }
}

// MARK: External Reference Resolver

@available(*, deprecated, renamed: "ExternalDocumentationSource", message: "Use 'ExternalDocumentationSource' instead. This deprecated API will be removed after 5.11 is released")
public protocol ExternalReferenceResolver {
    func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReferenceResolutionResult
    func entity(with reference: ResolvedTopicReference) throws -> DocumentationNode
    func urlForResolvedReference(_ reference: ResolvedTopicReference) -> URL
}

@available(*, deprecated)
extension OutOfProcessReferenceResolver: ExternalReferenceResolver {
    @_disfavoredOverload
    public func entity(with _: ResolvedTopicReference) throws -> DocumentationNode {
        assertionFailure("\(#function) is deprecated and is no longer used.")
        throw DeprecatedAPIError()
    }
    public func urlForResolvedReference(_ reference: ResolvedTopicReference) -> URL {
        assertionFailure("\(#function) is deprecated and is no longer used.")
        return reference.url.withoutHostAndPortAndScheme()
    }
    public func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReferenceResolutionResult {
        assertionFailure("\(#function) is deprecated and is no longer used.")
        return resolve(reference)
    }
}

// MARK: Fallback Reference Resolver

@available(*, deprecated, renamed: "ConvertServiceFallbackResolver", message: "Use 'ConvertServiceFallbackResolver' instead. This deprecated API will be removed after 5.11 is released")
public protocol FallbackReferenceResolver {
    func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReferenceResolutionResult
    func entityIfPreviouslyResolved(with reference: ResolvedTopicReference) throws -> DocumentationNode?
    func urlForResolvedReferenceIfPreviouslyResolved(_ reference: ResolvedTopicReference) -> URL?
}

@available(*, deprecated)
extension OutOfProcessReferenceResolver: FallbackReferenceResolver {
    public func entityIfPreviouslyResolved(with reference: ResolvedTopicReference) throws -> DocumentationNode? {
        assertionFailure("\(#function) is deprecated and is no longer used.")
        return nil
    }
    
    public func urlForResolvedReferenceIfPreviouslyResolved(_ reference: ResolvedTopicReference) -> URL? {
        assertionFailure("\(#function) is deprecated and is no longer used.")
        return nil
    }
}

// MARK: Fallback Asset Resolver

@available(*, deprecated, renamed: "ConvertServiceFallbackResolver", message: "Use 'ConvertServiceFallbackResolver' instead. This deprecated API will be removed after 5.11 is released")
public protocol FallbackAssetResolver {
    func resolve(assetNamed assetName: String, bundleIdentifier: String) -> DataAsset?
}

@available(*, deprecated)
extension OutOfProcessReferenceResolver: FallbackAssetResolver {
    public func resolve(assetNamed assetName: String, bundleIdentifier: String) -> DataAsset? {
        assertionFailure("\(#function) is deprecated and is no longer used.")
        return nil
    }
}

// MARK: External Asset Resolver

@available(*, deprecated, message: "This protocol is not used. This deprecated API will be removed after 5.11 is released")
public protocol _ExternalAssetResolver {
    func _resolveExternalAsset(named assetName: String, bundleIdentifier: String) -> DataAsset?
}

@available(*, deprecated)
extension OutOfProcessReferenceResolver: _ExternalAssetResolver {
    public func _resolveExternalAsset(named assetName: String, bundleIdentifier: String) -> DataAsset? {
        assertionFailure("\(#function) is deprecated and is no longer used.")
        return nil
    }
}
