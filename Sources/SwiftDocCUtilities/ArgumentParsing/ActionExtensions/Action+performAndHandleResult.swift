/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SwiftDocC
import Foundation

extension Action {
    /// Performs the action and checks for any problems in the result.
    ///
    /// If any warnings or errors are found, they will be printed to standard output.
    ///
    /// - throws: `ErrorsEncountered` if any errors are produced while performing the action.
    public mutating func performAndHandleResult() throws {
        /// A log handle used for printing to standard out in a terminal.
        let logHandle = LogHandle.standardOutput

        // Perform the Action and collect the result
        let result = try perform(logHandle: logHandle)

        // Throw if any errors were encountered. Errors will have already been
        // reported to the user by the diagnostic engine.
        if result.didEncounterError {
            throw ErrorsEncountered()
        }
    }
}
