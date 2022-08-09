# Customizing Your Documentation Appearance

Customize the look and feel of your documentation webpages.

## Overview

By default, rendered documentation webpages produced by DocC come with a default
visual styling. If you wish, you may make adjustments to this styling by adding
an optional `theme-settings.json` file to the root of your documentation catalog
with some configuration. This file is used to customize various things like
colors and fonts.  You can even make changes to the way that specific elements
appear, like buttons, code listings, and asides. Additionally, some metadata for
the website can be configured in this file, and it can also be used to opt in or
opt out of certain default rendering behavior.

If you're curious about the full capabilities of the `theme-settings.json` file,
you can check out the latest Open API specification for the it [here][1], which
documents all valid settings that could be present.

Let's walk through some basic examples of customizing the appearance of
documentation now.

### Colors

DocC-Render utilizes [CSS custom properties][2] (CSS variables) to define the
various colors that are used throughout the HTML elements of rendered
documentation. Any key/value in the `theme.color` object of
`theme-settings.json` will either update an existing color property used in the
renderer or add a new one that could be referenced by existing ones.

**Example**

As a simple example, the following configuration would update the background
fill color for the "documentation intro" element to `"rebeccapurple"` by
changing the value of the CSS property to `--color-documentation-intro-fill:
"rebeccapurple"`.

```json
{
  "theme": {
    "color": {
      "documentation-intro-fill": "rebeccapurple"
    }
  }
}
```

![A screenshot of the documentation intro element with a purple background color](theme-screenshot-01.png)

**Example**

Note that any valid CSS color value could be used. Here is a more advanced
example which demonstrates how specialized dark and light versions of the main
background fill and nav colors could be defined as varying lightness percentages
of a green hue.

```json
{
  "theme": {
    "color": {
      "hue-green": "120",
      "fill": {
        "dark": "hsl(var(--color-hue-green), 100%, 10%)",
        "light": "hsl(var(--color-hue-green), 100%, 90%)"
      },
      "fill-secondary": {
        "dark": "hsl(var(--color-hue-green), 100%, 20%)",
        "light": "hsl(var(--color-hue-green), 100%, 80%)"
      },
      "nav-solid-background": "var(--color-fill)"
    }
  }
}
```

![A screenshot of the green page background in dark mode](theme-screenshot-02.png)

![A screenshot of the green page background in light mode](theme-screenshot-03.png)

As a general rule, the default color properties provided by DocC-Render assumes
a naming convention where "fill" colors are used for backgrounds and "figure"
colors are used for foreground colors, like text.

> Tip:
> For a more complete example of a fully customized documentation website, you
> can check out [this fork][3] of the DocC documentation that is using this
> [theme-settings.json file][4].

### Fonts

Coming soon

### Element Borders

Coming soon

### Metadata and Feature Flags

Coming soon

[1]: https://github.com/apple/swift-docc/blob/main/Sources/SwiftDocC/SwiftDocC.docc/Resources/ThemeSettings.spec.json
[2]: https://drafts.csswg.org/css-variables/
[3]: https://mportiz08.github.io/swift-docc/documentation/docc
[4]: https://mportiz08.github.io/swift-docc/theme-settings.json

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
