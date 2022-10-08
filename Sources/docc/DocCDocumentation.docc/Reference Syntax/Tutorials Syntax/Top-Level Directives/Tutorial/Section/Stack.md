# ``DocC/Stack``

Displays set of horizontally arranged groupings that contain text and media in a section on a tutorial page.

## Overview

Use the Stack directive to horizontally arrange between one and three groupings of text and media (images or videos) in a section on a tutorial page.

```
@Tutorial(time: 30) {
    
    ...
    
    @Section(title: "Add a customization view") {
        @ContentAndMedia(layout: "horizontal") {
            Add the ability for users to customize sloths and select their powers.
            
            @Image(source: 01-creating-section2.png, alt: "An outline of a sloth surrounded by four power type icons. The power type icons are arranged in the following order, clockwise from the top: fire, wind, lightning, and ice.")
        }
        
        @Stack {
            @ContentAndMedia(layout: "horizontal") {
                ...
            }

            @ContentAndMedia(layout: "horizontal") {            
                ...            
            }

            @ContentAndMedia(layout: "horizontal") {
                ...
            }
        
        }            
        ...
 
    }
}
````

Example of a 1-column stack:

![A screenshot showing an example of a 1-column stack.](tutorial-stack-1col)

Example of a 2-column stack:

![A screenshot showing an example of a 2-column stack.](tutorial-stack-2col)

Example of a 3-column stack:

![A screenshot showing an example of a 3-column stack.](tutorial-stack-3col)

### Contained Elements

A stack contains the following items:

- term ``ContentAndMedia``: A grouping containing text and an image or a video. At least one is required `ContentAndMedia` element is required. **(optional)**

### Containing Elements

The following items can include a stack:

- ``Section``

## Topics

### Optional Directives

- ``ContentAndMedia``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
