# Formatted genus and taxon notes

## Supported fields

| Area | Add | Edit | Details |
| --- | --- | --- | --- |
| Genera | Genus notes | Genus notes | Formatted genus notes |
| Taxa | Growth notes and Notes | Growth notes and Taxon notes | Both formatted notes |

Each field has its own toolbar. Failed form validation retains the submitted
notes. Taxon Edit also retains them after an image-processing error.

## Behaviour and storage

The toolbar supports bold, italic, underline, bullets, numbering and clear
formatting. Quill 2.0.3 is bundled locally; no new CDN request is needed.

The shared C# RichNotes helper sanitises on save and before HTML display, allowing
only p, br, strong, em, u, ul, ol and li, with no attributes or CSS. Text is
Unicode Form C normalised. NBSP becomes a space; zero-width space, word joiner,
embedded BOM and unwanted controls are removed. Accents, punctuation, emoji and
emoji joining characters are retained.

New formatted values carry the explicit `<!--orchid-rich-notes:v1-->` prefix.
Unmarked historical values are treated as literal text, even if they resemble
HTML. They are converted only when saved through a supported Add or Edit page. No bulk rewrite
or schema change is performed. Database tools will show the marker and HTML.
Search/export features added later must use a plain-text representation.

Server limits: 10,000 UTF-16 text units, 200,000 raw submitted characters, and
60,000 UTF-8 bytes including markup/marker. Oversized notes are rejected rather
than silently truncated. The client counter uses Quill length (including line
breaks), so it can reject a multiline note slightly earlier than the server.
Blank formatted notes become NULL. If scripts fail, the textarea remains usable;
already-formatted notes then appear as marked HTML, so restore scripts before
editing those notes in the fallback field.

## Implementation and deployment

The shared `RichNotes` service sanitises saved and displayed content. The editor
uses `wwwroot/js/rich-notes.js`, `wwwroot/css/rich-notes.css` and locally bundled
Quill assets. Page handlers validate notes before submitting procedure parameters.
Genus and taxon notes already use TEXT columns and procedure parameters; formatting
does not introduce a schema migration. Existing installations still need suitable
utf8mb4 column character sets to store accented text and emoji.

Build and deploy the complete application through the normal platform upgrade
procedure; retain the bundled editor assets and `Legal/rich-notes` notices.
Quill uses the BSD-3-Clause licence; HtmlSanitizer and its documented dependencies
use MIT licences. See [third-party notices](../THIRD_PARTY_NOTICES.md).

## Validation

From the repository root:

```bash
dotnet run --configuration Release --project tests/RichNotes.Checks/RichNotes.Checks.csproj
```

Automated checks cover the shared sanitiser and Genus Add handler with a substitute
database executor. They do not establish live MariaDB save/reopen behaviour or
physical mobile-device support.

## Acceptance checks

- Edit an existing genus note with literal `<orchid>`, &, and multiple lines.
- Apply each format, save, view Genus details, reopen, edit, and save again.
- Mix bullet and numbered lists and switch between them.
- Paste from Word/Outlook/web; verify words/basic emphasis remain and foreign
  fonts, sizes, colours, images and links do not.
- Save/reopen `Floração très réussie £ € 🌸` and an emoji using a joiner.
- Clear the note, save, and confirm the empty display.
- Try an invalid genus name and confirm formatting survives the validation error.
- Try an excessive paste and confirm the note is not silently truncated.
- Test keyboard navigation, selection and formatting on actual iPhone/iPad Safari
  and Android Chrome. Phone-width desktop checks do not establish touch behaviour.
- Check the Licences page and your published package's licence files.

Also create and edit a taxon with different formatting in both notes fields;
check that each editor is independent and that clearing either field saves an
empty value. Check both notes survive invalid taxon input.

## Rollback

Revert the changed source files and rebuild. First restore any converted test notes
from the backup or convert them to plain text: older application code would show
the marker/HTML literally. The application does not perform that conversion
automatically.
