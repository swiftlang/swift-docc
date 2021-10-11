/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension PreviewAction {
    /// Creates a preview action with the given preview options.
    /// - Parameters:
    ///   - previewOptions: The preview options this `PreviewAction` will be based on.
    ///   - fallbackTemplateURL: A template URL to use if the one provided by the preview options is `nil`.
    ///   - printTemplatePath: Whether or not the HTML template used by the convert action should be printed when the action
    public convenience init(
        fromPreviewOptions previewOptions: PreviewOptions,
        withFallbackTemplate fallbackTemplateURL: URL? = nil,
        printTemplatePath: Bool = true) throws
    {
        // Initialize the `PreviewAction` from the options provided by the `Preview` command
        try self.init(
            tlsCertificateKey: previewOptions.externalConnectionOptions.tlsCertificateKeyURL,
            tlsCertificateChain: previewOptions.externalConnectionOptions.tlsCertificateChainURL,
            serverUsername: previewOptions.externalConnectionOptions.username,
            serverPassword: previewOptions.externalConnectionOptions.password,
            port: previewOptions.port,
            createConvertAction: {
                try ConvertAction(
                    fromConvertCommand: previewOptions.convertCommand,
                    withFallbackTemplate: fallbackTemplateURL
                )
            },
            printTemplatePath: printTemplatePath)
    }
}
