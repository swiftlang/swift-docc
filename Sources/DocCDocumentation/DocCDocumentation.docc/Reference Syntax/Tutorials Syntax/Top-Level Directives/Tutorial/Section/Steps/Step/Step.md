# ``DocC/Step``

Defines an individual task the reader performs within a set of steps on a tutorial page.

## Overview

Use the `Step` directive to define a single task the reader performs within a set of steps  on a tutorial page. Provide text that explains what to do, and provide a code listing , an image, or a video that illustrates the step.

![A screenshot showing a step on a tutorial page. The step has instructional text and a corresponding image.](2-a)

    @Tutorial(time: 30) {
        @Intro(title: "Creating Custom Sloths") {
            
            ...

        }
        
        @Section(title: "Create a new folder and add SlothCreator") {
            @ContentAndMedia(layout: "horizontal") {
                
                ...
                
            }
            
            @Steps {
                @Step {
                    Create the folder.
                    
                    @Image(source: "placeholder-image.png", alt: "A screenshot using the `mkdir` command to create a folder to place SlothCreator in.")
                }
                
                ...
                                
            }
        }
    }

- Tip: Don't number steps. Steps are automatically numbered in the rendered documentation.

### Setting Context for a Step 

To provide additional context about the step, add text before or after the step.

![A screenshot showing a step on a tutorial page. The step is preceded with context-setting text.](2-b)

    The following steps display your customized sloth view in the preview.

    @Step {
        Add the `sloth` parameter to initialize the `CustomizedSlothView` in the preview provider, and pass a new `Sloth` instance for the value.
        
        @Code(name: "CustomizedSlothView.swift", file: 01-creating-code-02-07.swift) {
            @Image(source: preview-01-creating-code-02-07.png, alt: "A portrait of a generic sloth displayed in the center of the canvas.")
        }
    }

### Contained Elements

A step contains one the following items:

- term ``Code``: A code listing, and optionally a preview of the expected result, reader sees when they reach the step. **(optional)**
- term ``Image``: An image the reader sees when they reach the step. **(optional)**
- term ``Video``: A video the reader sees when they reach the step. **(optional)**

### Containing Elements

The following items can include a step:

- ``Steps``

## Topics

### Displaying Code

- ``Code``

### Displaying Media

- ``Image``
- ``Video``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
