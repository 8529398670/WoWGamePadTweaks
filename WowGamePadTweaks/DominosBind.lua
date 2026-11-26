-- Wow GamePad Tweaks Dominos binding: controller buttons in Dominos' binding mode (LibKeyBound-1.0, so Bartender's
-- too). The library reads only the keyboard and mouse; while its mode is on, a listener takes pad presses over the
-- hovered button. Combos use the crossbar modifiers (the buttons holding leftmod and rightmod), the same way with the
-- Gamepad UI on or off:
--   nothing held -> cell layer T, game binding PAD1          leftmod held -> L, SHIFT-PAD1
--   rightmod     -> R, CTRL-PAD1                               both         -> B, CTRL-SHIFT-PAD1
-- Each press writes both forms. The game binding goes through LibKeyBound (Dominos stores and shows it); it fires
-- while the Gamepad UI is off, where the two modifier buttons act as Shift and Ctrl (GamePadEmulateShift/Ctrl, set
-- here and put back when the Gamepad UI comes on). The routed cell holds "dominos:<button>" (Face.lua fires the
-- action that button shows) and replaces what /fct had there; it fires while the Gamepad UI is on.
-- Changing that cell in /fct afterwards drops the game binding too (FCT_DOMINOS_CELL_LEFT), so both stay the same.
-- Back (Select/View/Share) over a button clears it, like Escape; clearing a button also gives back its cells.
local _, ns = ...
local Layout = ns.Layout

local DominosBind = {}
ns.DominosBind = DominosBind

local LAYERS = { "T", "L", "R", "B" }
local PREFIX = ns.Face.OFF_PREFIX
local CLEAR_KEY = "PADBACK"
local EMULATE = { shift = "GamePadEmulateShift", ctrl = "GamePadEmulateCtrl" }

local LKB
local function lib()
	if not LKB and LibStub then LKB = LibStub("LibKeyBound-1.0", true) end
	return LKB
end

local function store()
	if type(ns.db.dominos) ~= "table" then ns.db.dominos = {} end
	return ns.db.dominos
end

-- The native keys of the buttons holding leftmod and rightmod (with the Gamepad UI off the game's native config is
-- applied, so that is what they output).
local function modNatives()
	local left, right
	for phys, role in pairs(Layout.Roles()) do
		if role == "leftmod" then left = Layout.NATIVE_KEY[phys] elseif role == "rightmod" then right = Layout.NATIVE_KEY[phys] end
	end
	return left, right
end

-- The native key of the physical button that sent key now, and its name for roles (L1..P4; nil for the rest).
local function physical(key)
	local native, phys = Layout.PhysicalFor(key)
	return native or key, phys
end

-- The Bindings row code of a native key, or nil.
local function codeOf(native)
	for _, code in ipairs(ns.Face.CODES) do
		if ns.Face.CODE_KEY[code] == native then return code end
	end
end

-- Dominos hands LibKeyBound a proxy parented to the button; Bartender hands the button itself. The protected action
-- button with a name, or nil (a pet or stance button: those get the game binding only).
local function actionButton(target)
	for _, frame in ipairs({ target, target.GetParent and target:GetParent() or nil }) do
		if frame.IsProtected and frame:IsProtected() and frame:GetName() and frame:GetAttribute("action") ~= nil then return frame end
	end
end

local function buttonName(target)
	return target.GetActionName and target:GetActionName() or target:GetName() or "?"
end

