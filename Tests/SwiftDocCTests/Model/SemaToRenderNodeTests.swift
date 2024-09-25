/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@_spi(ExternalLinks) @testable import SwiftDocC
import Markdown
import XCTest
import SymbolKit
import SwiftDocCTestUtilities

class SemaToRenderNodeTests: XCTestCase {
    func testCompileTutorial() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift))
        
        guard let tutorialDirective = node.markup as? BlockDirective else {
            XCTFail("Unexpected document structure, tutorial not found as first child.")
            return
        }
        
        var problems = [Problem]()
        guard let tutorial = Tutorial(from: tutorialDirective, source: nil, for: bundle, in: context, problems: &problems) else {
            XCTFail("Couldn't create tutorial from markup: \(problems)")
            return
        }
        
        XCTAssertEqual(problems.count, 1, "Found problems \(DiagnosticConsoleWriter.formattedDescription(for: problems)) analyzing tutorial markup")
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(tutorial) as! RenderNode
        
        XCTAssertEqual(renderNode.variants?.flatMap(\.traits), [.interfaceLanguage("swift")])
        
        do {
            // Comment content should never make it into the render node JSON.
            let encoder = JSONEncoder()
            let data = try encoder.encode(renderNode)
            let jsonString = String(decoding: data, as: UTF8.self)
            XCTAssertFalse(jsonString.contains("This is a comment"))
        }
        
        XCTAssertEqual(renderNode.identifier, ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift))
        
        XCTAssertEqual(renderNode.sections.count, 4)
        guard let intro = renderNode.sections.first as? IntroRenderSection else {
            XCTFail("Unexpected first section.")
            return
        }
        XCTAssertEqual(intro.title, "Basic Augmented Reality App")
        XCTAssertEqual(intro.estimatedTimeInMinutes, 20)
        XCTAssertEqual(intro.xcodeRequirement?.identifier, "Xcode X.Y Beta Z")
        XCTAssertEqual(intro.chapter, "Chapter 1")
        // TODO: XcodeRequirement check
        
        guard let tutorialSections = renderNode.sections[1] as? TutorialSectionsRenderSection else {
            XCTFail("Unexpected second section.")
            return
        }
        
        XCTAssertEqual(tutorialSections.tasks.count, 3)
        
        do {
            let contentSection = tutorialSections.tasks[0].contentSection[0]
            guard case let .contentAndMedia(section) = contentSection,
                case let .aside(noteAside) = section.content[1],
                  noteAside.style == .init(rawValue: "Note"),
                case let .aside(importantAside) = section.content[2],
                  importantAside.style == .init(rawValue: "Important") else {
                    XCTFail("Expected `Note` and `Important` asides")
                    return
            }
            let noteContent = noteAside.content
            let importantContent = importantAside.content
            
            XCTAssertEqual(1, noteContent.count)
            guard case let .paragraph(notePara)? = noteContent.first,
                notePara.inlineContent.count == 1,
                case let .text(noteText)? = notePara.inlineContent.first else {
                    XCTFail("Expected single paragraph with single inline text at the start of a 'note' aside")
                    return
            }
            XCTAssertEqual("This is a note.", noteText)
            
            XCTAssertEqual(1, importantContent.count)
            guard case let .paragraph(importantPara)? = importantContent.first,
                importantPara.inlineContent.count == 1,
                case let .text(importantText)? = importantPara.inlineContent.first else {
                    XCTFail("Expected single paragraph with single inline text at the start of a 'important' aside")
                    return
            }
            XCTAssertEqual("This is important.", importantText)
        }
        
        let stepsSection = tutorialSections.tasks[0].stepsSection
        
        guard case .step(let s) = stepsSection[2] else {
            XCTFail("Expected step")
            return
        }
        let caption = s.caption
        let step1Media = s.media
        let step1Code = s.code
        let step1RuntimePreview = s.runtimePreview
        
        guard case .paragraph(let captionPara)? = caption.first, case .text(let captionText)? = captionPara.inlineContent.first else {
            XCTFail("Expected step caption")
            return
        }
        XCTAssertEqual(captionText, "This is a step caption.")
        
        XCTAssertNil(step1Media)
        XCTAssertEqual(step1Code?.identifier, "helloworld1.swift")
        XCTAssertEqual(step1RuntimePreview?.identifier, "step.png")
        
        guard let assessments = renderNode.sections[2] as? TutorialAssessmentsRenderSection else {
            XCTFail("Unexpected third section.")
            return
        }
        
        XCTAssertEqual(assessments.anchor, "Check-Your-Understanding")
        XCTAssertEqual(assessments.assessments.count, 2)
        guard let firstAssessment = assessments.assessments.first else {
            XCTFail("Missing first assessment.")
            return
        }
        XCTAssertEqual(firstAssessment.choices.count, 3)
        guard case RenderBlockContent.paragraph(let firstChoiceContentParagraph)? = firstAssessment.choices.first?.content.first else {
            XCTFail("Missing paragraph of content for first choice of first assessment.")
            return
        }
        XCTAssertEqual(firstChoiceContentParagraph.inlineContent, [RenderInlineContent.codeVoice(code: "anchor.hitTest(view)")])
        guard case RenderBlockContent.paragraph(let firstChoiceJustificationContentParagraph)? = firstAssessment.choices.first?.justification?.first else {
            XCTFail("Missing paragraph of justification for first choice of first assessment.")
            return
        }
        XCTAssertEqual(firstChoiceJustificationContentParagraph.inlineContent, [RenderInlineContent.text("This is correct because it is.")])
        
        guard case RenderBlockContent.paragraph(let lastChoiceContentParagraph)? = firstAssessment.choices.last?.content.first else {
            XCTFail("Missing paragraph of content for last choice of first assessment.")
            return
        }
        XCTAssertEqual(lastChoiceContentParagraph.inlineContent, [RenderInlineContent.codeVoice(code: "anchor.intersects(view)")])
        guard case RenderBlockContent.paragraph(let lastChoiceJustificationContentParagraph)? = firstAssessment.choices.last?.justification?.first else {
            XCTFail("Missing paragraph of justification for last choice of first assessment.")
            return
        }
        XCTAssertEqual(lastChoiceJustificationContentParagraph.inlineContent, [RenderInlineContent.text("This is incorrect because it is.")])
        
        XCTAssertEqual(renderNode.references.count, 33)
        guard let simpleImageReference = renderNode.references["figure1"] as? ImageReference else {
            XCTFail("Missing simple image reference")
            return
        }
        
        guard let imageReference = renderNode.references["figure1.png"] as? ImageReference else {
            XCTFail("Missing image reference")
            return
        }
        
        guard let introVideoReference = renderNode.references["introvideo.mp4"] as? VideoReference else {
            XCTFail("Missing intro video reference")
            return
        }
        
        guard let introPosterReference = renderNode.references["introposter.png"] as? ImageReference else {
            XCTFail("Missing intro poster reference")
            return
        }
        
        guard let stepImageReference = renderNode.references["step.png"] as? ImageReference else {
            XCTFail("Missing step image reference")
            return
        }
        XCTAssertEqual("step", stepImageReference.altText)
        
        guard let titled2upImageReference = renderNode.references["titled2up.png"] as? ImageReference else {
            XCTFail("Missing titled2up image reference")
            return
        }
        
        guard let xcodeRequirementReference = renderNode.references["Xcode X.Y Beta Z"] as? XcodeRequirementReference else {
            XCTFail("Missing Xcode requirement reference")
            return
        }
        
        if let testTutorialFirstSectionReference = renderNode.references["doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB"] as? TopicRenderReference {
            XCTAssertEqual(testTutorialFirstSectionReference.type, .section)
        } else {
            XCTFail("Missing reference to doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB")
        }
        
        if let testTutorial2FirstSectionReference = renderNode.references["doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2#Create-a-New-AR-Project"] as? TopicRenderReference {
            XCTAssertEqual(testTutorial2FirstSectionReference.type, .section)
        } else {
            XCTFail("Missing reference to doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2#Create-a-New-AR-Project")
        }
        
        if let testTutorialSecondSectionReference = renderNode.references["doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection"] as? TopicRenderReference {
            XCTAssertEqual(testTutorialSecondSectionReference.type, .section)
        } else {
            XCTFail("Missing reference to doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection")
        }
        
        if !renderNode.references.values.contains(where: {
            ($0 as? LinkReference)?.url == "https://swift.org/documentation/"
        }) {
            XCTFail("Missing external reference to https://swift.org/documentation/")
        }
        
        do {
            // Images with @2x or @3x should have their dimensions reduced by their respective scale factors (rdar://49228514).
            guard let somethingAt2xReference = renderNode.references["something.png"] as? ImageReference  else {
                XCTFail("Missing something.png image reference")
                return
            }
            
            XCTAssertEqual(1, somethingAt2xReference.asset.variants.count)
            XCTAssertEqual(.double, somethingAt2xReference.asset.variants.keys.first?.displayScale)
        }
        
        guard let downloadReference = renderNode.references["project.zip"] as? DownloadReference else {
            XCTFail("Missing download reference")
            return
        }
        
        XCTAssertEqual(simpleImageReference.identifier.identifier, "figure1")
        XCTAssertEqual(imageReference.identifier.identifier, "figure1.png")
                
        XCTAssertEqual(imageReference.altText, "figure1")
        XCTAssertEqual(stepImageReference.identifier.identifier, "step.png")
        XCTAssertEqual(stepImageReference.altText, "step")
        XCTAssertEqual(titled2upImageReference.identifier.identifier, "titled2up.png")
        
        XCTAssertEqual(introVideoReference.identifier.identifier, "introvideo.mp4")
        XCTAssertEqual(introPosterReference.identifier.identifier, "introposter.png")
        
        // Test "figure1.png" for light/dark variants (traits)
        XCTAssertNotNil(imageReference.asset.variants.first(where: { traits in
            return traits.key.userInterfaceStyle == .some(.light)
        }))
        XCTAssertNotNil(imageReference.asset.variants.first(where: { traits in
            return traits.key.userInterfaceStyle == .some(.dark)
        }))

        // Test "introvideo.mp4" for light/dark variants (traits)
        XCTAssertNotNil(introVideoReference.asset.variants.first(where: { traits in
            return traits.key.userInterfaceStyle == .some(.light)
        }))
        XCTAssertNotNil(introVideoReference.asset.variants.first(where: { traits in
            return traits.key.userInterfaceStyle == .some(.dark)
        }))

        // Verify that light mode only asset doesn't have a dark variant.
        XCTAssertNil(stepImageReference.asset.variants.first(where: { traits in
            return traits.key.userInterfaceStyle == .some(.dark)
        }))
        
        
        guard let helloworld1FileReference = renderNode.references["helloworld1.swift"] as? FileReference else {
            XCTFail("Missing helloworld1.swift")
            return
        }
        
        XCTAssertEqual(helloworld1FileReference.content, [
            "func foo() {",
            "",
            "}",
        ])
        
        XCTAssertEqual(helloworld1FileReference.identifier.identifier, "helloworld1.swift")
        XCTAssertEqual(helloworld1FileReference.fileName, "MyCode.swift")
        XCTAssertEqual(helloworld1FileReference.fileType, "swift")
        XCTAssertEqual(helloworld1FileReference.syntax, "swift")
        XCTAssertEqual(helloworld1FileReference.highlights.count, 0)
        
        guard let helloworld2FileReference = renderNode.references["helloworld2.swift"] as? FileReference else {
            XCTFail("Missing helloworld2.swift")
            return
        }
        
        XCTAssertEqual(helloworld2FileReference.content, [
            "func foo() {",
            "  print(\"1\")",
            "  print(\"2\")",
            "}",
        ])
        
        XCTAssertEqual(helloworld2FileReference.identifier.identifier, "helloworld2.swift")
        XCTAssertEqual(helloworld2FileReference.fileName, "MyCode.swift")
        XCTAssertEqual(helloworld2FileReference.fileType, "swift")
        XCTAssertEqual(helloworld2FileReference.syntax, "swift")
        XCTAssertEqual(helloworld2FileReference.highlights.map { $0.line }, [2, 3])
        
        guard let helloworld3FileReference = renderNode.references["helloworld3.swift"] as? FileReference else {
            XCTFail("Missing helloworld3.swift")
            return
        }
        
        XCTAssertEqual(helloworld3FileReference.content, [
            "func foo() {",
            "  print(\"1\")",
            "  print(\"2\")",
            "  print(\"3\")",
            "  print(\"4\")",
            "}",
        ])
        
        XCTAssertEqual(helloworld3FileReference.identifier.identifier, "helloworld3.swift")
        XCTAssertEqual(helloworld3FileReference.fileName, "MyCode.swift")
        XCTAssertEqual(helloworld3FileReference.fileType, "swift")
        XCTAssertEqual(helloworld3FileReference.syntax, "swift")
        XCTAssertEqual(helloworld3FileReference.highlights.map { $0.line }, [4, 5])
        
        guard let helloworld4FileReference = renderNode.references["helloworld4.swift"] as? FileReference else {
            XCTFail("Missing helloworld4.swift")
            return
        }
        
        XCTAssertEqual(helloworld4FileReference.content, [
            "func foo() {",
            "  print(\"1\")",
            "  print(\"2\")",
            "  print(\"3\")",
            "  print(\"4\")",
            "  print(\"5\")",
            "}",
        ])
        
        XCTAssertEqual(helloworld4FileReference.identifier.identifier, "helloworld4.swift")
        XCTAssertEqual(helloworld4FileReference.fileName, "MyCode.swift")
        XCTAssertEqual(helloworld4FileReference.fileType, "swift")
        XCTAssertEqual(helloworld4FileReference.syntax, "swift")
        XCTAssertEqual(helloworld4FileReference.highlights.map { $0.line }, [6])
        
        XCTAssertNotNil(renderNode.hierarchy)
        
        guard let callToAction = renderNode.sections.last as? CallToActionSection else {
            XCTFail("Expected call to action")
            return
        }
        
        XCTAssertEqual(callToAction.title, "Making an Augmented Reality App")
        
        XCTAssertFalse(callToAction.abstract.isEmpty)
        
        guard case .text(let text)? = callToAction.abstract.first else {
            XCTFail("Unexpected content in call to action")
            return
        }
        
        XCTAssertEqual(text, "This is an abstract for the intro.")
        XCTAssertEqual(callToAction.media?.identifier, "introposter2.png")
        
        guard case .reference(let identifier, _, let overridingTitle, let overridingTitleInlineContent) = callToAction.action else {
            XCTFail("Unexpected action")
            return
        }
        
        XCTAssertEqual(identifier.identifier, "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle")
        XCTAssertEqual(overridingTitle, "Read article")
        XCTAssertEqual(overridingTitleInlineContent, [.text("Read article")])
        
        XCTAssertEqual(xcodeRequirementReference.title, "Xcode X.Y Beta Z")
        XCTAssertEqual(xcodeRequirementReference.url.absoluteString, "https://www.example.com/download")
        
        XCTAssertEqual(downloadReference.identifier.identifier, "project.zip")
        XCTAssertEqual(downloadReference.checksum, "2521bb27db3f8b72f8f2bb9e3a33698b9c5c72a5d7862f5b209794099e1cf0acaab7d8a47760b001cb508b5c4f3d7cf7f8ce1c32679b3fde223e63b5a1e7e509")
        
        // This topic link didn't resolve, so it should not be in the references dictionary.
        // Additionally, the link should've been rendered inactive, i.e. a text element instead of a link.
        XCTAssertNil(renderNode.references["doc://org.swift.docc.example/ThisWillNeverResolve"])
        if case let .some(.contentAndMedia(contentAndMedia)) = renderNode.sections.compactMap({ $0 as? TutorialSectionsRenderSection }).first?
            .tasks.first?
            .contentSection.first
        {
            XCTAssertTrue(contentAndMedia.content.firstParagraph.contains(.text("doc:ThisWillNeverResolve")))
            XCTAssertFalse(contentAndMedia.content.firstParagraph.contains(.reference(identifier: .init("doc:ThisWillNeverResolve"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)))
        } else {
            XCTFail("Couldn't find first paragraph of first tutorial section")
        }
        
        XCTAssertNil(renderNode.metadata.roleHeading)
        XCTAssertEqual(renderNode.metadata.title, "Basic Augmented Reality App")
        
        XCTAssertNil(
            renderNode.metadata.sourceFileURI,
            "Unexpectedly found sourceFileURI: the documentation converter was not configured to emit this information."
        )
        
        XCTAssertNil(
            renderNode.metadata.symbolAccessLevel,
            "Unexpectedly found symbolAccessLevel: the documentation converter was not configured to emit this information."
        )
    }
    
    func testTutorialBackgroundComesFromImageOrVideoPoster() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        func assertTutorialWithPath(_ tutorialPath: String, hasBackground backgroundIdentifier: String) throws {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: tutorialPath, sourceLanguage: .swift))
            
            guard let tutorialDirective = node.markup as? BlockDirective else {
                XCTFail("Unexpected document structure, tutorial not found as first child.")
                return
            }
            
            var problems = [Problem]()
            guard let tutorial = Tutorial(from: tutorialDirective, source: nil, for: bundle, in: context, problems: &problems) else {
                XCTFail("Couldn't create tutorial from markup: \(problems)")
                return
            }
            
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(tutorial) as! RenderNode
            let intro = renderNode.sections.compactMap { $0 as? IntroRenderSection }.first!
            XCTAssertEqual(RenderReferenceIdentifier(backgroundIdentifier), intro.backgroundImage)
        }
        
        // @Video
        try assertTutorialWithPath("/tutorials/Test-Bundle/TestTutorial", hasBackground: "introposter.png")
        
        // @Image
        try assertTutorialWithPath("/tutorials/Test-Bundle/TestTutorial2", hasBackground: "introposter2.png")
    }
    
    func testCompileTutorialArticle() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/TestTutorialArticle", sourceLanguage: .swift))
        
        let article = node.semantic as! TutorialArticle
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(article) as! RenderNode
        
        XCTAssertEqual(renderNode.variants?.flatMap(\.traits), [.interfaceLanguage("swift")])

        guard renderNode.sections.count == 3 else {
            XCTFail("Unexpected section count.")
            return
        }
        
        XCTAssertEqual(renderNode.sections[0].kind, .hero)
        
        guard let intro = renderNode.sections[0] as? IntroRenderSection else {
            XCTFail("Expected intro to have type '\(IntroRenderSection.self)'")
            return
        }
        XCTAssertNotNil(intro.image)
        XCTAssertNil(intro.video)
        
        XCTAssertEqual(renderNode.sections[1].kind, .articleBody)
        
        guard let articleBody = renderNode.sections[1] as? TutorialArticleSection else {
            XCTFail("Expected article body to have type '\(TutorialArticleSection.self)'")
            return
        }
        
        XCTAssertEqual(articleBody.content.count, 8)
        
        XCTAssertEqual(renderNode.sections[2].kind, .callToAction)
        
        XCTAssertEqual(renderNode.navigatorChildren(for: nil).count, 0)
        
        XCTAssertNil(renderNode.metadata.roleHeading)
        XCTAssertEqual(renderNode.metadata.title, "Making an Augmented Reality App")

        XCTAssertNil(
            renderNode.metadata.sourceFileURI,
            "Unexpectedly found sourceFileURI: the documentation converter was not configured to emit this information."
        )
        
        XCTAssertNil(
            renderNode.metadata.symbolAccessLevel,
            "Unexpectedly found symbolAccessLevel: the documentation converter was not configured to emit this information."
        )
    }

    private func makeListItem(reference: String) -> RenderBlockContent.ListItem {
        return RenderBlockContent.ListItem(content: [
            RenderBlockContent.paragraph(.init(inlineContent: [
                .reference(identifier: .init(reference), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil),
            ])),
        ])
    }
    
    func testCompileOverviewWithNoVolumes() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        try assertCompileOverviewWithNoVolumes(bundle: bundle, context: context)
    }
    
    func testCompileOverviewWithEmptyChapter() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            try """
            @Tutorials(name: "Technology X") {
               @Intro(title: "Technology X") {

                  You'll learn all about Technology X.

                  @Video(source: introvideo.mp4, poster: introposter.png )
                  @Image(source: intro.png, alt: intro )
               }

               @Chapter(name: "Chapter 1") {

                  This is a `Chapter`.

                  @Image(source: figure1.png, alt: "Figure 1" )

                  @TutorialReference(tutorial: "doc:TestTutorial" )
                  @TutorialReference(tutorial: "doc:/TestTutorial" )
                  @TutorialReference(tutorial: "doc:TestTutorialArticle" )
                  @TutorialReference(tutorial: "doc:TestTutorial2" )
                  @TutorialReference(tutorial: "doc:TutorialMediaWithSpaces" )
               }
               
               @Chapter(name: "Empty Chapter") {

                  This is a `Chapter` with no tutorial references.

                  @Image(source: figure1.png, alt: "Figure 1")
               }

               @Resources {
                  Find the tools and a comprehensive set of resources for creating AR experiences on iOS.

                  @Documentation(destination: "https://www.example.com/documentation/technology") {
                     Browse and search detailed API documentation.

                     - <doc://org.swift.docc.example/TestTutorial>
                     - <doc://org.swift.docc.example/TestTutorial2>
                  }

                  @SampleCode(destination: "https://www.example.com/documentation/technology") {
                     Browse and search detailed sample code.

                     - <doc://org.swift.docc.example/TestTutorial>
                     - <doc://org.swift.docc.example/TestTutorial2>
                  }

                  @Downloads(destination: "https://www.example.com/download") {
                     Download Xcode 10, which includes the latest tools and SDKs.
                  }

                  @Videos(destination: "https://www.example.com/videos") {
                     See AR presentation from WWDC and other events.
                  }

                  @Forums(destination: "https://www.example.com/forums") {
                     Discuss AR with Apple engineers and other developers.
                  }
               }
            }
            """.write(to: url.appendingPathComponent("TestOverview.tutorial"), atomically: true, encoding: .utf8)
        }
        
        try assertCompileOverviewWithNoVolumes(
            bundle: bundle,
            context: context,
            // Expect one problem for the empty chapter.
            expectedProblemsCount: 1
        )
    }
    
    private func assertCompileOverviewWithNoVolumes(bundle: DocumentationBundle, context: DocumentationContext, expectedProblemsCount: Int = 0) throws {
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/TestOverview", sourceLanguage: .swift))
        
        guard let technologyDirective = node.markup as? BlockDirective else {
            XCTFail("Unexpected document structure, tutorial not found as first child.")
            return
        }
        
        var problems = [Problem]()
        guard let technology = Technology(from: technologyDirective, source: nil, for: bundle, in: context, problems: &problems) else {
            XCTFail("Couldn't create tutorial from markup: \(problems)")
            return
        }
        
        // Verify we emit a diagnostic for the chapter with no tutorial references.
        XCTAssertEqual(problems.count, expectedProblemsCount, "Found problems \(DiagnosticConsoleWriter.formattedDescription(for: problems)) analyzing tutorial markup")
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(technology) as! RenderNode
        
        XCTAssertEqual(renderNode.variants?.flatMap(\.traits), [.interfaceLanguage("swift")])
        
        XCTAssertEqual(renderNode.sections.count, 3, "Unexpected section count")
        
        guard let intro = renderNode.sections[0] as? IntroRenderSection else {
            XCTFail("Unexpected section of kind \(renderNode.sections[0].kind)")
            return
        }
        
        XCTAssertEqual(intro.action, RenderInlineContent.reference(identifier: RenderReferenceIdentifier("doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial"),
                                                                  isActive: true,
                                                                  overridingTitle: "Get started",
                                                                  overridingTitleInlineContent: [.text("Get started")]))

        guard let volume = renderNode.sections[1] as? VolumeRenderSection else {
            XCTFail("Unexpected section of kind \(renderNode.sections[1].kind)")
            return
        }
        
        XCTAssertNil(volume.name, "Expected anonymous volume because no Volumes where explicitly declared in source")
        XCTAssertNil(volume.image, "Expected anonymous volume because no Volumes where explicitly declared in source")
        XCTAssertEqual(volume.content, [], "Expected anonymous volume because no Volumes where explicitly declared in source")
        XCTAssertEqual(volume.chapters.count, 1)
        
        let chapter = volume.chapters[0]
        XCTAssertEqual(chapter.name, "Chapter 1")
        XCTAssertNotNil(chapter.content)
        XCTAssertEqual(chapter.tutorials.count, 5)
        XCTAssertEqual(chapter.image, RenderReferenceIdentifier("figure1.png"))
        
        XCTAssertEqual(renderNode.references.count, 13)
        
        XCTAssertEqual(renderNode.navigatorChildren(for: nil).count, 1)
        
        guard let introImageReference = renderNode.references["intro.png"] as? ImageReference else {
            XCTFail("Missing intro.png image reference")
            return
        }
        
        guard let introVideoReference = renderNode.references["introvideo.mp4"] as? VideoReference else {
            XCTFail("Missing introvideo.mp4 image reference")
            return
        }
        
        guard let introPosterImageReference = renderNode.references["introposter.png"] as? ImageReference else {
            XCTFail("Missing introposter.png image reference")
            return
        }
        
        XCTAssertEqual(introImageReference.identifier.identifier, "intro.png")
        XCTAssertEqual(introVideoReference.identifier.identifier, "introvideo.mp4")
        XCTAssertEqual(introPosterImageReference.identifier.identifier, "introposter.png")
        
        guard let firstTutorialReference = renderNode.references["doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial"] as? TopicRenderReference else {
            XCTFail("Missing first tutorial reference")
            return
        }
        XCTAssertEqual(firstTutorialReference.url, "/tutorials/test-bundle/testtutorial")
        XCTAssertFalse(firstTutorialReference.abstract.isEmpty)
        XCTAssertEqual(firstTutorialReference.estimatedTime, "20min")
        
        renderNode.references.compactMap { $0.value as? TopicRenderReference } .forEach {
            XCTAssertFalse($0.abstract.isEmpty)
        }
        
        XCTAssertEqual(renderNode.metadata.estimatedTime, "1hr 20min")
        
        guard let resources = renderNode.sections[2] as? ResourcesRenderSection else {
            XCTFail("Unexpected section kind.")
            return
        }
        let tiles = resources.tiles
        XCTAssertEqual(resources.tiles.count, 5)
        
        XCTAssertEqual(tiles[0].title, "Documentation")
        guard case .unorderedList(let tile0List) = tiles[0].content[1] else {
            XCTFail()
            return
        }
        let tile0Items = tile0List.items
        XCTAssertEqual(tile0Items.count, 2)
        XCTAssertEqual(tile0Items[0], makeListItem(reference: "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial"))
        XCTAssertEqual(tile0Items[1], makeListItem(reference: "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2"))
        
        XCTAssertEqual(tiles[1].title, "Sample Code")
        guard case .unorderedList(let tile1List) = tiles[1].content[1] else {
            XCTFail()
            return
        }
        let tile1Items = tile1List.items
        XCTAssertEqual(tile1Items.count, 2)
        XCTAssertEqual(tile1Items[0], makeListItem(reference: "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial"))
        XCTAssertEqual(tile1Items[1], makeListItem(reference: "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2"))
        
        XCTAssertEqual(tiles[2].title, "Xcode and SDKs")
        guard case .paragraph(let tile2Paragraph) = tiles[2].content[0] else {
            XCTFail()
            return
        }
        XCTAssertEqual(tile2Paragraph.inlineContent, [RenderInlineContent.text("Download Xcode 10, which includes the latest tools and SDKs.")])
        
        XCTAssertEqual(tiles[3].title, "Videos")
        guard case .paragraph(let tile3Paragraph) = tiles[3].content[0] else {
            XCTFail()
            return
        }
        XCTAssertEqual(tile3Paragraph.inlineContent, [RenderInlineContent.text("See AR presentation from WWDC and other events.")])
        
        guard case .paragraph(let tile4Paragraph) = tiles[4].content[0] else {
            XCTFail()
            return
        }
        XCTAssertEqual(tile4Paragraph.inlineContent, [RenderInlineContent.text("Discuss AR with Apple engineers and other developers.")])

        XCTAssertEqual(renderNode.metadata.title, "Technology X")
        
        XCTAssertNil(
            renderNode.metadata.sourceFileURI,
            "Unexpectedly found sourceFileURI: the documentation converter was not configured to emit this information."
        )
        
        XCTAssertNil(
            renderNode.metadata.symbolAccessLevel,
            "Unexpectedly found symbolAccessLevel: the documentation converter was not configured to emit this information."
        )
    }
    
    func testCompileOverviewWithVolumes() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
            let overviewURL = root.appendingPathComponent("TestOverview.tutorial")
            let text = """
            @Tutorials(name: "Technology X") {
               @Intro(title: "Technology X") {

                  You'll learn all about Technology X.

                  @Video(source: introvideo.mp4, poster: introposter.png)
                  @Image(source: intro.png, alt: intro)
               }

               @Volume(name: "Volume 1") {

                 This is a `Volume`.

                 @Image(source: figure1.png, alt: "Figure 1")

                 @Chapter(name: "Chapter 1") {

                    This is a `Chapter`.

                    @Image(source: figure1.png, alt: "Figure 1")

                    @TutorialReference(tutorial: "doc:TestTutorial")
                 }
               }

               @Volume(name: "Volume 2") {

                 This is a `Volume`.

                 @Image(source: figure1.png, alt: "Figure 1")

                 @Chapter(name: "Chapter A") {

                    This is a `Chapter`.

                    @Image(source: figure1.png, alt: "Figure 1")

                    @TutorialReference(tutorial: "doc:TestTutorialArticle")
                 }

                 @Chapter(name: "Chapter B") {

                    This is a `Chapter`.

                    @Image(source: figure1.png, alt: "Figure 1")

                    @TutorialReference(tutorial: "doc:TestTutorialArticle")
                    @TutorialReference(tutorial: "doc:TestTutorial2")
                    @TutorialReference(tutorial: "doc:TutorialMediaWithSpaces")
                 }
               }

               @Resources {
                  Find the tools and a comprehensive set of resources for creating AR experiences on iOS.
               
                  @Documentation(destination: "https://www.example.com/documentation/technology") {
                     Browse and search detailed API documentation.
               
                     - <doc://org.swift.docc.example/TestTutorial>
                     - <doc://org.swift.docc.example/TestTutorial2>
                  }
               
                  @SampleCode(destination: "https://www.example.com/documentation/technology") {
                     Browse and search detailed sample code.
               
                     - <doc://org.swift.docc.example/TestTutorial>
                     - <doc://org.swift.docc.example/TestTutorial2>
                  }
               
                  @Downloads(destination: "https://www.example.com/download") {
                     Download Xcode 10, which includes the latest tools and SDKs.
                  }
                
                  @Videos(destination: "https://www.example.com/videos") {
                     See AR presentation from WWDC and other events.
                  }
                
                  @Forums(destination: "https://www.example.com/forums") {
                     Discuss AR with Apple engineers and other developers.
                  }
               }
            }
            """
            try text.write(to: overviewURL, atomically: true, encoding: .utf8)
        }
    
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/TestOverview", sourceLanguage: .swift))
        
        guard let technologyDirective = node.markup as? BlockDirective else {
            XCTFail("Unexpected document structure, tutorial not found as first child.")
            return
        }
        
        var problems = [Problem]()
        guard let technology = Technology(from: technologyDirective, source: nil, for: bundle, in: context, problems: &problems) else {
            XCTFail("Couldn't create tutorial from markup: \(problems)")
            return
        }
        
        XCTAssertEqual(problems.count, 0, "Found problems \(DiagnosticConsoleWriter.formattedDescription(for: problems)) analyzing tutorial markup")
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(technology) as! RenderNode

        XCTAssertEqual(renderNode.sections.count, 4, "Unexpected section count")
        
        XCTAssertEqual(renderNode.sections[0].kind, .hero)
        
        guard let firstVolume = renderNode.sections[1] as? VolumeRenderSection else {
            XCTFail("Unexpected section of kind \(renderNode.sections[1].kind)")
            return
        }
        
        XCTAssertEqual(renderNode.references.count, 13)
        
        XCTAssertEqual(firstVolume.name, "Volume 1")
        XCTAssertEqual(firstVolume.image, RenderReferenceIdentifier("figure1.png"))
        XCTAssert(firstVolume.content?.isEmpty == false)
        XCTAssertEqual(firstVolume.chapters.count, 1)
        XCTAssertEqual(firstVolume.chapters[0].tutorials, [RenderReferenceIdentifier("doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial")])

        let volume1Chapter1 = firstVolume.chapters[0]
        XCTAssertEqual(volume1Chapter1.name, "Chapter 1")
        XCTAssertNotNil(volume1Chapter1.content)
        XCTAssertEqual(volume1Chapter1.tutorials, [RenderReferenceIdentifier("doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial")])
        XCTAssertEqual(volume1Chapter1.image, RenderReferenceIdentifier("figure1.png"))
        
        guard let secondVolume = renderNode.sections[2] as? VolumeRenderSection else {
            XCTFail("Unexpected section of kind \(renderNode.sections[2].kind)")
            return
        }

        XCTAssertEqual(secondVolume.name, "Volume 2")
        XCTAssertEqual(secondVolume.image, RenderReferenceIdentifier("figure1.png"))
        XCTAssert(secondVolume.content?.isEmpty == false)
        XCTAssertEqual(secondVolume.chapters.count, 2)
        XCTAssertEqual(secondVolume.chapters[0].tutorials, [RenderReferenceIdentifier("doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle")])
        
        let volume2Chapter1 = secondVolume.chapters[0]
        XCTAssertEqual(volume2Chapter1.name, "Chapter A")
        XCTAssertNotNil(volume2Chapter1.content)
        XCTAssertEqual(volume2Chapter1.tutorials, [RenderReferenceIdentifier("doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle")])
        XCTAssertEqual(volume2Chapter1.image, RenderReferenceIdentifier("figure1.png"))
        
        let volume2Chapter2 = secondVolume.chapters[1]
        XCTAssertEqual(volume2Chapter2.name, "Chapter B")
        XCTAssertNotNil(volume2Chapter2.content)
        XCTAssertEqual(volume2Chapter2.tutorials, [
            RenderReferenceIdentifier("doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle"),
            RenderReferenceIdentifier("doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2"),
            RenderReferenceIdentifier("doc://org.swift.docc.example/tutorials/Test-Bundle/TutorialMediaWithSpaces"),
        ])
        XCTAssertEqual(volume2Chapter2.image, RenderReferenceIdentifier("figure1.png"))
        
        XCTAssertEqual(renderNode.references.count, 13)
        
        XCTAssertEqual(renderNode.navigatorChildren(for: nil).count, 3, "Expected three chapters as children.")
        
        guard let introImageReference = renderNode.references["intro.png"] as? ImageReference else {
            XCTFail("Missing intro.png image reference")
            return
        }
        
        guard let introVideoReference = renderNode.references["introvideo.mp4"] as? VideoReference else {
            XCTFail("Missing introvideo.mp4 image reference")
            return
        }
        
        guard let introPosterImageReference = renderNode.references["introposter.png"] as? ImageReference else {
            XCTFail("Missing introposter.png image reference")
            return
        }
        
        XCTAssertEqual(introImageReference.identifier.identifier, "intro.png")
        XCTAssertEqual(introVideoReference.identifier.identifier, "introvideo.mp4")
        XCTAssertEqual(introPosterImageReference.identifier.identifier, "introposter.png")
        
        guard let firstTutorialReference = renderNode.references["doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial"] as? TopicRenderReference else {
            XCTFail("Missing first tutorial reference")
            return
        }
        XCTAssertEqual(firstTutorialReference.url, "/tutorials/test-bundle/testtutorial")
        XCTAssertFalse(firstTutorialReference.abstract.isEmpty)
        XCTAssertEqual(firstTutorialReference.estimatedTime, "20min")
        
        renderNode.references.compactMap { $0.value as? TopicRenderReference } .forEach {
            XCTAssertFalse($0.abstract.isEmpty)
        }

        XCTAssertEqual(renderNode.metadata.estimatedTime, "1hr 20min")

        XCTAssertEqual(renderNode.metadata.title, "Technology X")
        
        XCTAssertNil(
            renderNode.metadata.sourceFileURI,
            "Unexpectedly found sourceFileURI: the documentation converter was not configured to emit this information."
        )
        
        XCTAssertNil(
            renderNode.metadata.symbolAccessLevel,
            "Unexpectedly found symbolAccessLevel: the documentation converter was not configured to emit this information."
        )
    }
    
    func testCompileSymbol() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            // Remove the SideClass sub heading to match the expectations of this test
            let graphURL = url.appendingPathComponent("sidekit.symbols.json")
            var graph = try JSONDecoder().decode(SymbolGraph.self, from: try Data(contentsOf: graphURL))
            
            graph.symbols = graph.symbols.mapValues({ symbol -> SymbolGraph.Symbol in
                guard symbol.identifier.precise == "s:7SideKit0A5ClassC" else { return symbol }
                var symbol = symbol
                symbol.names.subHeading = nil
                return symbol
            })
            try JSONEncoder().encode(graph).write(to: graphURL)
        }
        
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyProtocol", sourceLanguage: .swift))
        
        // Verify that `MyProtocol` the symbol is loaded in the topic graph, but the `MyProtocol` sidecar article was removed.
        let matches = context.knownPages.filter({ reference -> Bool in
            return reference.path.contains("MyProtocol")
        })
        
        // Verify the sidecar article was merged successfully into the symbol
        XCTAssertEqual(matches.count, 1)
        guard matches.count == 1 else { return }
        
        XCTAssertNotEqual(try context.entity(with: matches[0]).kind, .article)
        
        // Compile docs and verify contents
        
        let symbol = node.semantic as! Symbol
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(symbol) as! RenderNode
        guard renderNode.primaryContentSections.count == 4 else {
            XCTFail("Unexpected primary section count.")
            return
        }

        // Verify the language variant is present
        XCTAssertEqual(renderNode.variants?.count, 1)
        
        guard let languageTrait = renderNode.variants?.first?.traits.first(where: { trait -> Bool in
            if case RenderNode.Variant.Trait.interfaceLanguage = trait {
                return true
            }
            return false
        }) else {
            XCTFail("Language trait was not found")
            return
        }
        
        // This condition is always true
        if case RenderNode.Variant.Trait.interfaceLanguage(let language) = languageTrait {
            XCTAssertEqual(language, "swift")
        }
        
        XCTAssertEqual(renderNode.variants?.first?.paths.first, "/documentation/mykit/myprotocol")
        
        // Declarations are always first primary section.
        guard let declarations = renderNode.primaryContentSections[0] as? DeclarationsRenderSection else {
            XCTFail("Could not find declarations primary section")
            return
        }
        XCTAssertEqual(declarations.kind, RenderSectionKind.declarations)
        
        guard declarations.declarations.count == 1 else {
            XCTFail("Could not find declaration section")
            return
        }
        
        XCTAssertEqual(declarations.declarations[0].platforms, [PlatformName(operatingSystemName: "ios")])
        XCTAssertEqual(declarations.declarations[0].tokens.count, 5)
        XCTAssertEqual(declarations.declarations[0].tokens.map { $0.text }.joined(), "protocol MyProtocol : Hashable")
        XCTAssertEqual(declarations.declarations[0].languages?.first, "swift")
        
        // Discussion section is always last.
        guard let content = renderNode.primaryContentSections[3] as? ContentRenderSection else {
            XCTFail("Could not find content primary section")
            return
        }
        XCTAssertEqual(content.kind, RenderSectionKind.content)
        
        let discussionParagraphPrefixes = content.content.paragraphText
        
        XCTAssertEqual(discussionParagraphPrefixes, [
            "Further discussion.",
            "Exercise links to symbols: relative ",
            "Exercise unresolved symbols: unresolved ",
            "Exercise known unresolvable symbols: know unresolvable ",
            "Exercise external references: ",
        ])
        
        XCTAssertEqual(renderNode.abstract, [
            SwiftDocC.RenderInlineContent.text("An abstract of a protocol using a "),
            SwiftDocC.RenderInlineContent.codeVoice(code: "String"),
            SwiftDocC.RenderInlineContent.text(" id value."),
        ])
        
        XCTAssertTrue(renderNode.defaultImplementationsSections.isEmpty)
        
        guard renderNode.relationshipSections.count == 2 else {
            XCTFail("MyProtocol should have exactly 2 relationships")
            return
        }
        
        XCTAssertEqual(renderNode.relationshipSections[0].identifiers, ["doc://org.swift.docc.example/5Foundation0A5NSCodableP"])
        XCTAssertEqual(renderNode.relationshipSections[0].type, "inheritsFrom")
        
        XCTAssertEqual(renderNode.relationshipSections[1].identifiers,
                       [
                        "doc://org.swift.docc.example/documentation/MyKit/MyClass",
                        "doc://org.swift.docc.example/documentation/SideKit/SideClass",
                       ]
        )
        XCTAssertEqual(renderNode.relationshipSections[1].type, "conformingTypes")
        
        guard renderNode.topicSections.count == 1 else {
            XCTFail("MyProtocol should have exactly 1 topic group")
            return
        }

        // Test all identifiers have been resolved to the ``MyClass`` symbol
        XCTAssertEqual(renderNode.topicSections[0].title, "Task Group Exercising Symbol Links")
        XCTAssertEqual(renderNode.topicSections[0].abstract?.map{ RenderBlockContent.paragraph(.init(inlineContent: [$0])) }.paragraphText.joined(), "Task Group abstract text.")
        
        guard let discussion = renderNode.topicSections[0].discussion as? ContentRenderSection else {
            XCTFail("Could not find group discussion")
            return
        }
        XCTAssertEqual(discussion.kind, RenderSectionKind.content)
        
        // Test childrenRelationships are handled correctly
        let children = renderNode.navigatorChildren(for: nil)
        XCTAssertEqual(children.count, renderNode.topicSections.count)
        XCTAssertEqual(children.first?.name, "Task Group Exercising Symbol Links")
        XCTAssertEqual(children.first?.references.count, 3)
        
        let groupDiscussionParagraphPrefixes = discussion.content.paragraphText
        
        // Check the text content of the discussion
        XCTAssertEqual(groupDiscussionParagraphPrefixes, [
            "Task Group Discussion paragraph 1.",
            "Task Group Discussion paragraph 2.",
            "Task Group Discussion paragraph 3.",
        ])

        // Check the code sample in the discussion
        XCTAssertTrue(discussion.content.last.map { block -> Bool in
            switch block {
            case .codeListing(let l):
                return l.syntax == "swift" && l.code.first == "struct MyClass : MyProtocol"
            default: return false
            }
        } ?? false)
        
        XCTAssertEqual(renderNode.topicSections[0].identifiers.count, 3)
        XCTAssertTrue(renderNode.topicSections[0].identifiers.allSatisfy({ identifier -> Bool in
            return identifier == "doc://org.swift.docc.example/documentation/MyKit/MyClass"
        }))
        
        guard renderNode.seeAlsoSections.count == 2 else {
            XCTFail("MyProtocol should have exactly 2 see also groups")
            return
        }

        // Test all identifiers have been resolved to the ``MyClass`` symbol
        XCTAssertEqual(renderNode.seeAlsoSections[0].title, "Related Documentation")
        XCTAssertEqual(renderNode.seeAlsoSections[0].abstract?.map{ RenderBlockContent.paragraph(.init(inlineContent: [$0])) }.paragraphText.joined(), "Further Reading abstract text.")
        XCTAssertNil(renderNode.seeAlsoSections[0].discussion)
        guard renderNode.seeAlsoSections[0].identifiers.count == 5 else {
            XCTFail("The amount of identifiers in See Also was not expected")
            return
        }
        XCTAssertTrue(Array(renderNode.seeAlsoSections[0].identifiers.prefix(3)).allSatisfy({ identifier -> Bool in
            return identifier == "doc://org.swift.docc.example/documentation/MyKit/MyClass"
        }))
        
        // Test markdown link with title in See Also
        do {
            let linkIdentifier = renderNode.seeAlsoSections[0].identifiers[3]
            guard let linkReference = renderNode.references[linkIdentifier] else {
                XCTFail("Link reference not found")
                return
            }
            XCTAssertEqual(linkReference.type.rawValue, "link")
            XCTAssertEqual((linkReference as? LinkReference)?.title, "Example!")
            XCTAssertEqual((linkReference as? LinkReference)?.titleInlineContent, [.text("Example!")])
            XCTAssertEqual((linkReference as? LinkReference)?.url, "https://www.example.com")
        }
        
        // Test markdown link without title in See Also
        do {
            let linkIdentifier = renderNode.seeAlsoSections[0].identifiers[4]
            guard let linkReference = renderNode.references[linkIdentifier] else {
                XCTFail("Link reference not found")
                return
            }
            XCTAssertEqual(linkReference.type.rawValue, "link")
            XCTAssertEqual((linkReference as? LinkReference)?.title, "https://www.example.com/page")
            XCTAssertEqual((linkReference as? LinkReference)?.titleInlineContent, [.text("https://www.example.com/page")])
            XCTAssertEqual((linkReference as? LinkReference)?.url, "https://www.example.com/page")
        }
        
        // Check that an unresolvable reference has been rendered with its fallback name
        XCTAssertEqual("Foundation.NSCodable", (renderNode.references["doc://org.swift.docc.example/5Foundation0A5NSCodableP"] as? UnresolvedRenderReference)?.title)
        
        // Check that an unresolvable reference with no fallback name has been ignored.
        // This relationship is defined in the mykit-iOS.json symbol graph but it's not resolvable.
        // {
        //  "source" : "s:5MyKit0A5ProtocolP",
        //  "target" : "s:5Foundation0A5EarhartP",
        //  "kind" : "conformsTo",
        // },
        XCTAssertNil(renderNode.references.first(where: { (key, value) -> Bool in
            return key.contains("Earhart") || value.identifier.identifier.contains("Earhart")
        }))
        
        // Verify a correct task group display name
        guard let topicReferenceMyClass = renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyClass"] as? TopicRenderReference else {
            XCTFail("Render reference doc://org.swift.docc.example/documentation/MyKit/MyClass was not found")
            return
        }
        
        XCTAssertEqual(topicReferenceMyClass.fragments?.map { $0.text }, ["class", " ", "MyClass"])

        // Verify missing display name
        guard let topicReferenceSideClass = renderNode.references["doc://org.swift.docc.example/documentation/SideKit/SideClass"] as? TopicRenderReference else {
            XCTFail("Render reference doc://org.swift.docc.example/documentation/SideKit/SideClass was not found")
            return
        }
        
        XCTAssertNil(topicReferenceSideClass.fragments)
        
        XCTAssertNil(
            renderNode.metadata.sourceFileURI,
            "Unexpectedly found sourceFileURI: the documentation converter was not configured to emit this information."
        )
        
        XCTAssertNil(
            renderNode.metadata.symbolAccessLevel,
            "Unexpectedly found symbolAccessLevel: the documentation converter was not configured to emit this information."
        )
    }

    func testCompileSymbolWithExternalReferences() throws {
        class TestSymbolResolver: GlobalExternalSymbolResolver {
            func symbolReferenceAndEntity(withPreciseIdentifier preciseIdentifier: String) -> (ResolvedTopicReference, LinkResolver.ExternalEntity)? {
                let reference = ResolvedTopicReference(bundleIdentifier: "com.test.external.symbols", path: "/\(preciseIdentifier)", sourceLanguage: .objectiveC)
                
                let entity = LinkResolver.ExternalEntity(
                    topicRenderReference: TopicRenderReference(
                        identifier: .init(reference.absoluteString),
                        title: "SymbolName ( \(preciseIdentifier) )",
                        abstract: [],
                        url: "/documentation/FrameworkName/path/to/symbol/\(preciseIdentifier)",
                        kind: .symbol,
                        role: "ExternalResolvedSymbolRoleHeading",
                        estimatedTime: nil
                    ),
                    renderReferenceDependencies: .init(),
                    sourceLanguages: [.objectiveC]
                )
                return (reference, entity)
            }
        }
        
        class TestReferenceResolver: ExternalDocumentationSource {
            func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult {
                .success(
                    ResolvedTopicReference(
                        bundleIdentifier: "com.test.external",
                        path: reference.url!.path,
                        sourceLanguage: .swift
                    )
                )
            }
            
            func entity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
                let (kind, role) = DocumentationContentRenderer.renderKindAndRole(.collection, semantic: nil)
                return LinkResolver.ExternalEntity(
                    topicRenderReference: TopicRenderReference(
                        identifier: .init(reference.absoluteString),
                        title: "Title for \(reference.url.path)",
                        abstract: [.text("Abstract for \(reference.url.path)")],
                        url: reference.url.path,
                        kind: kind,
                        role: role,
                        estimatedTime: nil
                    ),
                    renderReferenceDependencies: .init(),
                    sourceLanguages: [.swift]
                )
            }
        }
        
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        
        context.externalDocumentationSources = ["com.test.external": TestReferenceResolver()]
        context.globalExternalSymbolResolver = TestSymbolResolver()
        
        let testBundleURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let dataProvider = try LocalFileSystemDataProvider(rootURL: testBundleURL)
        try workspace.registerProvider(dataProvider)
        
        let bundle = workspace.bundles.values.first!
        
        // Symbols are loaded
        XCTAssertFalse(context.documentationCache.isEmpty)
        
        // MyProtocol is loaded
        let myProtocol = try XCTUnwrap(context.documentationCache["s:5MyKit0A5ProtocolP"], "`MyProtocol` not found in symbol graph")
        let myProtocolSymbol = try XCTUnwrap(myProtocol.semantic as? Symbol)
        
        // Verify that various symbols that exist are referenced in the symbol graph file have been resolved and added to the symbol index
        XCTAssertNotNil(context.externalCache["p:hPP"])
        XCTAssertNotNil(context.externalCache["s:Si"])
        XCTAssertNotNil(context.externalCache["s:10Foundation3URLV"])
        XCTAssertNotNil(context.externalCache["s:10Foundation4DataV"])
        XCTAssertNotNil(context.externalCache["s:5Foundation0A5NSCodableP"])
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: myProtocol.reference)

        let renderNode = translator.visit(myProtocolSymbol) as! RenderNode
        guard renderNode.primaryContentSections.count == 4 else {
            XCTFail("Unexpected primary section count.")
            return
        }

        // Declarations are always first primary section.
        guard let declarations = renderNode.primaryContentSections[0] as? DeclarationsRenderSection else {
            XCTFail("Could not find declarations primary section")
            return
        }
        XCTAssertEqual(declarations.kind, RenderSectionKind.declarations)

        guard declarations.declarations.count == 1 else {
            XCTFail("Could not find declaration section")
            return
        }

        XCTAssertEqual(declarations.declarations[0].platforms, [PlatformName(operatingSystemName: "ios")])
        XCTAssertEqual(declarations.declarations[0].tokens.count, 5)
        XCTAssertEqual(declarations.declarations[0].tokens.map { $0.text }.joined(), "protocol MyProtocol : Hashable")
        XCTAssertEqual(declarations.declarations[0].languages?.first, "swift")
        
        // Verify that the Hashable reference in the declaration has been resolved to a reference to that symbol.
        
        XCTAssertNotNil(declarations.declarations[0].tokens.last?.identifier)
        if let hashableDeclarationToken = declarations.declarations[0].tokens.last {
            XCTAssertEqual(hashableDeclarationToken.kind, .typeIdentifier)
            
            XCTAssertTrue(renderNode.references.keys.contains(hashableDeclarationToken.identifier!))
            
            if let reference = renderNode.references[hashableDeclarationToken.identifier!] as? TopicRenderReference {
                XCTAssertEqual(reference.title, "SymbolName ( p:hPP )")
                XCTAssertEqual(reference.url, "/documentation/FrameworkName/path/to/symbol/p:hPP")
            }
        }
        
        // Verify that the protocol inheritance relationships have been resolved to references to those symbols.
        
        XCTAssertEqual(renderNode.relationshipSections[0].type, "inheritsFrom")
        XCTAssertEqual(
            renderNode.relationshipSections[0].identifiers.sorted(),
            ["doc://com.test.external.symbols/s:5Foundation0A5EarhartP", "doc://com.test.external.symbols/s:5Foundation0A5NSCodableP"],
            "Since this is a protocol and it has conformsTo relationships to two other protocols, there are two 'Inherits From' references"
        )
        
        XCTAssertNotNil(renderNode.references["doc://com.test.external.symbols/s:5Foundation0A5EarhartP"] as? TopicRenderReference)
        if let reference = renderNode.references["doc://com.test.external.symbols/s:5Foundation0A5EarhartP"] as? TopicRenderReference {
            XCTAssertEqual(reference.title, "SymbolName ( s:5Foundation0A5EarhartP )")
            XCTAssertEqual(reference.url, "/documentation/FrameworkName/path/to/symbol/s:5Foundation0A5EarhartP")
        }
        
        XCTAssertNotNil(renderNode.references["doc://com.test.external.symbols/s:5Foundation0A5NSCodableP"] as? TopicRenderReference)
        if let reference = renderNode.references["doc://com.test.external.symbols/s:5Foundation0A5NSCodableP"] as? TopicRenderReference {
            XCTAssertEqual(reference.title, "SymbolName ( s:5Foundation0A5NSCodableP )")
            XCTAssertEqual(reference.url, "/documentation/FrameworkName/path/to/symbol/s:5Foundation0A5NSCodableP")
        }
        
        let externalPageReference = try XCTUnwrap(renderNode.references["doc://com.test.external/ExternalPage"] as? TopicRenderReference)
        XCTAssertEqual(externalPageReference.title, "Title for /ExternalPage")
        XCTAssertEqual(externalPageReference.url, "/ExternalPage")
        XCTAssertEqual(externalPageReference.abstract, [.text("Abstract for /ExternalPage")])
        
        XCTAssertNil(
            renderNode.metadata.sourceFileURI,
            "Unexpectedly found sourceFileURI: the documentation converter was not configured to emit this information."
        )
        
        XCTAssertNil(
            renderNode.metadata.symbolAccessLevel,
            "Unexpectedly found symbolAccessLevel: the documentation converter was not configured to emit this information."
        )
    }
    
    func testRenderConstraints() throws {
        
        // Check for constraints in render node
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift))
        
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(symbol) as! RenderNode
        guard let conf = renderNode.metadata.conformance else {
            XCTFail("Did not find extension metadata")
            return
        }
    
        XCTAssertEqual(conf.constraints.map { el -> String in
            switch el {
            case .text(let text): return text
            case .codeVoice(let text): return text
            default: return ""
            }
        }.joined(), "Label is Text, Observer inherits NSObject, and S conforms to StringProtocol.")
        
        // Check for constraints in render references
        let parent = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
        
        let parentSymbol = parent.semantic as! Symbol
        var parentTranslator = RenderNodeTranslator(context: context, bundle: bundle, identifier: parent.reference)
        
        let parentRenderNode = parentTranslator.visit(parentSymbol) as! RenderNode
        guard let functionReference = parentRenderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()"] as? TopicRenderReference else {
            XCTFail("Render reference doc://org.swift.docc.example/documentation/mykit/myclass/myfunction was not found")
            return
        }
        
        XCTAssertEqual(functionReference.conformance?.constraints.map { el -> String in
            switch el {
            case .text(let text): return text
            case .codeVoice(let text): return text
            default: return ""
            }
        }.joined(), "Label is Text, Observer inherits NSObject, and S conforms to StringProtocol.")
        
        
        // Check that serializing and deserializing the render node doesn't fail for conformance
        let encodedData = try JSONEncoder().encode(renderNode)
        XCTAssertNoThrow(try JSONDecoder().decode(RenderNode.self, from: encodedData))
        let decodedRenderNode = try JSONDecoder().decode(RenderNode.self, from: encodedData)
        XCTAssertNotNil(decodedRenderNode.metadata.conformance)
        XCTAssertEqual(decodedRenderNode.metadata.conformance?.constraints.count, 12)
        
        let constraintsString = decodedRenderNode.metadata.conformance?.constraints.reduce("", { $0 + $1.rawIndexableTextContent(references: [:]) })
        XCTAssertEqual(constraintsString, "Label is Text, Observer inherits NSObject, and S conforms to StringProtocol.")
    }
    
    func testRenderConditionalConstraintsOnConformingType() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyProtocol", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = translator.visit(symbol) as! RenderNode
        
        // Test conditional conformance for the conforming type
        guard let myClassRelationship = renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyClass"] as? TopicRenderReference else {
            XCTFail("Render reference doc://org.swift.docc.example/documentation/MyKit/MyClass was not found")
            return
        }
        
        XCTAssertEqual(myClassRelationship.conformance?.constraints.map { el -> String in
            switch el {
            case .text(let text): return text
            case .codeVoice(let text): return text
            default: return ""
            }
        }.joined(), "Element conforms to Equatable.")
    }
    
    func testRenderConditionalConstraintsOnProtocol() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = translator.visit(symbol) as! RenderNode
        
        // Test conditional conformance for the conforming type
        guard let myProtocolRelationship = renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyProtocol"] as? TopicRenderReference else {
            XCTFail("Render reference doc://org.swift.docc.example/documentation/MyKit/MyProtocol was not found")
            return
        }
        
        XCTAssertEqual(myProtocolRelationship.conformance?.constraints.map { el -> String in
            switch el {
            case .text(let text): return text
            case .codeVoice(let text): return text
            default: return ""
            }
        }.joined(), "Element conforms to Equatable.")
    }
    
    func testRenderReferenceResolving() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
        
        // Compile docs and verify contents
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)

        let renderNode = translator.visit(symbol) as! RenderNode

        guard renderNode.topicSections.count == 6 else {
            XCTFail("Did not find expected amount of topic sections")
            return
        }
        
        // Test resolving relative symbol links
        XCTAssertEqual(renderNode.topicSections[0].identifiers.sorted(), [
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()",
        ])
        
        // Test resolving module rooted links
        XCTAssertEqual(renderNode.topicSections[1].identifiers.sorted(), [
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()",
        ])

        // Test resolving absolute symbol links
        XCTAssertEqual(renderNode.topicSections[2].identifiers.sorted(), [
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()",
        ])

        // Test resolving relative topic links
        XCTAssertEqual(renderNode.topicSections[3].identifiers.sorted(), [
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()",
        ])

        // Test resolving module-level topic links
        XCTAssertEqual(renderNode.topicSections[4].identifiers.sorted(), [
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()",
        ])

        // Test resolving absolute topic links
        XCTAssertEqual(renderNode.topicSections[5].identifiers.sorted(), [
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()",
        ])

        // Additional test to cover relative links in See Also
        XCTAssertEqual(renderNode.seeAlsoSections.first?.identifiers.sorted(), [
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d",
            "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()",
        ])
    }
    
    func testAvailabilityMetadata() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
        
        // Compile docs and verify contents
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(symbol) as! RenderNode
        
        // Ensure the availability has platform and version.
        let platforms = (renderNode.metadata.platforms ?? []).sorted(by: { lhs, rhs in lhs.name! < rhs.name! })
        
        // Verify there are 6 availability items in the symbol graph
        XCTAssertEqual(symbol.availability?.availability.count, 6)

        // Verify only 3 availability items are rendered, since the iOS availability in the graph fixture is invalid
        // and therefore Catalyst and iPadOS are also invalid.
        XCTAssertEqual(platforms.count, 3)
        
        XCTAssertEqual(platforms[0].name, "macOS")
        XCTAssertEqual(platforms[0].introduced, "10.15")
        
        XCTAssertEqual(platforms[1].name, "tvOS")
        XCTAssertEqual(platforms[1].introduced, "13.0")
        
        XCTAssertEqual(platforms[2].name, "watchOS")
        XCTAssertEqual(platforms[2].introduced, "6.0")
    }
    
    func testAvailabilityFromCurrentPlatformOverridesExistingValue() throws {
        // The `MyClass` symbol has availability information for all platforms. Copy the symbol graph for each platform and override only the
        // availability for that platform to verify that the end result preferred the information for each platform.
        let allPlatformsNames: [(platformName: String, operatingSystemName: String)] = [("iOS", "ios"), ("macOS", "macosx"), ("watchOS", "watchos"), ("tvOS", "tvos")]
        
        // Override with both a low and a high value
        for version in [SymbolGraph.SemanticVersion(major: 1, minor: 1, patch: 1), SymbolGraph.SemanticVersion(major: 99, minor: 99, patch: 99)] {
            let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], configureBundle: { url in
                // Duplicate the symbol graph
                let myKitURL = url.appendingPathComponent("mykit-iOS.symbols.json")
                let myClassUSR = "s:5MyKit0A5ClassC"
                
                for testData in allPlatformsNames {
                    var graph = try JSONDecoder().decode(SymbolGraph.self, from: try Data(contentsOf: myKitURL))
                    
                    // Change the platform of the module
                    graph.module.platform.operatingSystem?.name = testData.operatingSystemName
                    graph.module.platform.operatingSystem?.minimumVersion = version
                    
                    // Change the availability of the MyClass symbol
                    var symbol = graph.symbols.removeValue(forKey: myClassUSR)!
                    var availability = symbol.mixins[SymbolGraph.Symbol.Availability.mixinKey]! as! SymbolGraph.Symbol.Availability
                    availability.availability.removeAll(where: { $0.domain?.rawValue == testData.platformName })
                    availability.availability.append(.init(domain: SymbolGraph.Symbol.Availability.Domain(rawValue: testData.platformName), introducedVersion: version, deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false))
                    
                    symbol.mixins[SymbolGraph.Symbol.Availability.mixinKey] = availability
                    graph.symbols[myClassUSR] = symbol
                    
                    let myKitURLForOtherPlatform = url.appendingPathComponent("mykit-\(testData.platformName).symbols.json")
                    try JSONEncoder().encode(graph).write(to: myKitURLForOtherPlatform)
                }
            })
            
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
            
            // Compile docs and verify contents
            let symbol = node.semantic as! Symbol
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            
            let renderNode = translator.visit(symbol) as! RenderNode
            
            // Ensure the availability has platform and version.
            let platforms = (renderNode.metadata.platforms ?? []).sorted(by: { lhs, rhs in lhs.name! < rhs.name! })
            
            XCTAssertEqual(platforms.count,6)
            let versionString = SemanticVersion(version).stringRepresentation(precisionUpToNonsignificant: .patch)
            
            XCTAssertEqual(platforms[0].name, "Mac Catalyst")
            XCTAssertEqual(platforms[0].introduced, versionString)
            
            XCTAssertEqual(platforms[1].name, "iOS")
            XCTAssertEqual(platforms[1].introduced, versionString)
            
            XCTAssertEqual(platforms[2].name, "iPadOS")
            XCTAssertEqual(platforms[2].introduced, versionString)
        }
    }
    
    func testMediaReferencesWithSpaces() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/TutorialMediaWithSpaces", sourceLanguage: .swift))
        
        guard let tutorialDirective = node.markup as? BlockDirective else {
            XCTFail("Unexpected document structure, tutorial not found as first child.")
            return
        }
        
        var problems = [Problem]()
        guard let tutorial = Tutorial(from: tutorialDirective, source: nil, for: bundle, in: context, problems: &problems) else {
            XCTFail("Couldn't create tutorial from markup: \(problems)")
            return
        }
        
        XCTAssertTrue(problems.isEmpty)
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(tutorial) as! RenderNode
        
        XCTAssertEqual(["project.zip", "Xcode X.Y Beta Z", "with spaces.png", "with spaces.mp4"].sorted(),
                       renderNode.references.keys.filter({ !$0.hasPrefix("doc://") }).sorted())
    }
    
    func testUnexpectedDirectivesAreDropped() throws {
        let source = """
This is some text.

- The next directives should get dropped.
  @MyDirective {
     This directive should be dropped.
  }
- @MyOtherDirective

@MyUnnestedDirective

This is more text.
"""
        let markup = Document(parsing: source, options: .parseBlockDirectives)
        
        XCTAssertEqual("""
Document @1:1-11:19
├─ Paragraph @1:1-1:19
│  └─ Text @1:1-1:19 "This is some text."
├─ UnorderedList @3:1-3:42
│  └─ ListItem @3:1-3:42
│     └─ Paragraph @3:3-3:42
│        └─ Text @3:3-3:42 "The next directives should get dropped."
├─ BlockDirective @4:3-6:4 name: "MyDirective"
│  └─ Paragraph @5:6-5:39
│     └─ Text @5:6-5:39 "This directive should be dropped."
├─ UnorderedList @7:1-7:20
│  └─ ListItem @7:1-7:20
│     └─ Paragraph @7:3-7:20
│        └─ Text @7:3-7:20 "@MyOtherDirective"
├─ BlockDirective @9:1-9:21 name: "MyUnnestedDirective"
└─ Paragraph @11:1-11:19
   └─ Text @11:1-11:19 "This is more text."
""",
                       markup.debugDescription(options: .printSourceLocations))
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var contentTranslator = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/TestTutorial", sourceLanguage: .swift))
        let renderContent = try XCTUnwrap(markup.children.reduce(into: [], { result, item in result.append(contentsOf: contentTranslator.visit(item))}) as? [RenderBlockContent])
        let expectedContent: [RenderBlockContent] = [
            .paragraph(.init(inlineContent: [
                RenderInlineContent.text("This is some text.")])),
            .unorderedList(.init(items: [
                            RenderBlockContent.ListItem(content: [
                                .paragraph(.init(inlineContent: [
                                    .text("The next directives should get dropped.")]))])])),
            .unorderedList(.init(items: [
                            RenderBlockContent.ListItem(content: [
                                .paragraph(.init(inlineContent: [
                                    .text("@MyOtherDirective")]))])])),
            .paragraph(.init(inlineContent: [.text("This is more text.")])),
            ]
        XCTAssertEqual(expectedContent, renderContent)
    }

    func testTaskLists() throws {
        let source = """
This is some text.

- [ ] Task one
- [x] Task two
"""
        let markup = Document(parsing: source, options: .parseBlockDirectives)

        XCTAssertEqual("""
Document
├─ Paragraph
│  └─ Text "This is some text."
└─ UnorderedList
   ├─ ListItem checkbox: [ ]
   │  └─ Paragraph
   │     └─ Text "Task one"
   └─ ListItem checkbox: [x]
      └─ Paragraph
         └─ Text "Task two"
""",
                       markup.debugDescription())

        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var contentTranslator = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/TestTutorial", sourceLanguage: .swift))
        let renderContent = try XCTUnwrap(markup.children.reduce(into: [], { result, item in result.append(contentsOf: contentTranslator.visit(item))}) as? [RenderBlockContent])
        let expectedContent: [RenderBlockContent] = [
                .paragraph(.init(inlineContent: [
                    .text("This is some text.")
                ])),
                .unorderedList(.init(items: [
                    .init(content: [.paragraph(.init(inlineContent: [.text("Task one")]))], checked: false),
                    .init(content: [.paragraph(.init(inlineContent: [.text("Task two")]))], checked: true)
                ]))
            ]
        XCTAssertEqual(expectedContent, renderContent)
    }
    
    func testInlineHTMLDoesNotCrashTranslator() throws {
        let markupSource = """
    # Test

    This is _<strong>_ and *<strong>* and __<em>__ and **<em>**.
    As well as just some plain <tags> in a <p>.
    """
        
        let document = Document(parsing: markupSource, options: [])
        let node = DocumentationNode(reference: ResolvedTopicReference(bundleIdentifier: "org.swift.docc", path: "/blah", sourceLanguage: .swift), kind: .article, sourceLanguage: .swift, name: .conceptual(title: "Title"), markup: document, semantic: Semantic())
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        XCTAssertNotNil(translator.visit(MarkupContainer(document.children)))
        }
        
    func testCompileSymbolMetadata() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyProtocol", sourceLanguage: .swift))
        
        // Compile docs and verify contents
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(symbol) as! RenderNode
        
        XCTAssertEqual(renderNode.metadata.title, "MyProtocol")
        XCTAssertEqual(renderNode.metadata.roleHeading, "Protocol")
        XCTAssertEqual(renderNode.metadata.modules?.map({ module -> String in
            return module.name
        }), ["MyKit"])
        XCTAssertEqual(renderNode.metadata.externalID, "s:5MyKit0A5ProtocolP")
        
        XCTAssertNil(
            renderNode.metadata.sourceFileURI,
            "Unexpectedly found sourceFileURI: the documentation converter was not configured to emit this information."
        )
        
        XCTAssertNil(
            renderNode.metadata.symbolAccessLevel,
            "Unexpectedly found symbolAccessLevel: the documentation converter was not configured to emit this information."
        )
    }
    
    func testLanguageVariants() throws {
        let variantSymbolURL = Bundle.module.url(
            forResource: "variants", withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: variantSymbolURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        XCTAssertEqual(symbol.identifier.sourceLanguage.id, "swift")
        XCTAssertEqual(symbol.variants, [
            RenderNode.Variant(
                traits: [.interfaceLanguage("swift")],
                paths: ["/plist/wifiaccess"]
            ),
            RenderNode.Variant(
                traits: [.interfaceLanguage("objc")],
                paths: ["/plist/wifiaccess"]
            ),
        ])
    }
    
    func testArticleRoleHeadings() throws {
        try assertRoleHeadingForArticleInTestBundle(expectedRoleHeading: "Article", content: """
            # Article 2

            This is article 2.
            """
        )
    }
    
    func testArticleRoleHeadingsWithAutomaticTitleHeadingDisabled() throws {
        try assertRoleHeadingForArticleInTestBundle(expectedRoleHeading: nil, content: """
            # Article 2
            
            @Options {
                @AutomaticTitleHeading(disabled)
            }

            This is article 2.
            """
        )
    }
    
    func testArticleRoleHeadingsWithAutomaticTitleHeadingForPageKind() throws {
        try assertRoleHeadingForArticleInTestBundle(expectedRoleHeading: "Article", content: """
            # Article 2
            
            @Options {
                @AutomaticTitleHeading(enabled)
            }

            This is article 2.
            """
        )
    }

    func testAPICollectionRoleHeading() throws {
        try assertRoleHeadingForArticleInTestBundle(expectedRoleHeading: nil, content: """
            # Article 2

            This is article 2.

            ## Topics

            ### Task Group 1
            - <doc:article>
            """
        )
    }
    
    
    private func renderNodeForArticleInTestBundle(content: String) throws -> RenderNode {
        // Overwrite the article so we can test the article eyebrow for articles without task groups
        let sourceURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let targetURL = try createTemporaryDirectory().appendingPathComponent("test.docc")
        
        try FileManager.default.copyItem(at: sourceURL, to: targetURL)

        try content.write(to: targetURL.appendingPathComponent("article2.md"), atomically: true, encoding: .utf8)

        let (_, bundle, context) = try loadBundle(from: targetURL)
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/article2", sourceLanguage: .swift))
        let article = node.semantic as! Article
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        return translator.visit(article) as! RenderNode
    }
    
    /*
        Asserts if `expectedRoleHeading` does not match the parsed render node's `roleHeading` after it's parsed.
        Uses 'TestBundle's documentation as a base for compiling, overwriting 'article2' with `content`.
    */
    private func assertRoleHeadingForArticleInTestBundle(expectedRoleHeading: String?, content: String, file: StaticString = #file, line: UInt = #line) throws {
        let renderNode = try renderNodeForArticleInTestBundle(content: content)
        XCTAssertEqual(expectedRoleHeading, renderNode.metadata.roleHeading, file: (file), line: line)
    }
    
    
    func testDisablingAutomaticArticleSubheadingGeneration() throws {
        // Assert that by default, articles include an "Overview" heading even if it's not authored.
        do {
            let articleRenderNode = try renderNodeForArticleInTestBundle(
                content: """
                # Article 2
                
                This is article 2.
                
                This is the article's second paragraph.
                """
            )
            
            let firstContentSection = try XCTUnwrap(
                articleRenderNode.primaryContentSections.first as? ContentRenderSection
            )
            if case let .heading(heading) = firstContentSection.content.first {
                XCTAssertEqual(heading.text, "Overview")
            } else {
                XCTFail("By default an article should receive an autogenerated 'Overview' heading.")
            }
            
            XCTAssertEqual(firstContentSection.content.count, 2)
        }
        
        // Assert that disabling the automatic behavior with the option directive works as expected.
        do {
            let articleRenderNode = try renderNodeForArticleInTestBundle(
                content: """
                # Article 2
                
                @Options {
                    @AutomaticArticleSubheading(disabled)
                }
                
                This is article 2.
                
                This is the second paragraph of the article.
                """
            )
            
            let firstContentSection = try XCTUnwrap(
                articleRenderNode.primaryContentSections.first as? ContentRenderSection
            )
            if case let .paragraph(paragraph) = firstContentSection.content.first {
                XCTAssertEqual(paragraph.inlineContent.first?.plainText, "This is the second paragraph of the article.")
            } else {
                XCTFail("An article with the '@AutomaticArticleSubheading(disabled)' specified should not receive an autogenerated heading.")
            }
            XCTAssertEqual(firstContentSection.content.count, 1)
        }
    }

    /// Verifies we emit the correct warning for external links in topic task groups.
    func testWarnForExternalLinksInTopicTaskGroups() throws {
        let (_, context) = try testBundleAndContext(named: "TestBundle")
        // Verify we warn for the external link planted in mykit.md
        XCTAssertEqual(context.problems.filter({ $0.diagnostic.identifier == "org.swift.docc.InvalidDocumentationLink" }).count, 1)
        XCTAssertNotNil(context.problems.first(where: { problem -> Bool in

            return problem.diagnostic.identifier == "org.swift.docc.InvalidDocumentationLink"
                && problem.diagnostic.summary.contains("https://external.com/link")
        }))
    }
    
    func testRendersBetaViolators() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = node.semantic as! Symbol
        
        // Not a beta platform
        do {
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let renderNode = translator.visitSymbol(symbol) as! RenderNode
            
            // Verify platform beta was plumbed all the way to the render JSON
            XCTAssertEqual(renderNode.metadata.platforms?.first?.isBeta, false)
        }
        
        // Beta platform
        context.externalMetadata = ExternalMetadata()
        context.externalMetadata.currentPlatforms = ["tvOS": PlatformVersion(VersionTriplet(100, 0, 0), beta: true)]

        // Different platform is beta
        do {
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let renderNode = translator.visitSymbol(symbol) as! RenderNode
            
            // Verify platform beta was plumbed all the way to the render JSON
            XCTAssertEqual(renderNode.metadata.platforms?.first?.isBeta, false)
        }
        
        // Beta platform but *not* matching the introduced version
        context.externalMetadata.currentPlatforms = ["macOS": PlatformVersion(VersionTriplet(100, 0, 0), beta: true)]
        
        do {
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let renderNode = translator.visitSymbol(symbol) as! RenderNode
            
            // Verify platform beta was plumbed all the way to the render JSON
            XCTAssertEqual(renderNode.metadata.platforms?.first?.isBeta, false)
        }

        // Beta platform matching the introduced version
        context.externalMetadata.currentPlatforms = ["macOS": PlatformVersion(VersionTriplet(10, 15, 0), beta: true)]

        do {
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let renderNode = translator.visitSymbol(symbol) as! RenderNode

            // Verify platform beta was plumbed all the way to the render JSON
            XCTAssertEqual(renderNode.metadata.platforms?.first?.isBeta, true)
        }

        // Beta platform earlier than the introduced version
        context.externalMetadata.currentPlatforms = ["macOS": PlatformVersion(VersionTriplet(10, 14, 0), beta: true)]
        
        do {
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let renderNode = translator.visitSymbol(symbol) as! RenderNode
            
            // Verify platform beta was plumbed all the way to the render JSON
            XCTAssertEqual(renderNode.metadata.platforms?.first?.isBeta, true)
        }

        // Set only some platforms to beta & the exact version MyClass is being introduced at
        context.externalMetadata.currentPlatforms = [
            "macOS": PlatformVersion(VersionTriplet(10, 15, 0), beta: true),
            "watchOS": PlatformVersion(VersionTriplet(9, 0, 0), beta: true),
            "tvOS": PlatformVersion(VersionTriplet(1, 0, 0), beta: true),
        ]
        
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            let symbol = node.semantic as! Symbol
            
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let renderNode = translator.visitSymbol(symbol) as! RenderNode
            
            // Verify task group link is beta
            XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyClass"] as? TopicRenderReference)?.isBeta, false)
        }

        // Set all platforms to beta & the exact version MyClass is being introduced at to test beta SDK documentation
        context.externalMetadata.currentPlatforms = [
            "macOS": PlatformVersion(VersionTriplet(10, 15, 0), beta: true),
            "watchOS": PlatformVersion(VersionTriplet(6, 0, 0), beta: true),
            "tvOS": PlatformVersion(VersionTriplet(13, 0, 0), beta: true),
            "iOS": PlatformVersion(VersionTriplet(13, 0, 0), beta: true),
        ]
        
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            let symbol = node.semantic as! Symbol
            
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let renderNode = translator.visitSymbol(symbol) as! RenderNode
            
            // Verify task group link is beta
            XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyClass"] as? TopicRenderReference)?.isBeta, true)
        }

        // Set all platforms to beta where the symbol is available,
        // some platforms not beta but the symbol is not available there.
        context.externalMetadata.currentPlatforms = [
            "macOS": PlatformVersion(VersionTriplet(10, 15, 0), beta: true),
            "watchOS": PlatformVersion(VersionTriplet(6, 0, 0), beta: true),
            "tvOS": PlatformVersion(VersionTriplet(13, 0, 0), beta: true),
            "iOS": PlatformVersion(VersionTriplet(13, 0, 0), beta: true),
            "FictionalOS": PlatformVersion(VersionTriplet(42, 0, 0), beta: false),
            "ImaginaryOS": PlatformVersion(VersionTriplet(3, 3, 3), beta: false),
        ]
        
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            let symbol = node.semantic as! Symbol

            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let renderNode = translator.visitSymbol(symbol) as! RenderNode
            
            // Verify task group link is beta
            XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyClass"] as? TopicRenderReference)?.isBeta, true)
        }

        // Add ImaginaryOS platform - but make it unconditionally unavailable and
        // verify that it doesn't affect the beta status
        do {
            // Add an extra platform where the symbol is not available.
            let renderReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
            let renderReferenceNode = try context.entity(with: renderReference)
            let renderReferenceSymbol = try XCTUnwrap(renderReferenceNode.semantic as? Symbol)
            renderReferenceSymbol.availability?.availability.append(SymbolGraph.Symbol.Availability.AvailabilityItem(domain: SymbolGraph.Symbol.Availability.Domain(rawValue: "ImaginaryOS"), introducedVersion: nil, deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: true, willEventuallyBeDeprecated: false))

            // Verify the rendered reference
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            let symbol = node.semantic as! Symbol
            
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let renderNode = translator.visitSymbol(symbol) as! RenderNode
            
            // Verify task group link is beta
            XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyClass"] as? TopicRenderReference)?.isBeta, true)
        }
    }
    
    func testRendersDeprecatedViolator() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")

        // Make the referenced symbol deprecated
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            (node.semantic as? Symbol)?.availability = SymbolGraph.Symbol.Availability(availability: [
                SymbolGraph.Symbol.Availability.AvailabilityItem(domain: .init(rawValue: "iOS"), introducedVersion: nil, deprecatedVersion: .init(major: 13, minor: 0, patch: 0), obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
            ])
        }
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = node.semantic as! Symbol
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        
        // The reference is deprecated on all platforms
        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()"] as? TopicRenderReference)?.isDeprecated, true)
    }

    func testDoesNotRenderDeprecatedViolator() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")

        // Make the referenced symbol deprecated
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            (node.semantic as? Symbol)?.availability = SymbolGraph.Symbol.Availability(availability: [
                SymbolGraph.Symbol.Availability.AvailabilityItem(domain: .init(rawValue: "iOS"), introducedVersion: .init(major: 13, minor: 0, patch: 0), deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
                SymbolGraph.Symbol.Availability.AvailabilityItem(domain: .init(rawValue: "macOS"), introducedVersion: nil, deprecatedVersion: .init(major: 10, minor: 15, patch: 0), obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: true, willEventuallyBeDeprecated: false),
            ])
        }
    
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = node.semantic as! Symbol
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        
        // The reference is not deprecated on all platforms
        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()"] as? TopicRenderReference)?.isDeprecated, false)
    }
    
    func testRendersDeprecatedViolatorForUnconditionallyDeprecatedReference() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")

        // Make the referenced symbol deprecated
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            (node.semantic as? Symbol)?.availability = SymbolGraph.Symbol.Availability(availability: [
                SymbolGraph.Symbol.Availability.AvailabilityItem(domain: .init(rawValue: "iOS"), introducedVersion: .init(major: 13, minor: 0, patch: 0), deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: true, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
                SymbolGraph.Symbol.Availability.AvailabilityItem(domain: .init(rawValue: "macOS"), introducedVersion: .init(major: 11, minor: 0, patch: 0), deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: true, willEventuallyBeDeprecated: false),
            ])
        }

        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = node.semantic as! Symbol
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        
        // Verify that the reference is deprecated on all platforms
        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()"] as? TopicRenderReference)?.isDeprecated, true)
    }
    
    func testRenderMetadataFragments() throws {
        
        // Check for fragments in metadata in render node
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
        
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(symbol) as! RenderNode
        guard let fragments = renderNode.metadata.fragments else {
            XCTFail("Did not find extension fragments")
            return
        }
        
        XCTAssertEqual(fragments, [
            .init(text: "class", kind: .keyword),
            .init(text: " ", kind: .text),
            .init(text: "MyClass", kind: .identifier),
        ])
    }
    
    func testRenderMetadataExtendedModule() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift))
        
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode)
        XCTAssertEqual(renderNode.metadata.extendedModule, "MyKit")
    }
    
    func testDefaultImplementations() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        // Verify that the render reference to a required symbol includes the 'required' key and the number of default implementations provided.
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideProtocol", sourceLanguage: .swift))
            let symbol = node.semantic as! Symbol
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(symbol) as! RenderNode

            let requiredFuncReference = try XCTUnwrap(renderNode.references["doc://org.swift.docc.example/documentation/SideKit/SideProtocol/func()"])
            
            XCTAssertEqual((requiredFuncReference as? TopicRenderReference)?.required, true)
            XCTAssertEqual((requiredFuncReference as? TopicRenderReference)?.defaultImplementationCount, 1)
        }

        // Verify that a required symbol includes a required metadata and default implementations
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideProtocol/func()", sourceLanguage: .swift))
            let symbol = node.semantic as! Symbol
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(symbol) as! RenderNode

            // Verify that the render reference to a required symbol includes the 'required' key and the number of default implementations provided.
            XCTAssertEqual(renderNode.metadata.required, true)
            XCTAssertEqual(renderNode.defaultImplementationsSections.count, 1)
            
            // Verify the default implementation data was captured correctly
            XCTAssertEqual(renderNode.defaultImplementationsSections.first?.identifiers, ["doc://org.swift.docc.example/documentation/SideKit/SideProtocol/func()-2dxqn"])
            XCTAssertEqual(renderNode.defaultImplementationsSections.first?.title, "SideProtocol Implementations")
        }
    }

    func testDefaultImplementationsNotListedInTopics() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        // Verify that a required symbol does not include default implementations in Topics groups
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideProtocol/func()", sourceLanguage: .swift))
            let symbol = node.semantic as! Symbol
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(symbol) as! RenderNode

            // Test that default implementations are listed ONLY under Default Implementations and not Topics
            XCTAssertTrue(renderNode.topicSections.isEmpty)
            XCTAssertFalse(renderNode.defaultImplementationsSections.isEmpty)
        }
    }
    
    func testNoStringMetadata() throws {
        
        // Check for fragments in metadata in render node
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
        
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(symbol) as! RenderNode
        let encoded = try JSONEncoder().encode(renderNode)
        var renderNodeJSON = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        
        let extra = ["foo", "bar"]
        var metadata = renderNodeJSON["metadata"] as! [String: Any]
        metadata["extra"] = extra
        renderNodeJSON["metadata"] = metadata
        
        let processedData = try JSONSerialization.data(withJSONObject: renderNodeJSON)
        
        XCTAssertNoThrow(try RenderNode.decode(fromJSON: processedData), "Arbitrarty data in metadata should not throw breaking the decoding process.")
        
        let modifiedRenderNode = try RenderNode.decode(fromJSON: processedData)
        let roundtripData = try JSONEncoder().encode(modifiedRenderNode)
        let roundtrip = try RenderNode.decode(fromJSON: roundtripData)
        let roundtripMetadata = roundtrip.metadata.extraMetadata[RenderMetadata.CodingKeys(stringValue: "extra")]
        XCTAssertEqual(extra, roundtripMetadata as? [String])
    }
    
    func testRenderDeclarations() throws {
        
        // Check for fragments in metadata in render node
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift))
        
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(symbol) as! RenderNode
        
        guard let section = renderNode.primaryContentSections.mapFirst(where: { $0 as? DeclarationsRenderSection}) else {
            XCTFail("Did not find a declarations section")
            return
        }
        
        XCTAssertEqual(section.declarations.count, 1)
        XCTAssertEqual(section.declarations.first?.languages, ["swift"])
    }

    func testDocumentationRenderReferenceRoles() throws {
        // Check for fragments in metadata in render node
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift))
        
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(symbol) as! RenderNode

        let roleFor = {(identifier: String) -> String? in
            return (renderNode.references[identifier] as? TopicRenderReference)?.role
        }

        XCTAssertEqual(roleFor("doc://org.swift.docc.example/documentation/MyKit/MyClass"), "symbol")
        XCTAssertEqual(roleFor("doc://org.swift.docc.example/documentation/Test-Bundle/article2"), "collectionGroup")
        XCTAssertEqual(roleFor("doc://org.swift.docc.example/documentation/MyKit"), "collection")
        XCTAssertEqual(roleFor("doc://org.swift.docc.example/documentation/Test-Bundle/Default-Code-Listing-Syntax"), "article")
    }

    func testTutorialsRenderReferenceRoles() throws {
        // Check for fragments in metadata in render node
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/TestOverview", sourceLanguage: .swift))
        
        let symbol = node.semantic as! Technology
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(symbol) as! RenderNode

        let roleFor = {(identifier: String) -> String? in
            return (renderNode.references[identifier] as? TopicRenderReference)?.role
        }

        XCTAssertEqual(roleFor("doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial"), "project")
        XCTAssertEqual(roleFor("doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle"), "article")
        XCTAssertEqual(roleFor("doc://org.swift.docc.example/tutorials/TestOverview"), "overview")
    }
    
    func testRemovingTrailingNewLinesInDeclaration() throws {
        // Check for fragments in metadata in render node
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")

        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/globalFunction(_:considering:)", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol

        // Subheading with trailing "\n"
        XCTAssertEqual(symbol.subHeading?.count, 11)

        // Navigator title with trailing "\n"
        XCTAssertEqual(symbol.navigator?.count, 11)

        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = translator.visit(symbol) as! RenderNode

        // Verify trailing newline removed from subheading
        XCTAssertEqual(renderNode.metadata.fragments?.count, 10)

        // Verify trailing newline removed from navigator
        XCTAssertEqual(renderNode.metadata.navigatorTitle?.count, 10)
    }
    
    func testRenderManualSeeAlsoInArticles() throws {
        // Check for fragments in metadata in render node
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/article", sourceLanguage: .swift))
        
        let article = node.semantic as! Article
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(article) as! RenderNode
        
        guard let seeAlso = renderNode.seeAlsoSections.first,
            let seeAlsoLinkReference = seeAlso.identifiers.first,
            let link = renderNode.references[seeAlsoLinkReference] as? LinkReference else {

            XCTFail("Did not find a See Also section with a valid reference")
            return
        }
        
        XCTAssertEqual(link.url, "https://www.website.com")
        XCTAssertEqual(link.title, "Website")
        XCTAssertEqual(link.titleInlineContent, [.text("Website")])
    }
    
    func testSafeSectionAnchorNames() throws {
        // Check that heading's anchor was safe-ified
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(symbol) as! RenderNode
        
        XCTAssertNotNil(renderNode.primaryContentSections.first { section -> Bool in
            guard section.kind == .content,
                let contentSection = section as? ContentRenderSection,
                !contentSection.content.isEmpty else { return false }
            switch contentSection.content[0] {
            case .heading(let h):
                return h.level == 2 && h.text == "Return Value" && h.anchor == "return-value"
            default: return false
            }
        })
    }
    
    func testDuplicateNavigatorTitleIsRemoved() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")

        let myFuncReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/globalFunction(_:considering:)", sourceLanguage: .swift)
        let node = try context.entity(with: myFuncReference)
        let symbol = node.semantic as! Symbol

        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        translator.collectedTopicReferences.append(myFuncReference)
        let renderNode = translator.visit(symbol) as! RenderNode

        let renderReference = try XCTUnwrap(renderNode.references[myFuncReference.absoluteString] as? TopicRenderReference)
        XCTAssertNotNil(renderReference.fragments)
        XCTAssertNil(renderReference.navigatorTitle)
    }

    func testNonDuplicateNavigatorTitleIsRendered() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")

        let myFuncReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyProtocol", sourceLanguage: .swift)
        let node = try context.entity(with: myFuncReference)
        let symbol = node.semantic as! Symbol

        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = translator.visit(symbol) as! RenderNode

        let renderReference = try XCTUnwrap(renderNode.references[myFuncReference.absoluteString] as? TopicRenderReference)
        XCTAssertNotNil(renderReference.fragments)
        XCTAssertNotNil(renderReference.navigatorTitle)
    }

    let asidesStressTest: [RenderBlockContent] = [
        .aside(.init(style: .init(rawValue: "Note"), content: [.paragraph(.init(inlineContent: [.text("This is a note.")]))])),
        .aside(.init(style: .init(rawValue: "Tip"), content: [.paragraph(.init(inlineContent: [.text("Here’s a tip.")]))])),
        .aside(.init(style: .init(rawValue: "Important"), content: [.paragraph(.init(inlineContent: [.text("Keep this in mind.")]))])),
        .aside(.init(style: .init(rawValue: "Experiment"), content: [.paragraph(.init(inlineContent: [.text("Try this out.")]))])),
        .aside(.init(style: .init(rawValue: "Warning"), content: [.paragraph(.init(inlineContent: [.text("Watch out for this.")]))])),
        .aside(.init(style: .init(rawValue: "Attention"), content: [.paragraph(.init(inlineContent: [.text("Head’s up!")]))])),
        .aside(.init(style: .init(rawValue: "Author"), content: [.paragraph(.init(inlineContent: [.text("I wrote this.")]))])),
        .aside(.init(style: .init(rawValue: "Authors"), content: [.paragraph(.init(inlineContent: [.text("We wrote this.")]))])),
        .aside(.init(style: .init(rawValue: "Bug"), content: [.paragraph(.init(inlineContent: [.text("This is wrong.")]))])),
        .aside(.init(style: .init(rawValue: "Complexity"), content: [.paragraph(.init(inlineContent: [.text("This takes time.")]))])),
        .aside(.init(style: .init(rawValue: "Copyright"), content: [.paragraph(.init(inlineContent: [.text("2021 Apple Inc.")]))])),
        .aside(.init(style: .init(rawValue: "Date"), content: [.paragraph(.init(inlineContent: [.text("1 January 1970")]))])),
        .aside(.init(style: .init(rawValue: "Invariant"), content: [.paragraph(.init(inlineContent: [.text("This shouldn’t change.")]))])),
        .aside(.init(style: .init(rawValue: "MutatingVariant"), content: [.paragraph(.init(inlineContent: [.text("This will change.")]))])),
        .aside(.init(style: .init(rawValue: "NonMutatingVariant"), content: [.paragraph(.init(inlineContent: [.text("This changes, but not in the data.")]))])),
        .aside(.init(style: .init(rawValue: "Postcondition"), content: [.paragraph(.init(inlineContent: [.text("After calling, this should be true.")]))])),
        .aside(.init(style: .init(rawValue: "Precondition"), content: [.paragraph(.init(inlineContent: [.text("Before calling, this should be true.")]))])),
        .aside(.init(style: .init(rawValue: "Remark"), content: [.paragraph(.init(inlineContent: [.text("Something you should know.")]))])),
        .aside(.init(style: .init(rawValue: "Requires"), content: [.paragraph(.init(inlineContent: [.text("This needs something.")]))])),
        .aside(.init(style: .init(rawValue: "Since"), content: [.paragraph(.init(inlineContent: [.text("The beginning of time.")]))])),
        .aside(.init(style: .init(rawValue: "Todo"), content: [.paragraph(.init(inlineContent: [.text("This needs work.")]))])),
        .aside(.init(style: .init(rawValue: "Version"), content: [.paragraph(.init(inlineContent: [.text("3.1.4")]))])),
        .aside(.init(style: .init(rawValue: "SeeAlso"), content: [.paragraph(.init(inlineContent: [.text("This other thing.")]))])),
        .aside(.init(style: .init(rawValue: "SeeAlso"), content: [.paragraph(.init(inlineContent: [.text("And this other thing.")]))])),
        .aside(.init(style: .init(rawValue: "Throws"), content: [.paragraph(.init(inlineContent: [.text("A serious error.")]))])),
    ]
    
    func testBareTechnology() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            try """
            @Tutorials(name: "<#text#>") {
              @Intro(title: "<#text#>") {
                <#text#>
              }

              @Chapter(name: "<#text#>") {
                @Image(source: <#file name#>, alt: "<#accessibility description#>")

                @TutorialReference(tutorial: "doc:<#tutorial name#>")
              }
            }
            """.write(to: url.appendingPathComponent("TestOverview.tutorial"), atomically: true, encoding: .utf8)
        }
        
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/TestOverview", sourceLanguage: .swift))
        
        guard let technologyDirective = node.markup as? BlockDirective else {
            XCTFail("Unexpected document structure, technology not found as first child.")
            return
        }
        
        var problems = [Problem]()
        guard let technology = Technology(from: technologyDirective, source: nil, for: bundle, in: context, problems: &problems) else {
            XCTFail("Couldn't create tutorial from markup: \(problems)")
            return
        }
        
        XCTAssert(problems.filter { $0.diagnostic.severity == .error }.isEmpty, "Found errors when analyzing Tutorials overview.")
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        // Verify we don't crash.
        _ = translator.visit(technology)
        
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift))
            
            guard let technologyDirective = node.markup as? BlockDirective else {
                XCTFail("Unexpected document structure, tutorial not found as first child.")
                return
            }
            
            guard let tutorial = Tutorial(from: technologyDirective, source: nil, for: bundle, in: context, problems: &problems) else {
                XCTFail("Couldn't create tutorial from markup: \(problems)")
                return
            }
        
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            XCTAssertNil(translator.visit(tutorial), "Render node for uncurated tutorial should not have been produced")
        }
    }

    func testBareTutorial() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            try """
            @Tutorial(time: <#number#>, projectFiles: <#.zip#>) {
              @Intro(title: "<#text#>") {
                <#text#>

                @Image(source: <#file name#>, alt: "<#accessibility description#>")
              }

              @Section(title: "<#text#>") {
                @ContentAndMedia {
                  <#text#>

                  @Image(source: <#file name#>, alt: "<#accessibility description#>")
                }

                @Steps {
                  @Step {
                    <#text#>
                    @Image(source: <#file name#>, alt: "<#accessibility description#>")
                  }
                  @Step {
                    <#text#>
                    @Code(name: "<#display name#>", file: <#filename.swift#>)
                  }
                }
              }

              @Assessments {
                @MultipleChoice {
                  <#question#>

                  @Choice(isCorrect: <#true#>) {
                    <#text#>

                    @Justification(reaction: "<#text#>") {
                      <#text#>
                    }
                  }

                  @Choice(isCorrect: <#false#>) {
                    <#text#>

                    @Justification(reaction: "<#text#>") {
                      <#text#>
                    }
                  }
                }
              }
            }
            """.write(to: url.appendingPathComponent("TestTutorial.tutorial"), atomically: true, encoding: .utf8)
        }
        
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift))
        
        guard let technologyDirective = node.markup as? BlockDirective else {
            XCTFail("Unexpected document structure, tutorial not found as first child.")
            return
        }
        
        var problems = [Problem]()
        guard let tutorial = Tutorial(from: technologyDirective, source: nil, for: bundle, in: context, problems: &problems) else {
            XCTFail("Couldn't create tutorial from markup: \(problems)")
            return
        }
        
        XCTAssert(problems.filter { $0.diagnostic.severity == .error }.isEmpty, "Found errors when analyzing tutorial.")
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        // Verify we don't crash.
        _ = translator.visit(tutorial)
    }
    
    /// Ensures we render our supported asides from symbol-graph content correctly, whether as a blockquote or as a list item.
    func testRenderAsides() throws {
        let asidesSGFURL = Bundle.module.url(
            forResource: "Asides.symbols", withExtension: "json", subdirectory: "Test Resources")!
        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: []) { url in
            try? FileManager.default.copyItem(at: asidesSGFURL, to: url.appendingPathComponent("Asides.symbols.json"))
        }
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }
        
        // Both of these symbols have the same content; one just has its asides as list items and the other has blockquotes.
        let testReference: (ResolvedTopicReference) throws -> () = { myFuncReference in
            let node = try context.entity(with: myFuncReference)
            let symbol = node.semantic as! Symbol
            
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(symbol) as! RenderNode
            let asides = try XCTUnwrap(renderNode.primaryContentSections.first(where: { $0.kind == .content }) as? ContentRenderSection)
            
            XCTAssertEqual(Array(asides.content.dropFirst()), self.asidesStressTest)
        }
        
        let dashReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Asides/dashAsides()", sourceLanguage: .swift)
        let quoteReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Asides/quoteAsides()", sourceLanguage: .swift)
        
        try testReference(dashReference)
        try testReference(quoteReference)
    }

    /// Tests parsing origin data from symbol graph.
    func testOriginMetadata() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")

        let myFuncReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass/Element/inherited()", sourceLanguage: .swift)
        let node = try context.entity(with: myFuncReference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        let origin = try XCTUnwrap(symbol.origin)

        // Verify the origin data from the symbol graph
        XCTAssertEqual(origin.identifier, "s:OriginalUSR")
        XCTAssertEqual(origin.displayName, "Module.Protocol.inherited()")
    }
    
    /// Tests that we inherit docs by default from within the same module.
    func testDocInheritanceInsideModule() throws {
        let sgURL = Bundle.module.url(
            forResource: "TestBundle.docc/sidekit.symbols", withExtension: "json", subdirectory: "Test Bundles")!

        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
            // Replace the out-of-bundle origin with a symbol from the same bundle.
            try String(contentsOf: sgURL)
                .replacingOccurrences(of: #"identifier" : "s:OriginalUSR"#, with: #"identifier" : "s:5MyKit0A5MyProtocol0Afunc()"#)
                .write(to: url.appendingPathComponent("sidekit.symbols.json"), atomically: true, encoding: .utf8)
        })

        let myFuncReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass/Element/inherited()", sourceLanguage: .swift)
        let node = try context.entity(with: myFuncReference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        // Verify that by default we inherit docs.
        do {
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode)

            // Verify the expected inherited abstract text.
            XCTAssertEqual(renderNode.abstract, [.text("Inherited abstract.")])
        }
    }

    /// Tests that we don't inherit docs by default from within the same bundle but not module.
    func testDocInheritanceInsideBundleButNotModule() throws {
        let sgURL = Bundle.module.url(
            forResource: "TestBundle.docc/sidekit.symbols", withExtension: "json", subdirectory: "Test Bundles")!

        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
            // Replace the out-of-bundle origin with a symbol from the same bundle but
            // from the MyKit module.
            try String(contentsOf: sgURL)
                .replacingOccurrences(of: #"identifier" : "s:OriginalUSR"#, with: #"identifier" : "s:5MyKit0A5ClassC"#)
                .write(to: url.appendingPathComponent("sidekit.symbols.json"), atomically: true, encoding: .utf8)
        })

        let myFuncReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass/Element/inherited()", sourceLanguage: .swift)
        let node = try context.entity(with: myFuncReference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        // Verify that by default we inherit docs.
        do {
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode)

            // Verify the expected default abstract text.
            XCTAssertEqual(renderNode.abstract, [.text("Inherited from "), .codeVoice(code: "Module.Protocol.inherited()"), .text(".")])
        }
    }
    /// Tests that we generated an automatic abstract and remove source docs.
    func testDisabledDocInheritance() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")

        // Verify that the inherited docs which should be ignored are not reference resolved.
        // Verify inherited docs are reference resolved and their problems are recorded.
        let missingResources = context.diagnosticEngine.problems.filter { p -> Bool in
            return p.diagnostic.identifier == "org.swift.docc.unresolvedResource"
        }
        XCTAssertFalse(missingResources.contains(where: { p -> Bool in
            return p.diagnostic.summary == "Resource 'my-inherited-image.png' couldn't be found"
        }))

        let myFuncReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass/Element/inherited()", sourceLanguage: .swift)
        let node = try context.entity(with: myFuncReference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        // Verify that by default we don't inherit docs and we generate default abstract.
        do {
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode)

            // Verify the expected default abstract text.
            XCTAssertEqual(renderNode.abstract, [.text("Inherited from "), .codeVoice(code: "Module.Protocol.inherited()"), .text(".")])
            
            // Verify that the only section in the node is the declaration.
            XCTAssertEqual(renderNode.primaryContentSections.count, 1)
            XCTAssertTrue(renderNode.primaryContentSections.first is DeclarationsRenderSection)
        }
    }

    /// Tests doc extensions are matched to inherited symbols
    func testInheritedSymbolDocExtension() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
            try? """
            # ``SideKit/SideClass/Element/inherited()``
            Doc extension abstract.

            Doc extension discussion. Missing: ![image](my-inherited-image.png).
            """.write(to: url.appendingPathComponent("inherited.md"), atomically: true, encoding: .utf8)
        })
        
        let myFuncReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass/Element/inherited()", sourceLanguage: .swift)
        let node = try context.entity(with: myFuncReference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        // Verify the doc extension was matched to the inherited symbol.
        do {
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode)

            // Verify the expected default abstract text.
            XCTAssertEqual(renderNode.abstract, [.text("Doc extension abstract.")])
            
            // Verify that there is a declaration section and a discussion section.
            XCTAssertEqual(renderNode.primaryContentSections.count, 2)
            guard renderNode.primaryContentSections.count == 2 else {
                return
            }
            XCTAssertTrue(renderNode.primaryContentSections[0] is DeclarationsRenderSection)

            // Verify the discussion was inherited.
            let discussion = try XCTUnwrap(renderNode.primaryContentSections[1] as? ContentRenderSection)
            XCTAssertEqual(discussion.content, [
                RenderBlockContent.heading(.init(level: 2, text: "Discussion", anchor: "discussion")),
                .paragraph(.init(inlineContent: [
                    .text("Doc extension discussion. Missing: "),
                    .text("."),
                ]))
            ])
        }
    }
    
    /// Tests that authored documentation for inherited symbols isn't removed.
    func testInheritedSymbolWithAuthoredDocComment() throws {
        struct TestData {
            let docCommentJSON: String
            let expectedRenderedAbstract: [RenderInlineContent]
        }
        let testData = [
            // With the new module information
            TestData(
                docCommentJSON: """
                {
                  "lines": [{
                    "text": "Authored abstract",
                    "range": {
                      "start": {"line": 1, "character": 4},
                      "end": {"line": 1, "character": 21}
                    }
                  }],
                  "module": "SideKit",
                  "uri": "file://path/to/file.swift"
                }
                """,
                expectedRenderedAbstract: [.text("Authored abstract")]
            ),
            TestData(
                docCommentJSON: """
                {
                  "lines": [{
                    "text": "Authored abstract",
                    "range": {
                      "start": {"line": 1, "character": 4},
                      "end": {"line": 1, "character": 21}
                    }
                  }],
                  "module": "SideKit",
                  "uri": "file://path/with spaces/to/file.swift"
                }
                """,
                expectedRenderedAbstract: [.text("Authored abstract")]
            ),
            TestData(
                docCommentJSON: """
                {
                  "lines": [{
                    "text": "Authored abstract",
                    "range": {
                      "start": {"line": 1, "character": 4},
                      "end": {"line": 1, "character": 21}
                    }
                  }],
                  "module": "OtherModule",
                  "uri": "file://path/to/file.swift"
                }
                """,
                expectedRenderedAbstract: [.text("Inherited from "), .codeVoice(code: "Module.Protocol.inherited()"), .text(".")]
            ),
            TestData(
                docCommentJSON: """
                {
                  "lines": [{
                    "text": "Authored abstract",
                    "range": {
                      "start": {"line": 1, "character": 4},
                      "end": {"line": 1, "character": 21}
                    }
                  }],
                  "module": "OtherModule",
                  "uri": "file://path/with spaces/to/file.swift"
                }
                """,
                expectedRenderedAbstract: [.text("Inherited from "), .codeVoice(code: "Module.Protocol.inherited()"), .text(".")]
            ),
            // Without the new module information
            TestData(
                docCommentJSON: """
                {
                  "lines": [{
                    "text": "Authored abstract",
                    "range": {
                      "start": {"line": 1, "character": 4},
                      "end": {"line": 1, "character": 21}
                    }
                  }]
                }
                """,
                expectedRenderedAbstract: [.text("Authored abstract")]
            ),
            TestData(
                docCommentJSON: """
                {
                  "lines": [{
                    "text": "Authored abstract",
                    "range": null
                  }]
                }
                """,
                expectedRenderedAbstract: [.text("Inherited from "), .codeVoice(code: "Module.Protocol.inherited()"), .text(".")]
            ),
        ]
            
        for testData in testData {
            let sgURL = Bundle.module.url(forResource: "TestBundle.docc/sidekit.symbols", withExtension: "json", subdirectory: "Test Bundles")!
         
            let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
                // Replace the out-of-bundle origin with a symbol from the same bundle but
                // from the MyKit module.
                var graph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: sgURL))
                
                graph.symbols["s:7SideKit0A5::SYNTHESIZED::inheritedFF"]?.docComment = try JSONDecoder().decode(SymbolGraph.LineList.self, from: testData.docCommentJSON.data(using: .utf8)!)
                
                try JSONEncoder().encode(graph)
                    .write(to: url.appendingPathComponent("sidekit.symbols.json"))
            })
            
            let myFuncReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass/Element/inherited()", sourceLanguage: .swift)
            let node = try context.entity(with: myFuncReference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            
            // Verify the doc extension was matched to the inherited symbol.
            do {
                var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
                let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode)
                
                // Verify the expected default abstract text.
                XCTAssertEqual(renderNode.abstract, testData.expectedRenderedAbstract)
            }
        }
    }
    
    /// Tests that we inherit docs when the feature is enabled.
    func testEnabledDocInheritance() throws {
        let bundleURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        let (_, bundle, context) = try loadBundle(from: bundleURL, configureContext: { context in
            context.externalMetadata.inheritDocs = true
        })

        // Verify that we don't reference resolve inherited docs.
        XCTAssertFalse(context.diagnosticEngine.problems.contains(where: { problem in
            problem.diagnostic.summary.contains("my-inherited-image.png")
        }))

        let myFuncReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass/Element/inherited()", sourceLanguage: .swift)
        let node = try context.entity(with: myFuncReference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        // Verify that by default we don't inherit docs and we generate default abstract.
        do {
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode)

            // Verify the expected default abstract text.
            XCTAssertEqual(renderNode.abstract, [.text("Inherited abstract.")])
            
            // Verify that there is a declaration section and a discussion section.
            XCTAssertEqual(renderNode.primaryContentSections.count, 2)
            guard renderNode.primaryContentSections.count == 2 else {
                return
            }
            XCTAssertTrue(renderNode.primaryContentSections[0] is DeclarationsRenderSection)

            // Verify the discussion was inherited.
            let discussion = try XCTUnwrap(renderNode.primaryContentSections[1] as? ContentRenderSection)
            XCTAssertEqual(discussion.content, [
                RenderBlockContent.heading(.init(level: 2, text: "Discussion", anchor: "discussion")),
                .paragraph(.init(inlineContent: [
                    .text("Inherited discussion. Missing: "),
                    .text("."),
                ])),
            ])
        }
    }
    
    // Verifies that undocumented symbol gets a nil abstract.
    func testNonDocumentedSymbolNilAbstract() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")

        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/globalFunction(_:considering:)", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)

        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode)

        // Verify that an undocumented symbol gets a nil abstract.
        XCTAssertNil(renderNode.abstract)
    }

    func testAsidesDecoding() throws {
        try assertRoundTripCoding(asidesStressTest)

        try assertJSONRepresentation(
            asidesStressTest,
            """
            [
            {"type":"aside", "style":"note", "name":"Note",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"This is a note."}]}]},
            {"type":"aside", "style":"tip", "name":"Tip",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"Here’s a tip."}]}]},
            {"type":"aside", "style":"important", "name":"Important",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"Keep this in mind."}]}]},
            {"type":"aside", "style":"experiment","name":"Experiment",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"Try this out."}]}]},
            {"type":"aside", "style":"warning", "name":"Warning",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"Watch out for this."}]}]},
            {"type":"aside", "style":"note", "name":"Attention",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"Head’s up!"}]}]},
            {"type":"aside", "style":"note", "name":"Author",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"I wrote this."}]}]},
            {"type":"aside", "style":"note", "name":"Authors",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"We wrote this."}]}]},
            {"type":"aside", "style":"note", "name":"Bug",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"This is wrong."}]}]},
            {"type":"aside", "style":"note", "name":"Complexity",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"This takes time."}]}]},
            {"type":"aside", "style":"note", "name":"Copyright",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"2021 Apple Inc."}]}]},
            {"type":"aside", "style":"note", "name":"Date",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"1 January 1970"}]}]},
            {"type":"aside", "style":"note", "name":"Invariant",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"This shouldn’t change."}]}]},
            {"type":"aside", "style":"note", "name":"Mutating Variant",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"This will change."}]}]},
            {"type":"aside", "style":"note", "name":"Non-Mutating Variant",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"This changes, but not in the data."}]}]},
            {"type":"aside", "style":"note", "name":"Postcondition",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"After calling, this should be true."}]}]},
            {"type":"aside", "style":"note", "name":"Precondition",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"Before calling, this should be true."}]}]},
            {"type":"aside", "style":"note", "name":"Remark",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"Something you should know."}]}]},
            {"type":"aside", "style":"note", "name":"Requires",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"This needs something."}]}]},
            {"type":"aside", "style":"note", "name":"Since",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"The beginning of time."}]}]},
            {"type":"aside", "style":"note", "name":"To Do",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"This needs work."}]}]},
            {"type":"aside", "style":"note", "name":"Version",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"3.1.4"}]}]},
            {"type":"aside", "style":"note", "name":"See Also",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"This other thing."}]}]},
            {"type":"aside", "style":"note", "name":"See Also",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"And this other thing."}]}]},
            {"type":"aside", "style":"note", "name":"Throws",
                "content": [{"type":"paragraph", "inlineContent":[{"type":"text", "text":"A serious error."}]}]},
            ]
            """)

        // While decoding, overwrite the style with the name, if both are specified. We expect the style's raw value
        // to be "Custom Title", not "important" in this example.
        try assertJSONRepresentation(
            RenderBlockContent.aside(
                .init(
                    style: .init(rawValue: "Custom Title"),
                    content: [.paragraph(.init(inlineContent: [.text("This is a custom title...")]))]
                )
            ),
            """
            {
              "type": "aside",
              "content": [
                {
                  "type": "paragraph",
                  "inlineContent": [
                    {
                      "type": "text",
                      "text": "This is a custom title..."
                    }
                  ]
                }
              ],
              "style": "important",
              "name": "Custom Title"
            }
            """)
            
        for style in Aside.Kind.allCases.map({ RenderBlockContent.AsideStyle(asideKind: $0) }) + [.init(displayName: "Custom Title")] {
            try assertRoundTripCoding(RenderBlockContent.aside(.init(style: style, content: [.paragraph(.init(inlineContent: [.text("This is a custom title...")]))])))
        }
    }

    /// Tests links to symbols that have deprecation summary in markdown appear deprecated.
    func testLinkToDeprecatedSymbolViaDirectiveIsDeprecated() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
            try """
            # ``MyKit/MyProtocol``
            @DeprecationSummary {
                This API is deprecated.
            }
            """.write(to: url.appendingPathComponent("documentation").appendingPathComponent("myprotocol.md"), atomically: true, encoding: .utf8)
        })
        
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift))
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode)
        
        let reference = try XCTUnwrap(renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyProtocol"] as? TopicRenderReference)
        XCTAssertTrue(reference.isDeprecated)
    }
    
    func testCustomSymbolDisplayNames() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
            try """
            # ``MyKit``
            
            @Metadata {
                @DisplayName("My custom conceptual name")
            }
            
            Abstract for `MyKit` with a custom conceptual display name.
            
            Discussion with reference to symbol with customized display name: ``MyKit/MyProtocol``
            
            ## Topics
            
            ### Example
            
            - ``MyKit/MyProtocol``
            """.write(to: url.appendingPathComponent("documentation").appendingPathComponent("mykit.md"), atomically: true, encoding: .utf8)
            
            try """
            # ``MyKit/MyProtocol``
            
            @Metadata {
                @DisplayName("My custom symbol name", style: symbol)
            }
            
            Abstract for `MyProtocol` with a custom symbol display name.
            """.write(to: url.appendingPathComponent("documentation").appendingPathComponent("myprotocol.md"), atomically: true, encoding: .utf8)
        })
         
        let moduleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
        let protocolReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyProtocol", sourceLanguage: .swift)
        let functionReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift)
        
        // Verify the MyKit module
        
        let moduleNode = try context.entity(with: moduleReference)
        XCTAssertEqual(moduleNode.name, .conceptual(title: "My custom conceptual name"))
        let moduleSymbol = try XCTUnwrap(moduleNode.semantic as? Symbol)
        
        XCTAssertEqual(moduleSymbol.title, "My custom conceptual name")
        for titleVariant in moduleSymbol.titleVariants.allValues {
            XCTAssertEqual(titleVariant.variant, "My custom conceptual name")
        }
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: moduleNode.reference)
        let moduleRenderNode = try XCTUnwrap(translator.visit(moduleSymbol) as? RenderNode)
        
        XCTAssertEqual(moduleRenderNode.metadata.title, "My custom conceptual name")
        for titleVariant in moduleRenderNode.metadata.titleVariants.variants {
            XCTAssertEqual(titleVariant.patch.description, "My custom conceptual name")
        }
        XCTAssertEqual(moduleRenderNode.navigatorTitle(), "My custom conceptual name")
        for navigatorVariant in moduleRenderNode.metadata.navigatorTitleVariants.variants {
            XCTAssertEqual(navigatorVariant.patch.description, "My custom conceptual name")
        }
        
        XCTAssertEqual((moduleRenderNode.metadata.modules ?? []).map { $0.name }, ["My custom conceptual name"])
        for moduleVariant in moduleRenderNode.metadata.modulesVariants.variants {
            XCTAssertEqual(moduleVariant.patch.description, "My custom conceptual name")
        }
        
        // Verify the MyProtocol node
        
        XCTAssertEqual((moduleRenderNode.references[protocolReference.absoluteString] as? TopicRenderReference)?.title, "My custom symbol name")
        
        let protocolNode = try context.entity(with: protocolReference)
        XCTAssertEqual(protocolNode.name, .symbol(name: "My custom symbol name"))
        let protocolSymbol = try XCTUnwrap(protocolNode.semantic as? Symbol)
        XCTAssertEqual(protocolSymbol.title, "My custom symbol name")
        
        let protocolRenderNode = try XCTUnwrap(translator.visit(protocolSymbol) as? RenderNode)
        
        XCTAssertEqual(protocolRenderNode.metadata.title, "My custom symbol name")
        for titleVariant in protocolRenderNode.metadata.titleVariants.variants {
            XCTAssertEqual(titleVariant.patch.description, "My custom symbol name")
        }
        XCTAssertEqual(protocolRenderNode.navigatorTitle(), "My custom symbol name")
        for navigatorVariant in protocolRenderNode.metadata.navigatorTitleVariants.variants {
            XCTAssertEqual(navigatorVariant.patch.description, "My custom symbol name")
        }
        
        XCTAssertEqual((protocolRenderNode.metadata.modules ?? []).map { $0.name }, ["My custom conceptual name"])
        for moduleVariant in protocolRenderNode.metadata.modulesVariants.variants {
            XCTAssertEqual(moduleVariant.patch.description, "My custom conceptual name")
        }
        
        // Verify the MyFunction node
        
        let functionNode = try context.entity(with: functionReference)
        let functionSymbol = try XCTUnwrap(functionNode.semantic as? Symbol)
        translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: functionNode.reference)
        let functionRenderNode = try XCTUnwrap(translator.visit(functionSymbol) as? RenderNode)
        XCTAssertTrue(functionRenderNode.metadata.modulesVariants.variants.isEmpty)
        // Test that the symbol name `MyKit` is not added as a related module.
        XCTAssertNil((functionRenderNode.metadata.modulesVariants.defaultValue!.first!.relatedModules))
        XCTAssertTrue(functionRenderNode.metadata.extendedModuleVariants.variants.isEmpty)
    }
    
    /// Tests that we correctly resolve links in automatic inherited API Collections.
    func testInheritedAPIGroupsInCollidedParents() throws {
        
        // Loads a symbol graph which has a property `b` and a struct `B` that
        // collide path-wise and `B` has inherited children:
        //
        //   ├ doc://com.test.TestBed/documentation/Minimal_docs/A/B-swift.struct
        //   │ ╰ doc://com.test.TestBed/documentation/Minimal_docs/A/B-swift.struct/Equatable-Implementations
        //   │   ╰ doc://com.test.TestBed/documentation/Minimal_docs/A/B-swift.struct/!=(_:_:)
        //   ╰ doc://com.test.TestBed/documentation/Minimal_docs/A/b-swift.property
        let (bundle, context) = try testBundleAndContext(named: "InheritedUnderCollision")

        // Verify that the inherited symbol got a path that accounts for the collision between
        // the struct `B` and the property `b`.
        
        let inheritedSymbolReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Minimal_docs/A/B-swift.struct/!=(_:_:)", sourceLanguage: .swift)
        XCTAssertNoThrow(try context.entity(with: inheritedSymbolReference))
        
        // Verify that the inherited symbol is automatically curated with its correct
        // reference path under the inherited symbols API collection
        
        let equatableImplementationsReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Minimal_docs/A/B-swift.struct/Equatable-Implementations", sourceLanguage: .swift)
        let equatableImplementationsNode = try context.entity(with: equatableImplementationsReference)
        let equatableImplementationsArticle = try XCTUnwrap(equatableImplementationsNode.semantic as? Article)
        let group = try XCTUnwrap(equatableImplementationsArticle.automaticTaskGroups.first)
        let groupReference = try XCTUnwrap(group.references.first)
        
        XCTAssertEqual(inheritedSymbolReference.absoluteString, groupReference.absoluteString)
    }
    
    func testVisitTutorialMediaWithoutExtension() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            try """
            @Tutorials(name: "Technology X") {
               @Intro(title: "Technology X") {
                  You'll learn all about Technology X.
                  @Video(source: introvideo, poster: introvideo )
               }
               @Chapter(name: "Chapter 1") {
                  @Image(source: intro.png, alt: intro )
                  @TutorialReference(tutorial: "doc:TestTutorial" )
               }
               @Chapter(name: "Chapter 2") {
                  @Image(source: introposter, alt: introposter )
                  @TutorialReference(tutorial: "doc:TestTutorial" )
               }
               @Chapter(name: "Chapter 3") {
                  @Image(source: introposter.png, alt: introposter )
                  @TutorialReference(tutorial: "doc:TestTutorial" )
               }
            }
            """.write(to: url.appendingPathComponent("TestOverview.tutorial"), atomically: true, encoding: .utf8)
        }
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/TestOverview", sourceLanguage: .swift))
        guard let technologyDirective = node.markup as? BlockDirective else {
            XCTFail("Unexpected document structure, tutorial not found as first child.")
            return
        }
        var problems = [Problem]()
        guard let technology = Technology(from: technologyDirective, source: nil, for: bundle, in: context, problems: &problems) else {
            XCTFail("Couldn't create technology from markup: \(problems)")
            return
        }
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = try XCTUnwrap(translator.visit(technology) as? RenderNode)
        XCTAssertEqual(renderNode.references.count, 5)
        XCTAssertNotNil(renderNode.references["doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial"] as? TopicRenderReference)
        XCTAssertNotNil(renderNode.references["doc://org.swift.docc.example/tutorials/TestOverview"] as? TopicRenderReference)
        XCTAssertNotNil(renderNode.references["introvideo.mp4"] as? VideoReference)
        XCTAssertNotNil(renderNode.references["intro.png"] as? ImageReference)
        XCTAssertNotNil(renderNode.references["introposter.png"] as? ImageReference)
        XCTAssertNil(renderNode.references["introvideo"] as? VideoReference)
        XCTAssertNil(renderNode.references["intro"] as? ImageReference)
        XCTAssertNil(renderNode.references["introposter"] as? ImageReference)
    }
    
    func testTopicsSectionWithAnonymousTopicGroup() throws {
        let (_, bundle, context) = try testBundleAndContext(
            copying: "TestBundle",
            configureBundle: { url in
                try """
                # Article
                
                Abstract.
                
                ## Topics
                
                - ``MyKit/MyProtocol``
                
                ### Named topic group
                
                - ``MyKit/MyClass``
                
                """.write(to: url.appendingPathComponent("article.md"), atomically: true, encoding: .utf8)
            }
        )
         
        let moduleReference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/Test-Bundle/article",
            sourceLanguage: .swift
        )
        
        let moduleNode = try context.entity(with: moduleReference)
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: moduleNode.reference)
        let moduleRenderNode = try XCTUnwrap(translator.visit(moduleNode.semantic) as? RenderNode)
        
        XCTAssertEqual(
            moduleRenderNode.topicSections.flatMap { taskGroup in
                [taskGroup.title] + taskGroup.identifiers
            },
            [
                nil,
                "doc://org.swift.docc.example/documentation/MyKit/MyProtocol",
                
                "Named topic group",
                "doc://org.swift.docc.example/documentation/MyKit/MyClass",
            ]
        )
    }
    
    func testTopicsSectionWithSingleAnonymousTopicGroup() throws {
        let (_, bundle, context) = try testBundleAndContext(
            copying: "TestBundle",
            configureBundle: { url in
                try """
                # Article
                
                Abstract.
                
                ## Topics
                
                - ``MyKit/MyProtocol``
                - ``MyKit/MyClass``
                
                """.write(to: url.appendingPathComponent("article.md"), atomically: true, encoding: .utf8)
            }
        )
         
        let articleReference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/Test-Bundle/article",
            sourceLanguage: .swift
        )
        
        let articleNode = try context.entity(with: articleReference)
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: articleNode.reference)
        let articleRenderNode = try XCTUnwrap(translator.visit(articleNode.semantic) as? RenderNode)
        
        XCTAssertEqual(
            articleRenderNode.topicSections.flatMap { taskGroup in
                [taskGroup.title] + taskGroup.identifiers
            },
            [
                nil,
                "doc://org.swift.docc.example/documentation/MyKit/MyProtocol",
                "doc://org.swift.docc.example/documentation/MyKit/MyClass",
            ]
        )
    }
    
    func testLanguageSpecificTopicSections() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "MixedLanguageFrameworkWithLanguageRefinements") { url in
            try """
            # ``MixedFramework/MyObjectiveCClassObjectiveCName``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            Provide different curation in different languages
            
            ## Topics
            
            ### Something Swift only
            
            This link is only for Swift
            
            @SupportedLanguage(swift)
            
            - ``MyObjectiveCClassSwiftName/myMethodSwiftName()``
            
            ### Something Objective-C only
                        
            This link is only for Objective-C
            
            @SupportedLanguage(objc)
            
            - ``MyObjectiveCClassObjectiveCName/myMethodWithArgument:``
            """.write(to: url.appendingPathComponent("MyObjectiveCClassObjectiveCName.md"), atomically: true, encoding: .utf8)
        }
        
        XCTAssert(context.problems.isEmpty, "\(context.problems.map(\.diagnostic.summary))")
        
        let reference = try XCTUnwrap(context.knownIdentifiers.first { $0.path.hasSuffix("MixedFramework/MyObjectiveCClassSwiftName") })
        
        let documentationNode = try context.entity(with: reference)
        XCTAssertEqual(documentationNode.availableVariantTraits.count, 2, "This page has Swift and Objective-C variants")
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = try converter.convert(documentationNode)
        
        let topicSectionsVariants = renderNode.topicSectionsVariants
        
        let swiftTopicSection = topicSectionsVariants.defaultValue
        
        XCTAssertEqual(swiftTopicSection.first?.title, "Something Swift only")
        XCTAssertEqual(swiftTopicSection.first?.abstract?.plainText, "This link is only for Swift")
        XCTAssertEqual(swiftTopicSection.first?.identifiers, [
            "doc://org.swift.MixedFramework/documentation/MixedFramework/MyObjectiveCClassSwiftName/myMethodSwiftName()"
        ])
        
        let objcTopicSection = topicSectionsVariants.value(for: [.interfaceLanguage("occ")])
        
        XCTAssertEqual(objcTopicSection.first?.title, "Something Objective-C only")
        XCTAssertEqual(objcTopicSection.first?.abstract?.plainText, "This link is only for Objective-C")
        XCTAssertEqual(objcTopicSection.first?.identifiers, [
            "doc://org.swift.MixedFramework/documentation/MixedFramework/MyObjectiveCClassSwiftName/myMethod(argument:)"
        ])
    }
    
    func testTopicSectionWithUnsupportedDirectives() throws {
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            TextFile(name: "root.md", utf8Content: """
                # Main article
                
                @Metadata {
                  @TechnologyRoot
                }
                
                ## Topics
                
                ### Something
                
                A mix of different directives that aren't supported in task groups.
                
                @Comment {
                  Some commented out markup
                }
                
                @SomeUnknownDirective()
                
                - <doc:article>
                """),
            
            TextFile(name: "article.md", utf8Content: """
                # An article
                """),
        ])
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try exampleDocumentation.write(inside: tempURL)
        
        let (_, bundle, context) = try loadBundle(from: bundleURL) { context in
            context.diagnosticEngine.consumers.sync({ $0.removeAll() })
        }
        
        let reference = try XCTUnwrap(context.soleRootModuleReference)
        
        let documentationNode = try context.entity(with: reference)
        XCTAssertEqual(documentationNode.availableVariantTraits.count, 1)
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = try converter.convert(documentationNode)
        
        let topicSection = renderNode.topicSectionsVariants.defaultValue
        
        XCTAssertEqual(topicSection.first?.title, "Something")
        XCTAssertEqual(topicSection.first?.abstract?.plainText, "A mix of different directives that aren’t supported in task groups.")
        XCTAssertEqual(topicSection.first?.identifiers, [
            "doc://unit-test/documentation/unit-test/article"
        ])
    }
    
    func testAutomaticCurationForRefinedSymbols() throws {
        let (_, bundle, context) = try testBundleAndContext(named: "GeometricalShapes")
        
        do {
            let root = try XCTUnwrap(context.soleRootModuleReference)
            let node = try context.entity(with: root)
            
            let converter = DocumentationNodeConverter(bundle: bundle, context: context)
            let renderNode = try converter.convert(node)
            
            let swiftTopicSections = renderNode.topicSectionsVariants.defaultValue
            XCTAssertEqual(swiftTopicSections.flatMap { [$0.title!] + $0.identifiers }, [
                "Structures",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle",
            ])
            
            let objcTopicSections = renderNode.topicSectionsVariants.value(for: .objectiveC)
            XCTAssertEqual(objcTopicSections.flatMap { [$0.title!] + $0.identifiers }, [
                "Structures",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle",
                
                "Variables",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/defaultRadius",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/null",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/zero",
                
                "Functions",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/debugDescription",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/init(string:)",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/intersects(_:)",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/isEmpty",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/isNull",
                "doc://GeometricalShapes/documentation/GeometricalShapes/TLACircleMake"
            ])
        }
        
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/GeometricalShapes/Circle", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            
            let converter = DocumentationNodeConverter(bundle: bundle, context: context)
            let renderNode = try converter.convert(node)
            
            let swiftTopicSections = renderNode.topicSectionsVariants.defaultValue
            XCTAssertEqual(swiftTopicSections.flatMap { [$0.title!] + $0.identifiers }, [
                "Initializers",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/init()",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/init(center:radius:)",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/init(string:)",
                
                "Instance Properties",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/center",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/debugDescription",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/isEmpty",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/isNull",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/radius",
                
                "Instance Methods", 
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/intersects(_:)",
                
                "Type Properties", 
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/defaultRadius",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/null",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/zero"
            ])
            
            let objcTopicSections = renderNode.topicSectionsVariants.value(for: .objectiveC)
            XCTAssertEqual(objcTopicSections.flatMap { [$0.title!] + $0.identifiers }, [
                "Instance Properties",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/center",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle/radius",
            ])
        }
    }
    
    func testThematicBreak() throws {
        let source = """

        ---

        """
        
        let markup = Document(parsing: source, options: .parseBlockDirectives)
        
        XCTAssertEqual(markup.childCount, 1)
        
        let (bundle, context) = try testBundleAndContext()
        
        var contentTranslator = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/TestThematicBreak", sourceLanguage: .swift))
        
        let renderContent = try XCTUnwrap(markup.children.reduce(into: [], { result, item in result.append(contentsOf: contentTranslator.visit(item))}) as? [RenderBlockContent])
        let expectedContent: [RenderBlockContent] = [
            .thematicBreak
        ]
        
        XCTAssertEqual(expectedContent, renderContent)
    }
}
