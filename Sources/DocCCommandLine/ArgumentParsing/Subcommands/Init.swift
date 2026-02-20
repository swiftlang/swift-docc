/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import ArgumentParser
private import SwiftDocC

extension Docc {
    public struct Init: AsyncParsableCommand {
        public init() {}
        
        public static var configuration: CommandConfiguration = CommandConfiguration(
            abstract: "Generate a documentation catalog from the selected template."
        )
        
        /// The options used for configuring the init action.
        @OptionGroup
        public var initOptions: InitOptions
        
        public func run() async throws {
            let initAction = try InitAction(
                catalogOutputDirectory: initOptions.providedCatalogOutputDirURL,
                documentationTitle: initOptions.name,
                catalogTemplate: initOptions.catalogTemplate
            )
            try await initAction.performAndHandleResult()
        }
    }
}