-- Every cell holding this button, as { code, layer } pairs.
local function cellsOf(name)
	local out, id = {}, "dominos:" .. name
	for _, code in ipairs(ns.Face.CODES) do
		for _, layer in ipairs(LAYERS) do
			local entry = ns.Face.CellEntry(code, layer)
			if entry and entry.id == id then out[#out + 1] = { code, layer } end
		end
	end
	return out
end

local function dropCells(target)
	local frame = target and actionButton(target)
	if not frame or InCombatLockdown() then return end
	for _, cell in ipairs(cellsOf(frame:GetName())) do ns.Face.SetCellEntry(cell[1], cell[2], nil) end
end

-- Held combo buttons, from the listener's own events; with the Gamepad UI off the emulated Shift and Ctrl count too
-- (a modifier held before binding mode came on sent its press to nobody).
local held = {}

local function layerNow()
	local off = not ns.Active()
	local left = held.leftmod or off and IsShiftKeyDown()
	local right = held.rightmod or off and IsControlKeyDown()
	return left and right and "B" or left and "L" or right and "R" or "T"
end

local function assign(binder, target, native)
	local layer = layerNow()
	local key = PREFIX[layer] .. native
	-- The cell first: replacing another Dominos button's cell drops that button's binding on this key, which SetKey
	-- then takes.
	-- With the Gamepad UI on, a button the crossbar can't route (a modifier or targeting button, a pet button) isn't
	-- bound either: the game binding would fight the crossbar for that key. With it off, anything goes.
	local frame, code = actionButton(target), codeOf(native)
	local ok, err = false, frame and "that button isn't free on the crossbar" or "only action buttons go on the crossbar"
	if frame and code then
		local slot = tonumber(frame:GetAttribute("action"))
		local entry = { id = "dominos:" .. frame:GetName(), name = buttonName(target), icon = slot and slot > 0 and GetActionTexture(slot) or 134400, kind = "dominos" }
		ok, err = ns.Face.SetCellEntry(code, layer, entry)
	end
	if not ok then
		ns.debug("dominos: %s not routed: %s", key, tostring(err))
		if ns.Active() then return ns.log(("Dominos: %s not bound: %s"):format(key, tostring(err))) end
	end
	binder:SetKey(target, key)
	LKB:Set(target)
end

local listener = CreateFrame("Frame", nil, UIParent)
listener:EnableGamePadButton(true)
listener:SetPropagateKeyboardInput(true)
listener:Hide()

listener:SetScript("OnGamePadButtonDown", function(self, key)
	if InCombatLockdown() then return end
	local native, phys = physical(key)
	local role = phys and Layout.Roles()[phys]
	if role == "leftmod" or role == "rightmod" then
		held[role] = true
		return self:SetPropagateKeyboardInput(true)
	end
	local binder = LKB and LKB.frame
	local target = binder and binder:IsShown() and binder.button
	self:SetPropagateKeyboardInput(not target)
	if not target then return end
	if native == CLEAR_KEY then
		binder:ClearBindings(target)
		LKB:Set(target)
	else
		assign(binder, target, native)
	end
end)

listener:SetScript("OnGamePadButtonUp", function(self, key)
	local _, phys = physical(key)
	local role = phys and Layout.Roles()[phys]
	if role then held[role] = nil end
	if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
end)

-- The emulated modifiers: on while the Gamepad UI is off and /fct dominos mods isn't off (and the game has the
-- options); the player's own values are kept in the store and put back otherwise. Face.lua then binds a key per
-- layer (Face.OFF_PREFIX).
local function setCVar(name, value)
	if GetCVar(name) ~= nil and GetCVar(name) ~= value then SetCVar(name, value) end
end

function DominosBind.ModsOn()
	return not ns.Active() and ns.db ~= nil and store().mods ~= false and GetCVar(EMULATE.shift) ~= nil and GetCVar(EMULATE.ctrl) ~= nil
end

local function syncMods()
	if InCombatLockdown() or not ns.db then return end
	local saved = store()
	if DominosBind.ModsOn() then
		local left, right = modNatives()
		if not saved.saved then saved.saved = { shift = GetCVar(EMULATE.shift), ctrl = GetCVar(EMULATE.ctrl) } end
		setCVar(EMULATE.shift, left or "NONE")
		setCVar(EMULATE.ctrl, right or "NONE")
	elseif type(saved.saved) == "table" then
		if saved.saved.shift then setCVar(EMULATE.shift, saved.saved.shift) end
		if saved.saved.ctrl then setCVar(EMULATE.ctrl, saved.saved.ctrl) end
		saved.saved = nil
	end
	ns.Face.Refresh()
end

local function refreshHotkeys()
	local dominos = _G.Dominos
	local buttons = type(dominos) == "table" and dominos.ActionButtons
	if buttons and buttons.ForAll then pcall(buttons.ForAll, buttons, "UpdateHotkeys") end
end

-- Hotkey text for pad keys: the controller's own short names (GetBindingText(key, true), as Dominos names its gamepad
-- slots), with Shift and Ctrl shown as the combo buttons they stand for: "LT+A" for SHIFT-PAD1.
local function label(key)
	local ok, text = pcall(GetBindingText, key, true)
	return ok and text and text ~= "" and text or key
end

