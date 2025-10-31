/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

struct CatalogTemplate {
    
    let files: [String: String]
    let additionalDirectories: [String]
    
    /// Creates a Catalog Template using one of the provided template kinds.
    init(_ templateKind: CatalogTemplateKind, title: String) throws {
        switch templateKind {
        case .articleOnly:
            self.files = CatalogTemplateKind.articleOnlyTemplateFiles(title)
            self.additionalDirectories = ["Resources"]
        case .tutorial:
            self.files = CatalogTemplateKind.tutorialTemplateFiles(title)
            self.additionalDirectories = ["Resources", "Chapter01/Resources"]
            
        }
    }
}
