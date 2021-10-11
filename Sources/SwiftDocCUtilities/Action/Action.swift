/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An independent unit of work in the command-line workflow.
///
/// An `Action` represents a discrete documentation task; it takes options and inputs, 
/// performs its work, reports any problems it encounters, and outputs it generates.
public protocol Action {
    /// Performs the action and returns an ``ActionResult``.
    mutating func perform(logHandle: LogHandle) throws -> ActionResult
}

/// An action for which you can optionally customize the documentation context.
public protocol RecreatingContext: Action {
    /// A closure that an action calls with the action's context for built documentation,
    /// before the action performs work.
    ///
    /// Use this closure to set the action's context to a certain state before the action runs.
    var setupContext: ((inout DocumentationContext) -> Void)? { get set }
}
