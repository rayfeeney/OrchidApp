# iPhone and iPad Home Screen client

Use an existing reachable OrchidApp server. This adds a client shortcut/web app, not a database or server on the phone. Ask the operator for its current URL and required trusted-network/VPN access.

1. Open that URL in Safari and confirm Home, a plant page and photos work.
2. Choose Share, then Add to Home Screen. Keep the OrchidApp name. If Open as Web App is offered, leave it enabled.
3. Launch the new icon. Check Home, Plants, Details, Back, Edit/Cancel and photos. Do not use real collection edits as an installation test.

The manifest requests standalone presentation and Home as its start URL. Icon artwork comes from the existing favicon. No service worker or offline mode is supplied. Changing hostname/scheme/port can create a different browser origin and installation state; an old icon may keep cached metadata.

Device behaviour still needs validation on the actual build and iOS/iPadOS/Safari versions. See [browser-client validation](../../validation/browser-clients.md) and the [Mac client](../macos/safari-web-app.md). Prior incident-specific addresses and investigation notes are preserved in [history](../../history/browser-investigation/ios/home-screen-web-app.md).
