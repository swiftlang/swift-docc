# ``DocC/Image``

Displays an image in a tutorial.

- Parameters:
    - source: The name and file extension of an image in your Swift framework or package project. **(required)**
    - alt: Alternative text that describes the image to screen readers. **(required)**

## Overview

The `Image` directive displays an image in your tutorial. Provide the name of an image and alternative text that describes the image in sufficient detail so screen readers can read that text aloud for people who are blind or have low-vision.

```
@Image(source: "overview-hero.png", alt: "An illustration of a sleeping sloth, hanging from a tree branch.”)
````

Images can exist anywhere in your code base, but it's good practice to centralize them in a resources folder. You create this folder in your documentation catalog. Within your code base, image names must be unique. Images must be in *.png*, *.jpg*, *.jpeg*, *.svg*, or *.gif* format.

- Tip: To differentiate tutorial images from reference documentation images, you may wish to prefix image file names with tutorial\.

### Provide Image Variants

To ensure images render well on both standard and high-resolution displays, and in light and dark appearance modes, you can provide up to four versions of each image.

Use the following naming conventions for your image files:

- term Standard Light: *[filename].[extension]*, e.g. *filename.png*
- term High-Resolution Light: *[filename]@2x.[extension]*, e.g. *filename@2x.png*
- term Standard Dark: *[filename]~dark.[extension]*, e.g. *filename~dark.png*
- term High-Resolution Dark: *[filename]~dark@2x.[extension]*, e.g. *filename~dark@2x.png*

Exclude the resolution and appearance-variant suffixes when specifying an image name in the `source` parameter. For example, when you specify `@Image(source: "overview-hero.png", alt: " ... ")`, the appropriate variant automatically displays based on the reader's context. If the reader views the tutorial **on a display that has dark appearance mode** enabled, *overview-hero~dark@2x.png* is shown. At minimum, strive to provide high resolution variants **in light and dark appearance modes.** If you don't provide a certain variant, **the system displays the closest match.**

### Containing Elements

The following tutorial elements can include images.

* ``Chapter``
* ``Choice``
* ``ContentAndMedia``
* ``Intro``
* ``Step``
* ``Tutorial``
* ``Volume``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
