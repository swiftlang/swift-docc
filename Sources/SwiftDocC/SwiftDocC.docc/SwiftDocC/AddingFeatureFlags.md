# Adding Feature Flags

Develop experimental features by adding feature flags.

## Overview

Make new features in Swift-DocC optional during active development by creating a command-line flag that enables the new behavior. 
Then pass a ``FeatureFlags`` value, or just one of its properties, to the code that needs to check that feature flag.

### The FeatureFlags structure

Feature flags are defined in the ``FeatureFlags`` structure.
When adding a flag property to this structure, specify a default value on the property instead of adding a parameters to the only (parameterless) initializer.
This way, a feature flag value created using `FeatureFlags()` has all flags set to their default values.

### Feature flags on the command line

Command-line feature flags live in the `Docc.Convert.FeatureFlagOptions` in `DocCCommandLine`.
This type implements the `ParsableArguments` protocol from Swift Argument Parser to create an option
group for the `convert` and `preview` commands.

`ConvertAction.init(fromConvertCommand:)`, still in `DocCCommandLine`, then transforms these parsed flags into a `FeatureFlags` value. 
The `ConvertAction` stores the newly created feature flags in the ``DocumentationContext/Configuration/featureFlags`` property of its `configuration`. 
The `ConvertAction` uses this configuration, and its feature flag information, to create the ``DocumentationContext`` which passes the feature flags to all the places that need to check them.

### Feature flags in Info.plist

Some documentation is authored with the expectation that it's always built with certain feature flags enabled and may not look or behave as intended without those flags.
For example, documentation that's organized based on the experimental overloaded symbol presentation flag can have a rather different organization without that flag,
making it harder for readers to navigate the documentation and find related API. 

If you add a feature flag like this, you should also add a corresponding flag to the ``DocumentationBundle/Info/BundleFeatureFlags`` type, 
so that flag can be specified from a documentation catalog's Info.plist.
The value from the catalog's Info.plist overrides any value that the developer may specify using a command line flag. 

The ``DocumentationContext`` calls the ``FeatureFlags/loadFlagsFromBundle(_:)`` method to override the feature flags it got from the convert action with those decoded from the Info.plist.
Update this method to ensure that your new flag properly overrides the values from the convert action.

<!-- Copyright (c) 2024-2026 Apple Inc and the Swift Project authors. All Rights Reserved. -->
