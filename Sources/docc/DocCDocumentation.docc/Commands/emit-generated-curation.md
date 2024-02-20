# ``emit-generated-curation``

Write documentation extension files with markdown representations of DocC's automatic curation.

@Metadata {
    @PageImage(purpose: icon, source: command-icon)
}

## Overview

Pass the same `<catalog-path>` and `--additional-symbol-graph-dir <symbol-graph-dir>` as you would for `docc convert` to emit documentation extension files for your project.

If you're getting started with arranging your symbols into topic groups, you can pass `--depth 0` to only emit a documentation extension file for the module, organizing the top-level symbols. 

If you want to arrange a specific sub-hierarchy of your project into topic groups you can pass `--from-symbol <symbol-link>` to only write documentation extension files for that symbol and its descendants. This can be combined with `--depth <limit>` to control how far to descend from the specified symbol.

> Important:
> When you have generated documentation extension files, you should go through the links and move them into new topic groups based on conceptually relevant topics for your project.
>
> Any links that you leave in the generated per-symbol-kind topic groups don't provide any additional organization of your project. 

To help you distinguish between API that you've arranged into topics and API that's automatically grouped by symbol kind, it is recommended to remove all generated per-symbol-kind topic groups that you didn't arrange into new conceptual topic groups. You can always run `emit-generated-curation` again later to iteratively work on arranging your documentation into topic groups.

For more information on arranging documentation into topic groups, see <doc:adding-structure-to-your-documentation-pages>.

## Arguments, Flags, and Options

### Inputs & Outputs

- term `<catalog-path>`:          
  Path to the documentation catalog ('.docc') directory.

- term `--additional-symbol-graph-dir <symbol-graph-dir>`:
  Path to a directory of additional symbol graph files.

- term `--output-path <output-path>`:
  The location where `docc` writes the transformed catalog.

  > Important: If no output-path is provided, `docc` will perform an in-place transformation of the provided documentation catalog.

### Generation Options

- term `--from-symbol <symbol-link>`:
  A link to a symbol to start generating documentation extension files from.

  If no symbol-link is provided, `docc` will generate documentation extension files starting from the module.

- term `--depth <limit>`:
  A depth limit for which pages to generate documentation extension files for.

  If no depth is provided, `docc` will generate documentation extension files for all pages from the starting point.

  If 0 is provided, `docc` will generate documentation extension files for only the starting page.

  If a positive number is provided, `docc` will generate documentation extension files for the starting page and its descendants up to that depth limit (inclusive).

### Other Options

- term `-h, --help`:
  Show help information.

<!-- Copyright (c) 2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->
