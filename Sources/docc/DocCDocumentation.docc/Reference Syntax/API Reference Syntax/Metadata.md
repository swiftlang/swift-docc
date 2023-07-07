# ``docc/Metadata``

Use metadata directives to instruct DocC how to build certain documentation files.

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

## Overview

Use the `Metadata` directive with other directives to configure how certain documentation files build. Place the directive after the documentation page's title. Use it with the ``DocumentationExtension`` directive to indicate whether content in a documentation extension file amends or replaces in-source documentation.

```
# ``SlothCreator/Sloth``

@Metadata {
    @DocumentationExtension(mergeBehavior: append)
}
````

Use the `Metadata` directive with the ``TechnologyRoot`` directive to configure a documentation page that's not associated with a particular framework, so that page appears as a top-level page.

Use the `Metadata` directive with the ``DisplayName`` directive to configure a symbol's documentation page to use a custom display name.

```
# ``SlothCreator``

@Metadata {
    @DisplayName("Sloth Creator")
}
```

Use the `Metadata` directive with the ``TitleHeading`` directive to configure the text of a page's title heading.

```
# ``SlothCreator``

@Metadata {
    @TitleHeading("Release Notes")
}
```

## Topics

### Extending or Overriding Source Documentation

- ``DocumentationExtension``

### Creating a Top-Level Technology Page

- ``TechnologyRoot``

### Customizing the Presentation of a Page

- ``DisplayName``
- ``PageImage``
- ``PageKind``
- ``PageColor``
- ``CallToAction``
- ``TitleHeading``

### Customizing the Languages of an Article

- ``SupportedLanguage``

### Customizing the Availability Information of a Page

- ``Available``

<!-- Copyright (c) 2021-2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->
