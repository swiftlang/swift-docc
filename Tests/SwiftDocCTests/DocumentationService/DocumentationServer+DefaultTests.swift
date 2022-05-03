/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DocumentationServer_DefaultTests: XCTestCase {
    func testCreatesDefaultServerWithSpecifiedQualityOfService() {
        XCTAssertEqual(
            DocumentationServer.createDefaultServer(
                qualityOfService: .userInitiated,
                peer: nil
            ).synchronizationQueue.qos,
            .userInitiated
        )
    }
    
    /// Tests that the documentation server handles "convert" requests.
    ///
    /// This test verifies that when a "convert" request with no payload is sent, the conversion services responds with
    /// a "missing-payload" error. For more thorough testing for the conversion service, see ``ConvertServiceTests``.
    func testRespondsToConvertRequests() throws {
        let message = DocumentationServer.Message(
            type: "convert",
            identifier: "test-identifier",
            payload: nil
        )
        
        let expectation = XCTestExpectation(description: "Receives response")
        
        DocumentationServer
            .createDefaultServer(qualityOfService: .userInitiated, peer: nil)
            .process(try JSONEncoder().encode(message)) { data in
                do {
                    let response = try JSONDecoder().decode(
                        DocumentationServer.Message.self, from: data)
                    
                    let payload = try JSONDecoder().decode(
                        ConvertServiceError.self, from: try XCTUnwrap(response.payload))
                    
                    XCTAssertEqual(payload.identifier, "missing-payload")
                } catch {
                    XCTFail(error.localizedDescription)
                }
                
                expectation.fulfill()
            }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testQueriesLinkResolutionServer() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: DocumentationBundle.Info(
                displayName: "TestBundle",
                identifier: "identifier",
                version: "1.0.0"
            ),
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        let message = DocumentationServer.Message(
            type: "convert",
            identifier: "test-identifier",
            payload: try JSONEncoder().encode(request)
        )
        
        let receivesResponseExpectation = XCTestExpectation(description: "Receives response")
        
        // Instead of using an `XCTestExpectation`, use a Boolean due to a bug in
        // swift-corelibs-xctest on Linux for expectations that get over-fulfilled
        // https://github.com/apple/swift/issues/55020.
        var hasLinkResolverBeenCalled = false
        
        let peerServer = DocumentationServer()
        peerServer.register(service: LinkResolvingService { message in
            defer { hasLinkResolverBeenCalled = true }
            
            do {
                return DocumentationServer.Message(
                    type: "resolve-reference-response",
                    payload: try JSONEncoder().encode(
                    OutOfProcessReferenceResolver.Response.errorMessage("Error"))
                )
            } catch {
                XCTFail(error.localizedDescription)
                return nil
            }
        })
        
        DocumentationServer
            .createDefaultServer(qualityOfService: .userInitiated, peer: peerServer)
            .process(try JSONEncoder().encode(message)) { data in
                do {
                    let response = try JSONDecoder().decode(
                        DocumentationServer.Message.self, from: data)
                    
                    XCTAssertEqual(response.type, "convert-response")
                } catch {
                    XCTFail(error.localizedDescription)
                }
                
                receivesResponseExpectation.fulfill()
            }
        
        wait(for: [receivesResponseExpectation], timeout: 5.0)
        XCTAssert(hasLinkResolverBeenCalled)
    }
    
    struct LinkResolvingService: DocumentationService {
        static var handlingTypes: [DocumentationServer.MessageType] = ["resolve-reference"]
        
        var processHandler: (DocumentationServer.Message) -> DocumentationServer.Message?
        
        func process(
            _ message: DocumentationServer.Message,
            completion: @escaping (DocumentationServer.Message) -> ()
        ) {
            if let response = processHandler(message) {
                completion(response)
            }
        }
    }
}
