/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

/// Simplifies validation of credential-related string command-line arguments.
enum CredentialArgumentValidator {
    /// If a non-optional string value is provided, validates that the string is an acceptable username.
    ///
    /// A valid username must contain only alphanumerics characters and be at least three characters long.
    ///
    /// ### Example Error Message
    /// Invalid username provided via `[argumentDescription]`. Username must be at least three alphanumeric characters.
    ///
    /// - Parameter username: An optional string value to be validated.
    /// - Parameter argumentDescription: A description of the command line argument or environment
    /// variable this string was initialized from.
    ///
    /// - Throws: A `ValidationError` that includes the `argumentDescription`.
    static func validateUsername(_ username: String?, forArgumentDescription argumentDescription: String) throws {
        // Validation is only necesary if a non-optional value has been passed.
        guard let username = username else { return }
        
        // Check that the there are least three characters and that there are no characters
        // besides those that are within the alphanumeric character set.
        guard username.count >= 3
            && username.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil else {
            throw ValidationError(
                """
                Invalid username provided via \(argumentDescription).
                Username must be at least three alphanumeric characters.
                """)
        }
    }

    /// If a non-optional, string value is provided, validates that the string is an acceptable password.
    ///
    /// A valid password must be at least eight characters and include mix-cased letters and numbers.
    ///
    /// ### Example Error Message
    /// Invalid password provided via `[argumentDescription]`.
    /// Password must be at least eight characters and include mix-cased letters and numbers.
    ///
    /// - Parameter username: An optional string value to be validated.
    /// - Parameter argumentDescription: A description of the command line argument or environment
    /// variable this string was initialized from.
    ///
    /// - Throws: A `ValidationError` that includes the `argumentDescription`.
    static func validatePassword(_ password: String?, forArgumentDescription argumentDescription: String) throws {
        // Validation is only necesary if a non-optional value has been passed.
        guard let password = password else { return }
        
        // Check that there are at least eight characters and that the string contains
        // lowercase, uppercase, and decimal digit values.
        guard password.count >= 8
            && password.rangeOfCharacter(from: .lowercaseLetters) != nil
            && password.rangeOfCharacter(from: .uppercaseLetters) != nil
            && password.rangeOfCharacter(from: .decimalDigits) != nil else {
            throw ValidationError(
                """
                Invalid password provided via \(argumentDescription).
                Password must be at least eight characters and include mix-cased letters and numbers.
                """)
        }
    }
}
