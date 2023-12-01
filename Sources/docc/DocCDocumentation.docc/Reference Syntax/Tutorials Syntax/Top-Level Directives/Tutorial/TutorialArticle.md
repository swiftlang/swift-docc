# ``docc/Article``

Displays a tutorial article page that teaches a conceptual topic about your Swift framework or package.

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

- Parameters:
    - time: An integer value that represents the estimated time it takes to complete the tutorial, in minutes. **(optional)**

## Overview

The `Article` directive defines the structure of an individual tutorial article page that teaches a conceptual topic about your Swift framework or package. 

A tutorial article supports many of the same directives as a ``Tutorial`` directive but doesn't teach its content through interactive exercise.

### Contained Elements

A tutorial page can contain the following items:

- term ``Intro``: Engaging introductory text and an image or video to display at the top of the page. **(optional)**
- term ``ContentAndMedia``: A grouping that contains text and an image or video. At least one `ContentAndMedia` directive is required and must be the first element within a section. **(optional)**
- term ``Stack``: A set of horizontally arranged groupings of text and media. **(optional)**
- term ``Assessments``: Assessments that test the reader's knowledge about the content described in the article. **(optional)**
- term ``Image``: An image that appears on the page. **(optional)**

## Topics

### Providing an Introduction

- ``Intro``

### Customizing Page Layout

- ``ContentAndMedia``
- ``Stack``

### Displaying Images

- ``Image``

### Testing Reader Knowledge

- ``Assessments``

<!-- Copyright (c) 2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->
