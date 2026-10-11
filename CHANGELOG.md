# Changelog

## Unreleased

### Changed

- Remove the deprecated SQL wrapper and exports; use oxmysql directly for database access.

- Delegate generic utilities to the required ox_lib dependency. Remove duplicate
  callback, loader, point/zone, locale, table, print, ID, vehicle-property and
  scaleform APIs; consumers use ox_lib directly.
- Keep provider adapters and bridge-specific world/animation extensions, using
  ox_lib for streaming, proximity scheduling, cloning and interpolation.

## 1.0.0 - 2026-10-10

First Concept Bridge release.

- Provides the `concept_bridge` compatibility layer for FiveM frameworks,
  inventories and other providers, including Concept HUD's seatbelt, voice and
  weapon integrations.
- Includes the prebuilt UI and complete source in the downloadable resource ZIP.
- Preserves the GPLv3 license and consolidates upstream credits in `ORIGIN.Md`.

Automated checks cover fixtures and builds; in-game/provider acceptance remains
deferred.
