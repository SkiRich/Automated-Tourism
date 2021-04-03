-- Code developed for Automated Tourism
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- If you are an Aboslute Games developer looking at this, just go away.  You suck at development.
-- You may not copy it, package it, or claim it as your own.
-- Created May 1st, 2019
-- Updated April 2nd, 2021


local lf_print = false -- Setup debug printing in local file
                       -- Use if lf_print then print("something") end


local ModDir   = CurrentModPath
local mod_name = "Automated Tourism"
local StringIdBase = 17764702300 -- Automated Tourism    : 702300 - 702499 File Starts at 100-199:  Next is 117
local iconATButtonNA    = ModDir.."UI/Icons/ATButtonNA.png"
local iconATButtonOn    = ModDir.."UI/Icons/ATButtonOn.png"
local iconATButtonOff   = ModDir.."UI/Icons/ATButtonOff.png"
local iconATSection     = ModDir.."UI/Icons/ATSection.png"
local iconTourist       = ModDir.."UI/Icons/ATtourist.png"
local iconClock         = ModDir.."UI/Icons/ATclock.png"
local imageTourist      = table.concat({"<image ", iconTourist, " 1000>"})
local imageClock        = table.concat({"<image ", iconClock, " 1300>"})

--  setup or tear down all the AT variables in a rocket
function ATsetupVariables(rocket, init)
  -- short circuit, just in case
  if not rocket then
    ModLog(string.format("ERROR: %s detected invalid rocket in ATsetupVariables(rocket, init)", mod_name))
    return
  end -- if not rocket
  if init then
    -- just in case these exist, kill them first
    if rocket.AT_depart_thread   and IsValidThread(rocket.AT_depart_thread)   then DeleteThread(rocket.AT_depart_thread)   end -- kill the departure thread if its running
    if rocket.AT_status_thread   and IsValidThread(rocket.AT_status_thread)   then DeleteThread(rocket.AT_status_thread)   end -- kill the status thread if its running
    if rocket.AT_boarding_thread and IsValidThread(rocket.AT_boarding_thread) then DeleteThread(rocket.AT_boarding_thread) end -- kill the boarding thread if its running
    g_AT_NumOfTouristRockets = g_AT_NumOfTouristRockets + 1 -- increment the global counter
    rocket.AT_enabled              = true     -- var used to turn system on/off
    rocket.AT_firstRun             = true     -- var used for very first pickup run
    rocket.AT_departures           = rocket.AT_departures or (rocket.boarded and #rocket.boarded) or 0  -- number of tourists returning to earth, keep departures if cycling button on/off, count boarded
    rocket.AT_arriving_tourists    = 0        -- number of tourists picked up from earth
    rocket.AT_departuretime        = 0        -- gametime var for departure time
    rocket.AT_have_departures      = false    -- bool var to signify we got departures onboard
    rocket.AT_leaving_colonists    = ((rocket.departures and #rocket.departures or 0)+(rocket.boarding and #rocket.boarding or 0)+(rocket.boarded and #rocket.boarded or 0))   -- var holds the colonists wanting to leave
    rocket.AT_boarded_colonists    = (rocket.boarded and #rocket.boarded) or 0       -- var holds the colonists that boarded
    rocket.AT_departuretimeText    = ""       -- text representation of gametime var
    rocket.AT_last_arrival_time    = 0        -- gametime var for last time rocket landed
    rocket.AT_touristBoundary      = false    -- var holds circle object for tourist boundary
    rocket.AT_last_voyage_time     = 0        -- gametime var holds last voyage from earth
    rocket.AT_next_voyage_time     = 0        -- gametime var holds next voyage from earth
    rocket.AT_next_voyage_timeText = ""       -- text representation of gametime var
    rocket.AT_status               = false    -- text var holds current status message
    rocket.AT_depart_thread        = false    -- var holds countdown thread for departures
    rocket.AT_status_thread        = false    -- var holds status thread if it exists for boarding complete
    rocket.AT_boarding_thread      = false    -- var hold boarding thread called from ATtoggleAutoExport()
    rocket.AT_GenDepartRan         = false    -- var holds status of GenerateDepartures
    rocket.AT_RecallRadiusMode     = "Mod Config Set" -- mode for recall radius
    rocket.AT_oldDecal             = false    -- var that holds the old decal entitiy
  else
    if rocket.AT_enabled then g_AT_NumOfTouristRockets = g_AT_NumOfTouristRockets - 1 end
    if rocket.AT_depart_thread and IsValidThread(rocket.AT_depart_thread) then DeleteThread(rocket.AT_depart_thread) end -- kill the departure thread if its running
    rocket.AT_depart_thread        = nil
    if rocket.AT_status_thread and IsValidThread(rocket.AT_status_thread) then DeleteThread(rocket.AT_status_thread) end -- kill the status thread if its running
    rocket.AT_status_thread        = nil
    if rocket.AT_boarding_thread and IsValidThread(rocket.AT_boarding_thread) then DeleteThread(rocket.AT_boarding_thread) end -- kill the boarding thread if its running
    rocket.AT_boarding_thread      = nil
    if rocket.AT_departures and (rocket.AT_departures < 1) then rocket.AT_departures = nil end -- if departures > 0 then keep departures if cycling on/off
    rocket.AT_arriving_tourists    = nil
    rocket.AT_departuretime        = nil
    rocket.AT_have_departures      = nil
    rocket.AT_leaving_colonists    = nil      -- var holds the colonists wanting to leave
    rocket.AT_boarded_colonists    = nil      -- var holds the colonists that boarded
    rocket.AT_departuretimeText    = nil
    rocket.AT_last_arrival_time    = nil
    ATtoggleTouristBoundary(rocket, false)    -- clear the tourist recall boundary
    rocket.AT_touristBoundary      = nil
    rocket.AT_last_voyage_time     = nil
    rocket.AT_next_voyage_time     = nil
    rocket.AT_next_voyage_timeText = nil
    rocket.AT_status               = nil
    rocket.AT_GenDepartRan         = nil
    rocket:AttachSign(false, "SignTradeRocket") -- remove sign
    rocket.AT_RecallRadiusMode     = nil
    rocket.AT_oldDecal             = nil
    rocket.AT_firstRun             = nil
    rocket.AT_enabled              = nil      -- keep this last
  end -- if init
end -- ATsetupvariables(state)


-- search for the reference points using TID, return false if not found
-- objStartPt  : the starting point
-- tId         : the id reference to find
local function ATfindReferences(objStartPt, objType, tId)
  if type(objStartPt) ~= "table" then
    ModLog("ERROR: Automated Tourism could not find reference start point.")
    return false
  end -- if type(objStartPt)

  if objType == "section" then
    for i = 1, #objStartPt do
      if TGetID(objStartPt[i].idSectionTitle.Text) == tId then return objStartPt[i] end
    end -- for i
  end -- if objType == "section"

  if objType == "button" then
    for i = 1, #objStartPt do
      if TGetID(objStartPt[i].RolloverTitle) == tId then return objStartPt[i] end
    end -- for i
  end -- if objType == "button"

  if lf_print then ModLog(string.format("ERROR: Automated Tourism could not find reference TGetID: %s", tId)) end
  return false
end -- ATfindReferences()


-- set the status of the button and show/hide status section
function ATsetButtonStatus(ref, state)
  if type(ref) ~= "table" then return end -- short circuit if ref (self) is not built yet

  local InfopanelDlg = ref.parent.parent.parent.parent.parent

  local tsections = {
    serviceArea    = ATfindReferences(InfopanelDlg.idContent, "section", 994862568830), -- idContent[2]
    droneArea      = ATfindReferences(InfopanelDlg.idContent, "section", 963695586350), -- idContent[3]
    basicResources = ATfindReferences(InfopanelDlg.idContent, "section", 494),          -- idContent[6]
    advResources   = ATfindReferences(InfopanelDlg.idContent, "section", 500) ,         -- idContent[7]
    otherResources = ATfindReferences(InfopanelDlg.idContent, "section", 12018),        -- idContent[8]
  } -- tsections

  local tbuttons = {
   launchButton     = ATfindReferences(ref.parent, "button", 526598507877), -- ref.parent[1],
   rareExportButton = ATfindReferences(ref.parent, "button", 8040),         -- ref.parent[3],
   expeditionButton = ATfindReferences(ref.parent, "button", 949636784531), -- ref.parent[4],
   salvageButton    = ATfindReferences(ref.parent, "button", 3973),         -- ref.parent[6],
  } -- tbuttons

  -- enable/disable buttons
  for item, button in pairs(tbuttons) do
    if button then button:SetEnabled(state) end
  end -- for button

  -- enable/disable AT section
  local ATSection = InfopanelDlg.idATSection -- Automated Tourism section
  ATSection:SetVisible(not state)

  -- enable/disable sections
  for item, section in pairs(tsections) do
    if section then section:SetVisible(state) end
  end -- for item

end -- ATsetButtonStatus(rocket)


-- returns the number of tourists waiting on earth
-- global used in Init file
function ATcountTouristsOnEarth()
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
    boarding       = T{StringIdBase + 156, "Boarding departures"},
    boardcomplete  = T{StringIdBase + 157, "Boarding complete"},
    departing      = T{StringIdBase + 158, "Departing"},
    checkdepart    = T{StringIdBase + 159, "Checking for departures"},
    warnleaving    = T{StringIdBase + 160, "Warning rocket leaving soon"},
    disembark      = T{StringIdBase + 161, "Colonists disembarking"},
  }
  return ui_status_list[ui_status]
end -- ATUpdateStatusText(rocket)

-- flash status based on two status, use enable to kill
function ATflashStatus(rocket, status1, status2, enable)
  rocket.AT_status = false
  -- delete thread and exit if not enabled
  if not enable and rocket and rocket.AT_status_thread and IsValidThread(rocket.AT_status_thread) then
    DeleteThread(rocket.AT_status_thread)
    rocket.AT_status_thread = false
    return
  end -- kill the status thread if its running
  if enable and rocket and status1 and status2 then
    if rocket.AT_status_thread and IsValidThread(rocket.AT_status_thread) then DeleteThread(rocket.AT_status_thread) end -- kill thread if still running
    rocket.AT_status_thread = CreateGameTimeThread(function(rocket, stat1, stat2)
      if lf_print then print(string.format("Status thread started.  Status1: %s,  Status2: %s", stat1, stat2)) end
      local threadlimit = 500 -- prevent runaway threads
      while IsValid(rocket) and threadlimit > 0 do
        rocket.AT_status = stat1
        Sleep(1000) -- wait 1 seconds
        rocket.AT_status = stat2
        Sleep(1000) -- wait 1 seconds
        threadlimit = threadlimit - 1
      end -- while
    end, rocket, status1, status2) -- AT_status_thread
  end -- if all vars
end -- ATflashStatus(rocket, status1, status2)

-- calculate funding from tourism, return string
-- added new celebrityFunds tourism
local function ATcalcTourismDollars()
  local tourismFunds = UICity and UICity.funding_gain_total.Tourist or 0
  local totalFunds = 0
  local denom = ""
  if tourismFunds > 0 then
    totalFunds = ((0.00 + tourismFunds) / const.ResourceScale) / 1000
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


-- calculate tourists within rocket range
local function ATcalcTouristsInRange(rocket)
  local domes = rocket.city.labels.Dome or ""
  local list = {}
  local touristDomes = {}
  local touristBreakdown = {
    ["1-5"] = 0,
    ["6+"] = 0,
  }
  local max_walk_dist = g_AT_Options.ATmax_walk_dist * const.ColonistMaxDomeWalkDist
  for i = 1, #domes do
    local dome = domes[i]
    local tested, suitable
    for _, c in ipairs(IsValid(dome) and dome.labels.Colonist or empty_table) do
      if not tested then
        suitable = c.traits.Tourist and ATcheckDist(rocket.landing_site, dome, max_walk_dist)
      end -- if not tested
      if suitable then
        if not touristDomes[dome.name] then touristDomes[dome.name] = 0 end
        touristDomes[dome.name] = touristDomes[dome.name] + 1
        list[#list + 1] = c
        if c.sols < 6 then touristBreakdown["1-5"] = touristBreakdown["1-5"] + 1
                      else touristBreakdown["6+"] = touristBreakdown["6+"] + 1 end
      end -- if suitable
    end -- for _
  end -- for i
  return list, touristDomes, touristBreakdown
end -- ATcalcTouristsInRange(rocket)


local function ATtouristInRangeText(rocket)
  local list, touristDomes, touristBreakdown = ATcalcTouristsInRange(rocket)
  local texts = {}
  local touristDomesTxt = table.concat(touristDomes)
  local touristBreakdownTxt = table.concat(touristBreakdown)
  local haveDomes = false

  texts[1] = T{StringIdBase + 130, "<em><center>Tourists Residing In Rocket Range<left></em>"}
  texts[2] = T{StringIdBase + 131, string.format("Total in range:<right><colonist(%s)><left><newline>", #list)}
  texts[3] = T{StringIdBase + 132, "<em><center>Sols On Mars Breakdown<left></em>"}
  texts[4] = T{StringIdBase + 133, string.format("1 to 5 Sols:<right><colonist(%s)><left>", touristBreakdown["1-5"])}
  texts[5] = T{StringIdBase + 134, string.format("6 or more Sols:<right><colonist(%s)><left>", touristBreakdown["6+"])}
  texts[6] = "<newline>"
  texts[7] = T{StringIdBase + 135, "<em><center>Local Dome Breakdown<left></em>"}

  -- add the dome names and breakdown
  for dome, count in pairs(touristDomes) do
    table.insert(texts, T{StringIdBase + 199, string.format("%s:<right><colonist(%s)><left>", dome, count)})
    haveDomes = true
  end -- for dome
  if not haveDomes then table.insert(texts, T{StringIdBase + 136, "<center>No tourists residing in rocket range<left>"}) end

  -- add the recall radius mode
  texts[#texts+1] = "<newline>"
  texts[#texts+1] = T{StringIdBase + 137,"Show recall radius: <right><em><tRecallRadius></em><left>", tRecallRadius = rocket.AT_RecallRadiusMode}

  return table.concat(texts, "<newline>")
end -- ATtouristInRangeText()


----------------------- OnMsg -------------------------------------------------------------------------------


function OnMsg.ClassesBuilt()
  local XTemplates = XTemplates
  local ObjModified = ObjModified
  local PlaceObj = PlaceObj
  local ATButtonID1 = "ATButton-01"
  local ATSectionID1 = "ATSection-01"
  local ATControlVer = "v1.26"
  local XT

  if lf_print then print("Loading Classes in AT_2Panels.lua") end


  -- retro fix versioning in old ipBuilding[1] template
  -- Tito changes
  XT = XTemplates.ipBuilding[1]
  if XT.AT then
    if lf_print then print("Retro Fit Check AT buttonss and panels in ipBuilding") end
    for i, obj in pairs(XT or empty_table) do
      if type(obj) == "table" and obj.__context_of_kind == "SupplyRocket" and (
       obj.UniqueID == ATButtonID1 or obj.UniqueID == ATSectionID1 ) and
       obj.Version ~= ATControlVer then
        table.remove(XT, i)
        if lf_print then print("Removed old AT buttons and panels ipBuilding") end
        XT.AT = nil
      end -- if obj
    end -- for each obj
  end -- retro fix versioning

  -- retro fix versioning in new customSupplyRocket[1] template
  -- remove if there and rebuild in xtemplate section
  XT = XTemplates.customSupplyRocket[1]
  if XT.AT then
    if lf_print then print("Retro Fit Check AT buttons and panels in customSupplyRocket") end
    for i, obj in pairs(XT or empty_table) do
      if type(obj) == "table" and obj.__context_of_kind == "SupplyRocket" and (
       obj.UniqueID == ATButtonID1 or obj.UniqueID == ATSectionID1 ) and
       obj.Version ~= ATControlVer then
        table.remove(XT, i)
        if lf_print then print("Removed old AT buittons and panels customSupplyRocket") end
        XT.AT = nil
      end -- if obj
    end -- for each obj
  end -- retro fix versioning


  -- build the classes just once per game
  if not XT.AT then
    XT.AT = true
    local foundsection, idx

    -- alter the infopanel template for AT
    -- alter the AT button panel
    XT[#XT + 1] = PlaceObj("XTemplateTemplate", {
      "Version", ATControlVer,
      "UniqueID", ATButtonID1,
      "Id", "idATbutton",
      "__context_of_kind", "SupplyRocket",
      "__condition", function (parent, context) return g_AT_modEnabled and context.can_fly_colonists and (not IsKindOfClasses(context, "RocketExpedition", "ForeignTradeRocket", "TradeRocket", "SupplyPod", "ArkPod", "DropPod")) and (not context.demolishing) and (not context.destroyed) and (not context.bulldozed) end,
      "__template", "InfopanelButton",
      "Icon", iconATButtonOff,
      "RolloverTitle", T{StringIdBase + 100, "Automated Tourism"}, -- Title Used for sections only
      "RolloverText", T{StringIdBase + 101, "Click to turn on Automated Tourism.<newline>Tourists waiting on earth: <em><tcount></em><newline>Tourists residing on Mars: <em><tmcount></em><newline><newline>Tourism Rocket Status: <em>OFF</em>", tcount = ATcountTouristsOnEarth(), tmcount = ATcountTouristsOnMars()},
      "RolloverHint", T{StringIdBase + 102, "<left_click> Activate"},
      "RolloverDisabledText", T{StringIdBase + 103, "Automated Tourism disabled while rocket is set for Automatic Mode or  Rare Metals Exports is allowed.<newline>Turn off Automated Mode and Rare Metal Exports."},
      "OnContextUpdate", function(self, context)
        local rocket = context

        -- enable or disable AT button based on exports
        if rocket.allow_export then
          self:SetEnabled(false)
        else
          self:SetEnabled(true)
        end -- if auto exporting

        -- begin flash sequence for status
        if (not rocket.AT_firstRun) and (not self.cxFlashStatus) and (rocket.AT_status == "boarding") and (rocket.AT_boarded_colonists >= rocket.AT_leaving_colonists) then
          ATflashStatus(rocket, "boardcomplete", "waitdepart", true)
          self.cxFlashStatus = true
        end -- if rocket.AT_status

        -- toggle tourism button status
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
          ATreplaceRocketLogo(rocket)
          self:SetIcon(iconATButtonOn)
          ATStopDepartureThreads(rocket) -- new for tourism patch there is a departure thread running all the time
          if ATcountTouristsOnEarth() > 0 then
            rocket.AT_status = "pickup"
          else
            rocket.AT_status = "flytoearth"
          end -- if ATcountTouristsOnEarth()
          if not rocket.auto_export then
            rocket:ReturnStockpiledResources() -- dump any resources on landing pad so we can launch
            rocket:ATtoggleAutoExport()
          end -- if not rocket.auto_export
        else
          self:SetIcon(iconATButtonOff)
          if rocket.auto_export then rocket:ATtoggleAutoExport() end
          ATreplaceRocketLogo(rocket, true) -- reset before AT vars clearing
          ATsetupVariables(rocket, false)
          ATStartDepartureThreads() -- there is a departure thread running all the time for regular rockets
        end -- if not rocket.AT_enabled

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
        "__condition", function (parent, context) return g_AT_modEnabled and (not IsKindOfClasses(context, "RocketExpedition", "ForeignTradeRocket", "TradeRocket", "SupplyPod", "ArkPod", "DropPod")) and (not context.demolishing) and (not context.destroyed) and (not context.bulldozed) end,
        "__template", "InfopanelSection",
        "Icon", iconATSection,
        "Title", T{StringIdBase + 105, "Tourist Rocket Status"},
        "RolloverTitle", T{StringIdBase + 100, "Automated Tourism"},
        "RolloverText", T{StringIdBase + 106, "Tourism rocket is operating a route."},
        "RolloverHint", T{StringIdBase + 107, "<right_click>Toggle showing the recall radius."},
        "OnContextUpdate", function(self, context)
          local rocket = context
          -- check for new vars on existing rockets
          if rocket.AT_enabled and (type(rocket.AT_boarded_colonists) == "nil") then
            rocket.AT_boarded_colonists = (rocket.boarded and #rocket.boarded) or 0
            rocket.AT_leaving_colonists = ((rocket.departures and #rocket.departures or 0)+(rocket.boarding and #rocket.boarding or 0)+(rocket.boarded and #rocket.boarded or 0))
          end -- if type

          if not self.cxROtext then
            self:SetRolloverText(ATtouristInRangeText(rocket))
            self.csROtext = true
          end -- not self.cxROtext

          self.idATstatusSection.idATstatusTextResult:SetText(ATUpdateStatusText(rocket.AT_status or "idle"))
          self.idATtouristSection.idATarrivingTextResult:SetText(T{StringIdBase + 199, "<AT_arriving_tourists><timageTourist>", timageTourist = imageTourist})
          self.idATtouristsOnEarthSection.idATtouristsOnEarthTextResult:SetText(T{StringIdBase + 199, "<touristsOnEarth><timageTourist>", touristsOnEarth = ATcountTouristsOnEarth(), timageTourist = imageTourist})
          self.idATtouristsOnMarsSection.idATtouristsOnMarsTextResult:SetText(T{StringIdBase + 199, "<touristsOnMars><timageTourist>", touristsOnMars = ATcountTouristsOnMars(), timageTourist = imageTourist})
          self.idATdeparturesSection.idATdeparturesTextResult:SetText(T{StringIdBase + 199, "<AT_departures><timageTourist>", timageTourist = imageTourist})
          self.idATboardingSection.idATboardingTextResult:SetText(T{StringIdBase + 199, "<AT_boarded_colonists>/<AT_leaving_colonists><timageTourist>", timageTourist = imageTourist})
          self.idATdepartureTimeSection.idATdepartureTimeTextResult:SetText(T{StringIdBase + 199, "<AT_departuretimeText>"})
          -- determine if voyage is ready
          if rocket.AT_next_voyage_time and (rocket.AT_next_voyage_time < GameTime()) then rocket.AT_next_voyage_timeText = "Ready for pickup" end
          self.idATvoyageTimeSection.idATvoyageTimeTextResult:SetText(T{StringIdBase + 199, "<AT_next_voyage_timeText>"})
          self.idATfundingSection.idATfundingTextResult:SetText(ATcalcTourismDollars())
        end, -- OnContextUpdate
      },{
         PlaceObj("XTemplateFunc", {
                  "name", "OnMouseButtonDown(self, pos, button)",
                  "parent", function(parent, context)
                          return parent.parent
                  end,
                  "func", function(self, pos, button)
                    local rocket = self.context
                    if button == "L" then
                      if lf_print then print("Left Button") end
                      PlayFX("DomeAcceptColonistsChanged", "start", rocket)
                    end -- buton L
                    if button == "R" then
                      if lf_print then print("Right Button") end
                      PlayFX("DomeAcceptColonistsChanged", "start", rocket)
                      if rocket.AT_RecallRadiusMode == "Mod Config Set" then
                        rocket.AT_RecallRadiusMode = "ON"
                        if not IsValid(rocket.AT_touristBoundary) then ATtoggleTouristBoundary(rocket, true) end
                      elseif rocket.AT_RecallRadiusMode == "ON" then
                        rocket.AT_RecallRadiusMode = "OFF"
                        ATtoggleTouristBoundary(rocket, false)
                      elseif rocket.AT_RecallRadiusMode == "OFF" then
                        rocket.AT_RecallRadiusMode = "Mod Config Set"
                        if g_AT_Options.ATrecallRadius and not IsValid(rocket.AT_touristBoundary) then ATtoggleTouristBoundary(rocket, true) end
                      end -- if rocket
                    end -- button R
                    ObjModified(rocket)
                  end
         }),

         -- Status Section
         PlaceObj('XTemplateWindow', {
           'comment', "Status Section",
          "Id", "idATstatusSection",
           "IdNode", true,
           "Margins", box(0, 0, 0, 0),
           "RolloverTemplate", "Rollover",
          },{
            -- Status Text Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATstatusText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 108, "Status:"},
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
              "Text", T{StringIdBase + 109, "Total funds from tourists:"},
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
              "Text", T{StringIdBase + 110, "Arriving tourist onboard:"},
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
              "Text", T{StringIdBase + 111, "Tourists waiting on Earth:"},
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
              "Text", T{StringIdBase + 112, "Tourists residing on Mars:"},
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
              "Text", T{StringIdBase + 113, "Departures on rocket:"},
            }),
            -- Departing Tourists Text Result Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATdeparturesTextResult",
              "Margins", box(0, 0, 0, 0),
              "TextHAlign", "right",
            }),
         }), -- end of idATtouristSection

         -- Boarding Tourists Section
         PlaceObj('XTemplateWindow', {
           'comment', "Status Section",
          "Id", "idATboardingSection",
           "IdNode", true,
           "Margins", box(0, 0, 0, 0),
           "RolloverTemplate", "Rollover",
          },{
            -- Departing Tourists Text Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATboardingText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 114, "Departures boarding rocket:"},
            }),
            -- Departing Tourists Text Result Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idATboardingTextResult",
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
              "Text", T{StringIdBase + 115, "Next departure:"},
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
              "Text", T{StringIdBase + 116, "Next voyage:"},
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