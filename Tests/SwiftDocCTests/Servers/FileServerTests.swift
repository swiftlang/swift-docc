/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import HTTPTypes

import XCTest
@testable import SwiftDocC

fileprivate let baseURL = URL(string: "test://")!
fileprivate let helloWorldHTML = "<html><header><title>Hello Title</title></header><body>Hello world</body></html>".data(using: .utf8)!
fileprivate let jsFile = "var jsFile = true;".data(using: .utf8)!

extension HTTPRequest {
    init(path: String) {
        self.init(method: .get, scheme: nil, authority: nil, path: path)
    }
}

extension HTTPTypes.HTTPResponse {
    init(mimeType: String? = nil, expectedContentLength: Int = -1) {
        var headerFields = HTTPFields()
        if let mimeType = mimeType {
            headerFields[.contentType] = mimeType
        }
        if expectedContentLength >= 0 {
            headerFields[.contentLength] = "\(expectedContentLength)"
        }
        self.init(status: .ok, headerFields: headerFields)
    }
    var mimeType: String? {
        self.headerFields[.contentType]
    }
}

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
        var retrieved = defaultFileServer.data(for: "/")
        XCTAssertEqual(helloWorldHTML, retrieved)
        
        retrieved = defaultFileServer.data(for: "index.html")
        XCTAssertEqual(helloWorldHTML, retrieved)
        
        retrieved = defaultFileServer.data(for: "/js/file.js")
        XCTAssertEqual(jsFile, retrieved)
    }
    
    func testBasicPath() {
        var retrieved = defaultFileServer.data(for: "index.html")
        XCTAssertEqual(helloWorldHTML, retrieved)
        
        retrieved = defaultFileServer.data(for: "/index.html")
        XCTAssertEqual(helloWorldHTML, retrieved)
        
        retrieved = defaultFileServer.data(for: "/js/file.js")
        XCTAssertEqual(jsFile, retrieved)
    }
    
    func testEmpty() {
        var retrieved = defaultFileServer.data(for: "/invalid.html")
        XCTAssertNil(retrieved, "`/invalid.html` should return nil, but returned \(String(describing: retrieved))")

        retrieved = defaultFileServer.data(for: "/invalid/")
        XCTAssertNil(retrieved, "`/invalid/` should return nil, but returned \(String(describing: retrieved))")
    }
    
    func testAddingFilesInFolder() {
        let folder = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        let memoryFileProvider = MemoryFileServerProvider()
        memoryFileProvider.addFiles(inFolder: folder.path)
        
        let fileServer = FileServer(baseURL: baseURL)
        fileServer.register(provider: memoryFileProvider)
        
        XCTAssertNotNil(fileServer.data(for: "/figure1.png"))
        XCTAssertNotNil(fileServer.data(for: "/images/figure1.jpg"))
    }
    
    func testAddingRemovingFromPath() {
        let folder = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        let memoryFileProvider = MemoryFileServerProvider()
        memoryFileProvider.addFiles(inFolder: folder.path)
        
        let fileServer = FileServer(baseURL: baseURL)
        fileServer.register(provider: memoryFileProvider)
        
        XCTAssertNotNil(fileServer.data(for: "/images/figure1.jpg"))

        memoryFileProvider.removeAllFiles(in: "/images")
        
        XCTAssertNil(fileServer.data(for: "/images/figure1.jpg"))
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
        
        XCTAssertNotNil(fileServer.data(for: "/images/figure1.jpg"))
        XCTAssertNotNil(fileServer.data(for: "/figure1.png"))
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
        
        XCTAssertNotNil(fileServer.data(for: "/images/figure1.jpg"))
        XCTAssertNotNil(fileServer.data(for: "/figure1.png"))
        
        var retrieved = fileServer.data(for: "/subPath")
        XCTAssertEqual(helloWorldHTML, retrieved)

        retrieved = fileServer.data(for: "/subPath/index.html")
        XCTAssertEqual(helloWorldHTML, retrieved)
        
        retrieved = fileServer.data(for: "/subPath/js/file.js")
        XCTAssertEqual(jsFile, retrieved)
    }
    
    func testResponse() {
        let folder = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        let memoryFileProvider = MemoryFileServerProvider()
        memoryFileProvider.addFiles(inFolder: folder.path)
        
        let fileServer = FileServer(baseURL: baseURL)
        fileServer.register(provider: memoryFileProvider)
        
        let request = HTTPRequest(path: "/images/figure1.jpg")

        var (response, data) = fileServer.response(to: request)
        XCTAssertNotNil(data)
        XCTAssertEqual(response.mimeType, "image/jpeg")
        
        let failingRequest = HTTPRequest(path: "/not/found.jpg")
        (response, data) = fileServer.response(to: failingRequest)
        XCTAssertEqual(response.mimeType, "application/octet-stream")
    }
    
    func testRedirectToHome() {
        var request = HTTPRequest(path: "/home")
        var (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)
        
        request = HTTPRequest(path: "/foo///bar")
        (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)
        
        request = HTTPRequest(path: "/project/Project")
        (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)
        
        request = HTTPRequest(path: "/project/subPath/'...(_:)-6u3ic")
        (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)
        
        request = HTTPRequest(path: "/project/subPath/body-swift.property")
        (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)

        request = HTTPRequest(path: "/theme/js/highlight-swift.js")
        (response, data) = defaultFileServer.response(to: request)
        XCTAssertNotEqual(helloWorldHTML, data)
        XCTAssertNotEqual("text/html", response.mimeType)
    }
    
    func testInvalidReference() {
        let request = HTTPRequest(path: "thisWontResolve")
        let (response, data) = defaultFileServer.response(to: request)
        XCTAssertEqual(helloWorldHTML, data)
        XCTAssertEqual("text/html", response.mimeType)
    }

}
