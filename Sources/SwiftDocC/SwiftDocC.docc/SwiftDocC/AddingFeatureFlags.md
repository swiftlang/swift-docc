# Adding Feature Flags

Develop experimental features by adding feature flags.

## Overview

Make new features in Swift-DocC optional during active development by creating a command-line flag that
enables the new behavior. Then set the new flag in the ``FeatureFlags``' ``FeatureFlags/current`` instance,
making it available for the rest of the compilation process.

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

A subset of feature flags can affect how you write documentation. 
For example, the experimental overloaded symbol presentation can affect how you curate symbols due to the creation of overload group pages. 
Feature flags like this can be defined in the ``DocumentationContext/Inputs/Info/BundleFeatureFlags`` the, so that they can be parsed out of a documentation catalog's Info.plist file.

Feature flags that are loaded from an Info.plist file are saved into the global ``FeatureFlags/current`` feature flags during the context registration. 
To ensure that your new feature flag is properly loaded, update the ``FeatureFlags/loadFlagsFromBundle(_:)`` method to load your new field into the global ``FeatureFlags/current`` flags.

<!-- Copyright (c) 2024-2025 Apple Inc and the Swift Project authors. All Rights Reserved. -->
