/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

/// Simplifies validation of URL command-line arguments.
enum URLArgumentValidator {
    /// If a non-optional URL value is provided, validates that the URL represents a directory that exists.
    ///
    /// ### Example Error Message
    /// Invalid path provided via `[argumentDescription]`. No directory exists at '`[path]`'.
    ///
    /// - Parameter url: An optional URL value to be validated.
    /// - Parameter argumentDescription: A description of the command line argument or environment
    /// variable this URL was initialized from.
    ///
    /// - Throws: A `ValidationError` that includes the `argumentDescription` and current path.
    static func validateHasDirectoryPath(_ url: URL?, forArgumentDescription argumentDescription: String) throws {
        // Validation is only necesary if a non-optional value has been passed.
        guard let url = url else { return }
        
        guard url.hasDirectoryPath && FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError(
                """
                Invalid path provided via the \(argumentDescription). No directory exists at '\(url.path)'.
                """)
        }
    }

    /// If a non-optional URL value is provided, validates that the URL represents a file that exists.
    ///
    /// ### Example Error Message
    /// Invalid path provided via `[argumentDescription]`. No file exists at '`[path]`'.
    ///
    /// - Parameter url: An optional URL value to be validated.
    /// - Parameter argumentDescription: A description of the command line argument or environment
    /// variable this URL was initialized from.
    ///
    /// - Throws: A `ValidationError` that includes the `argumentDescription` and current path.
    static func validateFileExists(_ url: URL?, forArgumentDescription argumentDescription: String) throws {
        // Validation is only necesary if a non-optional value has been passed.
        guard let url = url else { return }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError(
                """
                Invalid path provided via the \(argumentDescription). No file exists at '\(url.path)'.
                """)
        }
    }

    /// If a non-optional URL value is provided, validates that the URL represents an executable that exists.
    ///
    /// ### Example Error Message
    /// Invalid path provided via `[argumentDescription]`. Unable to execute file at '`[path]`'.
    ///
    /// - Parameter url: An optional URL value to be validated.
    /// - Parameter argumentDescription: A description of the command line argument or environment
    /// variable this URL was initialized from.
    ///
    /// - Throws: A `ValidationError` that includes the `argumentDescription` and current path.
    static func validateIsExecutableFile(_ url: URL?, forArgumentDescription argumentDescription: String) throws {
        // Validation is only necesary if a non-optional value has been passed.
        guard let url = url else { return }
        
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw ValidationError(
                """
                Invalid path provided via the \(argumentDescription). Unable to execute file at '\(url.path)'.
                """)
        }
    }
}
