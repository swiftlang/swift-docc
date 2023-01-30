/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An asset resolver that can be used to resolve assets that couldn't be resolved locally.
public protocol _ExternalAssetResolver {
    // This protocol only exist so that externally resolved media references can be returned separately from the external
    // content that is known to reference them. See details in OutOfProcessReferenceResolver.addImagesAndCacheMediaReferences(to:from:)
    // We should remove it when that's no longer necessary.
    // FIXME: https://github.com/apple/swift-docc/issues/468
    
    /// Attempts to resolve an asset that couldn't be resolved externally given its name and the bundle it's apart of.
    func _resolveExternalAsset(named assetName: String, bundleIdentifier: String) -> DataAsset?
}
