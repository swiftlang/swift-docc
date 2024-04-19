# Adding Feature Flags

Develop experimental features by adding feature flags.

## Overview

When developing a new feature in Swift-DocC, it's recommended to make it optional while it's being
actively developed by creating a command-line flag that enables the new behavior. This flag can then
be used to set a flag in the ``FeatureFlags``' ``FeatureFlags/current`` instance, which is then
available for the rest of the compilation process.

### The FeatureFlags structure

Feature flags are defined in the ``FeatureFlags`` structure. This type has a static
``FeatureFlags/current`` property that contains a global instance of the flags that can be accessed
throughout the compiler. When adding a flag property to this struct, give it a reasonable default
value so that the default initializer can be used.

### Feature flags on the command line

Command-line feature flags live in the `Docc.Convert.FeatureFlagOptions` in `SwiftDocCUtilities`.
This type implements the `ParsableArguments` protocol from Swift Argument Parser to create an option
group for the `convert` and `preview` commands.

These options are then handled in `ConvertAction.init(fromConvertCommand:)`, still in
`SwiftDocCUtilities`, where they are written into the global feature flags ``FeatureFlags/current``
instance, which can then be used during the compilation process.

### Feature flags in Info.plist

A subset of feature flags can affect how a documentation bundle is authored. For example, the
experimental overloaded symbol presentation can affect how a bundle curates its symbols due to the 
creation of overload group pages. These flags should also be added to the
``DocumentationBundle/Info/BundleFeatureFlags`` type, so that they can be parsed out of a bundle's
Info.plist.

Feature flags that are loaded from an Info.plist file are saved into the global feature flags while
the bundle is being registered. To ensure that your new feature flag is properly loaded, update the
``FeatureFlags/loadFlagsFromBundle(_:)`` method to load your new field into the global flags.

<!-- Copyright (c) 2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->
