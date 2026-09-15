-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User defaults overrides template.
-- This file is sourced by lua/user_defaults.lua.

KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}

-- Migrated from LegacyConfigs/20260915-080235/01-UserDefaults.conf.
if hl and hl.env then
  hl.env("EDITOR", "nvim")
end

KOOLDOTS_DEFAULTS.edit = "nvim"
KOOLDOTS_DEFAULTS.term = "alacritty"
KOOLDOTS_DEFAULTS.files = "nautilus"
KOOLDOTS_DEFAULTS.search_engine = "https://www.google.com/search?q={}"
