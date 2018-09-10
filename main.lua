local AddonName = ...
local Addon = CreateFrame("Frame", AddonName, _G.InterfaceOptionsFrame)
local L = _G.OMNICC_LOCALS
local CONFIG_ADDON_NAME = AddonName .. "_Config"

function Addon:Startup()
	self:SetupCommands()

	self:SetScript("OnEvent", function(f, event, ...)
		f[event](f, event, ...)
	end)

	self:SetScript("OnShow", function(f)
		LoadAddOn(CONFIG_ADDON_NAME)
		f:SetScript("OnShow", nil)
	end)

	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Addon:SetupCommands()
	_G[("SLASH_%s1"):format(AddonName)] = ("/%s"):format(AddonName:lower())

	_G[("SLASH_%s2"):format(AddonName)] = "/occ"

	_G.SlashCmdList[AddonName] = function(...)
		if ... == "version" then
			print(L.Version:format(self:GetVersion()))
		elseif self.ShowOptionsMenu or LoadAddOn(CONFIG_ADDON_NAME) then
			if type(self.ShowOptionsMenu) == "function" then
				self:ShowOptionsMenu()
			end
		end
	end
end

function Addon:SetupHooks()
	local Display = self.Display
	local GetSpellCooldown = _G.GetSpellCooldown
	local GCD_SPELL_ID = 61304
	local blacklist = {}

    local function hideTimer(cooldown)
		local display = Display:Get(cooldown:GetParent())

        if display then
            display:HideCooldownText(cooldown)
        end
    end

	local function showTimer(cooldown, duration)
		local enabled, minDuration
		local settings = Addon:GetGroupSettingsFor(cooldown)
        if settings then
            enabled = settings.enabled
			minDuration = settings.minDuration or 0
        else
            enabled = false
			minDuration = 0
		end

		if enabled and (duration or 0) > minDuration then
			Display:GetOrCreate(cooldown:GetParent()):ShowCooldownText(cooldown)
		else
			hideTimer(cooldown)
        end
	end

    local function setBlacklisted(cooldown, blacklisted)
        if blacklisted then
            if not blacklist[cooldown] then
				blacklist[cooldown] = true
                hideTimer(cooldown)
            end
        else
            blacklist[cooldown] = nil
        end
    end

	local Cooldown_MT = getmetatable(_G.ActionButton1Cooldown).__index

	hooksecurefunc(Cooldown_MT, "Clear", function(cooldown)
		hideTimer(cooldown)
	end)

	hooksecurefunc(Cooldown_MT, "SetCooldown", function(cooldown, start, duration, modRate)
        if cooldown.noCooldownCount or blacklist[cooldown] or cooldown:IsForbidden() then
            return
		end

		-- filter GCD
		local gcdStart, gcdDuration = GetSpellCooldown(GCD_SPELL_ID)
		if (gcdStart == start and gcdDuration == duration) then
			return
		end

		showTimer(cooldown, duration)
	end)

    hooksecurefunc(Cooldown_MT, "SetCooldownDuration", function(cooldown, duration)
        if cooldown.noCooldownCount or blacklist[cooldown] or cooldown:IsForbidden() then
            return
		end

		showTimer(cooldown, duration)
    end)

    hooksecurefunc("CooldownFrame_SetDisplayAsPercentage", function(cooldown)
        setBlacklisted(cooldown, true)
    end)
end

-- Events
function Addon:ADDON_LOADED(event, ...)
	if ... == AddonName then
		self:UnregisterEvent(event)

		SetCVar('countdownForCooldowns', 0)
		self:StartupSettings()
		self:SetupHooks()
	end
end

function Addon:PLAYER_ENTERING_WORLD()
	self.Timer:ForActive("Update")
end

-- Utility
function Addon:New(name, module)
	self[name] = module or LibStub("Classy-1.0"):New("Frame")

	return self[name]
end

function Addon:CreateHiddenFrame(...)
	local f = CreateFrame(...)

	f:Hide()

	return f
end

function Addon:GetButtonIcon(frame)
	if frame then
		local icon = frame.icon
		if type(icon) == "table" and icon.GetTexture then
			return icon
		end

		local name = frame:GetName()
		if name then
			icon = _G[name .. "Icon"] or _G[name .. "IconTexture"]

			if type(icon) == "table" and icon.GetTexture then
				return icon
			end
		end
	end
end

Addon:Startup()
