/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
@testable import SwiftDocCUtilities

import NIO
import NIOHTTP1

class FileRequestHandlerTests: XCTestCase {
    let fileIO = NonBlockingFileIO(threadPool: NIOThreadPool(numberOfThreads: 2))

    private func verifyAsset(root: URL, path: String, body: String, type: String, file: StaticString = #file, line: UInt = #line) throws {
        let request = makeRequestHead(path: path)
        let factory = FileRequestHandler(rootURL: root, fileIO: fileIO)
        let response = try responseWithPipeline(request: request, handler: factory)
        
        XCTAssertEqual(response.head?.status, .ok, file: (file), line: line)
        XCTAssertEqual(response.body, body, file: (file), line: line)
        XCTAssertEqual(response.head?.headers["Content-type"], [type], file: (file), line: line)
        XCTAssertEqual(response.head?.headers["Content-length"], ["\(body.count)"], file: (file), line: line)
    }
    
    func testFileHandlerAssets() throws {
        let tempDir = try TempFolder(content: [
            Folder(name: "data", content: [
                TextFile(name: "test.json", utf8Content: "data")
            ]),
            Folder(name: "css", content: [
                TextFile(name: "test.css", utf8Content: "css")
            ]),
            Folder(name: "js", content: [
                TextFile(name: "test.js", utf8Content: "js")
            ]),
            Folder(name: "fonts", content: [
                TextFile(name: "test.otf", utf8Content: "font"),
                TextFile(name: "test.ttf", utf8Content: "ttf")
            ]),
            Folder(name: "images", content: [
                TextFile(name: "image.png", utf8Content: "png"),
                TextFile(name: "image.gif", utf8Content: "gif"),
                TextFile(name: "image.jpg", utf8Content: "jpg"),
                TextFile(name: "logo.svg", utf8Content: "svg"),
            ]),
            Folder(name: "img", content: [
                TextFile(name: "image.png", utf8Content: "png"),
                TextFile(name: "image.gif", utf8Content: "gif"),
                TextFile(name: "image.jpg", utf8Content: "jpg")
            ]),
            Folder(name: "videos", content: [
                TextFile(name: "video.mov", utf8Content: "mov"),
                TextFile(name: "video.avi", utf8Content: "avi")
            ]),
            Folder(name: "downloads", content: [
                TextFile(name: "project.zip", utf8Content: "zip")
            ])
        ])
        try tempDir.write(to: URL(fileURLWithPath: NSTemporaryDirectory().appending(UUID().uuidString)))

        try verifyAsset(root: tempDir.url, path: "/data/test.json", body: "data", type: "application/json")
        try verifyAsset(root: tempDir.url, path: "/css/test.css", body: "css", type: "text/css")
        try verifyAsset(root: tempDir.url, path: "/js/test.js", body: "js", type: "text/javascript")
        try verifyAsset(root: tempDir.url, path: "/fonts/test.otf", body: "font", type: "font/otf")
        // default font type
        try verifyAsset(root: tempDir.url, path: "/fonts/test.ttf", body: "ttf", type: "application/octet-stream")
        try verifyAsset(root: tempDir.url, path: "/images/image.png", body: "png", type: "image/png")
        try verifyAsset(root: tempDir.url, path: "/images/image.gif", body: "gif", type: "image/gif")
        // default image type
        try verifyAsset(root: tempDir.url, path: "/images/image.jpg", body: "jpg", type: "image/jpeg")
        try verifyAsset(root: tempDir.url, path: "/images/logo.svg", body: "svg", type: "image/svg+xml")
        try verifyAsset(root: tempDir.url, path: "/img/image.png", body: "png", type: "image/png")
        try verifyAsset(root: tempDir.url, path: "/img/image.gif", body: "gif", type: "image/gif")
        // default image type
        try verifyAsset(root: tempDir.url, path: "/img/image.jpg", body: "jpg", type: "image/jpeg")
        try verifyAsset(root: tempDir.url, path: "/videos/video.mov", body: "mov", type: "video/quicktime")
        try verifyAsset(root: tempDir.url, path: "/videos/video.avi", body: "avi", type: "video/x-msvideo")
        try verifyAsset(root: tempDir.url, path: "/downloads/project.zip", body: "zip", type: "application/zip")
    }
    
    func testFileHandlerAssetsMissing() throws {
        let tempDir = try TempFolder(content: [])
        try tempDir.write(to: URL(fileURLWithPath: NSTemporaryDirectory().appending(UUID().uuidString)))

        let request = makeRequestHead(path: "/css/b00011100.css")
        let factory = FileRequestHandler(rootURL: tempDir.url, fileIO: fileIO)
        let response = try responseWithPipeline(request: request, handler: factory)
        
        XCTAssertEqual(response.requestError?.status, .notFound)
    }

    func testFileHandlerWithRange() throws {
        let tempDir = try TempFolder(content: [
            Folder(name: "videos", content: [
                TextFile(name: "video.mov", utf8Content: "Hello!")
            ])
        ])
        try tempDir.write(to: URL(fileURLWithPath: NSTemporaryDirectory().appending(UUID().uuidString)))

        let request = makeRequestHead(path: "/videos/video.mov", headers: [("Range", "bytes=0-1")])
        let factory = FileRequestHandler(rootURL: tempDir.url, fileIO: fileIO)
        let response = try responseWithPipeline(request: request, handler: factory)
        
        XCTAssertEqual(response.body, "He")
        XCTAssertEqual(response.head?.status, .partialContent)
        XCTAssertEqual(response.head?.headers["Accept-ranges"], ["bytes"])
        XCTAssertEqual(response.head?.headers["Content-range"], ["bytes 0-1/6"])
        // Verify we return the length of the requested range instead of the full length
        XCTAssertEqual(response.head?.headers["Content-length"], ["2"])
    }

    func testFileInUpperDirectory() throws {
        let tempDir = try TempFolder(content: [
            Folder(name: "videos", content: [
                TextFile(name: "video.mov", utf8Content: "Hello!")
            ])
        ])
        try tempDir.write(to: URL(fileURLWithPath: NSTemporaryDirectory().appending(UUID().uuidString)))

        let request = makeRequestHead(path: "/videos/../video.mov", headers: [("Range", "bytes=0-1")])
        let factory = FileRequestHandler(rootURL: tempDir.url, fileIO: fileIO)
        let response = try responseWithPipeline(request: request, handler: factory)
        
        XCTAssertNil(response.body, "He")
        XCTAssertEqual(response.requestError?.status.code, RequestError.init(status: .unauthorized).status.code)
    }

    func testMalformedPath() throws {
        let tempDir = try TempFolder(content: [
            Folder(name: "videos", content: [
                TextFile(name: "video.mov", utf8Content: "Hello!")
            ])
        ])
        try tempDir.write(to: URL(fileURLWithPath: NSTemporaryDirectory().appending(UUID().uuidString)))

        let request = makeRequestHead(path: "/videos/.  ? ? ? ./video.mov", headers: [("Range", "bytes=0-1")])
        let factory = FileRequestHandler(rootURL: tempDir.url, fileIO: fileIO)
        let response = try responseWithPipeline(request: request, handler: factory)
        
        XCTAssertNil(response.body, "He")
        XCTAssertEqual(response.requestError?.status.code, RequestError.init(status: .badRequest).status.code)
    }
}
