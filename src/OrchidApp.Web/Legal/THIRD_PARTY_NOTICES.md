================================================================================
OrchidApp — Third Party Notices
================================================================================

This software includes third-party open source components.

These components are used as dependencies of the OrchidApp system.
Their licences apply to the respective components.

OrchidApp itself is licensed separately under the GNU Affero General Public
License version 3.

-------------------------------------------------------------------------------
MariaDB Community Server
-------------------------------------------------------------------------------

OrchidApp includes a bundled MariaDB Community Server runtime for local database
storage.

Licence: GNU General Public License version 2 (GPLv2)

MariaDB Community Server is released under GPLv2. Licence information is
included in the MariaDB COPYING file. Third-party licence information is
included in the MariaDB THIRDPARTY file.

Project:
https://mariadb.org/
https://mariadb.com/

Licence files included with OrchidApp:
Legal/mariadb/COPYING
Legal/mariadb/THIRDPARTY

-------------------------------------------------------------------------------
NetVips
-------------------------------------------------------------------------------

OrchidApp uses NetVips, a .NET binding for the libvips image processing library.

Licence: MIT License

Project:
https://github.com/kleisauke/net-vips

NetVips is used by OrchidApp to call libvips from .NET.

-------------------------------------------------------------------------------
libvips
-------------------------------------------------------------------------------

OrchidApp includes a bundled libvips Windows runtime for image processing.

Licence: GNU Lesser General Public License version 2.1 or later
SPDX: LGPL-2.1-or-later

Project:
https://www.libvips.org/
https://github.com/libvips/libvips

libvips is dynamically loaded at runtime from the packaged OrchidApp runtime
folder.

Users may replace the bundled libvips shared libraries with compatible versions,
as allowed under the LGPL-2.1-or-later licence.

OrchidApp does not modify libvips.

Licence file included with OrchidApp:
Legal/libvips/LICENSE

-------------------------------------------------------------------------------
Dependency role in OrchidApp
-------------------------------------------------------------------------------

These components are used by OrchidApp for:

- Local relational database storage
- Database startup and migration support
- Image decoding
- Image resizing
- Image encoding
- Efficient media processing on local hardware

-------------------------------------------------------------------------------
No warranty
-------------------------------------------------------------------------------

Third-party components are provided under their respective licences.

They are distributed WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the individual licence texts included with OrchidApp for full terms.