local function padShort(key)
	local mods, base = key:match("^(.-)(PAD%w+)$")
	if not base then return end
	local left, right = modNatives()
	local parts = {}
	if mods:find("ALT%-") then parts[#parts + 1] = "A" end
	if mods:find("SHIFT%-") then parts[#parts + 1] = left and label(left) or "S" end
	if mods:find("CTRL%-") then parts[#parts + 1] = right and label(right) or "C" end
	parts[#parts + 1] = label(base)
	return table.concat(parts, "+")
end

local hooked
local function setUp()
	if hooked or not lib() then return end
	hooked = true

	local toShort = LKB.ToShortKey
	function LKB:ToShortKey(key)
		local short = type(key) == "string" and padShort(key)
		if short then return short end
		return toShort(self, key)
	end
	LKB.RegisterCallback(DominosBind, "LIBKEYBOUND_ENABLED", function()
		wipe(held)
		if LKB.frame and not LKB.frame.fctHooked then
			LKB.frame.fctHooked = true
			-- Escape and Back both clear through here: the button's cells go too.
			hooksecurefunc(LKB.frame, "ClearBindings", function(_, target) dropCells(target) end)
		end
		listener:Show()
	end)
	LKB.RegisterCallback(DominosBind, "LIBKEYBOUND_DISABLED", function()
		listener:Hide()
		wipe(held)
	end)
	refreshHotkeys()
end

ns.On("PLAYER_LOGIN", setUp)
ns.On("ADDON_LOADED", setUp)
-- Roles decide the modifier buttons; a cell change alone needs nothing here.
for _, event in ipairs({ "FCT_ACTIVE_CHANGED", "PLAYER_ENTERING_WORLD", "FCT_LAYOUT_CHANGED" }) do
	ns.On(event, function(reason)
		if event == "FCT_LAYOUT_CHANGED" and reason == "remap" then return end
		ns.whenPadFree("dominos modifiers", syncMods)
		if hooked then refreshHotkeys() end
	end)
end

-- True when key's game binding clicks this action bar button (Dominos' "CLICK <button>:HOTKEY" or its command name).
-- name nil: any protected action bar button (Dominos, Bartender).
local function clicksButton(action, name)
	local target = action:match("^CLICK ([^:]+):")
	local frame = _G[name or target or ""]
	if type(frame) ~= "table" or not (frame.IsProtected and frame:IsProtected() and frame.GetAttribute) then return false end
	if name then return target == name or action == frame:GetAttribute("commandName") end
	return target ~= nil and frame:GetAttribute("action") ~= nil
end

local function unbind(key, why)
	SetBinding(key, nil)
	local save = SaveBindings or AttemptToSaveBindings
	if save then save(GetCurrentBindingSet()) end
	ns.debug("dominos: %s unbound (%s)", key, why)
end

-- A cell set in /fct (or here) takes its combo from any action bar button bound to it, so the two never disagree:
-- a Dominos cell replaced or cleared drops that button's binding, and any other action placed there drops a button
-- binding on the same combo (it would fight the router for the key with the Gamepad UI off).
ns.On("FCT_CELL_SET", function(code, layer, new, old)
	if InCombatLockdown() or (new and new.kind == "dominos") then return end
	local native = ns.Face.CODE_KEY[code]
	if not (native and PREFIX[layer]) then return end
	local key = PREFIX[layer] .. native
	local action = GetBindingAction(key)
	if action == "" then return end
	local oldName = old and old.kind == "dominos" and tostring(old.id):match("^dominos:(.+)$")
	if oldName and clicksButton(action, oldName) then return unbind(key, "its cell " .. code .. "/" .. layer .. " changed") end
	if new and clicksButton(action) then unbind(key, "cell " .. code .. "/" .. layer .. " took it") end
end)

-- /fct dominos [mods on|off]: the state, or the emulated modifiers on or off.
function ns.commands.dominos(args)
	local word, value = (args or ""):lower():match("^(%S*)%s*(%S*)")
	if word == "mods" and (value == "on" or value == "off") then
		store().mods = value == "on"
		syncMods()
		ns.Face.Refresh()
		refreshHotkeys()
		ns.log("Dominos: controller Shift/Ctrl " .. (value == "on" and "on while the Gamepad UI is off" or "off (your own settings are back)"))
		return
	end
	local left, right = modNatives()
	ns.log(("dominos: LibKeyBound %s, binding mode %s, Gamepad UI %s, combo buttons %s/%s, mods %s, Shift=%s Ctrl=%s"):format(
		lib() and "found" or "not loaded", tostring(LKB and LKB:IsShown() or false), ns.Active() and "on" or "off",
		tostring(left), tostring(right), store().mods == false and "off" or "on",
		tostring(GetCVar(EMULATE.shift)), tostring(GetCVar(EMULATE.ctrl))))
	for _, code in ipairs(ns.Face.CODES) do
		for _, layer in ipairs(LAYERS) do
			local entry = ns.Face.CellEntry(code, layer)
			if entry and entry.kind == "dominos" then ns.log(("  %s/%s (%s%s): %s"):format(code, layer, PREFIX[layer], tostring(ns.Face.CODE_KEY[code]), tostring(entry.name))) end
		end
	end
end
