# Browser client validation

Record build/revision, date, exact OS/browser/device, operator-provided URL/scheme, required connectivity and fresh/existing installation state. Test the actual devices; desktop narrow-window screenshots do not establish touch or Safari behaviour.

1. Resolve manifest and Apple icon links from Home and a nested page. Verify HTTP 200, JSON manifest, PNG icons, relative Home start URL and standalone request.
2. Verify icon dimensions: 180, 167 and 152 pixels for Apple touch assets; 192 and 512 for manifest icons. Artwork is upscaled from the existing 64-pixel favicon, so larger PNGs do not add detail.
3. Preserve an existing installation for comparison, create a distinctly named test installation and record its icon/title/start page and standalone/toolbar behaviour. Do not assume cached installations refresh metadata.
4. Check Home, Plants, Details, return context, Edit/Cancel, collapsed navigation, photos, downloads and ordinary-browser access. Avoid modifying real collection data.
5. For a Mac toolbar issue, record toolbar and Show navigation controls checked/enabled state. Compare a trusted HTTPS test endpoint only when correctly configured. HTTP is a test variable, not an established cause; do not bypass certificate warnings.

[WebKit](https://webkit.org/blog/13878/) describes Apple touch-icon precedence. [Apple's web-app session](https://developer.apple.com/videos/play/wwdc2023/10120/) describes presentation requests. Neither is evidence of a passed test on the owner's devices. Real device acceptance was not run during documentation cleanup.
