# Genus Add page formatting update

This incremental update assumes the working Genus Edit formatting changes are
already installed.

Copy these two files from the ZIP into your OrchidApp repository, preserving paths:

- src/OrchidApp.Web/Pages/Setup/Genera/Actions/Add.cshtml
- src/OrchidApp.Web/Pages/Setup/Genera/Actions/Add.cshtml.cs

The ZIP also includes updated checks and documentation; those are optional for
running the app. No new packages, shared editor changes or database migrations
are required. Restart your development app after copying the files.

Genus notes on Add now has the same toolbar, size limits, Unicode cleaning and
server-side sanitisation as Edit. The existing details page displays the result.
Try creating a genus with bold text and both list types, then open Edit and check
that formatting is retained. Also try leaving the genus name blank to verify that
the note remains formatted after validation.

Verified: Release build with zero warnings/errors, and 22 automated checks,
including Add-page sanitised procedure parameters, redirect, validation redisplay
and rejection of oversized notes. The database executor is substituted in these
page-handler checks; a live database save/reopen remains to be checked locally.
