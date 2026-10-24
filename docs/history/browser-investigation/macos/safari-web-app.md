# Safari Dock web app

OrchidApp links a web app manifest requesting `display: standalone` so a newly
installed Safari Dock web app can use OrchidApp's own navigation without the
browser toolbar. The favicon is unchanged. Apple touch icons and manifest PNGs
reuse that same artwork. The manifest now sets `start_url: "./"`, so a fresh
installation starts at Home on the host and application path serving the manifest.
No explicit scope is set. No service worker or offline support is provided.

Apple describes the default navigation toolbar and the standalone display mode
in [What's new in web apps (WWDC23)](https://developer.apple.com/videos/play/wwdc2023/10120/).
This requests the initial window appearance; it does not establish why a
particular installation's Show navigation controls checkbox is disabled.

## Validate before release on the target Mac

1. Record the exact macOS version and build, Safari version, full application URL
   and scheme. Verify the reported macOS Tahoe 26.6.2 version on the machine.
   The reported application URL is `http://100.111.136.37:5000/`.
2. Inspect a rendered OrchidApp page. Confirm its head contains a
   `rel="manifest"` link, resolve that link against the page URL, and request the
   resolved URL. Confirm HTTP 200 and a JSON content type. Check `name` is
   `OrchidApp`, `display` is `standalone`, `start_url` is `./`, and both PNG icon
   URLs return HTTP 200 with `image/png`. See the
   [iPhone/iPad guide](../ios/home-screen-web-app.md) for icon sizes and provenance.

3. Keep the existing Dock app for comparison. Open the updated site in Safari,
   choose File > Add to Dock and give the test installation a distinct name,
   such as OrchidApp Toolbar Test. Do not assume refreshing an existing Dock
   installation adopts new manifest metadata.
4. Launch the fresh installation. Record whether browser navigation, Share and
   extension buttons are absent. Compare the orchid artwork with the existing Dock
   icon too; Safari may choose a new icon source for a fresh installation. In its General settings, record whether Show
   navigation controls is checked and whether it remains disabled. Compare the
   old installation and capture the results separately.
5. Check Home, Plants, Details, Back, Edit/Cancel, the collapsed navbar at a narrow
   window width, photos and downloads. Confirm navigation remains usable without
   browser controls. Avoid saving changes to real plant records during testing.
6. Check those same workflows in ordinary Safari browsing.
7. If the toolbar persists, compare the same build through a trusted HTTPS test
   endpoint, using another fresh Dock installation. Record its URL, scheme,
   toolbar appearance and checkbox state. Do not bypass certificate warnings or
   enable production HTTPS redirection before certificates and hosting are
   configured correctly. HTTP is a test variable, not an established cause.

## Record the outcome

Record the build/commit tested, date, exact macOS and Safari versions, resolved
manifest URL, response status/content type/content, installation name and whether
it is fresh or existing. For each installation, record toolbar presence, checkbox
checked/enabled state and workflow results. Include the HTTPS comparison if run.

Target-Mac Safari behaviour is unverified until these checks are performed. A
passing build and a correctly served manifest do not prove the toolbar issue or
the disabled setting has been resolved. If it persists, retain both installations
and the recorded evidence for further Safari investigation.
