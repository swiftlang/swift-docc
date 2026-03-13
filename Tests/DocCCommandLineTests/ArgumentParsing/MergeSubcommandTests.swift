/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import ArgumentParser
@testable import DocCCommandLine
import DocCTestUtilities

class MergeSubcommandTests: XCTestCase {
    func testCommandLineArgumentValidation() throws {
        let originalMergeCommandFileManager = Docc.Merge._fileManager
        defer {
            Docc.Merge._fileManager = originalMergeCommandFileManager
        }
        
        _ = try TestFileSystem(folders: [])
        
        // No input
        XCTAssertThrowsError(try Docc.Merge.parse([])) { error in
            XCTAssertEqual(Docc.Merge.message(for: error), "Missing expected argument '<archive-path> ...'")
        }
         
        Docc.Merge._fileManager = try TestFileSystem(folders: [])
        
        // Input archive with unexpected path extension
        XCTAssertThrowsError(try Docc.Merge.parse(["/path/to/not-an-archive"])) { error in
            XCTAssertEqual(Docc.Merge.message(for: error), "Missing 'doccarchive' path extension for archive '/path/to/not-an-archive'")
        }
        
        XCTAssertThrowsError(try Docc.Merge.parse(["/path/to/not-an-archive.something"])) { error in
            XCTAssertEqual(Docc.Merge.message(for: error), "Path extension 'something' is not 'doccarchive' for archive '/path/to/not-an-archive.something'")
        }
        
        // Missing input
        XCTAssertThrowsError(try Docc.Merge.parse(["/path/to/First.doccarchive"])) { error in
            XCTAssertEqual(Docc.Merge.message(for: error), "No directory exists at '/path/to/First.doccarchive'")
        }
        
        // Found archive input
        var fileSystem = try TestFileSystem(folders: [
            Folder(name: "path", content: [
                Folder(name: "to", content: [
                    Folder(name: "First.doccarchive", content: []),
                    Folder(name: "Second.doccarchive", content: []),
                ])
            ])
        ])
        Docc.Merge._fileManager = fileSystem
        
        XCTAssertNoThrow(try Docc.Merge.parse(["/path/to/First.doccarchive"]))
        
        do {
            let command = try Docc.Merge.parse(["/path/to/First.doccarchive", "/path/to/Second.doccarchive"])
            XCTAssertEqual(command.inputsAndOutputs.archives, [
                URL(fileURLWithPath: "/path/to/First.doccarchive"),
                URL(fileURLWithPath: "/path/to/Second.doccarchive"),
            ])
            
            XCTAssertNil(command.inputsAndOutputs.landingPageCatalog)
            XCTAssertEqual(command.inputsAndOutputs.outputURL, URL(fileURLWithPath: fileSystem.currentDirectoryPath).appendingPathComponent("Combined.doccarchive", isDirectory: true))
            
            XCTAssertEqual(command.synthesizedLandingPageOptions.name, "Documentation")
            XCTAssertEqual(command.synthesizedLandingPageOptions.kind, "Package")
        }
        
        // Input catalog with unexpected path extension
        XCTAssertThrowsError(try Docc.Merge.parse(["/path/to/First.doccarchive", "--landing-page-catalog", "/path/to/not-a-catalog"])) { error in
            XCTAssertEqual(Docc.Merge.message(for: error), "Missing 'docc' path extension for catalog '/path/to/not-a-catalog'")
        }
        
        XCTAssertThrowsError(try Docc.Merge.parse(["/path/to/First.doccarchive", "--landing-page-catalog", "/path/to/not-a-catalog.something"])) { error in
            XCTAssertEqual(Docc.Merge.message(for: error), "Path extension 'something' is not 'docc' for catalog '/path/to/not-a-catalog.something'")
        }
        
        // Missing input catalog
        XCTAssertThrowsError(try Docc.Merge.parse(["/path/to/First.doccarchive", "--landing-page-catalog", "/path/to/LandingPage.docc"])) { error in
            XCTAssertEqual(Docc.Merge.message(for: error), "No directory exists at '/path/to/LandingPage.docc'")
        }
        
        // Found catalog input
        fileSystem = try TestFileSystem(folders: [
            Folder(name: "path", content: [
                Folder(name: "to", content: [
                    Folder(name: "First.doccarchive", content: []),
                    Folder(name: "Second.doccarchive", content: []),
                    Folder(name: "LandingPage.docc", content: []),
                ])
            ])
        ])
        Docc.Merge._fileManager = fileSystem
        
        XCTAssertNoThrow(try Docc.Merge.parse(["/path/to/First.doccarchive", "--landing-page-catalog", "/path/to/LandingPage.docc"]))
        
        do {
            let command = try Docc.Merge.parse([
                "/path/to/First.doccarchive", 
                "/path/to/Second.doccarchive",
                "--landing-page-catalog", "/path/to/LandingPage.docc"
            ])
            XCTAssertEqual(command.inputsAndOutputs.archives, [
                URL(fileURLWithPath: "/path/to/First.doccarchive"),
                URL(fileURLWithPath: "/path/to/Second.doccarchive"),
            ])
            
            XCTAssertEqual(command.inputsAndOutputs.landingPageCatalog, URL(fileURLWithPath: "/path/to/LandingPage.docc"))
            XCTAssertEqual(command.inputsAndOutputs.outputURL, URL(fileURLWithPath: fileSystem.currentDirectoryPath).appendingPathComponent("Combined.doccarchive", isDirectory: true))
        }
        
        // Synthesized landing page info
        XCTAssertNoThrow(try Docc.Merge.parse(["/path/to/First.doccarchive", "--synthesized-landing-page-name", "Test Landing Page Name"]))
        XCTAssertNoThrow(try Docc.Merge.parse(["/path/to/First.doccarchive", "--synthesized-landing-page-kind", "Test Landing Page Kind"]))
        
        do {
            let command = try Docc.Merge.parse([
                "/path/to/First.doccarchive",
                "--synthesized-landing-page-name", "Test Landing Page Name",
                "--synthesized-landing-page-kind", "Test Landing Page Kind"
            ])
            XCTAssertEqual(command.synthesizedLandingPageOptions.name, "Test Landing Page Name")
            XCTAssertEqual(command.synthesizedLandingPageOptions.kind, "Test Landing Page Kind")
        }
        
        // Incomplete output argument
        XCTAssertThrowsError(try Docc.Merge.parse(["/path/to/First.doccarchive", "--output-path"])) { error in
            XCTAssertEqual(Docc.Merge.message(for: error), "Missing value for '--output-path <output-path>'")
        }
        
        // Unexpected path extension for output argument
        XCTAssertThrowsError(try Docc.Merge.parse(["/path/to/First.doccarchive", "--output-path", "/other/path/to/output-dir"])) { error in
            XCTAssertEqual(Docc.Merge.message(for: error), "Missing intermediate directory at '/other/path/to' for output path")
        }
        
        // Found output path
        fileSystem = try TestFileSystem(folders: [
            Folder(name: "path", content: [
                Folder(name: "to", content: [
                    Folder(name: "First.doccarchive", content: []),
                    Folder(name: "Second.doccarchive", content: []),
                    Folder(name: "LandingPage.docc", content: []),
                ])
            ]),
            Folder(name: "other", content: [
                Folder(name: "path", content: [
                    Folder(name: "to", content: [
                        // Intentionally empty
                    ])
                ])
            ])
        ])
        Docc.Merge._fileManager = fileSystem
        
        XCTAssertNoThrow(try Docc.Merge.parse(["/path/to/First.doccarchive", "--output-path", "/other/path/to/output-dir"]))
        
        do {
            let command = try Docc.Merge.parse([
                "/path/to/First.doccarchive",
                "/path/to/Second.doccarchive",
                "--landing-page-catalog", "/path/to/LandingPage.docc",
                "--output-path", "/other/path/to/output-dir"
            ])
            XCTAssertEqual(command.inputsAndOutputs.archives, [
                URL(fileURLWithPath: "/path/to/First.doccarchive"),
                URL(fileURLWithPath: "/path/to/Second.doccarchive"),
            ])
            
            XCTAssertEqual(command.inputsAndOutputs.landingPageCatalog, URL(fileURLWithPath: "/path/to/LandingPage.docc"))
            XCTAssertEqual(command.inputsAndOutputs.outputURL, URL(fileURLWithPath: "/other/path/to/output-dir"))
        }
    }
}
