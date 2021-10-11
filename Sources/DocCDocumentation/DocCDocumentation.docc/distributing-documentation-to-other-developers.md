# Distributing Documentation to Other Developers

Share your documentation by hosting it on a web server.

## Overview

As soon as you create a Swift framework or package, DocC is ready to
generate structured documentation for the public types in your code base. Whether
you only have documentation comments in your source files, or you craft a full
learning experience that includes articles and tutorials, you can easily share the documentation in your code base with other
developers.

To share your documentation, you create a documentation archive, a
self-contained bundle that has everything you need, including:

- Compiled documentation from in-source comments, articles, tutorials, and
  resources
- A single-page web app that renders the documentation

Distributing your documentation involves the following steps:

1. Export your documentation using the `docc` command-line tool.
2. Share your documentation by hosting it on a website.

### Generate a Publishable Archive of Your Documentation

To create a documentation archive, use the `docc` command-line tool.

To export the documentation archive from the command line, run `docc` in Terminal. 

For example, to build a documentation archive, use a command similar to the
following:

```shell 
docc convert MyNewPackage.docc --fallback-display-name MyNewPackage --fallback-bundle-identifier com.example.MyNewPackage --fallback-bundle-version 1 --additional-symbol-graph-dir .build --output-dir MyNewPackage.doccarchive
```


### Send a Documentation Archive Directly to Developers

Because a documentation archive is a self-contained bundle, you can easily
share it with other developers. For example, you can send it by email just like
a regular document, include it with a binary distribution of your framework or
package, or make it downloadable from a website.

To remove an imported documentation archive, place your pointer over the item
to display the More button, and then choose Remove.

### Host a Documentation Archive on Your Website

When DocC exports a documentation archive, it includes a single-page web app
in the bundle. This web app renders the documentation content as HTML, letting
you host the documentation archive on a web server.

For reference documentation and articles, the web app uses a URL path that
begins with `/documentation`. For tutorials, the URL path begins with
`/tutorials`. For example, if a project contains a protocol
with the name `MyNewProtocol`, the URL to view the `MyNewPackage`
documentation might resemble the following:

```
https://www.example.com/documentation/MyNewPackage/MyNewProtocol
```

> Note: The following sections use Apache as an example. Other web server
  installations have similar mechanisms. Consult your server's documentation
  for details about performing similar configurations.

To host a documentation archive on your website, do the following:

1. Copy the documentation archive to the directory that your web server uses to
   serve files. In this example, the documentation archive is
   `MyNewPackage.doccarchive`.
2. Add a rule on the server to rewrite incoming URLs that begin with
   `/documentation` or `/tutorial` to `MyNewPackage.doccarchive/index.html`.
3. Add another rule for incoming requests to support bundled resources in the
   documentation archive, such as CSS files and image assets.

The following example `.htaccess` file defines rules suitable for use with Apache:

```shell
# Enable custom routing.
RewriteEngine On

# Route documentation and tutorial pages.
RewriteRule ^(documentation|tutorials)\/.*$ MyNewPackage.doccarchive/index.html [L]

# Route files and data for the documentation archive.
#
# If the file path doesn't exist in the website's root ...
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d

# ... route the request to that file path with the documentation archive.
RewriteRule .* MyNewPackage.doccarchive/$0 [L]
```

With these rules in place, the web server provides access to the contents of
the documentation archive. 

After configuring your web server to host a documentation archive, keep it up
to date by using a continuous integration workflow that builds the
documentation archive using `docc`, and copies the resulting
`.doccarchive` to your web server.

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
