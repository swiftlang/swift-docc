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

class RenderSectionTests: XCTestCase {
    func testDecoderAcceptsHeroKey() throws {
        let json = """
        {
          "backgroundImage" : "intro_school.jpg",
          "chapter" : "Getting Started",
          "content" : [
            {
              "inlineContent" : [
                {
                  "text" : "Here is some introduction text that will explain all the things and such you will be following this tutorial. You are going to learn a lot by building an app.",
                  "type" : "text"
                }
              ],
              "type" : "paragraph"
            }
          ],
          "estimatedTimeInMinutes" : 20,
          "kind" : "hero",
          "projectFiles" : "project.zip",
          "title" : "Basic Augmented Reality App",
          "video" : "video.mov",
          "xcodeRequirement" : "Xcode 10 beta"
        }
        """.data(using: .utf8)!
        
        // We should be able to correctly decode a renderJSON intro section that is described as a hero
        let renderSection = try JSONDecoder().decode(CodableRenderSection.self, from: json)
        XCTAssertEqual(renderSection.section.kind, .hero)
    }

    func testDecoderAcceptsIntroKey() throws {
        let json = """
        {
          "backgroundImage" : "intro_school.jpg",
          "chapter" : "Getting Started",
          "content" : [
            {
              "inlineContent" : [
                {
                  "text" : "Here is some introduction text that will explain all the things and such you will be following this tutorial. You are going to learn a lot by building an app.",
                  "type" : "text"
                }
              ],
              "type" : "paragraph"
            }
          ],
          "estimatedTimeInMinutes" : 20,
          "kind" : "intro",
          "projectFiles" : "project.zip",
          "title" : "Basic Augmented Reality App",
          "video" : "video.mov",
          "xcodeRequirement" : "Xcode 10 beta"
        }
        """.data(using: .utf8)!
        
        // We should be able to correctly decode a renderJSON intro section that is described as an intro
        let renderSection = try JSONDecoder().decode(CodableRenderSection.self, from: json)
        XCTAssertEqual(renderSection.section.kind, .hero)
    }
    
    func testDecoderAcceptsIntroKeyAndOutputsHeroKey() throws {
        // The input JSON uses the "intro" kind key.
        let inputJSON = """
        {
          "backgroundImage" : "intro_school.jpg",
          "chapter" : "Getting Started",
          "content" : [
            {
              "inlineContent" : [
                {
                  "text" : "Here is some introduction text that will explain all the things and such you will be following this tutorial. You are going to learn a lot by building an app.",
                  "type" : "text"
                }
              ],
              "type" : "paragraph"
            }
          ],
          "estimatedTimeInMinutes" : 20,
          "kind" : "intro",
          "projectFiles" : "project.zip",
          "title" : "Basic Augmented Reality App",
          "video" : "video.mov",
          "xcodeRequirement" : "Xcode 10 beta"
        }
        """.data(using: .utf8)!
        
        // The expected output JSON uses the "hero" kind key.
        let expectedOutputJSON = """
        {
          "backgroundImage" : "intro_school.jpg",
          "chapter" : "Getting Started",
          "content" : [
            {
              "inlineContent" : [
                {
                  "text" : "Here is some introduction text that will explain all the things and such you will be following this tutorial. You are going to learn a lot by building an app.",
                  "type" : "text"
                }
              ],
              "type" : "paragraph"
            }
          ],
          "estimatedTimeInMinutes" : 20,
          "kind" : "hero",
          "projectFiles" : "project.zip",
          "title" : "Basic Augmented Reality App",
          "video" : "video.mov",
          "xcodeRequirement" : "Xcode 10 beta"
        }
        """
        
        let renderSection = try JSONDecoder().decode(CodableRenderSection.self, from: inputJSON)
        XCTAssertEqual(renderSection.section.kind, .hero)
        
        // We should always output renderJSON that uses "hero" to describe an intro section to
        // maintain compatibility
        let encodedJSONData = try RenderJSONEncoder.makeEncoder(prettyPrint: true).encode(renderSection)
        let encodedJSONString = String(data: encodedJSONData, encoding: .utf8)
        XCTAssertEqual(encodedJSONString, expectedOutputJSON)
    }
}

