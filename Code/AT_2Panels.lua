-- Code developed for Incubator
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- You may not copy it, package it, or claim it as your own.
-- Created May 1st, 2019
-- Updated May 1st, 2019


local lf_print = false -- Setup debug printing in local file
                       -- Use if lf_print then print("something") end

local ModDir = CurrentModPath
local StringIdBase = 17764702300 -- Automated Tourism    : 702300 - 702499 File Starts at 400-499:  Next is 400
local iconATButtonNA    = ModDir.."UI/Icons/ButtonIconBlank.png"
local iconATButtonOn    = ModDir.."UI/Icons/ButtonIconBlank.png"
local iconATButtonOff   = ModDir.."UI/Icons/ButtonIconBlank.png"

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

    --alter the ipBuilding template for AT
    -- alter the AT button panel
    XT[#XT + 1] = PlaceObj("XTemplateTemplate", {
    	"Version", ATControlVer,
    	"UniqueID", ATButtonID1,
    	"Id", "idATbutton",
      "__context_of_kind", "SupplyRocket",
      "__condition", function (parent, context) return (not context.demolishing) and (not context.destroyed) and (not context.bulldozed) end,
      "__template", "InfopanelButton",
      "Icon", iconATButtonNA,
      --"RolloverTitle", T{StringIdBase + 7, "Install Elevator A.I."}, -- Title Used for sections only
      --"RolloverText", T{StringIdBase + 8, "Install the Elevator A.I. for this Space Elevator."},
      --"RolloverHint", T{StringIdBase + 13, "<left_click> Activate<newline>Ctrl+<left_click> Uninstall A.I. from this Elevator"},
      "OnContextUpdate", function(self, context)

      end, -- OnContextUpdate

      "OnPress", function(self, gamepad)
      	PlayFX("DomeAcceptColonistsChanged", "start", self.context)

     	  ObjModified(self)
      end -- OnPress
    }) -- End PlaceObject

  end -- XT.AT

end -- OnMsg.ClassesBuilt