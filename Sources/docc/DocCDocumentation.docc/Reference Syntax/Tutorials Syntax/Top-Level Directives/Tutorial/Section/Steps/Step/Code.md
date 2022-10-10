# ``DocC/Code``

Defines the code for an individual step on a tutorial page.

- Parameters:
    - name: The file name and extension of the Swift code file that the reader edits in their project when performing the step. This name appears above the code of the step. **(required)**
    - file: The name and extension of the Swift file in which the code resides within your documentation catalog. The code appears next to the related step on the tutorial page. **(required)**
    - previousFile: The name and extension of the Swift file in which the previous step's code resides within your documentation catalog. DocC uses this file for comparison against the current step's code, so the reader can see what changed. By default, DocC automatically compares the current step's code against the previous step's code for differences. This parameter only needs a value if you want to override the default comparison and use a different previous file. **(optional)**
    - reset: A Boolean `true` or `false` value. Set this parameter to `true` to disable comparison against a previous step's code. **(optional)**

## Overview

Use a `Code` directive to display a code listing when the reader reaches a step on a tutorial page.

![A screenshot of an interactive coding step on a tutorial page. The step's text appears on the left. The code and a preview of the result appear on the right.](4)

Write the code listing in a `.swift` file in your Swift framework or package project. To help with organization, it's a good practice to create a folder in your code base's tutorial folder that contains all your code listing files. It's also recommended that you devise a naming convention for your code listing files to make them easy to find and reference. For example:

_[TutorialNameOrNumber]-[SectionNumber]-[StepNumber]-[DescriptiveName].swift_

In the `Code` directive, use the `file` parameter to list the file name and extension of your code listing file. When you build your tutorial, DocC extracts the code and shows it on the tutorial page.

Use the `name` parameter to indicate the name of the Swift file the reader edits in their own project when performing the step. The name appears above the code.

Add an ``Image`` directive to show a preview of what the reader sees after performing the step.

```
@Tutorial(time: 30) {
    
    ...
    
    @Section(title: "Add a customization view") {
        
        ...
        
        @Steps {

            ...

            @Step {
                Add the `sloth` parameter to initialize the `CustomizedSlothView` in the preview provider, and pass a new `Sloth` instance for the value.
                
                @Code(name: "CustomizedSlothView.swift", file: "01-creating-code-02-07.swift") {
                    @Image(source: "preview-01-creating-code-02-07.png", alt: "A portrait of a generic sloth displayed in the center of the canvas.")
                }
            }

            @Step {
                Set the preview provider sloth's `name` to `"Super Sloth"`, `color` to `.blue`, and `power` to `.ice`.
                
                @Code(name: "CustomizedSlothView.swift", file: "01-creating-code-02-08.swift") {
                    @Image(source: "preview-01-creating-code-02-08.png", alt: "A portrait of an ice sloth on top, followed by four power icons below. The power icons, clockwise from top left, include: ice, fire, wind, and lightning. The ice icon is selected.")
                }    
            
                ...
            }
        }
    }
}
```

### Showing Differences Between Steps

DocC automatically compares the code for each step against the code of the previous step, and highlights the differences on the tutorial page so the reader knows what to change in their own code. This automatic comparison doesn't happen on the first step of a section. You can force a comparison or override it for any step's code by using the `previousFile` parameter to denote a specific file for DocC to use for comparison. If you don't want to show any differences, provide the optional `reset` parameter and set it to `true`.

### Contained Elements

A code directive can contain the following items:

- term ``Image``: An image showing a preview of what the reader sees after performing the step. **(optional)**

### Containing Elements

The following items can include a code element:

- ``Step``

## Topics

### Previewing the Expected Result

- ``Image``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
