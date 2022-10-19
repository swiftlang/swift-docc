# ``DocC/TechnologyRoot``

Configures a documentation page that's not associated with a particular framework so it appears as a top-level page.

## Overview

Place the `TechnologyRoot` directive within a `Metadata` directive to configure a documentation page that's not associated with a particular framework so it appears as a top-level page. Make sure the page includes a title, a summary line, an overview section, and a topics section with at least one topic group.

```
# Page Title

@Metadata {
   @TechnologyRoot
}

Summary line introducing the page.

## Overview

Add documentation here.

## Topics

### Topic Group Name

- ``APILink``
````

### Containing Elements

The following items can include a technology root element:

- ``Metadata``

## See Also

- <doc:formatting-your-documentation-content>

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
