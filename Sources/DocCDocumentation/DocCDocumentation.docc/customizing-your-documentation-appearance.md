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

As a simple example, the following configuration would update the main
background fill color to `"rebeccapurple"` in both "Light Mode" and "Dark Mode"
by changing the value of the CSS property to `--color-fill: "rebeccapurple"`.

```json
{
  "theme": {
    "color": {
      "fill": "rebeccapurple"
    }
  }
}
```

Note that any valid CSS color value could be used. Also, if you wanted to update
a color and have it differ in "Light Mode" and "Dark Mode", you could
alternatively specify an object with `"light"` and `"dark"` values like so:

```json
{
  "theme": {
    "color": {
      "fill": {
        "dark": "rgba(0, 0, 0, 0)",
        "light": "#fff
      }
    }
  }
}
```

### Fonts

Coming soon

### Element Borders

Coming soon

### Metadata and Feature Flags

Coming soon

[1]: https://github.com/apple/swift-docc/blob/main/Sources/SwiftDocC/SwiftDocC.docc/Resources/ThemeSettings.spec.json
[2]: https://drafts.csswg.org/css-variables/

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
