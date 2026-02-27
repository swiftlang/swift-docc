/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import ArgumentParser
public import Foundation
import SwiftDocC

/// Resolves and validates a ``templateURL`` value that points to an HTML documentation template.
///
/// This value can be set via an environment variable.
public struct TemplateOption: ParsableArguments {

    public init() {}

    /// The environment variable key that can be used to set the ``templateURL`` property.
    static let environmentVariableKey = "DOCC_HTML_DIR"

    /// The path to an HTML template to be used during conversion as provided by
    /// the environment variable `DOCC_HTML_DIR`.
    public var templateURL: URL?

    /// The location of the docc executable that's running.
    /// This can be set to a known value for testing.
    static var doccExecutableLocation: URL = {
        // We rely on Bundle.main.executableURL here which is a robust API
        // that should always return the current executable's URL, regardless of how it is invoked.
        //
        // If docc is invoked directly, then the executable's path is always the first
        // command line argument provided. So, in the exceptional case where Bundle.main.executableURL
        // is nil, we fall back to the value provided in CommandLine.arguments[0].
        return Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
    }()
    
    /// The default template location.
    static var defaultTemplateURL: URL {
        // This looks for the template relative to the docc executable
        //
        //   executable: common-file-path/bin/docc
        //   template:   common-file-path/share/docc/render/
        let templatePath = doccExecutableLocation
            .deletingLastPathComponent() // docc
            .deletingLastPathComponent() // bin
            .appendingPathComponent("share", isDirectory: true)
            .appendingPathComponent("docc", isDirectory: true)
            .appendingPathComponent("render", isDirectory: true)
        
        return templatePath
    }
    
    static func validateRequiredFile(fileName requiredFileName: String, inHTMLTemplateAt templateLocation: URL) throws(ValidationError) {
        if FileManager.default.fileExists(atPath: templateLocation.appendingPathComponent(requiredFileName, isDirectory: false).path) {
            return
        }
        throw Self.missingRequiredFile(fileName: requiredFileName, inHTMLTemplateAt: templateLocation)
    }
    
    static func missingRequiredFile(fileName requiredFileName: String, inHTMLTemplateAt templateLocation: URL) -> ValidationError {
        ValidationError("""
            Missing '\(requiredFileName)' file in HTML template directory at '\(templateLocation.path)'.
            Set the '\(TemplateOption.environmentVariableKey)' environment variable to use a custom HTML template.
            """)
    }
    
    static func missingHTMLTemplate(at expectedTemplateLocation: URL) -> ValidationError {
        if ProcessInfo.processInfo.environment[TemplateOption.environmentVariableKey] != nil {
            ValidationError("""
                Missing HTML template directory at custom location '\(expectedTemplateLocation.path)' \
                specified using the '\(TemplateOption.environmentVariableKey)' environment variable.
                """)
        } else {
            ValidationError("""
                Missing HTML template directory, relative to the docc executable, at: '\(expectedTemplateLocation.path)'.
                Set the '\(TemplateOption.environmentVariableKey)' environment variable to use a custom HTML template.
                """)
        }
    }

    public mutating func validate() throws {
        templateURL = ProcessInfo.processInfo.environment[TemplateOption.environmentVariableKey]
            .map { URL(fileURLWithPath: $0) }
        
        // Validate that the provided template URL represents a directory
        try URLArgumentValidator.validateHasDirectoryPath(templateURL, forArgumentDescription: "'\(TemplateOption.environmentVariableKey)' environment variable")

        // Only perform further validation if a templateURL has been provided
        guard let templateURL else {
            if FileManager.default.fileExists(atPath: Self.defaultTemplateURL.appendingPathComponent(HTMLTemplate.indexFileName.rawValue).path) {
                self.templateURL = Self.defaultTemplateURL
            }
            return
        }
        
        // Confirm that the provided directory contains an 'index.html' file which is a required part of an HTML template for docc.
        try Self.validateRequiredFile(fileName: HTMLTemplate.indexFileName.rawValue, inHTMLTemplateAt: templateURL)
    }
}
