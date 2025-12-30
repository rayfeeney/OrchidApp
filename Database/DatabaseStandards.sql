/* ============================================================
   Project: Orchids
   Database: MySQL
   Version: V1

   File: DatabaseStandards.sql
   Purpose: Defines standards within this database.

   ------------------------
   Naming Standards
   ------------------------
   - camelCase naming used in MySQL for tables, columns, views, indexes
   - Suffixes:
       * Id        → identifiers (primary & foreign keys)
       * Code      → structured, filterable values
       * Notes     → free-text, user-entered narrative
       * Date      → DATE
       * Time      → TIME
       * DateTime  → DATETIME

   ------------------------
   Date & Time Handling
   ------------------------
   - All dates and times stored in local time
   - No UTC / GMT / offsets
   - Column suffix must match MySQL data type exactly

   ------------------------
   Behaviour Rules
   ------------------------
   - No triggers
   - No MySQL ENUMs
   - No hard deletes for domain data
   - Current state is derived, never stored as flags:
       * Current location → endDateTime IS NULL
       * Current flowering → endDate IS NULL
   - Progressive identification supported (speciesId may be NULL)

   ------------------------
   Notes
   ------------------------
   - Human-facing explanation lives in *Notes fields
   - Structured logic relies only on *Code fields

   Author:	Raymond Feeney
   Created: 30/12/2025
   ============================================================ */
