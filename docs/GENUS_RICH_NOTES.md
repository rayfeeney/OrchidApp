# Genus notes formatting proof of concept

Applies to `/Setup/Genera/Actions/Add`, `/Setup/Genera/Actions/Edit/{id}` and the
corresponding Genus details display. Every other notes field remains plain text.

## Apply

1. Back up or commit your current OrchidApp source and database.
2. Copy the supplied changed files into the repository, preserving paths. This
   patch was prepared against the uploaded OrchidApp 1.2.1+build.3 source. If your
   checkout has moved on, review the files before replacing them.
3. Restore/build `src/OrchidApp.Web/OrchidApp.Web.csproj`, then publish through your
   normal process. Keep the new `wwwroot/lib/quill` and `Legal/rich-notes` files.
4. No schema migration is included: genusNotes and spUpdateGenus already use TEXT.
   Check the actual installed column's charset/collation with `SHOW FULL COLUMNS
   FROM genus LIKE 'genusNotes';` before testing accented text and emoji. The source
   creates new databases and configures connections as utf8mb4, but that does not
   establish the charset of an existing installed column.

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
HTML. They are converted only when saved through this edit page. No bulk rewrite
or schema change is performed. Database tools will show the marker and HTML.
Search/export features added later must use a plain-text representation.

Server limits: 10,000 UTF-16 text units, 200,000 raw submitted characters, and
60,000 UTF-8 bytes including markup/marker. Oversized notes are rejected rather
than silently truncated. The client counter uses Quill length (including line
breaks), so it can reject a multiline note slightly earlier than the server.
Blank formatted notes become NULL. If scripts fail, the textarea remains usable;
already-formatted notes then appear as marked HTML, so restore scripts before
editing those notes in the fallback field.

## Verification completed here

- Release build: zero warnings/errors.
- 22 automated C# checks: legacy text and line breaks, literal angle brackets,
  formatting/lists, repeated saves, unsafe HTML/attributes, pasted spans,
  Unicode/emoji, empty notes, and visible/raw/storage limits; plus Add-page
  sanitised procedure parameters, redirect, validation redisplay and size rejection.
- Headless desktop Edge browser checks: literal historical text, semantic HTML,
  both list types after reopening, oversized save prevention, 375px layout, and
  no browser script errors. These exercise the actual browser editor files in an
  isolated form, rather than the database-backed page.

Run the server checks from the repository root:

    dotnet run --project tests/RichNotes.Checks/RichNotes.Checks.csproj

## Acceptance checks on your installation

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

The running database, actual Razor Page request/save cycle and physical mobile
devices have not been tested here. Do those checks before general rollout.

## Rollback

Revert the changed source files and rebuild. First restore any converted test notes
from the backup or convert them to plain text: older application code would show
the marker/HTML literally. This proof of concept does not perform that conversion
automatically.
