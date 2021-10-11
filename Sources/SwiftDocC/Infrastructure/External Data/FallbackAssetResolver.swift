/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An asset resolver that can be used to resolve assets that couldn't be resolved locally.
public protocol FallbackAssetResolver {
    /// Attempts to resolve an asset that couldn't be resolved externally given its name and the bundle it's apart of.
    func resolve(assetNamed assetName: String, bundleIdentifier: String) -> DataAsset?
}
