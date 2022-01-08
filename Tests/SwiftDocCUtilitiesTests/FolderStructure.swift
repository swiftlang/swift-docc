/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import SwiftDocC
@testable import SwiftDocCUtilities
import XCTest
import SwiftDocCTestUtilities

/*
 This file contains a test helper API for working with folder hierarchies, with the ability to:
 
  1. write a hierarchy of folders and files to disk
  2. verify that a hierarchy of folders and files exist on disk
*/

protocol AssertableFile: File {
    /// Asserts that a file exist a given URL.
    func __assertExist(at location: URL, fileManager: FileManagerProtocol, file: StaticString, line: UInt) // Implement this since protocol methods can't have default arguments.
}

extension AssertableFile {
    /// Asserts that a file exist a given URL.
    func assertExist(at location: URL, fileManager: FileManagerProtocol = FileManager.default, file: StaticString = #file, line: UInt = #line) {
        __assertExist(at: location, fileManager: fileManager, file: (file), line: line)
    }
}

extension AssertableFile {
    /// Writes the file inside of a folder and returns the URL that it was written to.
    func write(inside url: URL) throws -> URL {
        let outputURL = url.appendingPathComponent(name)
        try write(to: outputURL)
        return outputURL
    }
}

// MARK: -

extension Folder: AssertableFile {
    func __assertExist(at location: URL, fileManager: FileManagerProtocol, file: StaticString = #file, line: UInt = #line) {
        var isFolder: ObjCBool = false
        XCTAssert(fileManager.fileExists(atPath: location.path, isDirectory: &isFolder),
                  "Folder '\(name)' should exist at '\(location.path)'", file: (file), line: line)
        XCTAssert(isFolder.boolValue,
                  "Folder '\(name)' should be a folder", file: (file), line: line)
        for fileOrFolder in content as! [AssertableFile] {
            fileOrFolder.assertExist(at: location.appendingPathComponent(fileOrFolder.name), fileManager: fileManager, file: (file), line: line)
        }
    }
}

extension InfoPlist: AssertableFile {
    func __assertExist(at location: URL, fileManager: FileManagerProtocol, file: StaticString, line: UInt) {
        XCTAssert(fileManager.fileExists(atPath: location.path),
                  "File '\(name)' should exist at '\(location.path)'", file: (file), line: line)
        
        // TODO: Replace this with PropertListDecoder (see below) when it's available in swift-corelibs-foundation
        // https://github.com/apple/swift-corelibs-foundation/commit/d2d72f88d93f7645b94c21af88a7c9f69c979e4f
        do {
            guard let infoPlistData = fileManager.contents(atPath: location.path) else {
                XCTFail("File '\(name)' does not exist at path \(location.path.singleQuoted)", file: (file), line: line)
                return
            }
            let infoPlist = try PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: String]
            
            let displayName = infoPlist?["CFBundleIdentifier"]
            let identifier = infoPlist?["CFBundleVersion"]
            let versionString = infoPlist?["CFBundleDevelopmentRegion"]
            let developmentRegion = infoPlist?["CFBundleDisplayName"]
            
            XCTAssert(displayName == content.displayName && identifier == content.identifier && versionString == content.versionString && developmentRegion == content.developmentRegion,
                      "File '\(name)' should contain the correct information.", file: (file), line: line)
            
        } catch {
            XCTFail("File '\(name)' should contain the correct information.", file: (file), line: line)
        }
    }
}

extension TextFile: AssertableFile {
    func __assertExist(at location: URL, fileManager: FileManagerProtocol, file: StaticString, line: UInt) {
        XCTAssert(fileManager.fileExists(atPath: location.path),
                  "File '\(name)' should exist at '\(location.path)'", file: (file), line: line)
        XCTAssertEqual(fileManager.contents(atPath: location.path).map({ String(data: $0, encoding: .utf8)}), utf8Content,
                       "File '\(name)' should contain '\(utf8Content)'", file: (file), line: line)
    }
}

extension JSONFile: AssertableFile {
    func __assertExist(at location: URL, fileManager: FileManagerProtocol, file: StaticString, line: UInt) {
        XCTAssert(fileManager.fileExists(atPath: location.path),
                  "File '\(name)' should exist at '\(location.path)'", file: (file), line: line)
        
        guard let fileData = fileManager.contents(atPath: location.path),
            let other = try? JSONDecoder().decode(Content.self, from: fileData) else {
            XCTFail("File '\(name)' should contain '\(Content.self)' data at '\(location.path)'", file: (file), line: line)
            return
        }
        
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(content), let json = try? JSONSerialization.jsonObject(with: data),
            let otherData = try? encoder.encode(other), let otherJSON = try? JSONSerialization.jsonObject(with: otherData)
        else {
            XCTFail("The decoded data in '\(name)' should be encodable as '\(Content.self)'", file: (file), line: line)
            return
        }
        
        switch (json, otherJSON) {
        case let (array as NSArray, otherArray as NSArray):
            XCTAssertEqual(array, otherArray,
                           "File '\(name)' should contain JSON data that is equal to:\n\(array)", file: (file), line: line)
        case let (dictionary as NSDictionary, otherDictionary as NSDictionary):
            XCTAssertEqual(dictionary, otherDictionary,
                           "File '\(name)' should contain JSON data that is equal to:\n\(dictionary)", file: (file), line: line)
        default:
            XCTFail("The decoded data in '\(name)' should be encodable as '\(Content.self)'", file: (file), line: line)
        }
    }
}

extension CopyOfFile: AssertableFile {
    func __assertExist(at location: URL, fileManager: FileManagerProtocol, file: StaticString, line: UInt) {
        XCTAssert(fileManager.fileExists(atPath: location.path),
                  "File '\(name)' should exist at '\(location.path)'", file: (file), line: line)
        
        XCTAssert(fileManager.contentsEqual(atPath: original.path, andPath: location.path),
                  "File '\(name)' should contain the same content as '\(original.path)'", file: (file), line: line)
    }
}
