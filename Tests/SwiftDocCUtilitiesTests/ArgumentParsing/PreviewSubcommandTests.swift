/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

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
        
        // Test secure preview with valid certificate path & key
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "foobar", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "F1zzBuzz", 1)
            setenv(PreviewExternalConnectionOptions.certificateChainKey, testTLSCertificate.path, 1)
            setenv(PreviewExternalConnectionOptions.certificateKeyKey, testTLSKey.path, 1)
            
            XCTAssertNoThrow(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
        
        // Test secure preview with invalid certificate path
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "foobar", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "F1zzBuzz", 1)
            setenv(PreviewExternalConnectionOptions.certificateChainKey,
                testTLSCertificate.appendingPathComponent("invalidPath.pem").path, 1)
            setenv(PreviewExternalConnectionOptions.certificateKeyKey, testTLSKey.path, 1)
            
            XCTAssertThrowsError(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
        
        // Test secure preview with invalid key path
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "foobar", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "F1zzBuzz", 1)
            setenv(PreviewExternalConnectionOptions.certificateChainKey, testTLSCertificate.path, 1)
            setenv(PreviewExternalConnectionOptions.certificateKeyKey,
                   testTLSKey.appendingPathComponent("invalidPath.pem").path, 1)
            
            XCTAssertThrowsError(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
        
        // Test secure preview has a key if the certificate chain is provided
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "foobar", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "F1zzBuzz", 1)
            setenv(PreviewExternalConnectionOptions.certificateChainKey, testTLSCertificate.path, 1)
            unsetenv(PreviewExternalConnectionOptions.certificateKeyKey)
            XCTAssertThrowsError(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
        
        // Test secure preview has a certificate chain if the key is provided
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "foobar", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "F1zzBuzz", 1)
            unsetenv(PreviewExternalConnectionOptions.certificateChainKey)
            setenv(PreviewExternalConnectionOptions.certificateKeyKey, testTLSKey.path, 1)
            
            XCTAssertThrowsError(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
        
        // Test secure preview with provided valid username and password
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "foobar", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "F1zzBuzz", 1)
            setenv(PreviewExternalConnectionOptions.certificateChainKey, testTLSCertificate.path, 1)
            setenv(PreviewExternalConnectionOptions.certificateKeyKey, testTLSKey.path, 1)
            
            XCTAssertNoThrow(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
        
        // Test secure preview with a username that is too short
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "ed", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "F1zzBuzz", 1)
            setenv(PreviewExternalConnectionOptions.certificateChainKey, testTLSCertificate.path, 1)
            setenv(PreviewExternalConnectionOptions.certificateKeyKey, testTLSKey.path, 1)
            
            XCTAssertThrowsError(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
      
        // Test secure preview with a username that contains symbols
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "foobar$", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "F1zzBuzz", 1)
            setenv(PreviewExternalConnectionOptions.certificateChainKey, testTLSCertificate.path, 1)
            setenv(PreviewExternalConnectionOptions.certificateKeyKey, testTLSKey.path, 1)
            
            XCTAssertThrowsError(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
      }
        
        // Test secure preview with an invalid password: too short
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "foobar", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "fixx", 1)
            setenv(PreviewExternalConnectionOptions.certificateChainKey, testTLSCertificate.path, 1)
            setenv(PreviewExternalConnectionOptions.certificateKeyKey, testTLSKey.path, 1)
            
            XCTAssertThrowsError(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
        
        // Test secure preview with an invalid password: all lowercase
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "foobar", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "f1zzbuzz", 1)
            setenv(PreviewExternalConnectionOptions.certificateChainKey, testTLSCertificate.path, 1)
            setenv(PreviewExternalConnectionOptions.certificateKeyKey, testTLSKey.path, 1)
            
            XCTAssertThrowsError(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
        
        // Test secure preview with an invalid password: all uppercase
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "foobar", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "F1ZZBUZZ", 1)
            setenv(PreviewExternalConnectionOptions.certificateChainKey, testTLSCertificate.path, 1)
            setenv(PreviewExternalConnectionOptions.certificateKeyKey, testTLSKey.path, 1)
            
            XCTAssertThrowsError(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
        
        // Test secure preview with an invalid password: all characters
        do {
            setenv(TemplateOption.environmentVariableKey, templateDir.path, 1)
            
            setenv(PreviewExternalConnectionOptions.usernameKey, "foobar", 1)
            setenv(PreviewExternalConnectionOptions.passwordKey, "fIzZbUzZ", 1)
            setenv(PreviewExternalConnectionOptions.certificateChainKey, testTLSCertificate.path, 1)
            setenv(PreviewExternalConnectionOptions.certificateKeyKey, testTLSKey.path, 1)
            
            XCTAssertThrowsError(try Docc.Preview.parse([
                testBundleURL.path,
            ]))
        }
    }
}
