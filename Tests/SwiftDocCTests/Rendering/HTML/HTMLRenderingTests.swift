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
import SymbolKit

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
    
    @Test
    func includesConformsToAndConformingTypesRelationshipsSection() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            // public protocol SomeProtocol {}
            // public struct SomeStruct: SomeProtocol {}
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "protocol-id", kind: .protocol, pathComponents: ["SomeProtocol"]),
                makeSymbol(id: "struct-id",   kind: .struct,   pathComponents: ["SomeStruct"]),
            ], relationships: [
                .init(source: "struct-id", target: "protocol-id", kind: .conformsTo, targetFallback: nil)
            ]))
        }
        
        let context = try await load(catalog: catalog)
        #expect(context.diagnostics.isEmpty, "Encountered unexpected problems: \(context.diagnostics.map(\.summary))")
        
        do {
            let reference = try #require(context.documentationCache.reference(symbolID: "struct-id"))
            let symbol = try #require(context.documentationCache[reference]?.semantic as? Symbol)
            
            var renderer = HTMLRenderer(reference: reference, context: context, goal: .richness, featureFlags: context.configuration.featureFlags)
            let pageInfo = renderer.renderSymbol(symbol)
            
            let html = try #require(pageInfo.content)
            let data = HTMLFormatter.format(html, options: .prettyPrint)
            let formattedHTML = String(decoding: data, as: UTF8.self)
            #expect(formattedHTML == """
            <article>
              <section>
                <nav id="breadcrumbs">
                  <ul>
                    <li>
                      <a href="../index.html">ModuleName</a>
                    </li>
                    <li>SomeStruct</li>
                  </ul>
                </nav>
                <hgroup>
                  <p>Structure</p>
                  <h1>
                    Some<wbr>Struct
                  </h1>
                </hgroup>
              </section>
              <section id="Relationships">
                <h2>
                  <a href="#Relationships">Relationships</a>
                </h2>
                <h3 id="Conforms-To">
                  <a href="#Conforms-To">Conforms To</a>
                </h3>
                <ul>
                  <li>
                    <a href="../someprotocol/index.html">
                      <code>
                        Some<wbr>Protocol
                      </code>
                    </a>
                  </li>
                </ul>
              </section>
            </article>
            """)
        }
        
        do {
            let reference = try #require(context.documentationCache.reference(symbolID: "protocol-id"))
            let symbol = try #require(context.documentationCache[reference]?.semantic as? Symbol)
            
            var renderer = HTMLRenderer(reference: reference, context: context, goal: .richness, featureFlags: context.configuration.featureFlags)
            let pageInfo = renderer.renderSymbol(symbol)
            
            let html = try #require(pageInfo.content)
            let data = HTMLFormatter.format(html, options: .prettyPrint)
            let formattedHTML = String(decoding: data, as: UTF8.self)
            #expect(formattedHTML == """
            <article>
              <section>
                <nav id="breadcrumbs">
                  <ul>
                    <li>
                      <a href="../index.html">ModuleName</a>
                    </li>
                    <li>SomeProtocol</li>
                  </ul>
                </nav>
                <hgroup>
                  <p>Protocol</p>
                  <h1>
                    Some<wbr>Protocol
                  </h1>
                </hgroup>
              </section>
              <section id="Relationships">
                <h2>
                  <a href="#Relationships">Relationships</a>
                </h2>
                <h3 id="Conforming-Types">
                  <a href="#Conforming-Types">Conforming Types</a>
                </h3>
                <ul>
                  <li>
                    <a href="../somestruct/index.html">
                      <code>
                        Some<wbr>Struct
                      </code>
                    </a>
                  </li>
                </ul>
              </section>
            </article>
            """)
        }
    }
    
    @Test
    func includesInheritsFromAndInheritedByRelationshipsSection() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            // public class BaseClass {}
            // public class SubClass: BaseClass {}
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "base-class-id", kind: .class, pathComponents: ["BaseClass"]),
                makeSymbol(id: "sub-class-id",  kind: .class, pathComponents: ["SubClass"]),
            ], relationships: [
                .init(source: "sub-class-id", target: "base-class-id", kind: .inheritsFrom, targetFallback: nil)
            ]))
        }
        
        let context = try await load(catalog: catalog)
        #expect(context.diagnostics.isEmpty, "Encountered unexpected problems: \(context.diagnostics.map(\.summary))")
        
        do {
            let reference = try #require(context.documentationCache.reference(symbolID: "sub-class-id"))
            let symbol = try #require(context.documentationCache[reference]?.semantic as? Symbol)
            
            var renderer = HTMLRenderer(reference: reference, context: context, goal: .richness, featureFlags: context.configuration.featureFlags)
            let pageInfo = renderer.renderSymbol(symbol)
            
            let html = try #require(pageInfo.content)
            let data = HTMLFormatter.format(html, options: .prettyPrint)
            let formattedHTML = String(decoding: data, as: UTF8.self)
            #expect(formattedHTML == """
            <article>
              <section>
                <nav id="breadcrumbs">
                  <ul>
                    <li>
                      <a href="../index.html">ModuleName</a>
                    </li>
                    <li>SubClass</li>
                  </ul>
                </nav>
                <hgroup>
                  <p>Class</p>
                  <h1>
                    Sub<wbr>Class
                  </h1>
                </hgroup>
              </section>
              <section id="Relationships">
                <h2>
                  <a href="#Relationships">Relationships</a>
                </h2>
                <h3 id="Inherits-From">
                  <a href="#Inherits-From">Inherits From</a>
                </h3>
                <ul>
                  <li>
                    <a href="../baseclass/index.html">
                      <code>
                        Base<wbr>Class
                      </code>
                    </a>
                  </li>
                </ul>
              </section>
            </article>
            """)
        }
        
        do {
            let reference = try #require(context.documentationCache.reference(symbolID: "base-class-id"))
            let symbol = try #require(context.documentationCache[reference]?.semantic as? Symbol)
            
            var renderer = HTMLRenderer(reference: reference, context: context, goal: .richness, featureFlags: context.configuration.featureFlags)
            let pageInfo = renderer.renderSymbol(symbol)
            
            let html = try #require(pageInfo.content)
            let data = HTMLFormatter.format(html, options: .prettyPrint)
            let formattedHTML = String(decoding: data, as: UTF8.self)
            #expect(formattedHTML == """
            <article>
              <section>
                <nav id="breadcrumbs">
                  <ul>
                    <li>
                      <a href="../index.html">ModuleName</a>
                    </li>
                    <li>BaseClass</li>
                  </ul>
                </nav>
                <hgroup>
                  <p>Class</p>
                  <h1>
                    Base<wbr>Class
                  </h1>
                </hgroup>
              </section>
              <section id="Relationships">
                <h2>
                  <a href="#Relationships">Relationships</a>
                </h2>
                <h3 id="Inherited-By">
                  <a href="#Inherited-By">Inherited By</a>
                </h3>
                <ul>
                  <li>
                    <a href="../subclass/index.html">
                      <code>
                        Sub<wbr>Class
                      </code>
                    </a>
                  </li>
                </ul>
              </section>
            </article>
            """)
        }
    }
}
