# ``transform-for-static-hosting``

Transform an existing documentation archive into one that supports a static hosting environment.

@Metadata {
    @PageImage(purpose: icon, source: command-icon)
}

@DeprecationSummary {
  As of Swift-DocC 5.7, documentation archives support static hosting environments by default. There is no need to call this command anymore.
}

## Arguments, Flags, and Options


- term `<source-archive-path>`:
  Path to the documentation archive ('.doccarchive') directory that should be processed.

- term `--output-path <output-path>`:
  The location where `docc` writes the transformed archive.

  > Important: If no output-path is provided, `docc` will perform an in-place transformation of the provided documentation archive.
  
- term `--hosting-base-path <hosting-base-path>`:
  The base path where your will host your documentation.
  
  For example, if you deploy your site to `example.com/my_name/my_project/documentation` instead of `example.com/documentation`, pass `/my_name/my_project` as the base path.
  
- term `-h, --help`:
  Show help information.

  <!-- Copyright (c) 2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->
