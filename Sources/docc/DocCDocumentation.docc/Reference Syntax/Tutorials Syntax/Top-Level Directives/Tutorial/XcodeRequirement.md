# ``DocC/XcodeRequirement``

Lists the Xcode version required by a tutorial, and provides a link to download it.

- Parameters:
    - title: The Xcode name and version required by the tutorial. For example: "Xcode 13". **(required)**
    - destination: A URL to download the required version of Xcode. **(required)**

## Overview

If a tutorial page (`Tutorial`) requires a specific version of Xcode in order for the reader to follow along, use the `XcodeRequirement` directive to denote the requirement and provide a download link.

```
@Tutorial(time: 30) {
    @XcodeRequirement(
        title: "Xcode 13", 
        destination: "https://developer.apple.com/download/")
    
    ...

}
````

### Containing Elements

The following pages can display an Xcode requirement:

* ``Tutorial``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
