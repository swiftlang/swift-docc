/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation
import SwiftDocC

extension Docc {
    public struct Init: ParsableCommand {
        
        public init() {
        }
        
        // MARK: - Configuration
        
        public static var configuration: CommandConfiguration = CommandConfiguration(
            abstract: "Generates a .docc catalog for article-only documentation",
            shouldDisplay: true
        )
        
        // MARK: - Command Line Options & Arguments
        
        /// The options used for configuring the init action.
        @OptionGroup
        public var initOptions: InitOptions
        
        // MARK: - Property Validation
        
        // MARK: - Execution
        
        /// The file handle that should be used for emitting warnings during execution outside
        /// the perform init action.
        static var _errorLogHandle: LogHandle = .standardError
        
        public mutating func run() throws {
            
            // Initialize a `InitiAction` from the current options in the `Init` command.
            var initAction = try InitAction(fromInitOptions: initOptions)
            
            // Perform the action and print any warnings or errors found
            try initAction.performAndHandleResult()
        }
    }
}
