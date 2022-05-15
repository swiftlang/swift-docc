/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation
import SwiftDocC

/// Command-line arguments for specifying the catalog's source repository information.
public struct SourceRepositoryArguments: ParsableArguments {
    public init() {}
    
    /// The root path on disk of the repository's checkout.
    @Option(
        help: ArgumentHelp(
            "The root path on disk of the repository's checkout."
        )
    )
    public var checkoutPath: String?
    
    /// The source code service used to host the project's sources.
    ///
    /// Required when using `--source-service-base-url`. Supported values are `github`, `gitlab`, and `bitbucket`.
    @Option(
        help: ArgumentHelp(
            "The source code service used to host the project's sources.",
            discussion: """
                Required when using '--source-service-base-url'. Supported values are 'github', 'gitlab', and 'bitbucket'.
                """
        )
    )
    public var sourceService: String?
    
    /// The base URL where the source service hosts the project's sources.
    ///
    /// Required when using `--source-service`. For example, `https://github.com/my-org/my-repo/blob/main`.
    @Option(
        help: ArgumentHelp(
            "The base URL where the source service hosts the project's sources.",
            discussion: """
                Required when using '--source-service'. For example, 'https://github.com/my-org/my-repo/blob/main'.
                """
        )
    )
    public var sourceServiceBaseURL: String?
}

extension SourceRepository {
    init?(from arguments: SourceRepositoryArguments) throws {
        switch (arguments.sourceService, arguments.sourceServiceBaseURL, arguments.checkoutPath) {
        case (nil, nil, nil):
            return nil
        case (nil, _, _):
            throw ValidationError(
                """
                Missing argument '--source-service', which is required when using '--source-service-base-url' \
                and '--checkout-path'.
                """
            )
        case (_, nil, _):
            throw ValidationError(
                """
                Missing argument '--source-service-base-url', which is required when using '--source-service' \
                and '--checkout-path'.
                """
            )
        case (_, _, nil):
            throw ValidationError(
                """
                Missing argument '--checkout-path', which is required when using '--source-service' and \
                '--source-service-base-url'.
                """
            )
        case let (sourceService?, sourceServiceBaseURL?, checkoutPath?):
            guard let sourceServiceBaseURL = URL(string: sourceServiceBaseURL) else {
                throw ValidationError("Invalid URL '\(sourceServiceBaseURL)' for '--source-service-base-url' argument.")
            }
            
            switch sourceService.lowercased() {
            case "github":
                self = .github(checkoutPath: checkoutPath, sourceServiceBaseURL: sourceServiceBaseURL)
            case "gitlab":
                self = .gitlab(checkoutPath: checkoutPath, sourceServiceBaseURL: sourceServiceBaseURL)
            case "bitbucket":
                self = .bitbucket(checkoutPath: checkoutPath, sourceServiceBaseURL: sourceServiceBaseURL)
            default:
                throw ValidationError(
                    "Unsupported source service '\(sourceService)'. Use 'github', 'gitlab', or 'bitbucket'."
                )
            }
        }
    }
}
