# Adding Images to Your Content

Elevate your content's visual appeal by adding images.

## Overview

DocC extends Markdown's image support so you can provide appearance and 
display scale-aware versions of an image. You use specific components to create image filenames, and DocC uses the most appropriate version of the image when displaying your documentation.

![An image of a filename that's split into four labeled sections to highlight the individual components. From left to right, the components are the image name, the appearance mode, the display scale, and the file extension.](docc-image-filename)

| Component | Description |
| --- | --- |
| Image name | **Required**. Identifies the image within the documentation catalog. The name must be unique across all images in the catalog, even if you store them in separate folders. |
| Appearance | **Optional**. Identifies the appearance mode in which DocC uses the image. Add `~dark` directly after the image name to identify the image as a dark mode variant. |
| Display scale | **Optional**. Identifies the display scale at which DocC uses the image. Possible values are `@1x`, `@2x`, and `@3x`. When specifying a display scale, add it directly before the file extension. |
| File extension | **Required**. Identifies the type of image. The supported file extensions are `png`, `jpg`, `jpeg`, `svg` and `gif`. |

> Tip: To best support your readers, provide images in standard resolution and `@2x` scale.

For example, the following are all valid DocC image filenames:

- term `sloth.png`: An image that's independent of all appearance modes and display scales.
- term `sloth~dark.png`: An image that's specific to dark mode, but is display-scale independent.
- term `sloth~dark@2x.png`: An image that's specific to dark mode and the 2x display scale.

> Important: Include the image files in your documentation catalog. For more information, see <doc:documenting-a-swift-framework-or-package>.

To add an image, use an exclamation mark (`!`), a set of brackets 
(`[]`), and a set of parentheses (`()`).

Within the brackets, add a description of the image. This text, otherwise known as _alternative text_, is used by screen readers for people who have vision difficulties. Provide enough detail to describe the image so that people can understand what the image shows.  

Within the parentheses, include only the image name. Omit the appearance, 
display scale, and file extension components. Don't include the path to the 
image.

```markdown
![A sloth hanging off a tree.](sloth)
```

<!-- Copyright (c) 2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->
