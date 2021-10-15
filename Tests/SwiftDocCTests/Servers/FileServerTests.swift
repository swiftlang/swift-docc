/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import XCTest
@testable import SwiftDocC

fileprivate let baseURL = URL(string: "test://")!
fileprivate let helloWorldHTML = "<html><header><title>Hello Title</title></header><body>Hello world</body></html>".data(using: .utf8)!
fileprivate let jsFile = "var jsFile = true;".data(using: .utf8)!

class FileServerTests: XCTestCase {
    
    var defaultFileServer: FileServer = {
        var fileServer = FileServer(baseURL: baseURL)
        var memoryFileProvider = MemoryFileServerProvider()
        
        memoryFileProvider.addFile(path: "/", data: helloWorldHTML)
        memoryFileProvider.addFile(path: "/index.html", data: helloWorldHTML)
        memoryFileProvider.addFile(path: "/js/file.js", data: jsFile)
        
        fileServer.register(provider: memoryFileProvider)
        
        return fileServer
    }()
    
    func testBasicURL() {
        var retrieved = defaultFileServer.data(for: baseURL)
        XCTAssertEqual(helloWorldHTML, retrieved)
        
        retrieved = defaultFileServer.data(for: baseURL.appendingPathComponent("index.html"))
        XCTAssertEqual(helloWorldHTML, retrieved)
        
        retrieved = defaultFileServer.data(for: baseURL.appendingPathComponent("/js/file.js"))
        XCTAssertEqual(jsFile, retrieved)
    }
    
    func testBasicPath() {
        var retrieved = defaultFileServer.data(for: baseURL.appendingPathComponent("index.html"))
        XCTAssertEqual(helloWorldHTML, retrieved)
        
        retrieved = defaultFileServer.data(for: baseURL.appendingPathComponent("/index.html"))
        XCTAssertEqual(helloWorldHTML, retrieved)
        
        retrieved = defaultFileServer.data(for:  baseURL.appendingPathComponent("/js/file.js"))
        XCTAssertEqual(jsFile, retrieved)
    }
    
    func testEmpty() {
        var retrieved = defaultFileServer.data(for: baseURL.appendingPathComponent("/invalid.html"))
        XCTAssertNil(retrieved, "\(baseURL.appendingPathComponent("/invalid.html").absoluteString) should return nil, but returned \(String(describing: retrieved))")
        
        retrieved = defaultFileServer.data(for: baseURL.appendingPathComponent("/invalid/"))
        XCTAssertNil(retrieved, "\(baseURL.appendingPathComponent("/invalid/").absoluteString) should return nil, but returned \(String(describing: retrieved))")
    }
    
    func testAddingFilesInFolder() {
        let folder = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        let memoryFileProvider = MemoryFileServerProvider()
        memoryFileProvider.addFiles(inFolder: folder.path)
        
        let fileServer = FileServer(baseURL: baseURL)
        fileServer.register(provider: memoryFileProvider)
        
        XCTAssertNotNil(fileServer.data(for: baseURL.appendingPathComponent("/figure1.png")))
        XCTAssertNotNil(fileServer.data(for: baseURL.appendingPathComponent("/images/figure1.jpg")))
    }
    
    func testAddingRemovingFromPath() {
        let folder = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        let memoryFileProvider = MemoryFileServerProvider()
        memoryFileProvider.addFiles(inFolder: folder.path)
        
        let fileServer = FileServer(baseURL: baseURL)
        fileServer.register(provider: memoryFileProvider)
        
        XCTAssertNotNil(fileServer.data(for: baseURL.appendingPathComponent("/images/figure1.jpg")))
        
        memoryFileProvider.removeAllFiles(in: "/images")
        
        XCTAssertNil(fileServer.data(for: baseURL.appendingPathComponent("/images/figure1.jpg")))
    }
    
