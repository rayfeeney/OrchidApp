# iPhone and iPad Home Screen web app

Open OrchidApp in Safari using the normal reachable URL, for example
`http://100.111.136.37:5000/` while connected through Tailscale. Choose Share >
Add to Home Screen, keep the OrchidApp name and add it. If Safari offers Open as
Web App, leave it enabled. Launch the new icon from the Home Screen.

The manifest requests standalone presentation and starts at Home (`./`, relative
to the manifest). This intentionally changes the earlier minimal candidate, which
left the installation start URL to Safari. No host, IP, port or scheme is embedded
in metadata. Razor resolves `~/` icon and manifest links for the application path;
manifest URLs are relative to the manifest itself. Changing address still creates
a different origin with separate browser storage and installation state.

## Icon artwork and compatibility

The source is the existing `wwwroot/favicon.ico`, specifically its largest 64x64
frame. It is an opaque orchid image and is left byte-for-byte unchanged, as is the
Windows launcher icon. The launcher ICO contains a different rendering and is not
used for these web icons. The new PNGs are proportional Lanczos resizes of the
favicon with no cropping, padding, recolouring or generated artwork. Because the
source is only 64x64, larger sizes do not add detail; a higher-resolution original
of this exact artwork would be needed to improve sharpness without redesign.

| Asset under wwwroot | Dimensions | Use |
| --- | --- | --- |
| apple-touch-icon.png | 180x180 | iPhone and default Apple touch icon |
| icons/apple-touch-icon-167.png | 167x167 | iPad Pro |
| icons/apple-touch-icon-152.png | 152x152 | iPad |
| icons/icon-192.png | 192x192 | Manifest icon |
| icons/icon-512.png | 512x512 | Manifest icon |

The shared layout declares the Apple touch icons with sizes and an Apple web-app
title. The manifest declares the name, short name, relative start URL, standalone
display and PNG icons with purpose `any`. The artwork is not claimed to be
maskable. No service worker, offline support, dependency, MIME override or HTTPS
redirection is added. Ordinary browser navigation remains available.

WebKit documents that [Apple touch icons take precedence over manifest icons on
iOS/iPadOS](https://webkit.org/blog/13878/). Safari controls the installed icon's
mask and presentation. The unchanged favicon and identical source artwork preserve
the web branding; actual fresh Mac Dock rendering must still be compared.

## Validate on real devices before release

1. Record the tested build, exact iOS/iPadOS and Safari versions, device model,
   date, full URL and scheme. Verify Tailscale connectivity where required.
2. Inspect a rendered page (including a nested Details page): resolve its manifest
   and all three Apple icon links. Confirm HTTP 200, JSON for the manifest and
   `image/png` for each icon. Fetch both manifest icons, confirm their dimensions
   against the table, and verify the start URL resolves to OrchidApp Home on the
   current host. Repeat through a second hostname or a trusted test endpoint if
   available; never hard-code the Tailscale address in application metadata.
3. Keep the existing installation for comparison and add a fresh test installation
   under a distinct name on both iPhone and iPad. Do not assume an existing Home
   Screen icon or installation refreshes cached metadata. Confirm the Add to Home
   Screen preview and installed icon show the same orchid artwork.
4. Launch from the Home Screen. Record whether it opens at Home, uses standalone
   presentation and shows the expected title/icon in the app switcher. Where
   inspection is available, record `matchMedia('(display-mode: standalone)').matches`
   and `navigator.standalone`. Treat device observations as the acceptance result.
5. Check Home, Plants, Details, Back, Edit/Cancel, the collapsed navbar in portrait
   and landscape, photos and downloads. Avoid changing real plant data. Repeat
   ordinary Safari browsing and desktop browser smoke checks.
6. If the icon or presentation is wrong, record the manifest/icon responses and
   installation state. Compare the same build through trusted HTTPS using another
   fresh installation. Do not bypass certificate warnings or change production
   HTTPS settings without correctly configured hosting and certificates. HTTP is
   not an established explanation for either the icon issue or Mac toolbar issue.

The [Mac Dock toolbar investigation](../macos/safari-web-app.md) is separate.
A manifest requests presentation; it does not prove why Show navigation controls
is disabled or guarantee a fix. Record Mac toolbar/settings and Dock artwork
comparisons independently. Real iPhone, iPad and target-Mac results remain pending
until performed. No deployed Raspberry Pi files should be changed for this review.
