-- Code developed for Incubator
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- You may not copy it, package it, or claim it as your own.
-- Created May 1st, 2019
-- Updated May 5th, 2019


local lf_print = false -- Setup debug printing in local file
                       -- Use if lf_print then print("something") end

g_ATLoaded = true

local ModDir = CurrentModPath
local StringIdBase = 17764702300 -- Automated Tourism    : 702300 - 702499 File Starts at 100-199:  Next is 116
local iconATButtonNA    = ModDir.."UI/Icons/ATButtonNA.png"
local iconATButtonOn    = ModDir.."UI/Icons/ATButtonOn.png"
local iconATButtonOff   = ModDir.."UI/Icons/ATButtonOff.png"
local iconATSection     = ModDir.."UI/Icons/ATSection.png"

--  setup or tear down all the AT variables in a rocket
local function ATsetupVariables(rocket, init)
	if init then
		rocket.AT_enabled              = true  -- var used to turn system on/off
		rocket.AT_departures           = 0      -- number of tourists returning to earth
		rocket.AT_arriving_tourists    = 0      -- number of tourists picked up from earth
		rocket.AT_departuretime        = 0      -- gametime var for departure time
		rocket.AT_have_departures      = false  -- bool var to signify we got departures onnboard
		rocket.AT_departuretimeText    = ""     -- text representation of gametime var
		rocket.AT_last_arrival_time    = 0      -- gametime var for last time rocket landed
		rocket.AT_touristBoundary      = false  -- var holds circle object for tourist boundary
		rocket.AT_last_voyage_time     = 0      -- gametime var holds last voyage from earth
		rocket.AT_next_voyage_time     = 0      -- gametime var holds next voyage from earth
		rocket.AT_next_voyage_timeText = ""     -- text representation of gametime var
		rocket.AT_status               = false  -- text var holds current status message
		rocket.AT_thread               = false  -- var holds countdown thread for departures
	else
	  rocket.AT_enabled              = nil
		rocket.AT_departures           = nil
		rocket.AT_arriving_tourists    = nil
		rocket.AT_departuretime        = nil
		rocket.AT_have_departures      = nil
		rocket.AT_departuretimeText    = nil
		rocket.AT_last_arrival_time    = nil
		ATtoggleTouristBoundary(rocket, false) -- clear the tourist recall boundary
		rocket.AT_touristBoundary      = nil
		rocket.AT_last_voyage_time     = nil
		rocket.AT_next_voyage_time     = nil
		rocket.AT_next_voyage_timeText = nil
		rocket.AT_status               = nil
		if rocket.AT_thread and IsValidThread(rocket.AT_thread) then DeleteThread(rocket.AT_thread) end -- kill the departure thread if its running
		rocket.AT_thread               = nil
		rocket:AttachSign(rocket.AT_enabled, "SignTradeRocket") -- remove sign
	end -- if init
end -- ATsetupvariables(state)

-- set the status of the button and show/hide status section
local function ATsetButtonStatus(ref, state)
	if type(ref) ~= "table" then return end -- short circuit if ref (self) is not built yet

	local ATSection      = ref.parent.parent.parent.parent.parent.idATSection
	local ServiceArea    = ref.parent.parent.parent.parent.parent.idContent[2]
	local DroneArea      = ref.parent.parent.parent.parent.parent.idContent[3]
	local BasicResources = ref.parent.parent.parent.parent.parent.idContent[6]
	local AdvResources   = ref.parent.parent.parent.parent.parent.idContent[7]

	local tbuttons = {
	 launchButton     = ref.parent[1],
	 rareExportButton = ref.parent[3],
	 expeditionButton = ref.parent[4],
	 salvageButton    = ref.parent[6],
	} -- tbuttons

  for item, button in pairs(tbuttons) do
  	button:SetEnabled(state)
  end -- for button

  ATSection:SetVisible(not state)
  ServiceArea:SetVisible(state)
  DroneArea:SetVisible(state)
  BasicResources:SetVisible(state)
  AdvResources:SetVisible(state)

end -- ATsetButtonStatus(rocket)

-- returns the number of tourists waiting on earth
local function ATcountTouristsOnEarth()
  local applicantPool = g_ApplicantPool or ""
  local findTrait = "Tourist"
  local count = 0

  for idx = #applicantPool, 1, -1 do
  	if applicantPool[idx][1].traits[findTrait] then
  		count = count + 1
  	end -- if applicantPool
  end -- for idx

	return count
