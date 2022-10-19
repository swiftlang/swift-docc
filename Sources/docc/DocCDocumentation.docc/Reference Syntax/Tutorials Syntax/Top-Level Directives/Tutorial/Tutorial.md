# ``DocC/Tutorial``

Displays a tutorial page that teaches your Swift framework or package APIs through interactive coding exercises.

- Parameters:
    - time: An integer value that represents the estimated time it takes to complete the tutorial, in minutes. **(optional)**
    - projectFiles: The name and extension of an archive in your code base, which the reader can download and use or reference while following the tutorial's steps. **(optional)**

## Overview

The `Tutorial` directive defines the structure of an individual tutorial page that teaches your Swift framework or package APIs through a series of interactive steps. Your tutorial can include one or more of these individual tutorial pages, and readers navigate to them from a table of contents page—defined by the ``Tutorials`` directive.

![A screenshot of the top portion of a tutorial page.](tutorial-page)

### Create the Tutorial File

Use a text editor to add a Tutorial file to your documentation catalog and ensure the filename ends in `.tutorial`. Copy and paste the template below into your editor.

```
@Tutorial(time: <#number#>) {
    @Intro(title: "<#text#>") {
        <#text#>
        
        @Image(source: <#file#>, alt: "<#accessible description#>")
    }
    
    @Section(title: "<#text#>") {
        @ContentAndMedia(layout: horizontal) {
            <#text#>
            
            @Image(source: <#file#>, alt: "<#accessible description#>")
        }
        
        @Steps {
            @Step {
                <#text#>
                @Image(source: <#file#>, alt: "<#accessible description#>")
            }
            
            @Step {
                <#text#>
                @Code(name: "<#display name#>", file: <#filename.swift#>)
            }
        }
    }
}
```

### Estimate Completion Time

You can give the reader an idea of how long the tutorial page might take to complete by providing an optional estimate in the `time` parameter. Completion time estimates help the reader understand how long they need to set aside to learn your APIs.

```
@Tutorial(time: 30) {

    ...

}
````

When you provide estimates on your individual tutorial pages, the introduction section on the table of contents page automatically calculates and displays a total-completion time estimate for the entire tutorial.

### Provide Source Material

If you need to add downloadable materials, like sample projects and code examples, for your tutorials, archive them and add them to your documentation catalog. Consider offering a base project to which the reader can add code as they work through the steps, as well as a finished project for comparison with their work.

Project files can reside anywhere in your documentation catalog, but it's good practice to centralize them in a Resources folder. You may want to create a tutorial-specific one if you created a tutorial folder in your documentation catalog.

To share project files with the reader, provide the archive's name and extension in the `projectFiles` parameter.

```
@Tutorial(time: 30, projectFiles: "SlothCreatorFiles.zip") {

    ...

}
````

### Add an Introduction

A tutorial page begins with an introduction section, defined by an ``Intro`` directive. The introduction is the first thing a reader sees on the page, so it needs to draw them into the content that follows and let them know what to expect. An introduction includes text and an image that serves as the section's background, or a link to an introduction video.

```
@Tutorial(time: 30) {
    @Intro(title: "Creating and Building a Swift Package") {
        This tutorial guides you through creating and building a Swift Package. Use the package to add your own re-usable classes and structures.
        
        @Image(source: "creating-intro.png", alt: "An image of the Swift logo.")
    }

    ...
    
}
````

### Add Sections of Steps

A tutorial page includes sets of steps the reader performs, and those steps are organized into logical sections. For example, a tutorial might include a section of steps that guides a reader through setting up a Swift package, and another section that covers adding a class to that package.

Define sections using the ``Section`` directive. You can optionally start with descriptive text and an image or video animation by using the ``ContentAndMedia`` directive. Once you define a section, you can include steps to perform coding tasks by using the ``Steps`` directive. See the ``Code`` directive to learn how to provide code for a step.

```
@Tutorial(time: 30) {
    @Intro(title: "Creating Custom Sloths") {
        
        ...

    }
    
    @Section(title: "Create a Swift Package in a new directory") {
        @ContentAndMedia(layout: "horizontal") {
            
            ...
            
        }
        
        @Steps {
            @Step {
                Create the directory.
                
                @Image(source: "placeholder-image.png", alt: "A screenshot showing the command to type in the terminal to create the directory.")
            }
            
            @Step {
                Create the Swift Package. 
                
                @Image(source: "placeholder-image.png", alt: "A screenshot showing the command to type in the terminal to create the Swift package.")
            }
            
            @Step {
                
                ...

            }
            
            @Step {

                ...

            }
        }
    }
    
    @Section(title: "Add a customization view") {
        @ContentAndMedia(layout: "horizontal") {

            ...

        }
        
        @Steps {
        
            ...

        }    
    }
}
````

### Check the Reader's Knowledge

At the end of a tutorial page, you can optionally use an ``Assessments`` directive to create a section that tests the reader's knowledge. An assessment section includes a set of multiple-choice questions. If the reader gets a question wrong, you can provide a hint that points them toward the correct answer so they can try again.

```
@Tutorial(time: 30) {
    @Intro(title: "Creating Custom Sloths") {
        
        ...

    }
    
    @Section(title: "Create a new project and add SlothCreator") {
        @ContentAndMedia(layout: "horizontal") {
            
            ...

        }
        
        @Steps {
            
            ...

        }
    }
    
    ...

    @Assessments {
        @MultipleChoice {
            What element did you use to add space around and between your views?

            @Choice(isCorrect: false) {
                A state variable.

                @Justification(reaction: "Try again!") {
                    Remember, it's something you used to arrange views vertically.
                }
            }

            @Choice(isCorrect: true) {
                A VStack with trailing padding.

                @Justification(reaction: "That's right!") {
                    A VStack arranges views in a vertical line.
                }
            }

            @Choice(isCorrect: false) {
              
              ...
              
            }
        }
    }
}
```

To see the creation of a simple tutorial project from start to finish, see <doc:building-an-interactive-tutorial>.

### Contained Elements

A tutorial page can contain the following items:

- term ``Intro``: Engaging introductory text and an image or video to display at the top of the page. **(required)**
- term ``Section``: A group of related steps. **(required)**
- term ``Assessments``: Assessments that test the reader's knowledge about the steps performed on the page. **(optional)**
- term ``Image``: An image that appears on the page. **(optional)**

## Topics

### Setting an Xcode Requirement

- ``XcodeRequirement``

### Providing an Introduction

- ``Intro``

### Displaying Tasks

- ``Section``

### Displaying Images

- ``Image``

### Testing Reader Knowledge

- ``Assessments``

## See Also

- <doc:building-an-interactive-tutorial>

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
