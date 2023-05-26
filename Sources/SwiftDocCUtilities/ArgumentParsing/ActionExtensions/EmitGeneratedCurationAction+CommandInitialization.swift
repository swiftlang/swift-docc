/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import ArgumentParser

extension EmitGeneratedCurationAction {
    /// Initializes ``EmitGeneratedCurationAction`` from the options in the ``EmitGeneratedCuration`` command.
    /// - Parameters:
    ///   - cmd: The emit command this `TransformForStaticHosting` will be based on.
    init(fromCommand cmd: Docc.ProcessCatalog.EmitGeneratedCuration) throws {
        try self.init(
            documentationCatalog: cmd.documentationCatalog,
            additionalSymbolGraphDirectory: cmd.additionalSymbolGraphDirectory,
            outputURL: cmd.outputURL,
            shortenExistingLinks: cmd.shortenExistingLinks
        )
    }
}
