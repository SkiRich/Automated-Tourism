-- Code developed for Incubator
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- You may not copy it, package it, or claim it as your own.
-- Created May 1st, 2019
-- Updated May 4th, 2019


local lf_print = false -- Setup debug printing in local file
                       -- Use if lf_print then print("something") end

local ModDir = CurrentModPath
local StringIdBase = 17764702300 -- Automated Tourism    : 702300 - 702499 File Starts at 400-499:  Next is 400
local iconATButtonNA    = ModDir.."UI/Icons/ATButtonNA.png"
local iconATButtonOn    = ModDir.."UI/Icons/ATButtonOn.png"
local iconATButtonOff   = ModDir.."UI/Icons/ATButtonOff.png"



local function ATsetButtonStatus(ref, state)
	if type(ref) ~= "table" then return end -- short circuit if ref (self) is not built yet
	local tbuttons = {
	 launchButton     = ref.parent[1],
	 rareExportButton = ref.parent[3],
	 expeditionButton = ref.parent[4],
	 salvageButton    = ref.parent[6],
	} -- tbuttons

  for item, button in pairs(tbuttons) do
  	button:SetEnabled(state)
  end -- for button

end -- ATsetButtonStatus(rocket)

----------------------- OnMsg -------------------------------------------------------------------------------

function OnMsg.ClassesBuilt()
	local XTemplates = XTemplates
  local ObjModified = ObjModified
  local PlaceObj = PlaceObj
  local ATButtonID1 = "ATButton-01"
  local ATSectionID1 = "ATSection-01"
  local EAIControlVer = "v1.0"
  local XT = XTemplates.ipBuilding[1]

  if lf_print then print("Loading Classes in AT_2Panels.lua") end

  --retro fix versioning
  if XT.AT then
  	if lf_print then print("Retro Fit Check AT Panels in ipBuilding") end
  	for i, obj in pairs(XT or empty_table) do
  		if type(obj) == "table" and obj.__context_of_kind == "SupplyRocket" and (
  		 obj.UniqueID == ATButtonID1 or obj.UniqueID == ATSectionID1 ) and
  		 obj.Version ~= ATControlVer then
  			table.remove(XT, i)
  			if lf_print then print("Removed old AT Panels Class Obj") end
  			XT.AT = nil
  		end -- if obj
  	end -- for each obj
  end -- retro fix versioning

  -- build the classes just once per game
  if not XT.AT then
    XT.AT = true
    local foundsection, idx

    -- alter the ipBuilding template for AT
    -- alter the AT button panel
    XT[#XT + 1] = PlaceObj("XTemplateTemplate", {
    	"Version", ATControlVer,
    	"UniqueID", ATButtonID1,
    	"Id", "idATbutton",
      "__context_of_kind", "SupplyRocket",
      "__condition", function (parent, context) return (not context.demolishing) and (not context.destroyed) and (not context.bulldozed) end,
      "__template", "InfopanelButton",
      "Icon", iconATButtonOff,
      "RolloverTitle", T{StringIdBase + 400, "Automated Tourism"}, -- Title Used for sections only
      "RolloverText", T{StringIdBase + 401, "Click to turn on Automated Tourism.<newline>Tourism Rocket Status:<right><em>OFF</em>"},
      "RolloverHint", T{StringIdBase + 402, "<left_click> Activate"},
      "RolloverDisabledText", T{StringIdBase + 403, "Automated Tourism disabled while rocket is set for Automatic Mode or  Rare Metals Exports is allowed.<newline>Turn off Automated Mode and Rare Metal Exports."},
      "OnContextUpdate", function(self, context)
      	local rocket = context
      	-- setup initial variables
        if type(rocket.AT_enabled) == "nil" then rocket.AT_enabled = false end

        -- enable or disable button based on exports
        if rocket.allow_export then
        	self:SetEnabled(false)
        else
        	self:SetEnabled(true)
        end -- if auto exporting

        -- toggle tourism
        if rocket.AT_enabled then
        	ATsetButtonStatus(self, false)
        	self:SetIcon(iconATButtonOn)
        	self:SetRolloverText(T{StringIdBase + 404, "Click to turn off Automated Tourism.<newline>Tourism Rocket Status:<right><em>ON</em>"})
        else
        	ATsetButtonStatus(self, true)
        	self:SetIcon(iconATButtonOff)
        	self:SetRolloverText(T{StringIdBase + 401, "Click to turn on Automated Tourism.<newline>Tourism Rocket Status:<right><em>OFF</em>"})
        end -- if not self.cxATstatus

      end, -- OnContextUpdate

      "OnPress", function(self, gamepad)
      	PlayFX("DomeAcceptColonistsChanged", "start", self.context)
        local rocket = self.context
        if not rocket.AT_enabled then
        	rocket.AT_enabled = true
        	self:SetIcon(iconATButtonOn)
        	if not rocket.auto_export then rocket:ToggleAutoExport() end
        else
        	rocket.AT_enabled = false
        	self:SetIcon(iconATButtonOff)
        	if rocket.auto_export then rocket:ToggleAutoExport() end
        	rocket:AttachSign(rocket.AT_enabled, "SignTradeRocket") -- remove sign
        	if AT_thread and IsValidThread(rocket.AT_thread) then DeleteThread(rocket.AT_thread) end -- kill the departure thread if its running
        	ATtoggleTouristBoundary(rocket, false) -- clear the tourist recall boundary
        end -- if not rocket.AT_enabled

        --if not rocket.allow_export then rocket.AT_enabled = not rocket.AT_enabled end
     	  ObjModified(self)
      end -- OnPress
    }) -- End PlaceObject

  end -- XT.AT

end -- OnMsg.ClassesBuilt