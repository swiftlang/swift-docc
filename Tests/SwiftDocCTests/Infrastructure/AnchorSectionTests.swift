/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import Markdown
@testable import SymbolKit
@testable import SwiftDocC

class AnchorSectionTests: XCTestCase {
        
    func testResolvingArticleSubsections() throws {
        let (bundle, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
        
        // Verify the sub-sections of the article have been collected in the context
        [
            ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/TechnologyX/Article", fragment: "Article-Sub-Section", sourceLanguage: .swift),
            ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/TechnologyX/Article", fragment: "Article-Sub-Sub-Section", sourceLanguage: .swift),
        ]
        .forEach { sectionReference in
            XCTAssertTrue(context.nodeAnchorSections.keys.contains(sectionReference))
        }
        
        // Load the module page
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/CoolFramework", sourceLanguage: .swift)
        let entity = try context.entity(with: reference)
        
        // Extract the links from the discussion
        let discussion = try XCTUnwrap((entity.semantic as? Symbol)?.discussion)
        let linkList = try XCTUnwrap(discussion.content.mapFirst { markup -> UnorderedList? in
            return markup as? UnorderedList
        })
        let listItems = linkList.children.compactMap { markup -> ListItem? in
            return markup as? ListItem
        }
        let links = listItems.compactMap { item -> Link? in
            return item.children
                .mapFirst { markup -> Paragraph? in
                    return markup as? Paragraph
                }
                .flatMap { paragraph -> Link? in
                    return paragraph.children.mapFirst { markup -> Link? in
                        return markup as? Link
                    }
                }
        }
        
        guard links.count == 12 else {
            XCTFail("Did not resolve all links")
            return
        }
        
        // Verify the links have been resolved
        links[0...2].forEach { link in
            XCTAssertEqual(link.destination, "doc://org.swift.docc.example/documentation/TechnologyX/Article#Article-Sub-Section")
        }
        links[3...5].forEach { link in
            XCTAssertEqual(link.destination, "doc://org.swift.docc.example/documentation/TechnologyX/Article#Article-Sub-Sub-Section")
        }

        // Verify collecting section render references
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = try converter.convert(entity, at: nil)

        let sectionReference = try XCTUnwrap(renderNode.references["doc://org.swift.docc.example/documentation/TechnologyX/Article#Article-Sub-Section"] as? TopicRenderReference)
        XCTAssertEqual(sectionReference.title, "Article Sub-Section")
        XCTAssertEqual(sectionReference.url, "/documentation/technologyx/article#Article-Sub-Section")
    }

    func testResolvingSymbolSubsections() throws {
        let (bundle, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
        
        // Verify the sub-sections of the article have been collected in the context
        [
            ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/CoolFramework/CoolClass", fragment: "Symbol-Sub-Section", sourceLanguage: .swift),
            ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/CoolFramework/CoolClass", fragment: "Symbol-Sub-Sub-Section", sourceLanguage: .swift),
        ]
        .forEach { sectionReference in
            XCTAssertTrue(context.nodeAnchorSections.keys.contains(sectionReference))
        }
        
        // Load the module page
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/CoolFramework", sourceLanguage: .swift)
        let entity = try context.entity(with: reference)
        
        // Extract the links from the discussion
        let discussion = try XCTUnwrap((entity.semantic as? Symbol)?.discussion)
        let linkList = try XCTUnwrap(discussion.content.mapFirst { markup -> UnorderedList? in
            return markup as? UnorderedList
        })
        let listItems = linkList.children.compactMap { markup -> ListItem? in
            return markup as? ListItem
        }
        let links = listItems.compactMap { item -> Link? in
            return item.children
                .mapFirst { markup -> Paragraph? in
                    return markup as? Paragraph
                }
                .flatMap { paragraph -> Link? in
                    return paragraph.children.mapFirst { markup -> Link? in
                        return markup as? Link
                    }
                }
        }
        
        guard links.count == 12 else {
            XCTFail("Did not resolve all links")
            return
        }
        
        // Verify the links have been resolved
        links[6...8].forEach { link in
            XCTAssertEqual(link.destination, "doc://org.swift.docc.example/documentation/CoolFramework/CoolClass#Symbol-Sub-Section")
        }
        links[9...11].forEach { link in
            XCTAssertEqual(link.destination, "doc://org.swift.docc.example/documentation/CoolFramework/CoolClass#Symbol-Sub-Sub-Section")
        }

        // Verify collecting section render references
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = try converter.convert(entity, at: nil)

        let sectionReference = try XCTUnwrap(renderNode.references["doc://org.swift.docc.example/documentation/CoolFramework/CoolClass#Symbol-Sub-Section"] as? TopicRenderReference)
        XCTAssertEqual(sectionReference.title, "Symbol Sub-Section")
        XCTAssertEqual(sectionReference.url, "/documentation/coolframework/coolclass#Symbol-Sub-Section")
    }

    func testResolvingRootPageSubsections() throws {
        let (bundle, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
        
        // Verify the sub-sections of the article have been collected in the context
        [
            ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/CoolFramework", fragment: "Module-Sub-Section", sourceLanguage: .swift),
            ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/CoolFramework", fragment: "Module-Sub-Sub-Section", sourceLanguage: .swift),
        ]
        .forEach { sectionReference in
            XCTAssertTrue(context.nodeAnchorSections.keys.contains(sectionReference))
        }
        
        // Load the article page
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/TechnologyX/Article", sourceLanguage: .swift)
        let entity = try context.entity(with: reference)
        
        // Extract the links from the discussion
        let discussion = try XCTUnwrap((entity.semantic as? Article)?.discussion)
        let linkList = try XCTUnwrap(discussion.content.mapFirst { markup -> UnorderedList? in
            return markup as? UnorderedList
        })
        let listItems = linkList.children.compactMap { markup -> ListItem? in
            return markup as? ListItem
        }
        let links = listItems.compactMap { item -> Link? in
            return item.children
                .mapFirst { markup -> Paragraph? in
                    return markup as? Paragraph
                }
                .flatMap { paragraph -> Link? in
                    return paragraph.children.mapFirst { markup -> Link? in
                        return markup as? Link
                    }
                }
        }
        
        guard links.count == 6 else {
            XCTFail("Did not resolve all links")
            return
        }
        
        // Verify the links have been resolved
        links[0...2].forEach { link in
            XCTAssertEqual(link.destination, "doc://org.swift.docc.example/documentation/CoolFramework#Module-Sub-Section")
        }
        links[3...5].forEach { link in
            XCTAssertEqual(link.destination, "doc://org.swift.docc.example/documentation/CoolFramework#Module-Sub-Sub-Section")
        }

        // Verify collecting section render references
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = try converter.convert(entity, at: nil)

        let sectionReference = try XCTUnwrap(renderNode.references["doc://org.swift.docc.example/documentation/CoolFramework#Module-Sub-Section"] as? TopicRenderReference)
        XCTAssertEqual(sectionReference.title, "Module Sub-Section")
        XCTAssertEqual(sectionReference.url, "/documentation/coolframework#Module-Sub-Section")
    }
    
    func testWarnsWhenCuratingSections() throws {
        let (_, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
        
        // The module page has 3 section links in a Topics group,
        // the context should contain the three warnings about those links
        XCTAssertEqual(3,
            context.problems.filter({
                $0.diagnostic.identifier == "org.swift.docc.SectionCuration"
            }).count
        )
    }
}
