# Mac Safari Dock client

Use an existing OrchidApp server at the operator-provided reachable URL. This is a browser client; it does not install an OrchidApp server/database on the Mac.

1. Open the site in Safari and confirm the app works through the intended trusted connection.
2. Where supported, choose File, then Add to Dock and name it OrchidApp.
3. Launch the Dock app and check Home, Plants, Details, Back, Edit/Cancel, photos and downloads.

The site's manifest requests standalone display, starts at Home and provides icons using the existing artwork. Safari controls the resulting presentation. There is no offline mode. A new test installation may be needed to check changed cached metadata.

A correct manifest or passing build does not prove that Safari's navigation toolbar or a disabled setting has been resolved on a particular Mac. Record the actual macOS/Safari versions and test results using [browser-client validation](../../validation/browser-clients.md). Keep ordinary Safari available for comparison. Do not bypass certificate warnings or change server HTTPS settings to test a theory.

The previous incident-specific investigation is retained in [history](../../history/browser-investigation/macos/safari-web-app.md); its reported address/version are not general installation requirements.
