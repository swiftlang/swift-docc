/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

/// Resolves and validates ``username``, ``password``,  ``tlsCertificateChainURL``,  and ``tlsCertificateKeyURL``
/// values that can be used when configuring the preview server for external connections.
///
/// These values can be set via  via environment variables.
public struct PreviewExternalConnectionOptions: ParsableArguments {

    public init() {}

    // MARK: - Constants

    /// The environment variable key that can be used to set the ``username`` property.
    static let usernameKey = "DOCC_PREVIEW_USERNAME"

    /// The environment variable key that can be used to set the ``password`` property.
    static let passwordKey = "DOCC_PREVIEW_PASSWORD"

    /// The environment variable key that can be used to set the ``tlsCertificateChain`` property.
    static let certificateChainKey = "DOCC_TLS_CERTIFICATE_CHAIN"

    /// The environment variable key that can be used to set the ``tlsCertificateKey`` property.
    static let certificateKeyKey = "DOCC_TLS_CERTIFICATE_KEY"

    // MARK: - Environment Variable Values

    /// The username to use when configuring the preview server for external connections
    /// as provided by the environment variable `DOCC_PREVIEW_USERNAME`.
    public var username: String? {
        ProcessInfo.processInfo.environment[PreviewExternalConnectionOptions.usernameKey]
    }

    /// The password to use when configuring the preview server for external connections
    /// as provided by the envrionment variable `DOCC_PREVIEW_PASSWORD`.
    public var password: String? {
        ProcessInfo.processInfo.environment[PreviewExternalConnectionOptions.passwordKey]
    }

    /// The path to the TLS certificate chain to use when configuring the preview server for external connections
    /// as provided by the envrionment variable `DOCC_TLS_CERTIFICATE_CHAIN`.
    public var tlsCertificateChainURL: URL? {
        ProcessInfo.processInfo.environment[PreviewExternalConnectionOptions.certificateChainKey]
            .map { URL(fileURLWithPath: $0) }
    }

    /// The path to the TLS certificate key to use when configuring the preview server for external connections
    /// as provided by the envrionment variable `DOCC_TLS_CERTIFICATE_KEY`.
    public var tlsCertificateKeyURL: URL? {
        ProcessInfo.processInfo.environment[PreviewExternalConnectionOptions.certificateKeyKey]
            .map { URL(fileURLWithPath: $0) }
    }

    // MARK: - Public Properties

    /// A Boolean value indicating whether any configuration has been provided to enable external connections
    /// for the preview server.
    ///
    /// If this value is true, and the `validate()` function has been called,
    /// the ``username``, ``password``, ``tlsCertificateChainURL``, and
    /// ``tlsCertificateKeyURL`` properties are all guaranteed to have valid values.
    public var externalConnectionsAreEnabled: Bool {
        username != nil || password != nil || tlsCertificateChainURL != nil
            || tlsCertificateKeyURL != nil
    }

    // MARK: - Validation

    public mutating func validate() throws {
        // If a username has been provided, validate it
        try CredentialArgumentValidator.validateUsername(username,
            forArgumentDescription: """
                '\(PreviewExternalConnectionOptions.usernameKey)' environment variable.
                """)

        // If a password has been provided, validate it
        try CredentialArgumentValidator.validatePassword(password,
            forArgumentDescription: """
                '\(PreviewExternalConnectionOptions.passwordKey)' environment variable.
                """)

        // If a certificate chain URL has been provided, validate it
        try URLArgumentValidator.validateFileExists(tlsCertificateChainURL,
            forArgumentDescription: """
                '\(PreviewExternalConnectionOptions.certificateChainKey)' environment variable.
                """)

        // If a certificate key URL has been provided, validate it
        try URLArgumentValidator.validateFileExists(tlsCertificateKeyURL,
            forArgumentDescription: """
                '\(PreviewExternalConnectionOptions.certificateKeyKey)' environment variable.
                """)

        // If external connections are enabled, confirm that all four required values are present
        if externalConnectionsAreEnabled {
            let requiredValues: [(value: Any?, description: String)] = [
                (username, "username"),
                (password, "password"),
                (tlsCertificateChainURL, "tls-certificate-chain-path"),
                (tlsCertificateKeyURL, "tls-certificate-key-path"),
            ]

            // Collect the descriptions of all required values that are missing
            let missingValues = requiredValues.filter { $0.value == nil }.map { $0.description }

            // If any values are missing, throw an error that lists all missing values
            guard missingValues.isEmpty else {
                throw ValidationError(
                    """
                    Missing values that are required to configure the preview server for external connections.
                    If a password, username, certificate chain path, or certificate key path are provided, docc expects all four to be present.
                    Missing: \(missingValues.joined(separator: ", ")).
                    """)
            }
        }
    }
}
