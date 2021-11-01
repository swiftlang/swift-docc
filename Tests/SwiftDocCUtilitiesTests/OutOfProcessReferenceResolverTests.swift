/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
import SymbolKit
@testable import SwiftDocC
@testable import SwiftDocCUtilities

class OutOfProcessReferenceResolverTests: XCTestCase {
    
    func testInitializationProcess() throws {
        #if os(macOS)
        let temporaryFolder = Foundation.URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }
        
        let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
        // When the executable file doesn't exist
        XCTAssertFalse(FileManager.default.fileExists(atPath: executableLocation.path))
        XCTAssertThrowsError(try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in }),
                        "There should be a validation error if the executable file doesn't exist")
        
        // When the file isn't executable
        try "".write(to: executableLocation, atomically: true, encoding: .utf8)
        XCTAssertFalse(FileManager.default.isExecutableFile(atPath: executableLocation.path))
        XCTAssertThrowsError(try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in }),
                        "There should be a validation error if the file isn't executable")
        
        // When the file isn't executable
        try """
        #!/bin/bash
        echo '{"bundleIdentifier":"com.test.bundle"}'   # Write this resolver's bundle identifier
        read                                            # Wait for docc to send a topic URL
        """.write(to: executableLocation, atomically: true, encoding: .utf8)
        
        // `0o0700` is `-rwx------` (read, write, & execute only for owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
        XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
         
        let resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { errorMessage in
            XCTFail("No error output is expected for this test executable. Got:\n\(errorMessage)")
        })
        XCTAssertEqual(resolver.bundleIdentifier, "com.test.bundle")
        #endif
    }
    
    func assertResolvesTopicLink(
        makeResolver: (OutOfProcessReferenceResolver.ResolvedInformation) throws
            -> OutOfProcessReferenceResolver
    ) throws {
        let testMetadata = OutOfProcessReferenceResolver.ResolvedInformation(
            kind: .init(name: "Kind Name", id: "com.test.kind.id", isSymbol: true),
            url: URL(string: "doc://com.test.bundle/something")!,
            title: "Resolved Title",
            abstract: "Resolved abstract for this topic.",
            language: .init(name: "Language Name", id: "com.test.language.id"),
            availableLanguages: [
                .init(name: "Language Name 1", id: "com.test.language.id"),
                .init(name: "Language Name 2", id: "com.test.language2.id")
            ],
            platforms: [
                .init(name: "fooOS", introduced: "1.2.3", isBeta: false),
                .init(name: "barOS", introduced: "1.2.3", isBeta: false)
            ],
            declarationFragments: nil
        )
        
        let resolver = try makeResolver(testMetadata)
        XCTAssertEqual(resolver.bundleIdentifier, "com.test.bundle")
        
        // Resolve the reference
        let unresolved = TopicReference.unresolved(
            UnresolvedTopicReference(topicURL: ValidatedURL("doc://com.test.bundle/something")!))
        guard case .success(let resolvedReference) = resolver.resolve(
                unresolved, sourceLanguage: .swift)
        else {
            XCTFail("Unexpectedly failed to resolve reference")
            return
        }
        
        XCTAssertEqual(resolver.urlForResolvedReference(resolvedReference), testMetadata.url)
        
        let node = try resolver.entity(with: resolvedReference)
        
        XCTAssertEqual(node.kind.name, testMetadata.kind.name)
        XCTAssertEqual(node.kind.id, testMetadata.kind.id)
        XCTAssertEqual(node.kind.isSymbol, testMetadata.kind.isSymbol)
        
        XCTAssertEqual(node.name, .conceptual(title: testMetadata.title))
        
        XCTAssertEqual(node.sourceLanguage.name, testMetadata.language.name)
        XCTAssertEqual(node.sourceLanguage.id, testMetadata.language.id)

        XCTAssertEqual(node.availableSourceLanguages.count, 2)

        let availableSourceLanguages = node.availableSourceLanguages
            .sorted(by: { lhs, rhs in lhs.id < rhs.id })
        let expectedLanguages = testMetadata.availableLanguages
            .sorted(by: { lhs, rhs in lhs.id < rhs.id })
        
        XCTAssertEqual(availableSourceLanguages[0].name, expectedLanguages[0].name)
        XCTAssertEqual(availableSourceLanguages[0].id, expectedLanguages[0].id)

        XCTAssertEqual(availableSourceLanguages[1].name, expectedLanguages[1].name)
        XCTAssertEqual(availableSourceLanguages[1].id, expectedLanguages[1].id)

        XCTAssertEqual(node.platformNames?.sorted(), ["barOS", "fooOS"])
    }
    
    func testResolvingTopicLinkProcess() throws {
        #if os(macOS)
        try assertResolvesTopicLink(makeResolver: { testMetadata in
            let temporaryFolder = Foundation.URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
            try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true, attributes: nil)
            defer {
                try? FileManager.default.removeItem(at: temporaryFolder)
            }
            let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
            
            let encodedMetadata = try String(data: JSONEncoder().encode(testMetadata), encoding: .utf8)!
            
            try """
            #!/bin/bash
            echo '{"bundleIdentifier":"com.test.bundle"}'       # Write this resolver's bundle identifier
            read                                                # Wait for docc to send a topic URL
            echo '{"resolvedInformation":\(encodedMetadata)}'   # Respond with the test metadata (above)
            """.write(to: executableLocation, atomically: true, encoding: .utf8)
            
            // `0o0700` is `-rwx------` (read, write, & execute only for owner)
            try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
            XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
             
            return try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        })
        
        #endif
    }
    
    func testResolvingTopicLinkService() throws {
        try assertResolvesTopicLink(makeResolver: { testMetadata in
            let server = DocumentationServer()
            server.register(service: MockService { message in
                XCTAssertEqual(message.type, "resolve-reference")
                XCTAssert(message.identifier.hasPrefix("SwiftDocC"))
                do {
                    let payload = try XCTUnwrap(message.payload)
                    let request = try JSONDecoder()
                        .decode(
                            ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                            from: payload
                        )
                    
                    XCTAssertEqual(request.convertRequestIdentifier, "convert-id")
                    
                    guard case .topic(let url) = request.payload else {
                        XCTFail("Unexpected request")
                        return nil
                    }
                    
                    XCTAssertEqual(url, URL(string: "doc://com.test.bundle/something")!)
                    
                    let response = DocumentationServer.Message(
                        type: "resolve-reference-response",
                        payload: try JSONEncoder().encode(
                            OutOfProcessReferenceResolver.Response.resolvedInformation(testMetadata))
                    )
                    
                    return response
                } catch {
                    XCTFail(error.localizedDescription)
                    return nil
                }
            })

            return try OutOfProcessReferenceResolver(
                bundleIdentifier: "com.test.bundle",
                server: server,
                convertRequestIdentifier: "convert-id"
            )
        })
    }
    
    func assertResolvesSymbol(
        makeResolver: (OutOfProcessReferenceResolver.ResolvedInformation) throws
            -> OutOfProcessReferenceResolver
    ) throws {
        let testMetadata = OutOfProcessReferenceResolver.ResolvedInformation(
            kind: .init(name: "Kind Name", id: "com.test.kind.id", isSymbol: true),
            url: URL(string: "/relative/path/to/symbol")!,
            title: "Resolved Title",
            abstract: "Resolved abstract for this topic.",
            language: .init(name: "Language Name", id: "com.test.language.id"),
            availableLanguages: [
                .init(name: "Language Name 1", id: "com.test.language.id"),
                .init(name: "Language Name 2", id: "com.test.language2.id")
            ],
            platforms: [
                .init(name: "fooOS", introduced: "1.2.3", isBeta: false),
                .init(name: "barOS", introduced: "1.2.3", isBeta: false)
            ],
            declarationFragments: nil
        )
        
        let resolver = try makeResolver(testMetadata)
        
        XCTAssertEqual(resolver.bundleIdentifier, "com.test.bundle")
        
        // Resolve the symbol
        guard let symbolNode = try? resolver.symbolEntity(withPreciseIdentifier: "abc123") else {
            XCTFail("Unexpectedly failed to resolve symbol")
            return
        }
        
        XCTAssertEqual(resolver.urlForResolvedSymbol(reference: symbolNode.reference), testMetadata.url)
        
        XCTAssertEqual(symbolNode.kind.name, testMetadata.kind.name)
        XCTAssertEqual(symbolNode.kind.id, testMetadata.kind.id)
        XCTAssertEqual(symbolNode.kind.isSymbol, testMetadata.kind.isSymbol)
        
        XCTAssertNotNil(symbolNode.semantic as? Symbol)
        if let symbol = symbolNode.semantic as? Symbol {
            XCTAssertEqual(symbol.kind.identifier, SymbolGraph.Symbol.Kind.Swift.class.rawValue,
                           "When the node kind doesn't map to a known value it should fallback to a `.class` kind.")
            XCTAssertEqual(symbol.title, "Resolved Title")
        }
        
        XCTAssertEqual(symbolNode.name, .conceptual(title: testMetadata.title))
        
        XCTAssertEqual(symbolNode.sourceLanguage.name, testMetadata.language.name)
        XCTAssertEqual(symbolNode.sourceLanguage.id, testMetadata.language.id)

        XCTAssertEqual(symbolNode.availableSourceLanguages.count, 2)

        let availableSourceLanguages = symbolNode.availableSourceLanguages.sorted(by: { lhs, rhs in lhs.id < rhs.id })
        let expectedLanguages = testMetadata.availableLanguages.sorted(by: { lhs, rhs in lhs.id < rhs.id })
        
        XCTAssertEqual(availableSourceLanguages[0].name, expectedLanguages[0].name)
        XCTAssertEqual(availableSourceLanguages[0].id, expectedLanguages[0].id)

        XCTAssertEqual(availableSourceLanguages[1].name, expectedLanguages[1].name)
        XCTAssertEqual(availableSourceLanguages[1].id, expectedLanguages[1].id)

        XCTAssertEqual(symbolNode.platformNames?.sorted(), ["barOS", "fooOS"])
    }
    
    func testResolvingSymbolProcess() throws {
        #if os(macOS)
        try assertResolvesSymbol(makeResolver: { testMetadata in
            let temporaryFolder = Foundation.URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
            try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true, attributes: nil)
            defer {
                try? FileManager.default.removeItem(at: temporaryFolder)
            }
            let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
            
            let encodedMetadata = try String(data: JSONEncoder().encode(testMetadata), encoding: .utf8)!
            
            try """
        #!/bin/bash
        echo '{"bundleIdentifier":"com.test.bundle"}'         # Write this resolver's bundle identifier
        read                                                  # Wait for docc to send a symbol USR
        echo '{"resolvedInformation":\(encodedMetadata)}'     # Respond with the test metadata (above)
        """.write(to: executableLocation, atomically: true, encoding: .utf8)
            
            // `0o0700` is `-rwx------` (read, write, & execute only for owner)
            try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
            XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
            
            return try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        })
        #endif
    }
    
    func testResolvingSymbolService() throws {
        try assertResolvesSymbol(makeResolver: { testMetadata in
            let server = DocumentationServer()
            server.register(service: MockService { message in
                XCTAssertEqual(message.type, "resolve-reference")
                XCTAssert(message.identifier.hasPrefix("SwiftDocC"))
                do {
                    let payload = try XCTUnwrap(message.payload)
                    let request = try JSONDecoder()
                        .decode(
                            ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                            from: payload
                        )
                    
                    XCTAssertEqual(request.convertRequestIdentifier, "convert-id")
                    
                    guard case .symbol(let preciseIdentifier) = request.payload else {
                        XCTFail("Unexpected request")
                        return nil
                    }
                    
                    XCTAssertEqual(preciseIdentifier, "abc123")
                    
                    let response = DocumentationServer.Message(
                        type: "resolve-reference-response",
                        payload: try JSONEncoder().encode(
                            OutOfProcessReferenceResolver.Response.resolvedInformation(testMetadata))
                    )
                    
                    return response
                } catch {
                    XCTFail(error.localizedDescription)
                    return nil
                }
            })

            return try OutOfProcessReferenceResolver(
                bundleIdentifier: "com.test.bundle",
                server: server,
                convertRequestIdentifier: "convert-id"
            )
        })
    }
    
    func testForwardsErrorOutputProcess() throws {
        #if os(macOS)
        let temporaryFolder = Foundation.URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }
        
        let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
        try """
        #!/bin/bash
        echo "Some error output" 1>&2                   # Write to stderr
        echo '{"bundleIdentifier":"com.test.bundle"}'   # Write this resolver's bundle identifier
        read                                            # Wait for docc to send a topic URL
        """.write(to: executableLocation, atomically: true, encoding: .utf8)
        
        // `0o0700` is `-rwx------` (read, write, & execute only for owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
        XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
         
        let didReadErrorOutputExpectation = AsyncronousExpectation(description: "Did read forwarded error output.")
        DispatchQueue.global().async {
            let resolver = try? OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: {
                errorMessage in
                XCTAssertEqual(errorMessage, "Some error output\n")
                didReadErrorOutputExpectation.fulfill()
            })
            XCTAssertEqual(resolver?.bundleIdentifier, "com.test.bundle")
        }
        XCTAssertNotEqual(didReadErrorOutputExpectation.wait(timeout: 20.0), .timedOut)
        #endif
    }
    
    func assertForwardsResolverErrors(resolver: OutOfProcessReferenceResolver) throws {
        XCTAssertEqual(resolver.bundleIdentifier, "com.test.bundle")
        let resolverResult = resolver.resolve(.unresolved(UnresolvedTopicReference(topicURL: ValidatedURL("doc://com.test.bundle/something")!)), sourceLanguage: .swift)
        guard case .failure(_, let errorMessage) = resolverResult else {
            XCTFail("Encountered an unexpected type of error.")
            return
        }
        XCTAssertEqual(errorMessage, "Some error message.")
    }
    
    func testForwardsResolverErrorsProcess() throws {
        #if os(macOS)
        let temporaryFolder = Foundation.URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }
        
        let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
        try """
        #!/bin/bash
        echo '{"bundleIdentifier":"com.test.bundle"}'   # Write this resolver's bundle identifier
        read                                            # Wait for docc to send a topic URL
        echo '{"errorMessage":"Some error message."}'   # Respond with an error message
        """.write(to: executableLocation, atomically: true, encoding: .utf8)
        
        // `0o0700` is `-rwx------` (read, write, & execute only for owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
        XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
         
        let resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        try assertForwardsResolverErrors(resolver: resolver)
        #endif
    }
    
    func testForwardsResolverErrorsService() throws {
        let server = DocumentationServer()
        server.register(service: MockService { message in
            XCTAssertEqual(message.type, "resolve-reference")
            XCTAssert(message.identifier.hasPrefix("SwiftDocC"))
            do {
                let payload = try XCTUnwrap(message.payload)
                let request = try JSONDecoder()
                    .decode(
                        ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                        from: payload
                    )
                
                XCTAssertEqual(request.convertRequestIdentifier, "convert-id")
                
                guard case .topic = request.payload else {
                    XCTFail("Unexpected request")
                    return nil
                }
                                
                let response = DocumentationServer.Message(
                    type: "resolve-reference-response",
                    payload: try JSONEncoder().encode(
                        OutOfProcessReferenceResolver.Response.errorMessage("Some error message.")
                    )
                )
                
                return response
            } catch {
                XCTFail(error.localizedDescription)
                return nil
            }
        })
        
        let resolver = try OutOfProcessReferenceResolver(
            bundleIdentifier: "com.test.bundle", server: server, convertRequestIdentifier: "convert-id")
        
        try assertForwardsResolverErrors(resolver: resolver)
    }
    
    func testMessageEncodingAndDecoding() throws {
        #if os(macOS)
        // Bundle identifier
        do {
            let message = OutOfProcessReferenceResolver.Response.bundleIdentifier("com.example.test")
            
            let data = try JSONEncoder().encode(message)
            let decodedMessage = try JSONDecoder().decode(OutOfProcessReferenceResolver.Response.self, from: data)
            
            switch decodedMessage {
            case .bundleIdentifier(let decodedIdentifier):
                XCTAssertEqual(decodedIdentifier, "com.example.test")
                
            default:
                XCTFail("Decoded the wrong type of message")
            }
        }
        
        // Error message
        do {
            let message = OutOfProcessReferenceResolver.Response.errorMessage("Some error output.")
            
            let data = try JSONEncoder().encode(message)
            let decodedMessage = try JSONDecoder().decode(OutOfProcessReferenceResolver.Response.self, from: data)
            
            switch decodedMessage {
            case .errorMessage(let decodedErrorMessage):
                XCTAssertEqual(decodedErrorMessage, "Some error output.")
                
            default:
                XCTFail("Decoded the wrong type of message")
            }
        }
        
        // Resolved metadata
        do {
            let testMetadata = OutOfProcessReferenceResolver.ResolvedInformation(
                kind: .init(name: "Kind Name", id: "com.test.kind.id", isSymbol: true),
                url: URL(string: "scheme://host.name/path/")!,
                title: "Resolved Title",
                abstract: "Resolved abstract for this topic.",
                language: .init(name: "Language Name", id: "com.test.language.id"),
                availableLanguages: [],
                platforms: nil,
                declarationFragments: nil
            )
            let message = OutOfProcessReferenceResolver.Response.resolvedInformation(testMetadata)
            
            let data = try JSONEncoder().encode(message)
            let decodedMessage = try JSONDecoder().decode(OutOfProcessReferenceResolver.Response.self, from: data)
            
            switch decodedMessage {
            case .resolvedInformation(let decodedInformation):
                XCTAssertEqual(decodedInformation.kind.name, testMetadata.kind.name)
                XCTAssertEqual(decodedInformation.kind.id, testMetadata.kind.id)
                XCTAssertEqual(decodedInformation.kind.isSymbol, testMetadata.kind.isSymbol)
                
                XCTAssertEqual(decodedInformation.title, testMetadata.title)
                
                XCTAssertEqual(decodedInformation.language.name, testMetadata.language.name)
                XCTAssertEqual(decodedInformation.language.id, testMetadata.language.id)
                
            default:
                XCTFail("Decoded the wrong type of message")
            }
        }
        #endif
    }
    
    func testErrorWhenReceivingBundleIdentifierTwiceProcess() throws {
        #if os(macOS)
        let temporaryFolder = Foundation.URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? FileManager.default.removeItem(at: temporaryFolder)
        }
        
        let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
        try """
            #!/bin/bash
            echo '{"bundleIdentifier":"com.test.bundle"}'   # Write this resolver's bundle identifier
            read                                            # Wait for docc to send a topic URL
            echo '{"bundleIdentifier":"com.test.bundle"}'   # Write the bundle identifier again
            """.write(to: executableLocation, atomically: true, encoding: .utf8)
        
        // `0o0700` is `-rwx------` (read, write, & execute only for owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
        XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
        
        let resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        XCTAssertEqual(resolver.bundleIdentifier, "com.test.bundle")
        
        XCTAssertThrowsError(try resolver.resolveInformationForTopicURL(URL(string: "doc://com.test.bundle/something")!)) {
            guard case OutOfProcessReferenceResolver.Error.executableSentBundleIdentifierAgain = $0 else {
                XCTFail("Encountered an unexpected type of error.")
                return
            }
        }
        #endif
    }
    
    struct MockService: DocumentationService {
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
