/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(FoundationXML)
// TODO: Consider other HTML rendering options as a future improvement (rdar://165755530)
import FoundationXML
import FoundationEssentials
#else
import Foundation
#endif

import Testing
import DocCHTML
import Markdown
import DocCCommon
import SymbolKit

struct MarkdownRenderer_PageElementsTests {
    @Test(arguments: RenderGoal.allCases)
    func renderingBreadcrumbs(goal: RenderGoal) {
        let elements = [
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/index.html")!,
                names: .single(.symbol("ModuleName")),
                subheadings: .single(.symbol([.init(text: "ModuleName", kind: .identifier)])),
                abstract: nil
            ),
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/Something/index.html")!,
                names: .languageSpecificSymbol([
                    .swift:      "Something",
                    .objectiveC: "TLASomething",
                ]),
                subheadings: .languageSpecificSymbol([
                    .swift: [
                        .init(text: "class ", kind: .decorator),
                        .init(text: "Something", kind: .identifier),
                    ],
                    .objectiveC: [
                        .init(text: "@interface ",  kind: .decorator),
                        .init(text: "TLASomething", kind: .identifier),
                    ],
                ]),
                abstract: nil
            ),
        ]
        let breadcrumbs = makeRenderer(goal: goal, elementsToReturn: elements).breadcrumbs(references: elements.map { $0.path }, currentPageNames: .single(.conceptual("ThisPage")))
        switch goal {
        case .richness:
            breadcrumbs.assertMatches(prettyFormatted: true, expectedXMLString: """
            <nav id="breadcrumbs">
              <ul>
                <li>
                  <a href="../../index.html">ModuleName</a>
                </li>
                <li>
                  <a href="../index.html">
                    <span class="swift-only">Something</span>
                    <span class="occ-only">TLASomething</span>
                  </a>
                </li>
                <li>ThisPage</li>
              </ul>
            </nav>
            """)
        case .conciseness:
            breadcrumbs.assertMatches(prettyFormatted: true, expectedXMLString: """
            <ul>
              <li>
                <a href="../../index.html">ModuleName</a>
              </li>
              <li>
                <a href="../index.html">Something</a>
              </li>
              <li>ThisPage</li>
            </ul>
            """)
        }
    }
    
    @Test(arguments: RenderGoal.allCases)
    func renderingAvailability(goal: RenderGoal) {
        let availability = makeRenderer(goal: goal).availability([
            .init(name: "First",  introduced: "1.2", deprecated: "3.4", isBeta: false),
            .init(name: "Second", introduced: "1.2.3",                  isBeta: false),
            .init(name: "Third",  introduced: "4.5",                    isBeta: true),
        ])
        switch goal {
        case .richness:
            availability.assertMatches(prettyFormatted: true, expectedXMLString: """
            <ul id="availability">
              <li aria-label="First 1.2–3.4, Introduced in First 1.2 and deprecated in First 3.4" class="deprecated" role="text" title="Introduced in First 1.2 and deprecated in First 3.4">First 1.2–3.4</li>
              <li aria-label="Second 1.2.3+, Available on 1.2.3 and later" role="text" title="Available on 1.2.3 and later">Second 1.2.3+</li>
              <li aria-label="Third 4.5+, Available on 4.5 and later" class="beta" role="text" title="Available on 4.5 and later">Third 4.5+</li>
            </ul>
            """)
        case .conciseness:
            availability.assertMatches(prettyFormatted: true, expectedXMLString: """
            <ul id="availability">
              <li>First 1.2–3.4</li>
              <li>Second 1.2.3+</li>
              <li>Third 4.5+</li>
            </ul>
            """)
        }
    }
    
    @Test(arguments: RenderGoal.allCases)
    func renderingSingleLanguageParameters(goal: RenderGoal) {
        let parameters = makeRenderer(goal: goal).parameters([
            .swift: [
                .init(name: "First", content: parseMarkup(string: "Some _formatted_ description with `code`")),
                .init(name: "Second", content: parseMarkup(string: """
                Some **other** _formatted_ description

                That spans two paragraphs
                """)),
            ]
        ])
        
        switch goal {
        case .richness:
            parameters.assertMatches(prettyFormatted: true, expectedXMLString: """
            <section id="Parameters">
              <h2>
                <a href="#Parameters">Parameters</a>
              </h2>
              <dl>
                <dt>First</dt>
                <dd>
                  <p>
                    Some <i>formatted</i> description with <code>code</code>
                  </p>
                </dd>
                <dt>Second</dt>
                <dd>
                  <p>
                    Some <b>other</b> <i>formatted</i> description</p>
                  <p>That spans two paragraphs</p>
                </dd>
              </dl>
            </section>
            """)
        case .conciseness:
            parameters.assertMatches(prettyFormatted: true, expectedXMLString: """
            <h2>Parameters</h2>
            <dl>
              <dt>First</dt>
              <dd>
                <p>Some <i>formatted</i>description with <code>code</code>
                </p>
              </dd>
              <dt>Second</dt>
              <dd>
                <p>
                  Some <b>other</b> <i>formatted</i> description</p>
                <p>That spans two paragraphs</p>
              </dd>
            </dl>
            """)
        }
    }
    
    @Test
    func renderingLanguageSpecificParameters() {
        let parameters = makeRenderer(goal: .richness).parameters([
            .swift: [
                .init(name: "FirstCommon", content: parseMarkup(string: "Available in both languages")),
                .init(name: "SwiftOnly", content: parseMarkup(string: "Only available in Swift")),
                .init(name: "SecondCommon", content: parseMarkup(string: "Also available in both languages")),
            ],
            .objectiveC: [
                .init(name: "FirstCommon", content: parseMarkup(string: "Available in both languages")),
                .init(name: "SecondCommon", content: parseMarkup(string: "Also available in both languages")),
                .init(name: "ObjectiveCOnly", content: parseMarkup(string: "Only available in Objective-C")),
            ],
        ])
        parameters.assertMatches(prettyFormatted: true, expectedXMLString: """
        <section id="Parameters">
          <h2>
            <a href="#Parameters">Parameters</a>
          </h2>
          <dl>
            <dt>FirstCommon</dt>
            <dd>
              <p>Available in both languages</p>
            </dd>
            <dt class="swift-only">SwiftOnly</dt>
            <dd class="swift-only">
              <p>Only available in Swift</p>
            </dd>
            <dt>SecondCommon</dt>
            <dd>
              <p>Also available in both languages</p>
            </dd>
            <dt class="occ-only">ObjectiveCOnly</dt>
            <dd class="occ-only">
              <p>Only available in Objective-C</p>
            </dd>
          </dl>
        </section>
        """)
    }
    
    @Test
    func renderingManyLanguageSpecificParameters() {
        let parameters = makeRenderer(goal: .richness).parameters([
            .swift: [
                .init(name: "First", content: parseMarkup(string: "Some description")),
            ],
            .objectiveC: [
                .init(name: "Second", content: parseMarkup(string: "Some description")),
            ],
            .data: [
                .init(name: "Third", content: parseMarkup(string: "Some description")),
            ],
        ])
        parameters.assertMatches(prettyFormatted: true, expectedXMLString: """
        <section id="Parameters">
          <h2>
            <a href="#Parameters">Parameters</a>
          </h2>
          <dl class="swift-only">
            <dt>First</dt>
            <dd>
              <p>Some description</p>
            </dd>
          </dl>
          <dl class="data-only">
            <dt>Third</dt>
            <dd>
              <p>Some description</p>
            </dd>
          </dl>
          <dl class="occ-only">
            <dt>Second</dt>
            <dd>
              <p>Some description</p>
            </dd>
          </dl>
        </section>
        """)
    }
    
    @Test(arguments: RenderGoal.allCases)
    func renderingSingleLanguageReturnSections(goal: RenderGoal) {
        let returns = makeRenderer(goal: goal).returns([
            .swift: parseMarkup(string: "First paragraph\n\nSecond paragraph")
        ])
        
        let commonHTML = """
        <p>First paragraph</p>
        <p>Second paragraph</p>
        """
        
        switch goal {
        case .richness:
            returns.assertMatches(prettyFormatted: true, expectedXMLString: """
            <section id="Return-Value">
            <h2>
              <a href="#Return-Value">Return Value</a>
            </h2>
            \(commonHTML)
            </section>
            """)
        case .conciseness:
            returns.assertMatches(prettyFormatted: true, expectedXMLString: """
            <h2>Return Value</h2>
            \(commonHTML)
            """)
        }
    }
    
    @Test(arguments: RenderGoal.allCases)
    func renderingLanguageSpecificReturnSections(goal: RenderGoal) {
        let returns = makeRenderer(goal: goal).returns([
            .swift:      parseMarkup(string: "First paragraph\n\nSecond paragraph"),
            .objectiveC: parseMarkup(string: "Other language's paragraph"),
        ])
        
        let commonHTML = """
        <p class="swift-only">First paragraph</p>
        <p class="swift-only">Second paragraph</p>
        <p class="occ-only">Other language’s paragraph</p>
        """
        
        switch goal {
        case .richness:
            returns.assertMatches(prettyFormatted: true, expectedXMLString: """
            <section id="Return-Value">
            <h2>
              <a href="#Return-Value">Return Value</a>
            </h2>
            \(commonHTML)
            </section>
            """)
        case .conciseness:
            returns.assertMatches(prettyFormatted: true, expectedXMLString: """
            <h2>Return Value</h2>
            \(commonHTML)
            """)
        }
    }

    @Test(arguments: RenderGoal.allCases)
    func renderingSwiftDeclaration(goal: RenderGoal) {
        let symbolPaths = [
            "first-parameter-symbol-id":  URL(string: "/documentation/ModuleName/FirstParameterValue/index.html")!,
            "second-parameter-symbol-id": URL(string: "/documentation/ModuleName/SecondParameterValue/index.html")!,
            "return-value-symbol-id":     URL(string: "/documentation/ModuleName/ReturnValue/index.html")!,
        ]
        
        let declaration = makeRenderer(goal: goal, pathsToReturn: symbolPaths).declaration([
            .swift:  [
                .init(kind: .keyword,           spelling: "func",        preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "doSomething", preciseIdentifier: nil),
                .init(kind: .text,              spelling: "(",           preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "with",        preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "first",       preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": ",          preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "FirstParameterValue", preciseIdentifier: "first-parameter-symbol-id"),
                .init(kind: .text,              spelling: ", ",          preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "and",         preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "second",      preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": ",          preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "SecondParameterValue", preciseIdentifier: "second-parameter-symbol-id"),
                .init(kind: .text,              spelling: ") ",          preciseIdentifier: nil),
                .init(kind: .keyword,           spelling: "throws",      preciseIdentifier: nil),
                .init(kind: .text,              spelling: " -> ",        preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "ReturnValue", preciseIdentifier: "return-value-symbol-id"),
            ]
        ])
        switch goal {
        case .richness:
            #expect(declaration.plainTextForTesting == """
            func doSomething(
                with first: FirstParameterValue,
                and second: SecondParameterValue
            ) throws -> ReturnValue
            """)
            
            declaration.assertMatches(prettyFormatted: true, expectedXMLString: """
            <pre id="declaration">
            <code>
              <span class="keyword">func</span>
               doSomething(
                  with <span class="internalParameter">first</span>
              : <a class="typeIdentifier" href="../../firstparametervalue/index.html">FirstParameterValue</a>
              ,
                  and <span class="internalParameter">second</span>
              : <a class="typeIdentifier" href="../../secondparametervalue/index.html">SecondParameterValue</a>
              
              ) <span class="keyword">throws</span>
               -&gt; <a class="typeIdentifier" href="../../returnvalue/index.html">ReturnValue</a>
            </code>
            </pre>
            """)
        case .conciseness:
            declaration.assertMatches(prettyFormatted: true, expectedXMLString: """
            <pre>
              <code>func doSomething(with first: FirstParameterValue, and second: SecondParameterValue) throws -&gt; ReturnValue</code>
            </pre>
            """)
        }
    }
    
    @Test
    func prettyPrintsSwiftDeclarations() {
        let symbolPaths = [
            "first-parameter-symbol-id":  URL(string: "/documentation/ModuleName/FirstParameterValue/index.html")!,
            "second-parameter-symbol-id": URL(string: "/documentation/ModuleName/SecondParameterValue/index.html")!,
            "return-value-symbol-id":     URL(string: "/documentation/ModuleName/ReturnValue/index.html")!,
        ]
        
        // func withUnsafeTemporaryAllocation<T, R, E>(of type: T.Type, capacity: Int, _ body: (UnsafeMutableBufferPointer<T>) throws(E) -> R) throws(E) -> R where E : Error, T : ~Copyable, R : ~Copyable
        let functionDeclaration = makeRenderer(goal: .richness, pathsToReturn: symbolPaths).declaration([
            .swift:  [
                .init(kind: .keyword,           spelling: "func",           preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",              preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "withUnsafeTemporaryAllocation", preciseIdentifier: nil),
                .init(kind: .text,              spelling: "<",              preciseIdentifier: nil),
                .init(kind: .genericParameter,  spelling: "T",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: ", ",             preciseIdentifier: nil),
                .init(kind: .genericParameter,  spelling: "R",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: ", ",             preciseIdentifier: nil),
                .init(kind: .genericParameter,  spelling: "E",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: ">(",             preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "of",             preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",              preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "type",           preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": ",             preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "T",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: ".Type, ",        preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "capacity",       preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": ",             preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "Int",            preciseIdentifier: "s:Si"),
                .init(kind: .text,              spelling: ", ",             preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "_",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",              preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "body",           preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": (",            preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "UnsafeMutableBufferPointer", preciseIdentifier: "s:Sr"),
                .init(kind: .text,              spelling: "<",              preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "T",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: ">) ",            preciseIdentifier: nil),
                .init(kind: .keyword,           spelling: "throws",         preciseIdentifier: nil),
                .init(kind: .text,              spelling: "(",              preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "E",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: ") -> ",          preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "R",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: ") ",             preciseIdentifier: nil),
                .init(kind: .keyword,           spelling: "throws",         preciseIdentifier: nil),
                .init(kind: .text,              spelling: "(",              preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "E",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: ") -> ",          preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "R",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",              preciseIdentifier: nil),
                .init(kind: .keyword,           spelling: "where",          preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",              preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "E",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: " : ",            preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "Error",          preciseIdentifier: "s:s5ErrorP"),
                .init(kind: .text,              spelling: ", ",             preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "T",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: " : ~Copyable, ", preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "R",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: " : ~Copyable",   preciseIdentifier: nil),
            ]
        ])
        
        #expect(functionDeclaration.plainTextForTesting == """
        func withUnsafeTemporaryAllocation<T, R, E>(
            of type: T.Type,
            capacity: Int,
            _ body: (UnsafeMutableBufferPointer<T>) throws(E) -> R
        ) throws(E) -> R where E : Error, T : ~Copyable, R : ~Copyable
        """)
        
        functionDeclaration.assertMatches(prettyFormatted: true, expectedXMLString: """
        <pre id="declaration">
        <code>
          <span class="keyword">func</span>
           withUnsafeTemporaryAllocation&lt;T, R, E&gt;(
              of <span class="internalParameter">type</span>
          : <span class="typeIdentifier">T</span>
          .Type,
              capacity: <span class="typeIdentifier">Int</span>
          ,
              _ <span class="internalParameter">body</span>
          : (<span class="typeIdentifier">UnsafeMutableBufferPointer</span>
          &lt;<span class="typeIdentifier">T</span>
          &gt;) <span class="keyword">throws</span>
          (<span class="typeIdentifier">E</span>
          ) -&gt; <span class="typeIdentifier">R</span>
          
          ) <span class="keyword">throws</span>
          (<span class="typeIdentifier">E</span>
          ) -&gt; <span class="typeIdentifier">R</span>
           <span class="keyword">where</span>
           <span class="typeIdentifier">E</span>
           : <span class="typeIdentifier">Error</span>
          , <span class="typeIdentifier">T</span>
           : ~Copyable, <span class="typeIdentifier">R</span>
           : ~Copyable</code>
        </pre>
        """)
        
        // @attached(accessor) @attached(peer, names: prefixed(`$`)) macro TaskLocal()
        let macroDeclaration = makeRenderer(goal: .richness, pathsToReturn: symbolPaths).declaration([
            .swift:  [
                .init(kind: .attribute,  spelling: "@attached",    preciseIdentifier: nil),
                .init(kind: .text,       spelling: "(accessor) ",  preciseIdentifier: nil),
                .init(kind: .attribute,  spelling: "@attached",    preciseIdentifier: nil),
                .init(kind: .text,       spelling: "(peer, names: prefixed(`$`)) ", preciseIdentifier: nil),
                .init(kind: .keyword,    spelling: "macro",        preciseIdentifier: nil),
                .init(kind: .text,       spelling: " ",            preciseIdentifier: nil),
                .init(kind: .identifier, spelling: "TaskLocal",    preciseIdentifier: nil),
                .init(kind: .text,       spelling: "()",           preciseIdentifier: nil),
            ]
        ])
        
        #expect(macroDeclaration.plainTextForTesting == """
        @attached(accessor) @attached(peer, names: prefixed(`$`))
        macro TaskLocal()
        """)
        
        macroDeclaration.assertMatches(prettyFormatted: true, expectedXMLString: """
        <pre id="declaration">
        <code>
          <span class="attribute">@attached</span>
          (accessor) <span class="attribute">@attached</span>
          (peer, names: prefixed(`$`))
          <span class="keyword">macro</span>
           TaskLocal()</code>
        </pre>
        """)

        // @freestanding(declaration) macro warning(_ message: String)
        let macroDeclaration2 = makeRenderer(goal: .richness, pathsToReturn: symbolPaths).declaration([
            .swift:  [
                .init(kind: .attribute,         spelling: "@freestanding",  preciseIdentifier: nil),
                .init(kind: .text,              spelling: "(declaration) ", preciseIdentifier: nil),
                .init(kind: .keyword,           spelling: "macro",          preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",              preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "warning",        preciseIdentifier: nil),
                .init(kind: .text,              spelling: "(",              preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "_",              preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",              preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "message",        preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": ",             preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "String",         preciseIdentifier: "s:preciseIdentifierS"),
                .init(kind: .text,              spelling: ")",              preciseIdentifier: nil),
            ]
        ])
        
        #expect(macroDeclaration2.plainTextForTesting == """
        @freestanding(declaration)
        macro warning(_ message: String)
        """)
        
        macroDeclaration2.assertMatches(prettyFormatted: true, expectedXMLString: """
        <pre id="declaration">
        <code>
          <span class="attribute">@freestanding</span>
          (declaration)
          <span class="keyword">macro</span>
           warning(_ <span class="internalParameter">message</span>
          : <span class="typeIdentifier">String</span>
          )</code>
        </pre>
        """)
    }
    
    @Test(arguments: RenderGoal.allCases)
    func renderingLanguageSpecificDeclarations(goal: RenderGoal) {
        let symbolPaths = [
            "first-parameter-symbol-id":  URL(string: "/documentation/ModuleName/FirstParameterValue/index.html")!,
            "second-parameter-symbol-id": URL(string: "/documentation/ModuleName/SecondParameterValue/index.html")!,
            "return-value-symbol-id":     URL(string: "/documentation/ModuleName/ReturnValue/index.html")!,
            "error-parameter-symbol-id":  URL(string: "/documentation/Foundation/NSError/index.html")!,
        ]
        
        let declaration = makeRenderer(goal: goal, pathsToReturn: symbolPaths).declaration([
            .swift:  [
                .init(kind: .keyword,           spelling: "func",        preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "doSomething", preciseIdentifier: nil),
                .init(kind: .text,              spelling: "(",           preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "with",        preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "first",       preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": ",          preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "FirstParameterValue", preciseIdentifier: "first-parameter-symbol-id"),
                .init(kind: .text,              spelling: ", ",          preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "and",         preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "second",      preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": ",          preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "SecondParameterValue", preciseIdentifier: "second-parameter-symbol-id"),
                .init(kind: .text,              spelling: ") ",          preciseIdentifier: nil),
                .init(kind: .keyword,           spelling: "throws",      preciseIdentifier: nil),
                .init(kind: .text,              spelling: " -> ",        preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "ReturnValue", preciseIdentifier: "return-value-symbol-id"),
            ],
            
            .objectiveC:  [
                .init(kind: .text,              spelling: "- (",         preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "ReturnValue", preciseIdentifier: "return-value-symbol-id"),
                .init(kind: .text,              spelling: ") ",          preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "doSomethingWithFirst", preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": (",         preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "FirstParameterValue", preciseIdentifier: "first-parameter-symbol-id"),
                .init(kind: .text,              spelling: ") ",          preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "first",       preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "andSecond",   preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": (",         preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "SecondParameterValue", preciseIdentifier: "second-parameter-symbol-id"),
                .init(kind: .text,              spelling: ") ",          preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "second",      preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "error",       preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": (",         preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "NSError",     preciseIdentifier: "error-parameter-symbol-id"),
                .init(kind: .text,              spelling: " **) ",       preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "error",       preciseIdentifier: nil),
                .init(kind: .text,              spelling: ";",           preciseIdentifier: nil),
            ]
        ])
        switch goal {
        case .richness:
            #expect(declaration.childCount == 2)
            #expect((declaration.children ?? []).first?.plainTextForTesting == """
            func doSomething(
                with first: FirstParameterValue,
                and second: SecondParameterValue
            ) throws -> ReturnValue
            """)
            #expect((declaration.children ?? []).last?.plainTextForTesting == """
            - (ReturnValue) doSomethingWithFirst: (FirstParameterValue) first
                                       andSecond: (SecondParameterValue) second
                                           error: (NSError **) error;
            """)
            
            declaration.assertMatches(prettyFormatted: true, expectedXMLString: """
            <pre id="declaration">
            <code class="swift-only">
              <span class="keyword">func</span>
               doSomething(
                  with <span class="internalParameter">first</span>
              : <a class="typeIdentifier" href="../../firstparametervalue/index.html">FirstParameterValue</a>
              ,
                  and <span class="internalParameter">second</span>
              : <a class="typeIdentifier" href="../../secondparametervalue/index.html">SecondParameterValue</a>
              
              ) <span class="keyword">throws</span>
               -&gt; <a class="typeIdentifier" href="../../returnvalue/index.html">ReturnValue</a>
            </code>
            <code class="occ-only">- (<a class="typeIdentifier" href="../../returnvalue/index.html">ReturnValue</a>
              ) doSomethingWithFirst: (<a class="typeIdentifier" href="../../firstparametervalue/index.html">FirstParameterValue</a>
              ) <span class="internalParameter">first</span>
              
                                     andSecond: (<a class="typeIdentifier" href="../../secondparametervalue/index.html">SecondParameterValue</a>
              ) <span class="internalParameter">second</span>
              
                                         error: (<a class="typeIdentifier" href="../../../foundation/nserror/index.html">NSError</a>
               **) <span class="internalParameter">error</span>
              ;</code>
            </pre>
            """)
            
        case .conciseness:
            declaration.assertMatches(prettyFormatted: true, expectedXMLString: """
            <pre>
              <code>func doSomething(with first: FirstParameterValue, and second: SecondParameterValue) throws -&gt; ReturnValue</code>
            </pre>
            """)
        }
    }
    
    @Test(arguments: RenderGoal.allCases, ["Topics", "See Also"])
    func renderingSingleLanguageGroupedSectionsWithMultiLanguageLinks(goal: RenderGoal, expectedGroupTitle: String) {
        let elements = [
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/SomeClass/index.html")!,
                names: .languageSpecificSymbol([
                    .swift:      "SomeClass",
                    .objectiveC: "TLASomeClass",
                ]),
                subheadings: .languageSpecificSymbol([
                    .swift: [
                        .init(text: "class ",    kind: .decorator),
                        .init(text: "SomeClass", kind: .identifier),
                    ],
                    .objectiveC: [
                        .init(text: "@interface ",  kind: .decorator),
                        .init(text: "TLASomeClass", kind: .identifier),
                    ],
                ]),
                abstract: parseMarkup(string: "Some _formatted_ description of this class").first as? Paragraph
            ),
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/SomeArticle/index.html")!,
                names: .single(.conceptual("Some Article")),
                subheadings: .single(.conceptual("Some Article")),
                abstract: parseMarkup(string: "Some **formatted** description of this _article_.").first as? Paragraph
            ),
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/SomeClass/someMethod(with:and:)/index.html")!,
                names: .languageSpecificSymbol([
                    .swift:      "someMethod(with:and:)",
                    .objectiveC: "someMethodWithFirst:andSecond:",
                ]),
                subheadings: .languageSpecificSymbol([
                    .swift: [
                        .init(text: "func ",      kind: .decorator),
                        .init(text: "someMethod", kind: .identifier),
                        .init(text: "(",          kind: .decorator),
                        .init(text: "with",       kind: .identifier),
                        .init(text: ": Int, ",    kind: .decorator),
                        .init(text: "and",        kind: .identifier),
                        .init(text: ": String)",  kind: .decorator),
                    ],
                    .objectiveC: [
                        .init(text: "- ", kind: .decorator),
                        .init(text: "someMethodWithFirst:andSecond:", kind: .identifier),
                    ],
                ]),
                abstract: nil
            ),
        ]
        
        let renderer = makeRenderer(goal: goal, elementsToReturn: elements)
        let expectedSectionID = expectedGroupTitle.replacingOccurrences(of: " ", with: "-")
        let groupedSection = renderer.groupedSection(named: expectedGroupTitle, groups: [
            .swift: [
                .init(title: "Group title", content: parseMarkup(string: "Some description of this group"), references: [
                    URL(string: "/documentation/ModuleName/SomeClass/index.html")!,
                    URL(string: "/documentation/ModuleName/SomeArticle/index.html")!,
                    URL(string: "/documentation/ModuleName/SomeClass/someMethod(with:and:)/index.html")!,
                ])
            ]
        ])
        
        switch goal {
        case .richness:
            groupedSection.assertMatches(prettyFormatted: true, expectedXMLString: """
            <section id="\(expectedSectionID)">
              <h2>
                <a href="#\(expectedSectionID)">\(expectedGroupTitle)</a>
              </h2>
              <h3 id="Group-title">
                <a href="#Group-title">Group title</a>
              </h3>
              <p>Some description of this group</p>
              <ul>
                <li>
                  <a href="../../someclass/index.html">
                    <code class="swift-only">
                      <span class="decorator">class </span>
                      <span class="identifier">Some<wbr/>
                        Class</span>
                    </code>
                    <code class="occ-only">
                      <span class="decorator">@interface </span>
                      <span class="identifier">TLASome<wbr/>
                          Class</span>
                    </code>
                  </a>
                  <p>Some <i>formatted</i> description of this class</p>
                </li>
                <li>
                  <a href="../../somearticle/index.html">
                    <p>Some Article</p>
                  </a>
                  <p>Some <b>formatted</b>description of this <i>article</i>.</p>
                </li>
                <li>
                  <a href="../../someclass/somemethod(with:and:)/index.html">
                    <code class="swift-only">
                      <span class="decorator">func </span>
                      <span class="identifier">some<wbr/>
                        Method</span>
                      <span class="decorator">(</span>
                      <span class="identifier">with</span>
                      <span class="decorator">:<wbr/>
                         Int, </span>
                      <span class="identifier">and</span>
                      <span class="decorator">:<wbr/>
                         String)</span>
                    </code>
                    <code class="occ-only">
                      <span class="decorator">- </span>
                      <span class="identifier">some<wbr/>
                        Method<wbr/>
                        With<wbr/>
                        First:<wbr/>
                        and<wbr/>
                        Second:</span>
                    </code>
                  </a>
                </li>
            </ul>
            </section>
            """)
        case .conciseness:
            groupedSection.assertMatches(prettyFormatted: true, expectedXMLString: """
            <h2>\(expectedGroupTitle)</h2>
            <h3>Group title</h3>
            <p>Some description of this group</p>
            <ul>
            <li>
              <a href="../../someclass/index.html">
                <code>class SomeClass</code>
              </a>
              <p>Some <i>formatted</i> description of this class</p>
            </li>
            <li>
              <a href="../../somearticle/index.html">
                <p>Some Article</p>
              </a>
              <p>Some <b>formatted</b> description of this <i>article</i>.</p>
            </li>
            <li>
              <a href="../../someclass/somemethod(with:and:)/index.html">
                <code>func someMethod(with: Int, and: String)</code>
              </a>
            </li>
            </ul>
            """)
        }
    }
    
    @Test(arguments: RenderGoal.allCases)
    func testEmptyDiscussionSection(goal: RenderGoal) {
        let renderer = makeRenderer(goal: goal)
        let discussion = renderer.discussion([], fallbackSectionName: "Fallback")
        #expect(discussion.isEmpty)
    }
    
    @Test(arguments: RenderGoal.allCases)
    func testDiscussionSectionWithoutHeading(goal: RenderGoal) {
        let renderer = makeRenderer(goal: goal)
        let discussion = renderer.discussion(parseMarkup(string: """
        First paragraph
        
        Second paragraph
        """), fallbackSectionName: "Fallback")
        
        let commonHTML = """
        <p>First paragraph</p>
        <p>Second paragraph</p>
        """
        
        switch goal {
        case .richness:
            discussion.assertMatches(prettyFormatted: true, expectedXMLString: """
            <section id="Fallback">
            <h2>
              <a href="#Fallback">Fallback</a>
            </h2>
            \(commonHTML)
            </section>
            """)
        case .conciseness:
            discussion.assertMatches(prettyFormatted: true, expectedXMLString: """
            <h2>Fallback</h2>
            \(commonHTML)
            """)
        }
    }
    
    @Test(arguments: RenderGoal.allCases)
    func testDiscussionSectionWithHeading(goal: RenderGoal) {
        let renderer = makeRenderer(goal: goal)
        let discussion = renderer.discussion(parseMarkup(string: """
        ## Some Heading
        
        First paragraph
        
        Second paragraph
        """), fallbackSectionName: "Fallback")
        
        let commonHTML = """
        <p>First paragraph</p>
        <p>Second paragraph</p>
        """
        
        switch goal {
        case .richness:
            discussion.assertMatches(prettyFormatted: true, expectedXMLString: """
            <section id="Some-Heading">
            <h2>
              <a href="#Some-Heading">Some Heading</a>
            </h2>
            \(commonHTML)
            </section>
            """)
        case .conciseness:
            discussion.assertMatches(prettyFormatted: true, expectedXMLString: """
            <h2>Some Heading</h2>
            \(commonHTML)
            """)
        }
    }

    @Test(arguments: RenderGoal.allCases)
    func testDiscussionSectionWithCard(goal: RenderGoal) {
        let renderer = makeRenderer(goal: goal)
        let discussion = renderer.discussion(parseMarkup(string: """
        ## Some Heading

        @Card {
          ### This is a head heading

          This is a head paragraph

          ---

          ### This is a body heading

          This is a body paragraph
        }
        """), fallbackSectionName: "Fallback")

        switch goal {
        case .richness:
            discussion.assertMatches(prettyFormatted: true, expectedXMLString: """
            <section id="Some-Heading">
              <h2>
                <a href="#Some-Heading">Some Heading</a>
              </h2>
              <article class="card">
                <header class="card-head">
                  <h3 id="This-is-a-head-heading">
                    <a href="#This-is-a-head-heading">This is a head heading</a>
                  </h3>
                  <p>This is a head paragraph</p>
                </header>
                <div class="card-body">
                  <h3 id="This-is-a-body-heading">
                    <a href="#This-is-a-body-heading">This is a body heading</a>
                  </h3>
                  <p>This is a body paragraph</p>
                </div>
              </article>
            </section>
            """)
        default:
            _ = goal
        }
    }
    
    // MARK: -
    
    private func makeRenderer(
        goal: RenderGoal,
        elementsToReturn: [LinkedElement] = [],
        pathsToReturn: [String: URL] = [:],
        assetsToReturn: [String: LinkedAsset] = [:],
        fallbackLinkTextsToReturn: [String: String] = [:]
    ) -> MarkdownRenderer<some LinkProvider> {
        let path = URL(string: "/documentation/ModuleName/Something/ThisPage/index.html")!
        
        var elementsByURL = [
            path: LinkedElement(
                path: path,
                names: .single( .symbol("ThisPage") ),
                subheadings: .single( .symbol([
                    .init(text: "class ", kind: .decorator),
                    .init(text: "ThisPage", kind: .identifier),
                ])),
                abstract: nil
            )
        ]
        for element in elementsToReturn {
            elementsByURL[element.path] = element
        }
        
        return MarkdownRenderer(path: path, goal: goal, linkProvider: MultiValueLinkProvider(
            elementsToReturn: elementsByURL,
            pathsToReturn: pathsToReturn,
            assetsToReturn: assetsToReturn,
            fallbackLinkTextsToReturn: fallbackLinkTextsToReturn
        ))
    }
    
    private func parseMarkup(string: String) -> [any Markup] {
        let document = Document(parsing: string, options: [.parseBlockDirectives, .parseSymbolLinks])
        return Array(document.children)
    }
}

struct MultiValueLinkProvider: LinkProvider {
    var elementsToReturn: [URL: LinkedElement]
    func element(for path: URL) -> LinkedElement? {
        elementsToReturn[path]
    }
    
    var pathsToReturn: [String: URL]
    func pathForSymbolID(_ usr: String) -> URL? {
        pathsToReturn[usr]
    }
    
    var assetsToReturn: [String: LinkedAsset]
    func assetNamed(_ assetName: String) -> LinkedAsset? {
        assetsToReturn[assetName]
    }
    
    var fallbackLinkTextsToReturn: [String: String]
    func fallbackLinkText(linkString: String) -> String {
        fallbackLinkTextsToReturn[linkString] ?? linkString
    }
}

extension RenderGoal: CaseIterable {
    static var allCases: [RenderGoal] {
        [.richness, .conciseness]
    }
}

private extension XMLNode {
    var plainTextForTesting: String {
        var result = ""
        for child in self.children ?? [] {
            if child.kind == .text {
                result.append(child.stringValue ?? "")
            } else {
                result.append(child.plainTextForTesting)
            }
        }
        return result
    }
}
