# Mobile photo ingestion (WIN-PHOTO-02)

The development candidate starts from main at `3acf3da`. Tests use synthetic images and a private temporary upload root.

## Reproduction and candidate behaviour

| Case | Reproduced evidence | Candidate check |
| --- | --- | --- |
| JPEG EXIF orientation | The original pipeline throws `VipsJpeg: out of order read at line 3840` with a 5120 × 3840 orientation-6 JPEG on libvips 8.18.2. The lazy rotation requests rows the sequential loader already passed. | A generated 8000 × 6000 orientation-6 JPEG is accepted from a non-seeking stream and produces 2304 × 3072 and 225 × 300 JPEGs. |
| Bad seek | Windows native HEIC pixel decoding reproduced `bad seek` diagnostics followed by libheif reporting unavailable compression support. The earlier Pi log shows seek errors accompanying the JPEG row-order failure. Exact Pi JPEG offsets were not reproduced. | The Windows app takes the HEIF decode path through Magick.NET. The same fixture must fully decode and reopen as a JPEG on both OSes in the native suite. |
| Dimensions | A generated 48 MP JPEG is rejected by the original 40 MP guard. | 48 MP succeeds. A generated 65 MP JPEG is rejected before pixel processing. |
| Bytes | A stream of 10 MiB plus one byte is rejected by the original byte guard. | A generated JPEG over 10 MiB succeeds. A stream of 25 MiB plus one byte is rejected. |

The branch retains pair publication and the C19 request journal. The native suite also exercises publication faults, database completion states and recovery policy. Input staging is outside web storage and is removed on normal completion, rejection and cancellation. An interrupted process can leave a private temporary file. The 25 MiB and 64 MP limits were chosen to cover typical phone captures within the existing default HTTP request budget. High-resolution modes above the limits and real phone variations require separate acceptance. Existing server and proxy request limits still apply.

The synthetic HEVC fixtures, including the portrait container rotation case, were generated from pixels created for these tests with Pillow 13.0.0 and pillow-heif 1.8.1. No camera or collection data is included. No encoder is required to run the suite. Set `Storage__UploadRoot` to an absolute disposable path and run `dotnet run --configuration Release --project tests/DevelopmentNative.Checks`, or use the repository's development check wrapper. Windows requires the prepared pinned libvips DLLs on PATH. Linux requires native libvips with libheif/HEVC support, which depends on the distribution's build and decoder packages. Ubuntu CI installs the libde265 plugin explicitly. The health readiness probe continues to verify the common JPEG path. A successful readiness result alone does not certify HEIC.

The prebuilt Windows libvips distribution excludes HEVC. Magick.NET supplies a Windows x64 decoder without a separate codec installation. See [upstream libvips build notes](https://github.com/libvips/build-win64-mxe#hevc-related-dependencies) and [Magick.NET](https://github.com/dlemstra/Magick.NET). The native notices are copied from the restored NuGet package at build/publish time. The AnyCPU package keeps the managed assembly architecture-neutral. It adds approximately 36 MiB of Magick.NET files to the Linux ARM64 publish even though Linux decoding uses system libvips.

## Confirmed on Windows

The Release native suite passed on .NET SDK 8.0.427 with libvips 8.18.2 and Magick.NET 15.1.0. It passed 611 metadata/orientation/colour assertions, 37 photo pair/transaction recovery assertions, and the mobile cases above, including HEIF container orientation and rejection of a truncated JPEG. The separate photo deletion storage check passed its runnable cases and skipped the symlink case on this machine. Framework-dependent Windows x64 and Linux ARM64 publish outputs were checked for the web assembly and notices. The Windows output also contained the native Magick.NET decoder.

## Remaining release acceptance

Run Windows and Linux hosted native jobs and verify the installed package on disposable Windows and Pi targets, including real portrait iPhone HEIC, high-resolution JPEG from Android and iPhone, browser file selection, save/reopen, rejection and peak Pi memory on large HEIC. The live Pi and v1.4.0 baseline were outside this test scope.
