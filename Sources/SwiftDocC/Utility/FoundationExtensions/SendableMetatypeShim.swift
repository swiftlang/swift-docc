/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// In Swift 6.2, metatypes are no longer sendable by default (SE-0470).
// Instead a type needs to conform to `SendableMetatype` to indicate that its metatype is sendable.
//
// However, `SendableMetatype` doesn't exist before Swift 6.1 so we define an internal alias to `Any` here.
// This means that conformances to `SendableMetatype` has no effect before 6.2 indicates metatype sendability in 6.2 onwards.
//
// Note: Adding a protocol requirement to a _public_ API is a breaking change.

#if compiler(<6.2)
typealias SendableMetatype = Any
#endif
