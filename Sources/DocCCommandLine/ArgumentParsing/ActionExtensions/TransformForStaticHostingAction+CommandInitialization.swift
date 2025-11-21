/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import ArgumentParser


extension TransformForStaticHostingAction {
    /// Initializes ``TransformForStaticHostingAction`` from the options in the ``TransformForStaticHosting`` command.
    /// - Parameters:
    ///   - cmd: The emit command this `TransformForStaticHostingAction` will be based on.
    init(fromCommand cmd: Docc.ProcessArchive.TransformForStaticHosting, withFallbackTemplate fallbackTemplateURL: URL? = nil) throws {
        // Initialize the `TransformForStaticHostingAction` from the options provided by the `EmitStaticHostable` command
        
        guard let htmlTemplateFolder = cmd.templateOption.templateURL ?? fallbackTemplateURL else {
            throw TemplateOption.missingHTMLTemplateError(
                path: cmd.templateOption.defaultTemplateURL.path
            )
        }
        
        try self.init(
            documentationBundleURL: cmd.documentationArchive.urlOrFallback,
            outputURL: cmd.outputURL,
            hostingBasePath: cmd.hostingBasePath,
            htmlTemplateDirectory: htmlTemplateFolder )
    }
}
