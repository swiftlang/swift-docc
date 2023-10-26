/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SwiftDocC
import Foundation

extension InitAction {
    /// Creates a init action from the options given in the init command
    /// - Parameters:
    ///   - initOptions: The init options this `InitAction` will be based on.
    public init(
        fromInitOptions initOptions: InitOptions
    ) throws {
        // Initialize the `InitAction` from the options provided by the `Init` command
        try self.init(
            catalogOutputDirectory: initOptions.providedCatalogOutputDirURL,
            documentationTitle: initOptions.name,
            catalogTemplate: initOptions.catalogTemplate
        )
    }
}
