# Technical review of the frozen Linux specimen

Reviewed locally on 28 October 2026. The owner subsequently published the exact reviewed archive and sidecar under [the dedicated fixture pre-release](https://github.com/rayfeeney/OrchidApp/releases/tag/ci-fixture-linux-arm64-1.3.0-080ba9c-v1); published hashes were verified. The private capture was not uploaded. This review is of the exact CI specimen, not the original private capture or an installed application release. The exact fixture database phase subsequently passed [reviewed adoption](historical-linux-adoption.md); technical sanitisation checks alone do not establish full C18 package/application/recovery acceptance.

| Identity | Value |
| --- | --- |
| Asset | `OrchidApp-Pi-specimen-1.3.0-080ba9c-review.tar.gz` |
| Size | 94,612,484 bytes |
| SHA-256 | `7ffd16949ae07238f31447ad7d64e1444e898a00248b8e14757533bcbf00f3b5` |
| Application metadata | 1.3.0, Linux ARM64/.NET 8 |
| Observed source checkout | `080ba9c377fc22b781640272d7d32ecc3ae46a42` (`v1.3.0-7-g080ba9c`) |
| Binary source revision | Not independently established |
| Inner inventory | 1,073 files with verified checksums |

## Checks on the exact asset

- All 798 upload images match regenerated deterministic 96×96 JPEG/PNG test patterns byte-for-byte. No original image pixels or EXIF are retained in those files.
- Four known captured credential strings were searched in the exact package, including UTF-16 representations; none matched. Selected owner account/machine identifiers were also absent. Secret values/hashes are not published in the report or source.
- Narrative fields in 15 relevant tables were checked over their complete expected row counts. Designated notes/acquisition sources contain only the replacement marker, empty string or NULL; custom plant names, app location names and importer file paths match their synthetic patterns, and legacy photo paths are NULL. No original free-text value was found in those designated fields.
- Original private environment files, Git history, source/build/importer trees and PDBs are not part of the candidate. Runtime configuration contains only the documented fixture-specific loopback connection/credential and upload root. The verifier rejects alternate/private settings and unsafe archive members.
- IDs, botanical taxonomy, dates/status, lineage, photo reference filenames and numeric historical climate readings with generic sensor labels are intentionally retained. The asset includes 149 plants, 230 plant-photo rows, 182 taxon-photo rows and 1,202,998 climate readings. This is sanitised historical data, not a wholly invented database.
- Four missing photo/file references on inactive historical records remain documented; no active reference was missing. They were not fabricated or silently erased.

Known-value and designated-field checks are bounded technical evidence, not proof that every possible sensitive value has been identified. The retained data and provenance description must remain explicit when the owner decides to publish a fixture release. No production credentials are needed to use the specimen; its intentional test-only credentials are safe only within the disposable harness.

The frozen bytes remain unchanged. A future publication would attach this asset and its matching `.sha256` sidecar to a clearly labelled fixture release, not extract/commit the large archive into source. Do not upload any file named `private` or any whole chat workspace. The workflow's proposed fixture tag is not evidence that a release exists.

For current status and the migration compatibility blocker, see [historical Linux acceptance](../historical-linux-upgrade.md) and [ledger review](historical-ledger-compatibility.md). Local detailed review evidence remains outside the source package; it contains no published secret values.
