/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension DocumentationContext {
    @available(*, deprecated, message: "This deprecated API will be removed after 6.0 is released")
    public var _externalAssetResolvers: [BundleIdentifier: _ExternalAssetResolver] {
        get { [:] }
        set { /* do nothing */ }
    }
    
    @available(*, deprecated, renamed: "globalExternalSymbolResolver", message: "Use 'globalExternalSymbolResolver' instead. This deprecated API will be removed after 6.0 is released")
    public var externalSymbolResolver: ExternalSymbolResolver? {
        get { nil }
        set { /* do nothing */ }
    }
    
    @available(*, deprecated, renamed: "externalDocumentationSources", message: "Use 'externalDocumentationSources' instead. This deprecated API will be removed after 6.0 is released")
    public var externalReferenceResolvers: [BundleIdentifier: ExternalReferenceResolver] {
        get { [:] }
        set { /* do nothing */ }
    }
    
    @available(*, deprecated, renamed: "convertServiceFallbackResolver", message: "Use 'convertServiceFallbackResolver' instead. This deprecated API will be removed after 6.0 is released")
    public var fallbackReferenceResolvers: [BundleIdentifier: FallbackReferenceResolver] {
        get { [:] }
        set { /* do nothing */ }
    }
    
    @available(*, deprecated, renamed: "convertServiceFallbackResolver", message: "Use 'convertServiceFallbackResolver' instead. This deprecated API will be removed after 6.0 is released")
    public var fallbackAssetResolvers: [BundleIdentifier: FallbackAssetResolver] {
        get { [:] }
        set { /* do nothing */ }
    }
}
