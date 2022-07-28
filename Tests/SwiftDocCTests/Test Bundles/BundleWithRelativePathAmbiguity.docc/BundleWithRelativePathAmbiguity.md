# ``BundleWithRelativePathAmbiguity``

This bundle contains external symbols of the dependency module and local extensions to external symbols where some cannot be referenced unambigously.

## Overview

This bundle tests path resolution in a combined documentation archive of the module ``BundleWithRelativePathAmbiguity`` and its ``/Dependency``. The main bundle ``BundleWithRelativePathAmbiguity`` extends its ``/Dependency``, thus many of the types from ``/Dependency`` have Extended Type Pages in ``BundleWithRelativePathAmbiguity``. Since this document is part of ``BundleWithRelativePathAmbiguity``, ambiguous relative paths should always resolve to the Extended Type Pages and not the original type pages from the external module's documentation.

Absolute references can be used to unambigously refer to the pages in the external module's documentation in ambiguous situations. While one could also use the fully qualified URI including the bundle identifier, the shorthand syntax with a leading slash is the preferred way to go.

### Module Pages

#### `/BundleWithRelativePathAmbiguity`

``BundleWithRelativePathAmbiguity`` is the main module and can therefore be referenced using all of the following:
- ``BundleWithRelativePathAmbiguity`` (relative)
- ``/BundleWithRelativePathAmbiguity`` (absolute, shorthand)
- ``doc://org.swift.docc.example/documentation/BundleWithRelativePathAmbiguity`` (absolute, fully qualified)

#### `/Dependency`

``/Dependency`` is the original module page in the dependency's documentation and can therefore only be referenced absolutely:
- ``/Dependency`` (absolute, shorthand)
- ``doc://org.swift.docc.example/documentation/Dependency`` (absolute, fully qualified)

### Extended Module Pages

#### `/BundleWithRelativePathAmbiguity/Dependency`

``Dependency`` is the Extended Module Page for the dependency module in the main module's documentation. As it is the local type, it can be referenced with a relative address:
- ``Dependency`` (relative)
- ``/BundleWithRelativePathAmbiguity/Dependency`` (absolute, shorthand)
- ``doc://org.swift.docc.example/documentation/BundleWithRelativePathAmbiguity/Dependency`` (absolute, fully qualified)


### Type Pages

#### `/Dependency/AmbiguousType`

- ``/Dependency/AmbiguousType`` (absolute, shorthand)
- ``doc://org.swift.docc.example/documentation/Dependency/AmbiguousType`` (absolute, fully qualified)

#### `/Dependency/UnambiguousType`

It should be possible to reference `/Dependency/UnambiguousType` relatively, even from `documentation/BundleWithRelativePathAmbiguity`. This way, the relative link switches to the extended type page automatically when the type gets extended. 

- ``Dependency/UnambiguousType`` (relative)
- ``/Dependency/UnambiguousType`` (absolute, shorthand)
- ``doc://org.swift.docc.example/documentation/Dependency/UnambiguousType`` (absolute, fully qualified)

### Extended Type Pages

#### `/BundleWithRelativePathAmbiguity/Dependency/AmbiguousType`

- ``Dependency/AmbiguousType`` (relative)
- ``/BundleWithRelativePathAmbiguity/Dependency/AmbiguousType`` (absolute, shorthand)
- ``doc://org.swift.docc.example/documentation/BundleWithRelativePathAmbiguity/Dependency/AmbiguousType`` (absolute, fully qualified)

### Member Pages

#### `/Dependency/AmbiguousType/unambiguousFunction()`

- ``Dependency/AmbiguousType/unambiguousFunction()`` (relative)
- ``/Dependency/AmbiguousType/unambiguousFunction()`` (absolute, shorthand)
- ``doc://org.swift.docc.example/documentation/Dependency/AmbiguousType/unambiguousFunction()`` (absolute, fully qualified)

<!-- Copyright (c) 2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
