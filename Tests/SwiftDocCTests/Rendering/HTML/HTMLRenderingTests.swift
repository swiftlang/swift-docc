/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
import DocCHTML
@testable import SwiftDocC
import DocCTestUtilities

struct HTMLRenderingTests {
    @Test
    func imageSourcesUseRelativePaths() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            TextFile(name: "Root.md", utf8Content: """
            # Root
            
            A root page with an image.
            
            ![Some alt text](image-name)
            """)
            
            DataFile(name: "image-name@2x.png", data: Data())
            DataFile(name: "image-name~dark@2x.png", data: Data())
        }
        
        let context = try await load(catalog: catalog)
        #expect(context.diagnostics.isEmpty, "Encountered unexpected problems: \(context.diagnostics.map(\.summary))")
        
        let reference = try #require(context.soleRootModuleReference)
        let article = try #require(context.documentationCache[reference]?.semantic as? Article)
        
        var renderer = HTMLRenderer(reference: reference, context: context, goal: .richness, featureFlags: context.configuration.featureFlags)
        let pageInfo = renderer.renderArticle(article)
        
        let html = try #require(pageInfo.content)
        let data = HTMLFormatter.format(html, options: .prettyPrint)
        let formattedHTML = String(decoding: data, as: UTF8.self)
        #expect(formattedHTML == """
        <article>
          <section id="hero" class="article">
            <nav id="breadcrumbs">
              <ul>
                <li>Root</li>
              </ul>
            </nav>
            <hgroup>
              <p>Article</p>
              <h1>Root</h1>
            </hgroup>
            <p>A root page with an image.</p>
          </section>
          <section id="Overview">
            <h2>
              <a href="#Overview">Overview</a>
            </h2>
            <p>
              <picture>
                <source media="(prefers-color-scheme: light)" srcset="../../images/unit-test/image-name@2x.png">
                <source media="(prefers-color-scheme: dark)" srcset="../../images/unit-test/image-name~dark@2x.png">
                <img alt="Some alt text" decoding="async" loading="lazy">
              </picture>
            </p>
          </section>
        </article>
        """)
    }
}
    
