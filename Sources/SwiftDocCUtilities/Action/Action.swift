/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An independent unit of work in the command-line workflow.
///
/// An action represents a discrete documentation task; it takes options and inputs, performs its work, reports any problems it encounters, and outputs it generates.
package protocol AsyncAction {
    /// Performs the action and returns an ``ActionResult``.
    func perform(logHandle: inout LogHandle) async throws -> ActionResult
}

package extension AsyncAction {
    func perform(logHandle: LogHandle) async throws -> ActionResult {
        var logHandle = logHandle
        return try await perform(logHandle: &logHandle)
    }
}

