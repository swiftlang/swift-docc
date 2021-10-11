# ``DocC/ContentAndMedia``

Displays a grouping that contains text and an image or a video in a section on a tutorial page.

## Overview

Use a `ContentAndMedia` directive within a ``Section`` or ``Stack`` directive to display a grouping that contains text and an image or a video. Set the `layout` parameter's value to `"horizontal"`. Then, provide one or more paragraphs of text, followed by an ``Image`` or ``Video`` directive.

```
@Tutorial(time: 30) {
    
    ...
    
    @Section(title: "Add a customization view") {
        @ContentAndMedia(layout: "horizontal") {
            Add the ability for users to customize sloths and select their powers.
            
            @Image(source: 01-creating-section2.png, alt: "An outline of a sloth surrounded by four power type icons. The power type icons are arranged in the following order, clockwise from the top: fire, wind, lightning, and ice.")
        }
            
        ...
 
    }
}
````

### Contained Elements

A content and media element must contain one of the following items:

- term ``Image``: An image to display. **(optional)**
- term ``Video``: A video to display. **(optional)**

### Containing Elements

The following items can include a content and media element:

- ``Section``
- ``Stack``

## Topics

### Displaying Media

- ``Image``
- ``Video``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
