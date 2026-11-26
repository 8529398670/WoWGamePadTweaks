-- Wow GamePad Tweaks NPC windows by controller (Gamepad UI off): the Gamepad UI has its own controller NPC windows,
-- the standard ones only take the mouse. While a gossip or quest window shows (out of combat, Gamepad UI off), the
-- D-pad moves a gold highlight over its buttons (options, quests, reward choices, Accept / Complete), A clicks the
-- highlighted one and B closes the window. Priority override bindings on our own (plain, unprotected) button, set
-- while the window shows and cleared when it hides or a fight starts. Only Blizzard's own buttons are clicked, so
-- the window does exactly what a mouse click would.
local _, ns = ...

local KEYS = { PAD1 = "select", PAD2 = "close", PADDUP = "up", PADDDOWN = "down", PADDLEFT = "left", PADDRIGHT = "right" }

local owner = CreateFrame("Frame", nil, UIParent)
local buttons, focus, bound = {}, nil, false

local highlight = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
highlight:SetFrameStrata("TOOLTIP")
highlight:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
highlight:SetBackdropBorderColor(1, 0.82, 0, 1)
highlight:Hide()

local hint = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetText("D-pad: move   A: choose   B: close")
hint:Hide()

local function shownFrame()
	if GossipFrame and GossipFrame:IsShown() then return GossipFrame end
	if QuestFrame and QuestFrame:IsShown() then return QuestFrame end
end

local function wanted()
	return shownFrame() ~= nil and not ns.Active() and not InCombatLockdown()
end

local function hasText(button)
	local text = button.GetText and button:GetText()
	if (not text or text == "") and button.Name and button.Name.GetText then text = button.Name:GetText() end
	return text and text ~= ""
end