end -- ATcountTouristsOnEarth()

-- returns the number of tourists on Mars
local function ATcountTouristsOnMars()
  local colonists = (UICity and UICity.labels.Colonist) or ""
  local findTrait = "Tourist"
  local count = 0

  for i = 1, #colonists do
  	if colonists[i].traits[findTrait] then count = count + 1 end
  end -- for i

	return count
end -- ATcountTouristsOnMars()


-- updates the status text of the tourist rocket
local function ATUpdateStatusText(ui_status)
	--idATstatusTextResult
	local ui_status_list = {
		idle           = T{StringIdBase + 150, "Idle"},
		pickup         = T{StringIdBase + 151, "Picking up tourists"},
		flytoearth     = T{StringIdBase + 152, "Flying to earth"},
		flyingtourists = T{StringIdBase + 153, "Flying back with tourists"},
		flyingempty    = T{StringIdBase + 153, "Flying back empty"},
		landed         = T{StringIdBase + 154, "Landed"},
		waitdepart     = T{StringIdBase + 155, "Waiting to depart"},
	}
	return ui_status_list[ui_status]
end -- ATUpdateStatusText(rocket)


-- calculate funding from tourism, return string
local function ATcalcTourismDollars()
	local tourismFunds = (UICity and UICity.funding_gain_total.Tourist) or 0
	local totalFunds = 0
	local denom = ""
	if tourismFunds > 0 then
		totalFunds = (0.00 + tourismFunds) / const.ResourceScale / 1000
		if totalFunds >= 1000 then
			totalFunds = totalFunds / 1000
			denom = "B"
			return string.format("$%.2f%s", totalFunds, denom)
		else
			denom = "M"
			return string.format("$%d%s", totalFunds, denom)
		end -- if totalFunds
	else
		return 0
	end -- if tourismFunds
end -- ATcalcTourismDollars()


----------------------- OnMsg -------------------------------------------------------------------------------


