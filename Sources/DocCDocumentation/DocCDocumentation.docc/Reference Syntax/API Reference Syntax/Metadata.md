# ``DocC/Metadata``

Use metadata directives to instruct DocC how to build certain documentation files.

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
````

### Contained Elements

A metadata element must contain one of the following items:

- term ``DocumentationExtension``: Defines whether the content in a documentation extension file amends or replaces in-source documentation. **(optional)**
- term ``TechnologyRoot``: Configures a documentation page that's not associated with a particular framework to appear as a top-level page. **(optional)**
- term ``DisplayName``: Configures a symbol's documentation page to use a custom display name. **(optional)**

## Topics

### Extending or Overriding Source Documentation

- ``DocumentationExtension``

### Creating a Top-Level Technology Page

- ``TechnologyRoot``

### Customizing the Presentation of a Symbol Page

- ``DisplayName``

<!-- Copyright (c) 2021-2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