-- Shown, enabled, clickable buttons with text under root (scroll bars and close boxes have none).
local function collect(root, out)
	for _, child in ipairs({ root:GetChildren() }) do
		if child:IsVisible() then
			-- Reward items that aren't choices are only shown, not picked.
			if child:IsObjectType("Button") and child:IsEnabled() and child:IsMouseEnabled() and hasText(child) and (not child.type or child.type == "choice") then
				out[#out + 1] = child
			end
			collect(child, out)
		end
	end
	return out
end

-- Reward choices (quest turn-in), in their own grid.
local function rewardChoices(out)
	local rewards = QuestInfoRewardsFrame
	for _, button in ipairs(rewards and rewards:IsVisible() and rewards.RewardButtons or {}) do
		if button:IsVisible() and button.type == "choice" then out[#out + 1] = button end
	end
	return out
end

local function byPosition(a, b)
	local at, bt = a:GetTop() or 0, b:GetTop() or 0
	if math.abs(at - bt) > 4 then return at > bt end
	return (a:GetLeft() or 0) < (b:GetLeft() or 0)
end

local function contains(list, item)
	for _, value in ipairs(list) do
		if value == item then return true end
	end
end

local function setFocus(button)
	if focus and focus ~= button and focus:GetScript("OnLeave") then pcall(focus:GetScript("OnLeave"), focus) end
	focus = button
	if not button then return highlight:Hide() end
	highlight:ClearAllPoints()
	highlight:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
	highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4)
	highlight:Show()
	-- A reward's tooltip, as hovering it shows.
	if button.type == "choice" and button:GetScript("OnEnter") then pcall(button:GetScript("OnEnter"), button) end
end

-- The button a window should start on: Accept, Continue or Complete when there is one, else the first.
local function defaultFocus()
	if QuestFrameAcceptButton and contains(buttons, QuestFrameAcceptButton) then return QuestFrameAcceptButton end
	if QuestFrameCompleteButton and contains(buttons, QuestFrameCompleteButton) then return QuestFrameCompleteButton end
	local choices = rewardChoices({})
	if #choices > 1 then return choices[1] end
	if QuestFrameCompleteQuestButton and contains(buttons, QuestFrameCompleteQuestButton) then return QuestFrameCompleteQuestButton end
	return buttons[1]
end

local function rebuild()
	local frame = shownFrame()
	wipe(buttons)
	if frame then
		collect(frame, buttons)
		for _, choice in ipairs(rewardChoices({})) do
			if not contains(buttons, choice) then buttons[#buttons + 1] = choice end
		end
		table.sort(buttons, byPosition)
	end
	if not (focus and contains(buttons, focus)) then setFocus(defaultFocus()) end
end

local function close()
	if GossipFrame and GossipFrame:IsShown() then
		if C_GossipInfo and C_GossipInfo.CloseGossip then C_GossipInfo.CloseGossip() else HideUIPanel(GossipFrame) end
	elseif QuestFrame and QuestFrame:IsShown() then
		if CloseQuest then CloseQuest() else HideUIPanel(QuestFrame) end
	end
end

-- The previous (up, left) or next (down, right) button in reading order, wrapping around.
local function move(direction)
	rebuild()
	if #buttons == 0 then return end
	local index = 1
	for i, button in ipairs(buttons) do
		if button == focus then index = i end
	end
	local step = (direction == "up" or direction == "left") and -1 or 1
	setFocus(buttons[(index - 1 + step) % #buttons + 1])
end

local function select()
	rebuild()
	local button = focus
	if not button then return end
	local wasChoice = button.type == "choice"
	button:Click()
	-- Picking a reward moves on to Complete Quest.
	if wasChoice and QuestFrameCompleteQuestButton and QuestFrameCompleteQuestButton:IsVisible() then
		setFocus(QuestFrameCompleteQuestButton)
	end
	C_Timer.After(0.05, function() if shownFrame() then rebuild() end end)
end

local actions = { select = select, close = close, up = function() move("up") end, down = function() move("down") end,
	left = function() move("left") end, right = function() move("right") end }

local clickers = {}
for key, action in pairs(KEYS) do
	local button = CreateFrame("Button", "WowGamePadTweaksNPC" .. action:gsub("^%l", string.upper), UIParent)
	button:SetScript("OnClick", function() actions[action]() end)
	clickers[key] = button
end

local function update()
	if wanted() then
		if not bound then
			for key, button in pairs(clickers) do SetOverrideBindingClick(owner, true, key, button:GetName(), "LeftButton") end
			bound = true
			ns.debug("npc windows: controller on (%s)", shownFrame():GetName() or "?")
		end
		local frame = shownFrame()
		hint:ClearAllPoints()
		hint:SetPoint("TOP", frame, "BOTTOM", 0, -4)
		hint:Show()
		C_Timer.After(0, function() if wanted() then rebuild() end end)
	else
		if bound and not InCombatLockdown() then
			ClearOverrideBindings(owner)
			bound = false
		end
		hint:Hide()
		setFocus(nil)
	end
end

for _, event in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED", "PLAYER_REGEN_ENABLED", "FCT_ACTIVE_CHANGED" }) do
	ns.On(event, function()
		-- A new page of the same window starts on its own default button.
		if event ~= "PLAYER_REGEN_ENABLED" and event ~= "FCT_ACTIVE_CHANGED" then setFocus(nil) end
		-- The closed events fire before the frame hides.
		C_Timer.After(0, update)
	end)
end
-- Bindings can't change in a fight: they go as it starts and come back after it if the window is still open.
ns.On("FCT_COMBAT_START", function()
	if bound then
		ClearOverrideBindings(owner)
		bound = false
	end
	hint:Hide()
	setFocus(nil)
end)
for _, name in ipairs({ "GossipFrame", "QuestFrame" }) do
	local frame = _G[name]
	if frame then
		frame:HookScript("OnShow", function() C_Timer.After(0, update) end)
		frame:HookScript("OnHide", function() C_Timer.After(0, update) end)
	end
end
