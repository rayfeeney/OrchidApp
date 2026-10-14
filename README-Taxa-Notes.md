# Taxa notes formatting update

This incremental update requires the shared rich-notes files from the working
Genus formatting update already to be installed.

Copy all five files under `src/` from the ZIP into your OrchidApp repository,
preserving paths, then restart the development app:

- Pages/Setup/Taxa/Actions/Add.cshtml and Add.cshtml.cs
- Pages/Setup/Taxa/Actions/Edit.cshtml and Edit.cshtml.cs
- Pages/Setup/Taxa/Details.cshtml

All paths above are under src/OrchidApp.Web.

Add: Growth notes and Notes now support formatting.
Edit: Growth notes and Taxon notes now support formatting.
Details: both notes display formatted content safely.

Each field uses the same shared editor and C# sanitisation, Unicode cleaning,
legacy plain-text handling and limits as Genus notes. Each has its own toolbar.
No package additions or database migrations are required; the source schema and
procedures already define both notes parameters/columns as TEXT.

Validation errors retain the submitted formatted notes. An image-processing
error on Edit also retains entered notes rather than reloading the old notes
from the database.

Verified here:
- Release build: zero warnings/errors.
- Existing 22 C# checks pass (shared sanitisation and Genus Add handler checks).
- Eight isolated Edge browser checks pass: two editors initialise, existing
  formatted notes reopen, editing one leaves the other intact, growth formatting
  synchronises, both form values submit, an oversized second note blocks the
  form, a 375px layout fits, and no script errors occur.

The actual Taxa page save requests and MariaDB procedures were not executed here.
Please test locally:

1. Add a species/hybrid with different formatting in each field; save and check
   Details, then reopen in Edit.
2. Change both fields in Edit, save and reopen again.
3. Test bullets, numbering, accented text and emoji in both fields.
4. Leave the name missing (or enter both species and hybrid) and confirm that
   validation preserves both notes.
5. Clear either note and check the saved empty display.
6. Check existing unformatted records remain literal text, including < and &.
7. Test on your normal phone/tablet before wider rollout.

The source has been prepared in a separate working copy; your repository and
database have not been modified automatically.
