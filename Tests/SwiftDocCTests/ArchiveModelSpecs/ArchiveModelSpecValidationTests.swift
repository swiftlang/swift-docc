/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import _OpenAPIGeneratorCore
import OpenAPIKit
@testable import SwiftDocC

class ArchiveModelSpecValidationTests: XCTestCase {

    struct ThrowingDiagnosticCollector: DiagnosticCollector, Sendable {
        public init() {}
        public func emit(_ diagnostic: _OpenAPIGeneratorCore.Diagnostic) throws {
            if diagnostic.severity == .warning || diagnostic.severity == .error {
                throw diagnostic
            }
        }
    }

    func testOpenAPISpecIsValid() throws {
        let renderIndexspecURL = Bundle.module.url(
            forResource: "RenderIndex.spec", withExtension: "json", subdirectory: "Test Resources")!
        let data = try Data(contentsOf: renderIndexspecURL)

        let diagCollector = ThrowingDiagnosticCollector()

        let _ = try _OpenAPIGeneratorCore.runGenerator(input: .init(absolutePath: renderIndexspecURL, contents: data), config: Config(
            mode: .types,
            access: Config.defaultAccessModifier,
            namingStrategy: Config.defaultNamingStrategy
        ), diagnostics: diagCollector)
    }
}
