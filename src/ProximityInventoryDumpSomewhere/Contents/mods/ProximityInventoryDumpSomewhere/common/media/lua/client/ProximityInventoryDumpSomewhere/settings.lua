

local log = require('ProximityInventoryDumpSomewhere/log.lua');

ProximityInventoryDumpSomewhereSettings = ProximityInventoryDumpSomewhereSettings or {};
local Settings = ProximityInventoryDumpSomewhereSettings;

Settings.ModOptionsID = "ProximityInventoryDumpSomewhere";

-- Values returned when PZAPI.ModOptions is unavailable or the option is not
-- registered yet; they mirror the registered defaults.
Settings.Defaults = Settings.Defaults or { ExcludeTrashCans = true; };

-- Registers this mod's page in the vanilla B42 mod settings (Settings -> Mods tab).
-- PZAPI.ModOptions is a boot-level global whose data survives Lua reloads and
-- reads ModOptions.ini at boot, so registration is guarded to avoid a duplicate
-- page on reload. getOptions must be called with a colon (self otherwise
-- swallows the first argument and the lookup always fails).
function Settings:register()
  if PZAPI.ModOptions == nil or PZAPI.ModOptions.create == nil then
    log("PZAPI.ModOptions is not available, mod settings are not exposed");
    return;
  end

  if PZAPI.ModOptions:getOptions(self.ModOptionsID) ~= nil then
    return;
  end

  local opts = PZAPI.ModOptions:create(self.ModOptionsID, "Proximity Inventory Dump Somewhere");
  opts:addTickBox("ExcludeTrashCans", "Exclude trash cans", true,
    "Don't dump items into containers the game treats as trash cans (they offer a 'Remove All' button). Disable to allow dumping into them.");
end

Settings:register();

-- Live read of the option state. The game loads ModOptions.ini while creating the
-- settings screen at boot and updates option.value when the user presses Apply,
-- so reading the option on every call needs no event subscription and picks up
-- changes made mid-session.
---@return boolean
function Settings:isExcludeTrashCans()
  local opts = PZAPI.ModOptions and PZAPI.ModOptions:getOptions(self.ModOptionsID);
  local option = opts and opts:getOption("ExcludeTrashCans");
  if option and option.getValue then
    return option:getValue() == true;
  end
  return self.Defaults.ExcludeTrashCans;
end

return Settings;