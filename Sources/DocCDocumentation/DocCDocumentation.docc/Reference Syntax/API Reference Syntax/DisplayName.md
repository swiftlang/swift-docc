# ``DocC/DisplayName``

Configures a symbol's documentation page to use a custom display name.

## Overview

Place the `DisplayName` directive within a `Metadata` directive to configure a symbol's documentation page to use a custom display name.

```
# ``SlothCreator``

@Metadata {
    @DisplayName("Sloth Creator")
}
```

The custom name will appear as the main header for that page, in the navigator hierarchy, in the breadcrumbs for the customized symbols and its child symbols, and in the link text for symbol links to that symbol. Customizing the title of a symbol page does not alter the URL of that page.

By default, customized symbol display names are "conceptual", meaning that they render without a monospaced text style. To customize a symbol's display name and keep the monospaced text style, specify `symbol` for the optional `style` argument:

```
# ``SlothCreator``

@Metadata {
    @DisplayName("Sloth Creator", style: symbol)
}
```

Adding a `DisplayName` directive to a non-symbol page will result in a warning. 

### Containing Elements

The following items can include a display name element:

- ``Metadata``

<!-- Copyright (c) 2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
