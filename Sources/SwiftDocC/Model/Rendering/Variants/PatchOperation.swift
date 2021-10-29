/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// The patch operation to apply.
///
/// Values of this type follow the [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) format.
///
/// > Warning: The cases of this enumeration are non-exhaustive for the supported operations of JSON Patch schema. Further JSON Patch operations may
/// be added in the future.
public enum PatchOperation: String, Codable {
    /// A replacement operation.
    case replace
    
    /// An add operation.
    case add
    
    /// A removal operation.
    case remove
}