function OnMsg.ClassesBuilt()
	local XTemplates = XTemplates
  local ObjModified = ObjModified
  local PlaceObj = PlaceObj
  local ATButtonID1 = "ATButton-01"
  local ATSectionID1 = "ATSection-01"
  local ATControlVer = "v1.1"
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
      "__condition", function (parent, context) return g_ATLoaded and (not context.demolishing) and (not context.destroyed) and (not context.bulldozed) end,
      "__template", "InfopanelButton",
      "Icon", iconATButtonOff,
      "RolloverTitle", T{StringIdBase + 100, "Automated Tourism"}, -- Title Used for sections only
      "RolloverText", T{StringIdBase + 101, "Click to turn on Automated Tourism.<newline>Tourists waiting on earth: <em><tcount></em><newline>Tourists residing on Mars: <em><tmcount></em><newline><newline>Tourism Rocket Status: <em>OFF</em>", tcount = ATcountTouristsOnEarth(), tmcount = ATcountTouristsOnMars()},
      "RolloverHint", T{StringIdBase + 102, "<left_click> Activate"},
      "RolloverDisabledText", T{StringIdBase + 103, "Automated Tourism disabled while rocket is set for Automatic Mode or  Rare Metals Exports is allowed.<newline>Turn off Automated Mode and Rare Metal Exports."},
      "OnContextUpdate", function(self, context)
      	local rocket = context

        -- enable or disable button based on exports
        if rocket.allow_export then
        	self:SetEnabled(false)
        else
        	self:SetEnabled(true)
        end -- if auto exporting

        -- toggle tourism
        if rocket.AT_enabled then
        	ATsetButtonStatus(self, false) -- set original buttons to disabled
        	self:SetIcon(iconATButtonOn)
        	self:SetRolloverText(T{StringIdBase + 104, "Click to turn on Automated Tourism.<newline>Tourists waiting on earth: <em><tcount></em><newline>Tourists residing on Mars: <em><tmcount></em><newline><newline>Tourism Rocket Status: <em>ON</em>", tcount = ATcountTouristsOnEarth(), tmcount = ATcountTouristsOnMars()})
        else
        	ATsetButtonStatus(self, true) -- set original buttons to enabled
        	self:SetIcon(iconATButtonOff)
        	self:SetRolloverText(T{StringIdBase + 101, "Click to turn on Automated Tourism.<newline>Tourists waiting on earth: <em><tcount></em><newline>Tourists residing on Mars: <em><tmcount></em><newline><newline>Tourism Rocket Status: <em>OFF</em>", tcount = ATcountTouristsOnEarth(), tmcount = ATcountTouristsOnMars()})
        end -- if not self.cxATstatus

      end, -- OnContextUpdate

      "OnPress", function(self, gamepad)
      	PlayFX("DomeAcceptColonistsChanged", "start", self.context)
        local rocket = self.context
        if not rocket.AT_enabled then
        	ATsetupVariables(rocket, true)
        	self:SetIcon(iconATButtonOn)
        	if ATcountTouristsOnEarth() > 0 then
        		rocket.AT_status = "pickup"
        	else
        		rocket.AT_status = "flytoearth"
        	end -- if ATcountTouristsOnEarth()
        	if not rocket.auto_export then rocket:ToggleAutoExport() end
        else
        	rocket.AT_enabled = false
        	self:SetIcon(iconATButtonOff)
        	if rocket.auto_export then rocket:ToggleAutoExport() end
        	ATsetupVariables(rocket, false)
        end -- if not rocket.AT_enabled

        --if not rocket.allow_export then rocket.AT_enabled = not rocket.AT_enabled end
     	  ObjModified(self)
      end -- OnPress
    }) -- End PlaceObject

    --Check for Cheats Menu and insert before Cheats menu
    --foundsection, idx = table.find_value(XT, "__template", "sectionCheats")
    --if not idx then idx = #XT + 1 end
    idx = 1 -- set tourist section up top
    if lf_print then print("Inserting AT Section Template into idx: ", tostring(idx)) end

    -- AT Status Section
    table.insert(XT, idx,
      PlaceObj("XTemplateTemplate", {
      	"UniqueID", ATSectionID1,
      	"Version", ATControlVer,
      	"Id", "idATSection",
        "__context_of_kind", "SupplyRocket",
        "__condition", function (parent, context) return g_ATLoaded and (not context.demolishing) and (not context.destroyed) and (not context.bulldozed)end,
        "__template", "InfopanelSection",
        "Icon", iconATSection,
        "Title", T{StringIdBase + 105, "Tourist Rocket Status"},
        "RolloverTitle", T{StringIdBase + 100, "Automated Tourism"},
        "RolloverText", T{StringIdBase + 106, "Status Area Text"},
        "OnContextUpdate", function(self, context)
        	local rocket = context
        	self.idATstatusSection.idATstatusTextResult:SetText(ATUpdateStatusText(rocket.AT_status or "idle"))
          self.idATtouristSection.idATarrivingTextResult:SetText(T{StringIdBase, "<colonist(AT_arriving_tourists)>"})
          self.idATtouristsOnEarthSection.idATtouristsOnEarthTextResult:SetText(T{StringIdBase, "<colonist(touristsOnEarth)>", touristsOnEarth = ATcountTouristsOnEarth()})
          self.idATtouristsOnMarsSection.idATtouristsOnMarsTextResult:SetText(T{StringIdBase, "<colonist(touristsOnMars)>", touristsOnMars = ATcountTouristsOnMars()})
          self.idATdeparturesSection.idATdeparturesTextResult:SetText(T{StringIdBase, "<colonist(AT_departures)>"})
          self.idATdepartureTimeSection.idATdepartureTimeTextResult:SetText(T{StringIdBase, "<AT_departuretimeText>"})
          -- determine if voyage is ready
          if rocket.AT_next_voyage_time and (rocket.AT_next_voyage_time < GameTime()) then rocket.AT_next_voyage_timeText = "Ready for pickup" end
          self.idATvoyageTimeSection.idATvoyageTimeTextResult:SetText(T{StringIdBase, "<AT_next_voyage_timeText>"})
          self.idATfundingSection.idATfundingTextResult:SetText(ATcalcTourismDollars())
        end, -- OnContextUpdate
      },{

      	 -- Status Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Status Section",
          "Id", "idATstatusSection",
	   			"IdNode", true,
	   			"Margins", box(0, 0, 0, 0),
    		 	"RolloverTemplate", "Rollover",
    	  	--"RolloverTitle", T{StringIdBase + 17, "Elevator A.I. Restock Schedule"},
          --"RolloverText", T{StringIdBase + 18, "The schedule is set by the frequency.  24 hours are divided by the frequency number and the A.I schedule is evenly distributed throughout the day.<newline><newline><em>Schedule</em><newline><EAI_schedule>"},
	   		 },{
          	-- Status Text Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATstatusText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 107, "Status:"},
            }),
            -- Status Text Result Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATstatusTextResult",
              "Margins", box(0, 0, 0, 0),
              "TextHAlign", "right",
              --"Text", ATUpdateStatusText("idle"),
            }),
	   	  }), -- end of idATstatusSection

      	 -- Tourism Dollars Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Status Section",
          "Id", "idATfundingSection",
	   			"IdNode", true,
	   			"Margins", box(0, 0, 0, 0),
    		 	"RolloverTemplate", "Rollover",
	   		 },{
          	-- Tourism Dollars Text Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATfundingText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 114, "Total funds from tourists:"},
            }),
            -- Tourism Dollars Text Result Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATfundingTextResult",
              "Margins", box(0, 0, 0, 0),
              "TextHAlign", "right",
            }),
	   	  }), -- end of idATfundingSection

      	 -- Arriving Tourist Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Status Section",
          "Id", "idATtouristSection",
	   			"IdNode", true,
	   			"Margins", box(0, 0, 0, 0),
    		 	"RolloverTemplate", "Rollover",
	   		 },{
          	-- Arriving Tourists Text Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATarrivingText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 108, "Arriving tourist onboard:"},
            }),
            -- Arriving Tourists Text Result Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATarrivingTextResult",
              "Margins", box(0, 0, 0, 0),
              "TextHAlign", "right",
            }),
	   	  }), -- end of idATtouristSection

      	 -- Tourist on Earth Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Status Section",
          "Id", "idATtouristsOnEarthSection",
	   			"IdNode", true,
	   			"Margins", box(0, 0, 0, 0),
    		 	"RolloverTemplate", "Rollover",
	   		 },{
          	-- Arriving Tourists Text Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATtouristsOnEarthText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 109, "Tourists waiting on Earth:"},
            }),
            -- Arriving Tourists Text Result Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATtouristsOnEarthTextResult",
              "Margins", box(0, 0, 0, 0),
              "TextHAlign", "right",
            }),
	   	  }), -- end of idATtouristOnEarthSection

      	 -- Tourist on Mars Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Status Section",
          "Id", "idATtouristsOnMarsSection",
	   			"IdNode", true,
	   			"Margins", box(0, 0, 0, 0),
    		 	"RolloverTemplate", "Rollover",
	   		 },{
          	-- Tourists on Mars Text Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATtouristsOnMarsText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 110, "Tourists residing on Mars:"},
            }),
            -- Tourists on Mars Text Result Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATtouristsOnMarsTextResult",
              "Margins", box(0, 0, 0, 0),
              "TextHAlign", "right",
            }),
	   	  }), -- end of idATtouristOnMarsSection

      	 -- Departing Tourists Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Status Section",
          "Id", "idATdeparturesSection",
	   			"IdNode", true,
	   			"Margins", box(0, 0, 0, 0),
    		 	"RolloverTemplate", "Rollover",
	   		 },{
          	-- Departing Tourists Text Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATdeparturesText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 111, "Departures on rocket:"},
            }),
            -- Departing Tourists Text Result Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATdeparturesTextResult",
              "Margins", box(0, 0, 0, 0),
              "TextHAlign", "right",
            }),
	   	  }), -- end of idATtouristSection

      	 -- Departure Time Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Status Section",
          "Id", "idATdepartureTimeSection",
	   			"IdNode", true,
	   			"Margins", box(0, 0, 0, 0),
    		 	"RolloverTemplate", "Rollover",
	   		 },{
          	-- Departure Time Text Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATdepartureTimeText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 112, "Next departure:"},
            }),
            -- Departure Time Text Result Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATdepartureTimeTextResult",
              "Margins", box(0, 0, 0, 0),
              "TextHAlign", "right",
            }),
	   	  }), -- end of idATdepartureSection

      	 -- Voyage Time Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Status Section",
          "Id", "idATvoyageTimeSection",
	   			"IdNode", true,
	   			"Margins", box(0, 0, 0, 0),
    		 	"RolloverTemplate", "Rollover",
	   		 },{
          	-- Voyage Time Text Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATvoyageTimeText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 113, "Next voyage:"},
            }),
            -- Voyage Time Text Result Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATvoyageTimeTextResult",
              "Margins", box(0, 0, 0, 0),
              "TextHAlign", "right",
            }),
	   	  }), -- end of idATvoyageSection

      }) -- End PlaceObject XTemplate
    ) --table.insert

  end -- XT.AT

end -- OnMsg.ClassesBuilt