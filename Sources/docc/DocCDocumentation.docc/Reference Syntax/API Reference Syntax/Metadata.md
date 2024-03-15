# ``docc/Metadata``

Use metadata directives to instruct DocC how to build certain documentation files.

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

## Overview

Use the `Metadata` directive with other directives to configure how certain documentation files build. Place the directive after the documentation page's title. 

Use it with the ``DocumentationExtension`` directive to replace in-source documentation with the documentation extension file's content. 

```
# ``SlothCreator/Sloth``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}
```

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

Starting with version 5.11, use the `Metadata` directive with one or more ``Redirected`` directives
to add additional URLs for a page.
```
# ``SlothCreator``

@Metadata {
    @Redirected(from: "old/path/to/page")
    @Redirected(from: "another/old/path/to/page")
}
```

> Note: Starting with version 5.11, @Redirected is supported as a child directive of @Metadata. In
previous versions, @Redirected must be used as a top level directive.

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

### Specifying an Additional URL of a Page

- ``Redirected``

> Note: Starting with version 5.11, @Redirected is supported as a child directive of @Metadata. In
previous versions, @Redirected must be used as a top level directive.

<!-- Copyright (c) 2021-2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->
