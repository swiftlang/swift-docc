# Indicating Feature Availability to Tools

Add features to DocC and indicate the feature's availability to other tools.

Over time as we develop new features in DocC we also add, update, or remove the flags and options that the `docc` executable accepts. So that other tools can know what flags and options a certain version of the `docc` executable accepts, we add new entries in the "features.json" file.

## Adding a New Feature

When adding a new collection of command line flags or options to the `docc` executable that relate to some new feature, add a new entry to the "feature.json" file that name the new feature. For example:

```json
{
  "features": [
    {
      "name": "name-of-first-feature"
    },
    {
      "name": "name-of-second-feature"
    }
  ]
}
```

> Note: Use a single entry for multiple related command line flags and options if they are all added in the same build.

## Checking what Features DocC Supports

In a Swift toolchain, the `docc` executable is installed at `usr/bin/docc`. In the same toolchain, the "features.json" file is installed at `usr/share/docc/features.json`.

Tools that call the `docc` executable from a Swift toolchain can read the "features.json" file to check if a specific feature is available in that build.

> Note: The feature entry describes the feature name and doesn't list what command line flags or options that feature corresponds to.

<!-- Copyright (c) 2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->
