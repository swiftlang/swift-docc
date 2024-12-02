/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SwiftDocC
import Foundation

extension AsyncAction {
    /// Performs the action and checks for any problems in the result.
    ///
    /// - Parameter logHandle: The log handle to write encountered warnings and errors to.
    ///
    /// - Throws: `ErrorsEncountered` if any errors are produced while performing the action.
    public func performAndHandleResult(logHandle: LogHandle = .standardOutput) async throws {
        var logHandle = logHandle
        // Perform the Action and collect the result
        let result = try await perform(logHandle: &logHandle)

        // Throw if any errors were encountered. Errors will have already been
        // reported to the user by the diagnostic engine.
        if result.didEncounterError {
            throw ErrorsEncountered()
        }
    }
}
