/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A node that represents API symbol hierarchy.
public struct RenderReferenceHierarchy: Codable {
    /// The paths (breadcrumbs) that lead from the landing page to the given symbol.
    ///
    /// A single path is a list of topic-graph references, that trace the curation
    /// through the documentation hierarchy from a framework landing page to a
    /// given target symbol.
    ///
    /// Symbols curated multiple times have multiple paths, for example:
    ///  - Example Framework / Example Type / Example Property
    ///  - Example Framework / My Article / Example Type / Example Property
    ///  - Example Framework / Related Type / Example Property
    /// > Note: The first element in `paths` is the _canonical_ breadcrumb for the symbol.
    ///
    /// Landing pages' hierarchy contains a single, empty path.
    public let paths: [[String]]
}
