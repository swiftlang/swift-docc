# ``convert``

Convert documentation markup, assets, and symbol information into a documentation archive.

@Metadata {
    @PageImage(purpose: icon, source: command-icon)
}

## Arguments, Flags, and Options

### Inputs & Outputs

- term `<catalog-path>`:
  Path to the documentation catalog ('.docc') directory.

- term `--additional-symbol-graph-dir <additional-symbol-graph-dir>`:
  A path to a directory of additional symbol graph files.

- term `-o, --output-path, --output-dir <output-path>`:
  The location where the documentation compiler writes the built documentation.

### Availability Options

- term `--platform <platform>`:   
  Specify information about the current release of a platform.
  
  Each platform's information is specified via separate `--platform` values using the following format: `name={platform name},version={semantic version}`.

  Optionally, the platform information can include a `beta={true|false}` component. If no beta information is provided, the platform is considered not in beta.

### Source Repository Options (Swift-DocC 5.8+)

- term `--checkout-path <checkout-path>`:
  The root path on disk of the repository's checkout.

- term `--source-service <source-service>`:
  The source code service used to host the project's sources. Supported values are `github`, `gitlab`, and `bitbucket`.

  Required when using `--source-service-base-url`. 

- term `--source-service-base-url <source-service-base-url>`:
  The base URL where the source service hosts the project's sources. For example: `"https://github.com/my-org/my-repo/blob/main"`.

  Required when using `--source-service`. 

### Hosting Options (Swift-DocC 5.6+)

- term `--hosting-base-path <hosting-base-path>`:
  The base path where your will host your documentation.
  
  For example, if you deploy your site to `example.com/my_name/my_project/documentation` instead of `example.com/documentation`, pass `/my_name/my_project` as the base path.

- term `--no-transform-for-static-hosting`:
  Don't produce a documentation output that supports static hosting environments.

### Diagnostic Options

- term `--analyze`:             
  Include `note`/`information` level diagnostics in addition to warnings and errors.

- term `--diagnostics-file, --diagnostics-output-path <diagnostics-file>` **(Swift-DocC 5.9+)**:
  The location where the documentation compiler writes the diagnostics file.

  Specifying a diagnostic file path implies `--ide-console-output`.

- term `--diagnostic-filter, --diagnostic-level <diagnostic-filter>`:
  Filter diagnostics with a lower severity than this level.

  This option is ignored if `--analyze` is passed.

  This filter level is inclusive. If a level of `note` is specified, diagnostics with a severity up to and including `note` will be printed.

  The supported diagnostic filter levels are:
  - `error`
  - `warning`
  - `note`, `info`, `information`
  - `hint`, `notice`

- term `--ide-console-output, --emit-fixits`:
  Format output to the console intended for an IDE or other tool to parse.

- term `--warnings-as-errors` **(Swift-DocC 5.8+)**:
  Treat warnings as errors.

### Info.plist Fallbacks

- term `--default-code-listing-language <default-code-listing-language>`:
  A fallback default language for code listings if no value is provided in the documentation catalogs's Info.plist file.

- term `--fallback-display-name  <fallback-display-name>`:
  A fallback display name if no value is provided in the documentation catalogs's Info.plist file.

  If no display name is provided in the catalogs's Info.plist file or via the `--fallback-display-name` option, DocC will infer a display name from the documentation catalog base name or from the module name from the symbol graph files provided via
        the `--additional-symbol-graph-dir` option.

- term `--fallback-bundle-identifier <fallback-bundle-identifier>`:
  A fallback bundle identifier if no value is provided in the documentation catalogs's Info.plist file.

  If no bundle identifier is provided in the catalogs's Info.plist file or via the '--fallback-bundle-identifier' option, DocC will infer a bundle identifier from the display name.

- term `--fallback-default-module-kind <fallback-default-module-kind>` **(Swift-DocC 5.6+)**:
  A fallback default module kind if no value is provided in the documentation catalogs's Info.plist file.

  If no module kind is provided in the catalogs's Info.plist file or via the `--fallback-default-module-kind` option, DocC will display the module kind as a "Framework".

### Documentation Coverage Options (Experimental)

- term `--experimental-documentation-coverage`:
  Generate documentation coverage output.

  Detailed documentation coverage information will be written to `documentation-coverage.json` in the output directory.

- term `--coverage-summary-level <symbol-kind>`:
  The level of documentation coverage information to write on standard out. (default: `brief`)
        
  The `--coverage-summary-level` level has no impact on the information in the "documentation-coverage.json" file.

  The supported coverage summary levels are `brief` and `detailed`.

- term `--coverage-symbol-kind-filter <symbol-kind>`:
  Filter documentation coverage to only analyze symbols of the specified symbol kinds.

  Specify a list of symbol kind values to filter the documentation coverage to only those types symbols.

  The supported symbol kind values are: `associated-type`, `class`, `dictionary`, `enumeration`, `enumeration-case`, `function`, `global-variable`, `http-request`, `initializer`, `instance-method`, `instance-property`, `instance-subscript`, `instance-variable`, `module`, `operator`, `protocol`, `structure`, `type-alias`, `type-method`, `type-property`, `type-subscript`, `typedef`.


### Link Resolution Options (Experimental) (Swift-DocC 5.11+)
- term `--dependency <dependency>`:
  A path to a documentation archive ('.doccarchive') directory to resolve external links against.

  Only documentation archives built with `--enable-experimental-external-link-support` are supported as dependencies.

### Feature Flags

- term `--experimental-enable-custom-templates`:
  Allows for custom templates, like `header.html`.

- term `--enable-inherited-docs`:
  Inherit documentation for inherited symbols.

- term `--allow-arbitrary-catalog-directories` **(Experimental)** **(Swift-DocC 5.10+)**:
  Allow catalog directories without the `.docc` extension.

- term `--enable-experimental-external-link-support` **(Swift-DocC 5.11+)**:
  Support external links to this documentation output.

  Write additional link metadata files to the output directory to support resolving documentation links to the documentation in that output directory.

- term `--enable-experimental-overloaded-symbol-presentation` **(Swift-DocC 5.11+)**:
  Collects all the symbols that are overloads of each other onto a new merged-symbol page.

- term `--enable-experimental-mentioned-in` **(Swift-DocC 5.11+)**:
  Render a section on symbol documentation which links to articles that mention that symbol.

- term `--enable-experimental-parameters-and-returns-validation` **(Swift-DocC 5.11+)**:
  Validate parameter and return value documentation.

  Validates and filters symbols' parameter and return value documentation based on the symbol's function signature in each language representation.

- term `--emit-digest`:        
  Write additional metadata files to the output directory.

- term `--emit-lmdb-index`:      
  Writes an LMDB representation of the navigator index to the output directory.

  A JSON representation of the navigator index is emitted by default.

### Other Options

- term `-h, --help`:
  Show help information.

<!-- Copyright (c) 2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->

