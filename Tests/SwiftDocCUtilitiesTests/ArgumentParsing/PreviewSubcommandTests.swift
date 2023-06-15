/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(NIOHTTP1)
import XCTest
@testable import SwiftDocCUtilities

class PreviewSubcommandTests: XCTestCase {
    func testOptionsValidation() throws {
        let testBundleURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        // Create HTML template dir.
        let templateDir = try createTemporaryDirectory()
        try "".write(to: templateDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        
        let tempURL = try createTemporaryDirectory()
        // Create Test TLS Certificate File
        let testTLSCertificate = tempURL.appendingPathComponent("testCert.pem")
        try "".write(to: testTLSCertificate, atomically: true, encoding: .utf8)
        
        // Create Test TLS Key File
        let testTLSKey = tempURL.appendingPathComponent("testCert.pem")
        try "".write(to: testTLSKey, atomically: true, encoding: .utf8)
        
        // Tests a single input.
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            XCTAssertNoThrow(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
        
        // Test no template folder throws
        do {
            unsetenv(TemplateOption.environmentVariableKey)
            XCTAssertThrowsError(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
        
        // Test default template
        do {
            unsetenv(TemplateOption.environmentVariableKey)
            let tempFolder = try createTemporaryDirectory()
            let doccExecutableLocation = tempFolder
                .appendingPathComponent("bin")
                .appendingPathComponent("docc-executable-name")
            let defaultTemplateDir = tempFolder
                .appendingPathComponent("share")
                .appendingPathComponent("docc")
                .appendingPathComponent("render", isDirectory: true)
            let originalDoccExecutableLocation = TemplateOption.doccExecutableLocation
            
            TemplateOption.doccExecutableLocation = doccExecutableLocation
            defer {
                TemplateOption.doccExecutableLocation = originalDoccExecutableLocation
            }
            try FileManager.default.createDirectory(at: defaultTemplateDir, withIntermediateDirectories: true, attributes: nil)
            try "".write(to: defaultTemplateDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
            
            let preview = try Docc.Preview.parse([
                testBundleURL.path,
            ])
            XCTAssertEqual(
                preview.previewOptions.convertCommand.templateOption.templateURL?.standardizedFileURL,
                defaultTemplateDir.standardizedFileURL
            )
            let action = try PreviewAction(fromPreviewOptions: preview.previewOptions)
            XCTAssertEqual(
                action.convertAction.htmlTemplateDirectory,
                defaultTemplateDir.standardizedFileURL
            )
        }
        
        // Test previewing with valid port
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            XCTAssertNoThrow(try Docc.Preview.parse([
                "--port", "2048",
                testBundleURL.path,
            ]))
        }

        // Test previewing with invalid port
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            XCTAssertThrowsError(try Docc.Preview.parse([
                "--port", "42",
                testBundleURL.path,
            ]))
        }
    }
}
#endif
