# ``docc/TitleHeading``

A directive that specifies a title heading for a given documentation page.

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

- Parameters:
    - heading: The text for the custom title heading.

## Overview

Place the `TitleHeading` directive within a `Metadata` directive to configure a documentation page to show a custom title heading. Custom title headings, along with custom [page icons](doc:PageImage) and [page colors](doc:PageColor), allow for the creation of custom kinds of pages beyond just articles.

A title heading is also known as a page eyebrow or kicker.

```
# ``SlothCreator``

@Metadata {
    @TitleHeading("Release Notes")
}
```

A custom title heading appears in place of the page kind at the top of the page.
### Containing Elements

The following items can include a title heading element:

@Links(visualStyle: list) {
   - ``Metadata``
}

<!-- Copyright (c) 2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->
