/* Macros for the header version.
 */

#ifndef VIPS_VERSION_H
#define VIPS_VERSION_H

#define VIPS_VERSION "8.18.2"
#define VIPS_VERSION_STRING "8.18.2"
#define VIPS_MAJOR_VERSION (8)
#define VIPS_MINOR_VERSION (18)
#define VIPS_MICRO_VERSION (2)

/* The ABI version, as used for library versioning.
 */
#define VIPS_LIBRARY_CURRENT (62)
#define VIPS_LIBRARY_REVISION (2)
#define VIPS_LIBRARY_AGE (20)

#define VIPS_CONFIG "enable debug: false\nenable deprecated: false\nenable modules: true\nenable C++ binding: true\nenable RAD load/save: true\nenable Analyze7 load: true\nenable PPM load/save: true\nenable GIF load: true\nFFTs with fftw3: true\nSIMD support with libhwy: true\nICC profile support with lcms2: true\ndeflate compression with zlib: true\ntext rendering with pangocairo: true\nfont file support with fontconfig: true\nEXIF metadata support with libexif: true\nJPEG load/save with libjpeg: true\nUHDR load/save with libuhdr: true\nJXL load/save with libjxl: true (dynamic module: true)\nJPEG2000 load/save with libopenjp2: true\nPNG load/save with libpng: true\nimage quantisation with imagequant: true\nTIFF load/save with libtiff-4: true\nimage pyramid save with libarchive: true\nHEIC/AVIF load/save with libheif: true (dynamic module: false)\nWebP load/save with libwebp: true\nPDF load with poppler-glib: true (dynamic module: true)\nSVG load with librsvg-2.0: true\nEXR load with OpenEXR: true\nWSI load with openslide: true (dynamic module: true)\nMatlab load with matio: true\nNIfTI load/save with niftiio: true\nFITS load/save with cfitsio: true\nGIF save with cgif: true\nRAW load with libraw_r: true\nMagick load/save with MagickCore: true (dynamic module: true)"

/* Not really anything to do with versions, but this is a handy place to put
 * it.
 */
#define VIPS_ENABLE_DEPRECATED 0

#endif /*VIPS_VERSION_H*/
