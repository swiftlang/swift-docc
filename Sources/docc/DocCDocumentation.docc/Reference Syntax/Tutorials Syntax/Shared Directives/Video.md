# ``DocC/Video``

Displays a video in a tutorial.

- Parameters:
    - source: The name and file extension of a video in your Swift framework or package project. **(required)**
    - poster: The name and file extension of an image in your Swift framework or package project. This image serves as a poster image for the video and shows when the video isn't playing. **(required)**


## Overview

The `Video` directive displays a video in your tutorial. Provide the name of a video and the name of a poster image to show when the video isn't playing.

```
@Video(source: "sloth-smiling.mp4", poster: "happy-sloth-frame.png")
````

Videos and poster images can exist anywhere in your code base, but it's good practice to centralize them in a resources folder. You create a resources` folder in your documentation catalog.

Within your code base, media file names must be unique. Videos must be in *.mov* or *.mp4* format. Poster images must be in *.png*, *.jpg*, *.jpeg*, *.svg*, or *.gif* format.

- Tip: To differentiate tutorial media files from reference documentation media files, you may wish to prefix media file names with tutorial\.

### Provide Poster Image Variants

To ensure poster images look great on both standard and high-resolution displays, and in light and dark appearance modes, you can provide up to four versions of each image.

Use the following naming conventions for poster image files:

- term Standard Light: *[filename].[extension]*, e.g. *filename.png*
- term High-Resolution Light: *[filename]@2x.[extension]*, e.g. *filename@2x.png*
- term Standard Dark: *[filename]~dark.[extension]*, e.g. *filename~dark.png*
- term High-Resolution Dark: *[filename]~dark@2x.[extension]*, e.g. *filename~dark@2x.png*

Exclude the resolution and appearance variant suffixes when specifying an image name in the `poster` parameter. For example, when you specify `@Video(source: "sloth-smiling.mp4", poster: "happy-sloth-frame.png")`, the appropriate variant automatically displays based on the reader's context. If the reader views the tutorial on a high-resolution display with a dark appearance mode enabled, *happy-sloth-frame~dark@2x.png* is shown. At minimum, strive to provide high-resolution variants in light and dark appearance modes. If you don't provide a certain variant, the system displays the closest match.

### Containing Elements

The following tutorial elements can include videos.

* ``ContentAndMedia``
* ``Intro``
* ``Step``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
