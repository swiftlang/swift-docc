/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation
import SwiftDocC

extension Docc.ProcessArchive {
    struct DiffRenderJSON: ParsableCommand {
        
        // MARK: - Configuration
        
        static var configuration = CommandConfiguration(
            commandName: "diff-render-json",
            abstract: "Produce the symbol diff between two Render JSON files.",
            shouldDisplay: true)
        
        // MARK: - Command Line Options & Arguments
        
        @Argument(
            help: ArgumentHelp(
                "The path to a Render JSON file to be compared.",
                valueName: "renderJSON1"),
            transform: URL.init(fileURLWithPath:))
        var firstRenderJSON: URL
        
        @Argument(
            help: ArgumentHelp(
                "The path to a second Render JSON file to be compared.",
                valueName: "renderJSON2"),
            transform: URL.init(fileURLWithPath:))
        var secondRenderJSON: URL
        
        // MARK: - Execution
        
        public mutating func run() throws {
            let firstRenderJSONData = try Data(contentsOf: firstRenderJSON)
            let secondRenderJSONData = try Data(contentsOf: secondRenderJSON)
            
            let decoder = RenderJSONDecoder.makeDecoder()
            let firstRenderNode = try decoder.decode(RenderNode.self, from: firstRenderJSONData)
            let secondRenderNode = try decoder.decode(RenderNode.self, from: secondRenderJSONData)
            
            let difference = firstRenderNode._difference(from: secondRenderNode)
            print(difference)
        }
        
    }
}
