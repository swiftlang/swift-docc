# ``DocC/DisplayName``

Configures a symbol's documentation page and any references to that page to show a custom name instead of the symbol name.

- Parameters:
    - style: The text style used to format the symbol's display name. A value of `conceptual` (the default) denotes a plain text style that's not monospaced. A value of `symbol` denotes a monospaced text style. **(optional)**

## Overview

Place the `DisplayName` directive within a `Metadata` directive to configure a symbol's documentation page and any references to that page to show a custom name.

```
# ``SlothCreator``

@Metadata {
    @DisplayName("Sloth Creator")
}
```

A custom display name appears in place of the symbol's name in the following locations:

- The main header on the symbol page
- The navigator hierarchy
- Breadcrumbs for the symbol page and its child symbol pages 
- Link text anywhere that includes a link to the symbol page

> Note: Customizing the name of a symbol page doesn't alter the page's URL.

By default, a custom display name renders without a monospaced text style. To retain the monospaced text style that's typically used when referencing APIs, specify a value of `symbol` for the optional `style` parameter:

```
# ``SlothCreator``

@Metadata {
    @DisplayName("Sloth Creator", style: symbol)
}
```

> Note: Adding a `DisplayName` directive to a non-symbol page results in a warning. 

### Containing Elements

The following items can include a display name element:

- ``Metadata``

<!-- Copyright (c) 2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