    func testDiskServerProvider() {
        let folder = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!.path
        
        guard let fileSystemFileProvider = FileSystemServerProvider(directoryPath: folder) else {
            XCTFail("Provided folder is not valid, it cannot be served.")
            return
        }
        
        let fileServer = FileServer(baseURL: baseURL)
        fileServer.register(provider: fileSystemFileProvider)
        
        XCTAssertNotNil(fileServer.data(for: baseURL.appendingPathComponent("/images/figure1.jpg")))
        XCTAssertNotNil(fileServer.data(for: baseURL.appendingPathComponent("/figure1.png")))
    }
    
    func testSubPathProvider() {
        let folder = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!.path
        
        guard let fileSystemFileProvider = FileSystemServerProvider(directoryPath: folder) else {
            XCTFail("Provided folder is not valid, it cannot be served.")
            return
        }
        
        let fileServer = FileServer(baseURL: baseURL)
        fileServer.register(provider: fileSystemFileProvider)
        
        let memoryFileProvider = MemoryFileServerProvider()
        memoryFileProvider.addFile(path: "/", data: helloWorldHTML)
        memoryFileProvider.addFile(path: "/index.html", data: helloWorldHTML)
        memoryFileProvider.addFile(path: "/js/file.js", data: jsFile)
        
        fileServer.register(provider: memoryFileProvider, subPath: "/subPath")
        
        XCTAssertNotNil(fileServer.data(for: baseURL.appendingPathComponent("/images/figure1.jpg")))
        XCTAssertNotNil(fileServer.data(for: baseURL.appendingPathComponent("/figure1.png")))
        
        var retrieved = fileServer.data(for: baseURL.appendingPathComponent("/subPath"))
        XCTAssertEqual(helloWorldHTML, retrieved)

        retrieved = fileServer.data(for: baseURL.appendingPathComponent("/subPath/index.html"))
        XCTAssertEqual(helloWorldHTML, retrieved)
        
        retrieved = fileServer.data(for: baseURL.appendingPathComponent("/subPath/js/file.js"))
        XCTAssertEqual(jsFile, retrieved)
    }
    
    func testResponse() {
        let folder = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        let memoryFileProvider = MemoryFileServerProvider()
        memoryFileProvider.addFiles(inFolder: folder.path)
        
        let fileServer = FileServer(baseURL: baseURL)
        fileServer.register(provider: memoryFileProvider)
        
        let request = URLRequest(url:  baseURL.appendingPathComponent("/images/figure1.jpg"))
        
        var (response, data) = fileServer.response(to: request)
        XCTAssertNotNil(data)
        XCTAssertEqual(response.mimeType, "image/jpeg")
        
        let failingRequest = URLRequest(url:  baseURL.appendingPathComponent("/not/found.jpg"))
        (response, data) = fileServer.response(to: failingRequest)
        XCTAssertNil(data)
        // Initializing a URLResponse with `nil` as MIME type in Linux returns nil
        #if os(Linux) || os(Android)
        XCTAssertNil(response.mimeType)
        #else
        // Doing the same in macOS or iOS returns the default MIME type
        XCTAssertEqual(response.mimeType, "application/octet-stream")
        #endif
    }
    
    func testRedirectToHome() {
        var request = URLRequest(url:  baseURL.appendingPathComponent("/home"))
        var (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)
        
        request = URLRequest(url:  baseURL.appendingPathComponent("/foo///bar"))
        (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)
        
        request = URLRequest(url:  baseURL.appendingPathComponent("/project/Project"))
        (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)
        
        request = URLRequest(url:  baseURL.appendingPathComponent("/project/subPath/'...(_:)-6u3ic"))
        (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)
        
        request = URLRequest(url:  baseURL.appendingPathComponent("/project/subPath/body-swift.property"))
        (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)

        request = URLRequest(url:  baseURL.appendingPathComponent("/theme/js/highlight-swift.js"))
        (response, data) = defaultFileServer.response(to: request)
        XCTAssertNotEqual(helloWorldHTML, data)
        XCTAssertNotEqual("text/html", response.mimeType)
    }
    
    func testInvalidReference() {
        let request = URLRequest(url:  baseURL.appendingPathComponent("thisWontResolve"))
        let (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)
    }

}
