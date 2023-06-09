# ``docc/TitleHeading``

Configures a symbol's documentation page and any references to that page to show a custom title heading instead of the default (page kind).

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

- Parameters:
    - headingText: The text for the custom title heading.

## Overview

Place the `TitleHeading` directive within a `Metadata` directive to configure a symbol's documentation page to show a custom title heading. This allows for the creation of custom kinds of pages beyond just articles.

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
