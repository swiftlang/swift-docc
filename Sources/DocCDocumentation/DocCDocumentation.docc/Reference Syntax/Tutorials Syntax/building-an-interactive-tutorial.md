# Building an Interactive Tutorial

Construct a step-by-step guided learning experience for your Swift framework or package. 

## Overview

A tutorial expands your Swift framework or package's reference documentation with interactive educational content. Create a tutorial by adding a table of contents and individual tutorial pages that walk the reader through coding exercises that teach your APIs.

![Two diagrams representing different pages in a tutorial. On the left, a diagram of a blocked out table of contents page. On the right, a blocked out version of a tutorial page.](building-tutorial)

### Scope Your Tutorial

A good tutorial starts with a well-designed plan of what you're going to teach. When deciding what your tutorial covers, do the following:

* Define Your Audience. Decide whether you're targeting new developers or experienced programmers. Consider what skills you expect readers to have before they start working through the tutorial. Knowing your audience helps you write to their level of knowledge and experience.

* Define Teaching Goals. Consider what you need the reader be able to do after working through your tutorial. Outline everything you expect the reader to learn. Then, use your outline to structure the different parts of your tutorial.

* Define the Scope. Think about what the reader actually does to learn the concepts you defined. A tutorial needs to be engaging and produce a sense of accomplishment. Identify specific tasks the reader can perform and projects they can build.

### Prepare Your Code Project

In order to prepare your framework or package project for a tutorial, you need a documentation catalog. If your code base's folder doesn't have a documentation catalog, learn how to add one in <doc:documenting-a-swift-framework-or-package>. Inside the documentation catalog, add a folder for your tutorial content. By default, a documentation catalog includes a Resources folder. This is where you place tutorial images, code-listing files, and other assets.

### Add a Table of Contents Page

A table of contents page sets context and introduces the reader to your tutorial. It needs to provide enough information that the reader can gain a solid understanding of what your APIs do, before they start performing tutorial steps. The table of contents also organizes your tutorial pages into chapters so readers can browse and navigate to them.

Use a text editor and the following listing to create a table of contents file named `Table Of Contents.tutorial`.

```
@Tutorials(name: "Add the name of your tutorial here. This usually matches your framework name.") {
    @Intro(title: "Add a title for your introduction here.") {
        Add engaging introduction text here.
        
        @Image(source: "toc-introduction-image-filename.png", alt: "Add an accessible description for your image here.")
    }
    
    @Chapter(name: "Add a chapter title here.") {
        Add chapter text here.
        
        @Image(source: "chapter-image-filename-here.png", alt: "Add an accessible description for your image here.")
        
        @TutorialReference(tutorial: "doc:tutorial-page-file-name-here")
        @TutorialReference(tutorial: "doc:another-tutorial-page-file-name-here")
    }

    @Chapter(name: "Add the next chapter title here.") {
    }
}
````

The top level of the listing the includes a ``Tutorials`` directive. This directive and the directives it contains, define the structure of the page.

Rename the table of contents file and replace the placeholder content with your custom content. Use the ``Intro`` directive to introduce the reader to your tutorial through engaging text and imagery. Next, use ``Chapter`` directives to reference the step-by-step pages.

For more information about table of contents pages, see ``Tutorials``.

### Add Step-By-Step Pages

Tutorial pages provide instructions that walk through using your APIs in realistic ways. A tutorial project can include a single tutorial page, or many. Create a new tutorial page using your favorite editor. Give the file a name and add the `.tutorial` extension, then copy the following template into the file.

```
@Tutorial(time: number) {
    @Intro(title: "Add the name of your title here.") {
        Add engaging introduction text here.
        
        @Image(source: "intro-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
    }
    
    @Section(title: "Add the name of your section here.") {
        @ContentAndMedia(layout: horizontal) {
            Add engaging section text here.
            
            @Image(source: "section-image-filename-here.jpg", alt: "Add an accessible description for your image here.")    
        }
        
        @Steps {
            @Step {
                Add engaging step 1 text here.

                @Image(source: "step-1-image-filename-here.jpg", alt: "Add an accessible description for your step here.")
            }
            
            @Step {
                Add code for step 1 here.

                @Code(name: "code-display-name-here", file: "step-1-code-image-filename-here.jpg")
            }
        }
    }
}
```

Replace the placeholders with your custom content. Use the ``Intro`` directive to introduce the reader to the page's content, ``Steps`` directives to define steps the reader follows, and ``Section`` directives to organize the steps into related groups. For example, your tutorial might include a section of steps that walks through creating something, and another section that walks through customizing it. At the end of each tutorial page, you can optionally use an ``Assessments`` directive to test the reader's knowledge. See the ``Code`` directive to learn how to provide code for a step.

```
@Tutorial(time: 20) {
    @Intro(title: "Add a title for your tutorial page here.") {
        Add engaging introduction text here.
        
        @Image(source: "tutorial-introduction-image-filename.png", alt: "Add an accessible description for your image here.")
    }
    
    @Section(title: "Add a section title here") {
        @ContentAndMedia(layout: "horizontal") {
            Add some content here to introduce the steps that follow.
            
            @Image(source: "section-image-filename.png", alt: "Add an accessible description for your image here.")
        }
        
        @Steps {
            @Step {
                Provide text for a step here.
                @Image(source: "step1-image-filename.png", alt: "Add an accessible description for your image here.")
            }
            @Step {
                Provide text for another step here.
                @Image(source: "step2-image-filename.png", alt: "Add an accessible description for your image here.")
            }
        }
    }

    @Assessments {
        @MultipleChoice {
            Add a question to test the reader's knowledge here.

            @Choice(isCorrect: false) {
                Add an incorrect answer here.

                @Justification(reaction: "Try again!") {
                    Add a hint that helps direct the reader to the right answer.
                }
            }

            @Choice(isCorrect: true) {
                Add the correct answer here.

                @Justification(reaction: "That's right!") {
                    Add some text that reinforces the right answer.
                }
            }

            @Choice(isCorrect: false) {
                Add another incorrect answer here.

                @Justification(reaction: "Try again!") {
                    Add another hint that helps direct the reader to the right answer.
                }
            }
        }
    }
}
```

Repeat the process for any additional tutorial pages, and remember to add each page you create to the table of contents.

For more information about tutorial pages, see ``Tutorial``.

### Reference Images and Videos

Add any images and videos that you reference throughout your tutorial to the Resources folder of your documentation catalog. Because DocC references these media files by name, their names must be unique. See ``Image`` and ``Video`` for supported media file formats, variants, and naming conventions.

- Tip: To differentiate tutorial media from reference documentation media, you can add a prefix like _tutorial\__ to your media files.

### View Your Tutorial

To view your tutorial, invoke the following command to compile it:

```
docc preview MyPackage.docc --fallback-display-name MyPackage --fallback-bundle-identifier com.example.MyPackage --fallback-bundle-version 1
```

DocC compiles your documentation catalog and generates the tutorial. Copy the URL from the terminal and paste it into your browser to view the tutorial.


Learn how to share your documentation in <doc:distributing-documentation-to-other-developers>.

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
