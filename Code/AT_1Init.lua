-- Code developed for Automated Tourism
-- Coyright 2018-2021 SkiRich @ Szkodzinski.com
-- All rights reserved, terms of use is governed by license, see LICENSE file for details
-- If you are an Aboslute Games developer looking at this, just go away.  You suck at development.
-- Created May 1st, 2019
-- Hotfix Jan 25th, 2020
-- Tourism patch fixes March 15th 2021
-- Update Sept 21th, 2021

local lf_printdistance = false -- setup debug for distance checking
                               -- Use Msg("ToggleLFPrint", "AT", "distance")

local lf_printcolonist = false -- setup debug colonist leaving
                               -- Use Msg("ToggleLFPrint", "AT", "colonist")

local lf_print = false -- Setup debug printing in local file
                       -- Use if lf_print then print("something") end
                       -- use Msg("ToggleLFPrint", "AT") to toggle

-- global variables
g_AT_modEnabled = true  -- used in xtemplate condition.  If missing the xtemplate will not show - must be global non-persistent
                        -- also used to revert re-writen code to original function
                        -- settable Mod Config Reborn
-- global variable to contain AT options
g_AT_Options = {
  ATdismissMsg        = true,
  ATnoticeDismissTime = 20 * 1000, -- 20 seconds the dismiss time for notifications
  ATMaxTourists       = 20,        -- Maximum number of tourists per rocket
  ATvoyageWaitTime    = 5,         -- Wait this amount of sols between voyages
  ATrecallRadius      = true,      -- display recall radius on landed rocket
  ATearlyDepartures   = true,      -- allow for earlier departures when voyages waiting
  ATexpressOverstay   = true,      -- allow for early departure of there are nearby overstaying tourists
  ATstripSpecialty    = true,      -- strip a tourists specialty upon arrival
  ATpreventDepart     = true,      -- prevents colonists from using non AT rockets to depart
  ATmax_walk_dist     = 2,         -- x const.ColonistMaxDomeWalkDist for calcs in recall and boundary
  ATfoodPerTourist    = 1,         -- Food each tourist brings to mars on board rocket
  ATreplaceLogo       = true,      -- replace the tourism rocket logo with Mars Touring Company
} -- g_AT_Options

-- Save game fixup variables
g_AT_fixupVer = "220"
GlobalVar("g_AT_currentFixupVer", "0")

g_AT_NumOfTouristRockets = 0       -- keeps track of the number of tourist rockets
g_AT_RocketCheckComplete = false   -- lets other processes know we checked the savegame for tourist rockets

-- trait table we use for boarded tourists on ejection routines
local ATcolonistGenTraits = {
  -- these are the standards for GenerateArrivals Colonist:New()
  GenTraits = {"age", "age_trait", "birthplace", "city", "entity_gender", "gender", "name", "race", "specialist", "traits"},
  -- these we'll keep as we eject the tourists to set them as they were
  ReplaceTraits = {"base_base_morale", "base_birth_comfort_modifier", "base_DailyHealthRecover", "base_DailySanityRecover", "base_morale", "base_performance",
                   "daily_interest", "death_age", "entity", "infopanel_icon", "inner_entity", "ip_specialization_icon", "log_comfort", "log_health", "log_sanity", "log_satisfaction",
                   "performance", "pin_icon", "pin_specialization_icon", "sols", "stat_comfort", "stat_health", "stat_morale", "stat_sanity", "stat_satisfaction", "workplace_shift", "status_effects" }
} -- local ATcolonistGenTraits

local StringIdBase = 17764702300 -- Automated Tourism    : 702300 - 702499 File Starts at 0-50:  Next is 7
local ModDir   = CurrentModPath
local mod_name = "Automated Tourism"
local iconATnoticeIcon = ModDir.."UI/Icons/ATNoticeIcon.png"

-- count the number of AT rockets in play
local function ATcountATrockets()
  local ATcount = 0
  local rockets = UIColony and UIColony.city_labels.labels.SupplyRocket or empty_table  -- current for Picard
  for i = 1, #rockets do
    if rockets[i].AT_enabled then ATcount = ATcount + 1 end
  end -- for i
  return ATcount
end -- ATcountATrockets()

-- return sol, hour and minute of curreentTime as a string
-- currentTime   : GameTime var
function ATConvertDateTime(currentTime)
  local deltaTime = (currentTime or GameTime()) + (6 * const.HourDuration) + const.DayDuration
  local sol    = (deltaTime / const.DayDuration)
  local hour   = ((deltaTime % const.DayDuration) / const.HourDuration)
  local minute = ((deltaTime % const.DayDuration) % const.HourDuration) / const.MinuteDuration
  return string.format("Sol: %s Time: %02d:%02d", sol, hour, minute)
end -- ATConvertDateTime()



-- checks to see if there are tourists that have overstayed in range of the rocket
local function ATcheckForExpressOverStay(rocket)
  local domes = rocket.city.labels.Dome or empty_table
  local map = rocket:GetMapID() or MainMapID
  local overstayedTourists = g_OverstayingTourists[map] or empty_table
  local max_walk_dist = g_AT_Options.ATmax_walk_dist * const.ColonistMaxDomeWalkDist
  local count = 0
  
  for i = 1, #domes do
    local dome = domes[i]
    local suitable    
    for _, c in ipairs(IsValid(dome) and dome.labels.Colonist or empty_table) do
        if c:CanChangeCommand() and (c.traits.Tourist and c.sols > g_Consts.TouristSolsOnMarsMin) then
          suitable = ATcheckDist(c:GetMapID(), rocket, dome, max_walk_dist)
          if suitable then count = count + 1 end
        end -- if c:CanChangeCommand
    end -- for _, c
  end -- for i
  if count > 0 then return true end
  return false
end -- ATcheckForExpressOverStay(rocket)


-- calculate departure time
local function ATcalcDepartureTime(rocket)

  if rocket.AT_leaving_colonists <= 0 then
    if lf_print then print("No leaving colonists on: ", rocket.name) end
    --no deparures then wait X days
    rocket.AT_departuretime = rocket.AT_last_arrival_time + const.HourDuration + (5 * const.DayDuration) -- wait 5 days and 1 hour to depart if no immediate departures
    rocket.AT_have_departures = false
    -- check for early departures if voyages exist
    if g_AT_Options.ATexpressOverstay and ATcheckForExpressOverStay(rocket) then
      if lf_print then print("Express Overstay rocket running: ", rocket.name) end
      rocket.AT_departuretime = GameTime() + (6 * const.HourDuration)
      rocket.AT_express = true
    elseif g_AT_Options.ATearlyDepartures and rocket.AT_next_voyage_time and (rocket.AT_next_voyage_time <= rocket.AT_departuretime) then
      if rocket.AT_next_voyage_time <= GameTime() then
        rocket.AT_departuretime = GameTime() + (12 * const.HourDuration)
      else
        rocket.AT_departuretime = rocket.AT_next_voyage_time
      end -- if rocket.AT_next_voyage_time
    end -- if g_AT_Options.ATexpressOverstay
  else
    if lf_print then print("Departures boarding on rocket: ", rocket.name) end
    -- if we have departures then reset last arrival time to now so we can recalculate departure time properly
    rocket.AT_departuretime = GameTime() + (12 * const.HourDuration) -- wait 1/2 day to depart since we got departures
    rocket.AT_have_departures = true
  end -- rocket.AT_leaving_colonists

  -- add departure time text
  rocket.AT_departuretimeText = ATConvertDateTime(rocket.AT_departuretime)

end -- ATcalcDepartureTime()


-- toggle the tourist recall boundary circle
function ATtoggleTouristBoundary(rocket, state)
    -- just in case the circle is still painted or painted off map
    -- caused if mod options changed while still in space
    if state and rocket.AT_touristBoundary then
      DoneObject(rocket.AT_touristBoundary)
      rocket.AT_touristBoundary = false
    end -- if rocket.AT_touristBoundary

    -- setup rocket recall tourist boundary
    if state and (not rocket.AT_touristBoundary) and not (rocket:GetPos() == InvalidPos()) then
      rocket.AT_touristBoundary = Circle:new()
      rocket.AT_touristBoundary:SetPos(rocket:GetPos())
      rocket.AT_touristBoundary:SetRadius(g_AT_Options.ATmax_walk_dist * const.ColonistMaxDomeWalkDist)
      rocket.AT_touristBoundary:SetColor(white)
    end -- if not rocket.touristBoundary

    -- turn off boundary
    if (not state) and rocket.AT_touristBoundary and IsValid(rocket.AT_touristBoundary) then
      DoneObject(rocket.AT_touristBoundary)
      rocket.AT_touristBoundary = false
    end -- if rocket.AT_touristBoundary
end -- ATtoggleTouristBoundary(rocket, state)



-- function that fixes various save game issues
-- only runs if game save was from previous version
local function ATfixupSaves()
  -- if we got things to fix update the ver
  if g_AT_currentFixupVer ~= g_AT_fixupVer then
    g_AT_currentFixupVer = g_AT_fixupVer

    -- fix for stuck rockets waiting to unload cargo
    -- do this once and never again since its fixed going forward in templates
    local rockets = UIColony and UIColony.city_labels.labels.SupplyRocket or empty_table
    for i = 1, #rockets do
      if rockets[i].AT_enabled then
        if (rockets[i].status == "launch suspended") and (rockets[i]:GetStoredAmount() > 0) then
          rockets[i]:ToggleAutoExport()
          rockets[i]:ReturnStockpiledResources()
          rockets[i]:ToggleAutoExport()
        end -- if rockets[i].status == "launch suspended"
        if type(rockets[i].AT_RecallRadiusMode) == "nil" then rockets[i].AT_RecallRadiusMode = "Mod Config Set" end
      end -- if rockets[i].AT_enabled
    end -- for i
  end -- if g_AT_currentFixupVer
end -- ATfixupSave()

-- copied from dome.lua  its a local function - Boo-Hiss
local function ResolvePos(realm, bld1, bld2)
  local pos
  local invalid_pos = InvalidPos()
  if IsPoint(bld1) then
    pos = bld1
  else
    bld1 = IsKindOf(bld1, "Unit") and (IsUnitInDome(bld1) or bld1.holder) or bld1
    if IsValid(bld1) then
      if IsKindOf(bld1, "Building") then
        bld1 = bld1.parent_dome or bld1
        local entrance
        entrance, pos = bld1:GetEntrance(bld2)
        pos = pos or bld2 and bld1:GetSpotPos(bld1:GetNearestSpot("idle", "Workdrone", bld2))
      end
      pos = pos or bld1:GetPos()
    end
  end
  return pos and invalid_pos ~= pos and realm:GetPassablePointNearby(pos)
end -- function ResolvePos(realm, bld1, bld2)

-- rewrite of CheckDist which is in dome.lua but is a local ... boo-hiss
-- called in panels so is global now
function ATcheckDist(map_id, bld1, bld2, distance)
  -- local CheckDist = function(bld1, bld2)
  -- from _GameConst.lua
  -- these changed since curiosity patch
  -- const.ColonistMaxDepartureRocketDist = 1200 * guim --when leaving, a rocket cant be used if placed beyond that distance from the dome
  -- const.ColonistMaxDomeWalkDist = 400 * guim -- distance between two domes to consider them in walk range

  local realm = GetRealmByID(map_id)
  local p1, p2 = ResolvePos(realm, bld1, bld2), ResolvePos(realm, bld2, bld1)
  if not p1 or not p2 then
    if lf_printdistance then print("--- Distance not resolved sending false") end
    return false, max_int
  end
  if p1 == p2 then
    if lf_printdistance then print("--- Distance calc not needed, same building") end
    return true, 0
  end
  local len_sl = p1:Dist2D(p2)
  if len_sl > distance then
    if lf_printdistance then print("--- Distance too far, sending false") end
    return false, len_sl, true
  end
  local has_path, len = PathLenCached(map_id, p1, Colonist.pfclass, p2)
  if has_path and len > distance then
    if lf_printdistance then print("--- Distance OK but no path to destination, sending false") end
    has_path = false
  end
  if lf_printdistance then print("--- ATcheckDist result: ", has_path) end
  -- return has_path or false, len
  return has_path or false
end -- ATcheckDist(bld1, bld2)


-- start all the departure threads if possible on SupplyRockets only
-- made global - used in all files
function ATStartDepartureThreads()
  -- start the departure threads only if there are no more AT rockets
  -- only for landed supply rockets
  if (g_AT_NumOfTouristRockets < 1) or (not g_AT_Options.ATpreventDepart) then
    local rockets = UIColony and UIColony.city_labels.labels.SupplyRocket or empty_table
    for i = 1, #rockets do
      if rockets[i]:IsRocketOnMars() and rockets[i].can_fly_colonists and (not rockets[i].AT_enabled) and
      (not IsKindOfClasses(rockets[i], "RocketExpedition", "ForeignTradeRocket", "TradeRocket", "SupplyPod", "ArkPod", "DropPod", 
                                       "RefugeeRocket", "ForeignAidRocket", "RocketBuildingBase")) then
        rockets[i]:StartDepartureThread() 
      end -- if rockets
    end -- for i
  end -- if g_AT_NumOfTouristRockets
end -- function ATStartDepartureThreads()


-- stop all the departure threads on all landed rockets of all types.
-- devs made a mistake and thiss should have never happened.
-- made global - used in all files
-- new for tourism patch there is a departure thread running all the time
function ATStopDepartureThreads(rocket)
  local rockets

  -- kill the current rocket thread immediatly
  if rocket then rocket:StopDepartureThread() end

  -- check all landed supply rockets for thread and kill
  -- dont kill if g_AT_Options.ATpreventDepart is false
  -- only for landed supply rockets
  if g_AT_Options.ATpreventDepart then
    rockets = UIColony and UIColony.city_labels.labels.SupplyRocket or empty_table
    for i = 1, #rockets do
      if rockets[i]:IsRocketOnMars() then
        rockets[i]:StopDepartureThread()
        if not IsValidThread(rockets[i].departure_thread) then rockets[i].departure_thread = false end -- easy to spot in examine
      end -- for i
    end -- for i
  end -- if g_AT_Options.ATpreventDepart

  -- check all landed trade rockets for thread and kill - what where they thinking letting these have departure threads
  -- only for landed trade rockets
  rockets = UIColony and UIColony.city_labels.labels.TradeRocket or empty_table
  for i = 1, #rockets do
    if rockets[i]:IsRocketOnMars() then
      rockets[i]:StopDepartureThread()
      if not IsValidThread(rockets[i].departure_thread) then rockets[i].departure_thread = false end -- easy to spot in examine
    end -- for i
  end -- for i

  -- check all landed foreign trade rockets for thread and kill - what where they thinking letting these have departure threads
  -- only for landed trade rockets
  rockets = UIColony and UIColony.city_labels.labels.ForeignTradeRocket or empty_table
  for i = 1, #rockets do
    if rockets[i]:IsRocketOnMars() then
      rockets[i]:StopDepartureThread()
      if not IsValidThread(rockets[i].departure_thread) then rockets[i].departure_thread = false end -- easy to spot in examine
    end -- for i
  end -- for i

end -- function ATStopDepartureThreads(rocket)


-- function to eject any colonists that have boarded a rocket to return to earth
-- global used panels
function ATejectColonists(rocket)
  -- do not run if thread already started
  if rocket.disembarking and (#rocket.disembarking > 0) then return end -- short circuit in case people are still getting off
  if IsValid(rocket) and (not rocket:IsDeparting()) and rocket:IsRocketOnMars() and ((rocket.boarded and #rocket.boarded > 0)) and not IsValidThread(rocket.AT_eject_thread) then
    rocket:StopDepartureThread() -- got to kill this thread first otherwise they turn around and come back
    
    -- start the thread
    rocket.AT_eject_thread = CreateGameTimeThread(function(rocket)

      local tEjectedColonists = {}
      -- setup new table and remove some of the unecessary fields to generate colonist table
      -- keep old colonist data where it makes sense
      -- remove colonists from boarded var - counting backwards to avoid table corruption and allow for new additions simulatneously
      local idx = #rocket.boarded
      for i = idx, 1, -1 do
        local colonist = table.remove(rocket.boarded, i) or empty_table
        tEjectedColonists[i] = {}
        for _, traitList in pairs(ATcolonistGenTraits) do
          for j = 1, #traitList do
            local data = traitList[j]
            if colonist[data] then tEjectedColonists[i][data] = colonist[data] end
          end -- for j
        end -- for _, trait
        tEjectedColonists[i].boardedData = colonist -- save the boarded data in case we need to put these colonists back during ejection
        if tEjectedColonists[i].sols and tEjectedColonists[i].sols > 0 then tEjectedColonists[i].oldSols = tEjectedColonists[i].sols end -- need to replace this after generating new colonist
      end -- for i

      if not rocket.disembarking then rocket.disembarking = {} end
      rocket.disembarking_confused = false
      local city = rocket.city
      local domes, safety_dome = GetDomesInWalkableDistance(city, rocket:GetPos())
      local num_colonists = 0
      local num_tourists = 0

      idx = #tEjectedColonists
      -- only generate new colonists if not in the process of leaving
      while (idx > 0) and IsValid(rocket) and (not rocket:IsDeparting()) do
        local applicant = table.remove(tEjectedColonists, idx)
        if applicant then
          applicant.boardedData = nil -- too late, cant use it anymore so dump it
          if applicant.traits.Tourist then
            num_tourists = num_tourists + 1
          else
            num_colonists = num_colonists + 1
          end
          local dome = ChooseDome(applicant.traits, domes, safety_dome)
          applicant.emigration_dome = dome
          applicant.city = dome and dome.city or city
          applicant.arriving = rocket
                    
          local colonist = Colonist:new(applicant, rocket:GetMapID())

          -- put back the time they were on mars
          if colonist.oldSols then
            colonist.sols = colonist.oldSols
            colonist.oldSols = nil
          end -- if colonist.oldSols
          -- if the time is an overstay put them back in the overstay group
          -- no need to modify their satifaction, its already accounted for
          if colonist.traits.Tourist and colonist.sols >= g_Consts.TouristSolsOnMarsMax then
            RequestNewObjsNotif(g_OverstayingTourists, colonist, colonist:GetMapID(), true)
            if HintsEnabled then
              HintTrigger("HintOverstayingTourists")
            end
          end -- if self.traits.Tourist

          rocket.disembarking[#rocket.disembarking + 1] = colonist
          Sleep(1000 + Random(0, 500))
        end -- if applicant
        idx = idx - 1
      end -- while
      
      -- in case we takeoff while ejecting colonists, put the left overs that didnt make it out back in boarded
      if IsValid(rocket) and rocket:IsDeparting() and (#tEjectedColonists > 0) then
        -- rocket.boarded = tEjectedColonists or empty_table
        for _, c in pairs(tEjectedColonists or empty_table) do
          rocket.boarded[#rocket.boarded+1] = c.boardedData
        end -- for _, c
        if rocket.AT_enabled then rocket.AT_departures = #tEjectedColonists or 0 end
      end -- if IsValid
      
      -- hold rocket until all have left rocket
      while (#rocket.disembarking > 0) do
        rocket:CheckDisembarkationTable()
        Sleep(100) -- 1/10 of a second
      end -- while
           
      if num_colonists > 0 then
        AddOnScreenNotification("NewColonists", nil, {count = num_colonists}, {rocket}, rocket:GetMapID())
      end -- if num_colonists
      if num_tourists > 0 then
        AddOnScreenNotification("NewTourists", nil, {count = num_tourists}, {rocket}, rocket:GetMapID())
      end -- if num_tourists
      if rocket.disembarking_confused then
        AddOnScreenNotification("ConfusedColonists", nil, {}, {rocket:GetPos()}, rocket:GetMapID())
      end -- if self.disembarking_confuse
      
      Msg("ColonistsLanded", rocket:GetMapID())
      

    end, rocket) -- AT_eject_thread

  end -- if rocket.boarded
end -- ATejectColonists(rocket)


-- function to replace current rocket decal with Mars Touring Company decal
-- global used in all files
-- rocket  : current rocket
-- reset   : boolean, reset the current rocket to the original decal
-- resetAll: boolean,  loops through all rockets reseting any it find to original decals, should only be called from MCR
-- applyAll: boolean,  loops through all rockets and applys new logo to AT rockets only, should only be called in LoadGame()
function ATreplaceRocketLogo(rocket, reset, resetAll, applyAll)
  local AutoAttachObjects = AutoAttachObjects
  local ModLog = ModLog
  local logo
  local sformat = string.format

  -- change one rocket to Mars Tourism Company
  -- dont run if we put something in there already
  if g_AT_Options.ATreplaceLogo and g_AT_modEnabled and rocket and (not reset) and rocket.AT_enabled and (not rocket.AT_oldDecal) then
    logo = rocket:GetAttach("Logo")
    -- reset the attaches, if they are missing
    if not logo then
      ModLog(sformat("ERROR: %s detected invalid attach Logo in rocket: %s attempting correction", mod_name, rocket.name))
      if lf_print then print(sformat("ERROR: %s detected invalid attach Logo in rocket: %s", mod_name, rocket.name)) end
      AutoAttachObjects(rocket)
      logo = rocket:GetAttach("Logo")
    end -- if not logo
    rocket.AT_oldDecal = logo:GetEntity() -- save the old logo
    logo:ChangeEntity("AutomatedTourismLogo")
  end -- if rocket and (not reset)

  -- reset one rocket to original decal
  if rocket and reset and rocket.AT_oldDecal then
    logo = rocket:GetAttach("Logo")
    -- reset the attaches, if they are missing
    if not logo then
      ModLog(sformat("ERROR: %s detected invalid attach Logo in rocket: %s attempting correction", mod_name, rocket.name))
      if lf_print then print(sformat("ERROR: %s detected invalid attach Logo in rocket: %s", mod_name, rocket.name)) end
      AutoAttachObjects(rocket)
      logo = rocket:GetAttach("Logo")
    end -- if not logo
    logo:ChangeEntity(rocket.AT_oldDecal)
    rocket.AT_oldDecal = false
  end -- if rocket and reset

  -- reset all rockets if they have an old entity
  if rocket or reset or applyAll then resetAll = false end -- just in case
  if resetAll then
    local rockets = UIColony.city_labels.labels.SupplyRocket or empty_table
    for i = 1, #rockets do
      logo = rockets[i]:GetAttach("Logo")
      -- reset the attaches, if they are missing
      if not logo then
        ModLog(sformat("ERROR: %s detected invalid attach Logo in rocket: %s attempting correction", mod_name, rockets[i].name))
        if lf_print then print(sformat("ERROR: %s detected invalid attach Logo in rocket: %s", mod_name, rockets[i].name)) end
        AutoAttachObjects(rockets[i])
        logo = rockets[i]:GetAttach("Logo")
      end -- if not logo
      if rockets[i].AT_oldDecal and (not IsKindOfClasses(rockets[i], "RocketExpedition", "ForeignTradeRocket", "TradeRocket", "SupplyPod", "ArkPod", "DropPod",
                                                                     "RefugeeRocket", "ForeignAidRocket", "RocketBuildingBase")) then
        logo:ChangeEntity(rockets[i].AT_oldDecal)
        rockets[i].AT_oldDecal = false
      end -- if rockets[i]
    end -- for i
  end -- if resetAll

  -- apply to all rockets if mod enabled and rocket is an AT rocket
  if rocket or reset or resetAll then applyAll = false end -- just in case
  if applyAll and g_AT_modEnabled and g_AT_Options.ATreplaceLogo then
    local rockets = UIColony.city_labels.labels.SupplyRocket or empty_table
    for i = 1, #rockets do
      logo = rockets[i]:GetAttach("Logo")
      -- reset the attaches, if they are missing
      if not logo then
        ModLog(sformat("ERROR: %s detected invalid attach Logo in rocket: %s attempting correction", mod_name, rockets[i].name))
        if lf_print then print(sformat("ERROR: %s detected invalid attach Logo in rocket: %s", mod_name, rockets[i].name)) end
        AutoAttachObjects(rockets[i])
        logo = rockets[i]:GetAttach("Logo")
        rockets[i].AT_oldDecal = false  -- allow for overwrite since attach busted
      end -- if not logo
      -- dont overwrite old decal
      if rockets[i].AT_enabled and (not rockets[i].AT_oldDecal) and (not IsKindOfClasses(rockets[i], "RocketExpedition", "ForeignTradeRocket", "TradeRocket", "SupplyPod", "ArkPod", "DropPod",
                                                                                                     "RefugeeRocket", "ForeignAidRocket", "RocketBuildingBase")) then
        rockets[i].AT_oldDecal = logo:GetEntity() -- save the old logo
        logo:ChangeEntity("AutomatedTourismLogo")
      end -- if rockets[i].AT_enabled
    end -- for i
  end -- if resetAll
end --ATreplaceRocketLogo(rocket, reset, resetAll, applyAll)



--------------------------------------------------------- OnMsgs --------------------------------------------------------

function OnMsg.CityStart()
  -- since there are no rockets yet this is true
  g_AT_RocketCheckComplete = true
end -- OnMsg.CityStart()

function OnMsg.LoadGame()
  ATfixupSaves()
  g_AT_NumOfTouristRockets = ATcountATrockets()
  g_AT_RocketCheckComplete = true
  ATreplaceRocketLogo(nil, nil, nil, true) -- applyAll
  -- remove any threads from landed rockets if AT is running
  if g_AT_modEnabled and g_AT_NumOfTouristRockets > 0 then
    ATStopDepartureThreads() -- stop all departure threads
  end -- if g_AT_NumOfTouristRockets
end -- OnMsg.LoadGame()


function OnMsg.RocketReachedEarth(rocket)
  -- short circuit if mod disabled
  if g_AT_modEnabled then
    if lf_print and rocket.AT_enabled then print("Tourist Rocket Reached Earth: ", rocket.name) end

    -- run this regardless of AT status - doesnt hurt since originally it runs when launching a rocket from mars
    rocket:ClearDepartures(true) -- true set here to postpone clearing the vars so we can still use the UIOpenTouristOverview

    if rocket.AT_enabled then
       -- clear departure variables
      rocket.AT_departures = 0
      rocket.AT_leaving_colonists = 0      -- var holds the colonists wanting to leave
      rocket.AT_boarded_colonists = 0      -- var holds the colonists that boarded
      rocket.departures = {}
      rocket.boarding = {}
      rocket.boarded = {}
    elseif rocket.AT_departures then
      -- remove variables if there were departures on a non AT rocket, just in case - should not ever happen
      rocket.AT_departures = nil
      rocket.AT_leaving_colonists = nil
      rocket.AT_boarded_colonists = nil
    end -- if rocket.AT_enabled
  end -- if g_AT_modEnabled
end -- OnMsg.RocketReachedEarth(rocket)


function OnMsg.RocketLaunched(rocket)
  if lf_print and rocket.AT_enabled then print("Tourist Rocket Launched from Mars: ", rocket.name) end

  if g_AT_modEnabled and rocket.AT_enabled then
    -- fix running tourism rockets for tourism patch fuckups
    -- delete departure thread if its running, should not be on return trip from earth
    rocket:StopDepartureThread() -- new for Tourism patch there is a departure thread running all the time, just in case put this here

     -- turn off tourist recall boundary
    ATtoggleTouristBoundary(rocket, false)
    rocket.AT_departuretimeText = ""
    -- calc departures based on boarded colonists
    rocket.AT_departures = (rocket.boarded and #rocket.boarded) or rocket.AT_boarded_colonists
    --rocket.AT_departures = rocket.AT_boarded_colonists -- legacy code from pre tourist patch
    if rocket.AT_departures < 0 then rocket.AT_departures = 0 end

    -- notification of rocket launch
    local msg = T{StringIdBase + 2, "Departures: <count>", count = rocket.AT_departures}
    AddCustomOnScreenNotification("AT_Notice_Leaving", T{StringIdBase + 1, "Tourist Rocket Leaving"}, msg, iconATnoticeIcon, nil, {cycle_objs = {rocket}, expiration = g_AT_Options.ATnoticeDismissTime}, rocket:GetMapID())
    PlayFX("UINotificationResearchComplete", rocket)

    -- determing status
    local tt = 0 < (rocket.custom_travel_time_earth or 0) and rocket.custom_travel_time_earth or g_Consts.TravelTimeMarsEarth
    if (rocket.AT_next_voyage_time > 0) and (rocket.AT_next_voyage_time  >= (GameTime() + tt)) then
      if lf_print then print("Status set to flytoearth") end
      rocket.AT_status = "flytoearth"
    else
      if lf_print then print("Status set to pickup") end
      rocket.AT_status = "pickup"
    end -- if (rocket.AT_next_voyage_time > 0) -- determine status

  end -- if rocket.AT_enabled
end -- OnMsg.RocketLaunched(rocket)


-- all the magic happens here
function OnMsg.RocketLanded(rocket)

  -- tourist rockets only
  if g_AT_modEnabled and rocket.AT_enabled then
    if lf_print then print("Tourist Rocket Landed On Mars: ", rocket.name) end
    rocket.AT_status = "landed"
    rocket.AT_GenDepartRan = false 

    -- Check AT_RecallRadiusMode first
    -- setup rocket recall tourist boundary
    if rocket.AT_RecallRadiusMode and rocket.AT_RecallRadiusMode == "ON" then
      ATtoggleTouristBoundary(rocket, true)
    elseif rocket.AT_RecallRadiusMode and rocket.AT_RecallRadiusMode == "Mod Config Set" and g_AT_Options.ATrecallRadius then
      ATtoggleTouristBoundary(rocket, true)
    end -- if rocket.AT_RecallRadiusMode

    -- if g_AT_Options.ATrecallRadius then ATtoggleTouristBoundary(rocket, true) end

    -- notification of rocket landed
    local msg = T{StringIdBase + 4, "Arrivals: <count>", count = rocket.AT_arriving_tourists}
    AddCustomOnScreenNotification("AT_Notice_Landed", T{StringIdBase + 3, "Tourist Rocket Landed"}, msg, iconATnoticeIcon, nil, {cycle_objs = {rocket}, expiration = g_AT_Options.ATnoticeDismissTime}, rocket:GetMapID())
    PlayFX("UINotificationResearchComplete", rocket)

    -- if a thread is already running then delete it (should never happen)
    if IsValidThread(rocket.AT_depart_thread) then DeleteThread(rocket.AT_depart_thread) end
    -- create thread to wait before launch up to X days if no tourists departing
    rocket.AT_depart_thread = CreateGameTimeThread(function(rocket)
      if rocket.auto_export then rocket:ToggleAutoExport() end -- turn off auto launch sequence
      rocket:AttachSign(true, "SignTradeRocket")

       -- GenerateDepartures() is called automatically upon landing a rocket so we dont need to call it here -- still true in Picard
       -- it is called in the refuel code
       -- I rewrote the start thread function to make it not use departure threads and instead just execute once

      if rocket.AT_arriving_tourists > 0 then ATflashStatus(rocket, "disembark", "landed", true) end

      rocket.AT_departuretime = ""
      rocket.AT_departuretimeText = ""

      -- check AT_GenDepartRan the var, which is set in the new GenerateDepartures function
      while IsValid(rocket) and (rocket.AT_enabled) and (not rocket.AT_GenDepartRan) do
        Sleep(100) -- wait a moment to check if GenerateDepartures finished
      end -- while rocket.AT_GenDepartRan
      
      -- this is a double check to make sure user did not demolish rocket while in loop above
      if not IsValid(rocket) then return end -- short circuit
      
      rocket.AT_GenDepartRan = false  -- reset the variable
      rocket:StopDepartureThread() -- New for tourism patch, added here in case the existing rocket is running it, should not be

      -- check if we still got arriving passengers
      if rocket.cargo and rocket.cargo[1] and rocket.cargo[1].class == "Passengers" then
        -- cargo will nil out when passengers all disembark and food is gone
        -- thread will end when passengers disembark or if no passengers
        while IsValid(rocket) and rocket.cargo and rocket.cargo[1].applicants_data and (#rocket.cargo[1].applicants_data > 0) do
          Sleep(1000) -- wait a moment and check to make sure passengers get off
        end -- while
        Sleep(2000) -- pause a moment and reset the AT_last_arrival_time to the moment all passengers debark
      end -- if rocket.cargo
      rocket.AT_arriving_tourists = 0
      ATflashStatus(rocket) -- kill status thread
      rocket.AT_status = "landed"
      rocket.AT_last_arrival_time = GameTime() -- set the arrival time when rocket touches down, used to calc next departure


      if lf_print then
        print(string.format("%s departures on %s", rocket.AT_leaving_colonists, rocket.name))
        print("Calculating departure time: ", rocket.name)
      end -- if lf_print

      -- set departure time and have_departures
      ATcalcDepartureTime(rocket)

      if not rocket.AT_have_departures then
        -- if not departures
        if lf_print then print(string.format("Rocket %s waiting until %s - No current departures", rocket.name, rocket.AT_departuretimeText)) end
        if rocket.AT_express then ATflashStatus(rocket, "express", "waitdepart", true)
                             else rocket.AT_status = "waitdepart" end
        while IsValid(rocket) and rocket.AT_enabled and (GameTime() < rocket.AT_departuretime) do
          Sleep(5000) -- sleep 5 seconds at a time
        end -- while GameTime
        rocket.AT_express = false
        -- call tourists to rocket
        ATflashStatus(rocket, "checkdepart", "waitdepart", true)
        rocket.departures = nil -- nil out departures to have GenerateDepartures execute
        rocket:GenerateDepartures(true, true) -- count the earthsick and the tourists
        -- reset departure time and have_departures if there are departures
        -- check the var, which is set in the new GenerateDepartures function
        while IsValid(rocket) and rocket.AT_enabled and (not rocket.AT_GenDepartRan) do
          Sleep(500)
        end -- while rocket.AT_GenDepartRan
        
        -- this is a double check to make sure user did not demolish rocket while in loop above
        if not IsValid(rocket) then return end -- short circuit
        
        rocket.AT_GenDepartRan = false

        if lf_print then
          print(string.format("%s departures on %s", (rocket.departures and #rocket.departures) or 0, rocket.name))
           print("Calculating departure time: ", rocket.name)
        end -- if lf_print

        ATcalcDepartureTime(rocket)
      end -- if not rocket.AT_have_departures

      if rocket.AT_have_departures then
        ATflashStatus(rocket) -- kill status thread if it exists
        rocket.AT_status = "boarding"
        local flashwarn = false
        -- if we have departures then reset and start countdown
        if lf_print then print(string.format("Rocket %s has %s departures, departing %s", rocket.name, #rocket.departures, rocket.AT_departuretimeText)) end
        while IsValid(rocket) and rocket.AT_enabled and (GameTime() < rocket.AT_departuretime) do
          Sleep(2000) -- sleep 2 seconds at a time
          if not flashwarn and (GameTime() >= (rocket.AT_departuretime - (3 * const.HourDuration))) and (rocket.AT_leaving_colonists ~= rocket.AT_boarded_colonists) then -- warn 3 hours before
            flashwarn = true
            ATflashStatus(rocket, "warnleaving", "boarding", true)
          end -- if GameTime
        end -- while GameTime
      end -- if rocket.AT_have_departures

      if lf_print then print("Rocket ready to depart: ", rocket.name) end

      ATflashStatus(rocket) -- kill status thread if it exists (possible set in oncontextupdate if tourists did board)
      rocket.AT_status = "departing"
      rocket:ReturnStockpiledResources() -- dump any resources on landing pad so we can launch
      if rocket.AT_enabled then rocket:ToggleAutoExport() end -- turn on auto launch sequence, check to make sure still a tourist rocket
    end, rocket) -- AT_depart_thread

  end -- if AT_enabled

end -- OnMsg.RocketLanded(rocket)


function OnMsg.RocketLaunchFromEarth(rocket)
  if lf_print and rocket.AT_enabled then print("Tourist Rocket Launched from Earth: ", rocket.name) end

  if g_AT_modEnabled and rocket.AT_enabled then
    -- make sure last voyage was at least X sols ago
    if (rocket.AT_last_voyage_time == 0 ) or (rocket.AT_next_voyage_time <= GameTime()) then

      if lf_print and rocket.AT_enabled then print("Last tourist rocket older than 5 days, picking up new tourists: ", rocket.name) end

      -- gather new tourists
      local capacity = Min(g_Consts.MaxColonistsPerRocket, g_AT_Options.ATMaxTourists) -- set capacity to the smaller of current allowed passengers
      local applicantPool = g_ApplicantPool or empty_table
      local findTrait = "Tourist"
      local count = 0
      local tourists = {}

      if lf_print then print("Total applicants in pool: ", #applicantPool) end

      for idx = #applicantPool, 1, -1 do
        if applicantPool[idx][1].traits[findTrait] then
          count = count + 1
          tourists[#tourists + 1] = applicantPool[idx][1] -- add to tourist pool
          table.remove(applicantPool, idx) -- remove from applicant pool
          if count == capacity then break end  -- break out of the loop when rocket capacity reached
        end -- if applicantPool
      end -- for idx

      if lf_print then
        print(string.format("Found %s of %s in Applicant Pool", count, findTrait))
        --ex(applicantPool)
        --ex(tourists)
      end -- if lf_print

      -- load up tourists into cargo bay of rocket with some food
      local cargo = {}

      if #tourists > 0 then
        if g_AT_Options.ATstripSpecialty then
          -- remove specializations from tourists
          for i = 1, #tourists do
            if tourists[i].specialist ~= "none" then
              tourists[i].traits[tourists[i].specialist] = nil
              tourists[i].specialist = "none"
              tourists[i].traits.none = true
            end -- if tourists[i]
          end -- for i
        end -- if g_AT_Options.ATstripSpecialty

        -- load up the passenger manifest
        cargo[1] = {
          class = "Passengers",
          amount = count,
          applicants_data = tourists
        }
        -- load up the food manifest
        if g_AT_Options.ATfoodPerTourist > 0 then
          cargo[2] = {
           class = "Food",
           -- original formula used whatever the mission sponsor food amount was, now use modconfig.
           -- amount = MulDivRound(count, g_Consts.FoodPerRocketPassenger, const.ResourceScale)
           amount = MulDivRound(count * g_AT_Options.ATfoodPerTourist, 1000, const.ResourceScale)
         }
        end -- if ATfoodPerTourist
      end -- if #tourists

      -- load up the tourists and set last and next voyage time
      if lf_print then print(string.format("Sending %s tourist rocket with %s tourists", rocket.name, #tourists)) end
      rocket.cargo = cargo
      rocket.AT_arriving_tourists = #tourists
      rocket.AT_status = "flyingtourists"
      rocket.AT_last_voyage_time = GameTime()
      rocket.AT_next_voyage_time = rocket.AT_last_voyage_time + (g_AT_Options.ATvoyageWaitTime  * const.DayDuration)
      rocket.AT_next_voyage_timeText = ATConvertDateTime(rocket.AT_next_voyage_time)

    else
      if lf_print and rocket.AT_enabled then print(string.format("Last %s tourist rocket was %.2f sols ago.  Not sending new tourists.", rocket.name, (GameTime() - rocket.AT_last_voyage_time + 0.00)/const.DayDuration)) end
      rocket.AT_status = "flyingempty"
    end --if (not rocket.AT_last_voyage_time)

    -- notification of rocket leaving earth
    local msg = T{StringIdBase + 6, "On Board: <count>", count = rocket.AT_arriving_tourists}
    AddCustomOnScreenNotification("AT_Notice_Voyage", T{StringIdBase + 5, "Tourist Rocket En Route"}, msg, iconATnoticeIcon, nil, {cycle_objs = {rocket}, expiration = g_AT_Options.ATnoticeDismissTime}, MainMapID)
    PlayFX("UINotificationResearchComplete", rocket)

  else
    -- short circuit if not a tourist rocket
    if lf_print then print("Launched rocket is not a tourist rocket:", rocket.name)  end
  end -- if rocket.AI_enabled

end -- OnMsg.RocketLaunchFromEarth(rocket)



------------------------------------------------------ ClassesGenerate() ----------------------------------------
function OnMsg.ClassesGenerate()


  -- new function - needs to be here, before xtemplates generate otherwise it errors out in the xtemplate
  -- used instead of function SupplyRocket:ToggleAutoExport() in panels
  -- prevents launch of rocket if there are tourists leaving mars until they board when turning on AT
  function SupplyRocket:ATtoggleAutoExport()
    local rocket = self
    if (not rocket.auto_export) and rocket.AT_firstRun and rocket.departures then
      -- we have departures coming to the rocket, so wait and start counting
      if IsValidThread(rocket.AT_boarding_thread) then DeleteThread(rocket.AT_boarding_thread) end -- just in case
      rocket.AT_boarding_thread = CreateGameTimeThread(function(rocket)
        local tick = 3000 -- cant wait forever, so we'll wait 300 seconds max
        if rocket.AT_leaving_colonists > 0 then ATflashStatus(rocket, "warnleaving", "boarding", true) end -- set the flash status if there are departures
        repeat
          -- tick up the counters for the infopanel as they board
          rocket.AT_boarded_colonists = (rocket.boarded and #rocket.boarded) or 0
          rocket.AT_departures = (rocket.boarded and #rocket.boarded) or 0
          Sleep(100) -- wait 1/10 of one second
          tick = tick - 1
        until (not IsValid(rocket)) or ((#rocket.departures < 1) and (#rocket.boarding < 1)) or (tick <= 0)
        -- true up stats in case colonists came aboard while thread slept
        rocket.AT_boarded_colonists = (rocket.boarded and #rocket.boarded) or 0
        rocket.AT_departures = (rocket.boarded and #rocket.boarded) or 0
        ATflashStatus(rocket, "boardcomplete", "warnleaving", true)
        Sleep(15000) -- wait 15 seconds to let the last colonists on the ramp inside
        ATflashStatus(rocket) -- kill status thread
        Sleep(250) -- give the status thread a chance to exit
        if ATcountTouristsOnEarth() > 0 then
          rocket.AT_status = "pickup"
        else
          rocket.AT_status = "flytoearth"
        end -- if ATcountTouristsOnEarth()
        rocket:ToggleAutoExport()
        rocket.AT_firstRun = false
      end, rocket) -- rocket.AT_boarding_thread
    else
      rocket:ToggleAutoExport()  -- no rocket departure table or we are turning AT off then just execute
      rocket.AT_firstRun = false
    end -- if rocket.departures
  end -- SupplyRocket:ATtoggleAutoExport()


  -- re-write function so we can intercept expedition rocket before takeoff
  -- to eject tourists and earthsick
  local Old_RocketExpedition_Takeoff = RocketExpedition.Takeoff
  function RocketExpedition:Takeoff()
    if g_AT_modEnabled and (not self:IsDemolishing()) and self.boarded and #self.boarded > 0 then
      self:UpdateStatus("countdown")  -- no turning back now
      ATejectColonists(self)
      local tick = 600 -- cant wait forever so wait twice as long as the eject thread should take
      -- boarded will nil out when eject thread is done
      while self.boarded and (tick > 0) do
        Sleep(1000) -- one second
        tick = tick - 1
      end -- while
      return Old_RocketExpedition_Takeoff(self)
    else
      return Old_RocketExpedition_Takeoff(self)
    end -- if self.boarded
  end -- RocketExpedition:Takeoff()

  -- re-write OnSelected()
  -- highlights all tourists when selecting a tourism rocket
  local Old_DroneControl_OnSelected = DroneControl.OnSelected
  function DroneControl:OnSelected()
    -- short circuit if not a Tourist Rocket or if mod is disabled
    if g_AT_modEnabled and self.AT_enabled then
      local colonists = UIColony.city_labels.labels.Colonist or empty_table
      local tourists = {}
      for i = 1, #colonists do
        if colonists[i].traits.Tourist then tourists[#tourists+1] = colonists[i] end
      end -- for i
      if #tourists > 0 then SelectionArrowAdd(tourists) end
    end -- if g_AT_modEnabled

    return Old_DroneControl_OnSelected(self)
  end -- DroneControl:OnSelected()


  -- fix for broken source code
  -- local Old_SupplyRocket_UIOpenTouristOverview = SupplyRocket.UIOpenTouristOverview -- not needed since old one is broke dick
  function SupplyRocket:UIOpenTouristOverview()
    local reward_info
    local tourists = {}
    local boarded = self.boarded or empty_table
    for i = 1, #boarded do
      local colonist = self.boarded[i]
      if colonist.traits.Tourist then
        table.insert(tourists, colonist)
      end -- if
    end -- for i
    reward_info = {
      rocket_name = Untranslated(self.name),
      colonists = tourists,
    } -- reward_info
    HolidayRating:OpenTouristOverview(reward_info)
  end -- SupplyRocket:UIOpenTouristOverview(reward_info)


  -- re-write OnDemolish to make sure vars, threads and other items are killed
  -- updated for Tourism patch
  local Old_RocketBase_OnDemolish = RocketBase.OnDemolish
  function RocketBase:OnDemolish()
    local rocket = self
    -- short circuit of mod disabled
    if g_AT_modEnabled then
      if not IsKindOfClasses(rocket, "RocketExpedition", "ForeignTradeRocket", "TradeRocket", "SupplyPod", "ArkPod", "DropPod", "RefugeeRocket", "ForeignAidRocket", "RocketBuildingBase") then
        ATsetupVariables(rocket, false) -- clear all AT vars
      end --if not IsKindOfClasses
      rocket:StopDepartureThread() -- prevent memory leak.
    end -- if g_AT_modEnabled
    return Old_RocketBase_OnDemolish(rocket) -- call original function
  end -- RocketBase:OnDemolish()


  -- rewrite old function to exclude tourist rockets from expeditions
  -- causes expedition planatary view to consider tourism rocket off limits for expeditions
  -- updated for Tourism Patch
  local Old_RocketBase_IsRocketLanded = RocketBase.IsRocketLanded
  function RocketBase:IsRocketLanded()
    if g_AT_modEnabled and self.AT_enabled then
      return false
    else
      return Old_RocketBase_IsRocketLanded(self)
    end -- if g_AT_modEnabled
  end -- RocketBase:IsRocketLanded()


  -- duplicate of old IsRocketLanded
  -- updated for Tourism patch
  -- only used by AT so no need to disable
  function RocketBase:IsRocketOnMars()
    return self.command == "Refuel" or self.command == "WaitLaunchOrder" or self.command == "Unload"
  end -- RocketBase:IsRocketOnMars()


  -- add tourist rocket status to rockets in send expedition view
  -- from PlanetaryView.lua
  local Old_GetRocketExpeditionStatus = GetRocketExpeditionStatus
  function GetRocketExpeditionStatus(rocket)
    if g_AT_modEnabled and rocket.AT_enabled then
      return T(StringIdBase + 7, "Tourist rocket")
    end
    return Old_GetRocketExpeditionStatus(rocket)
  end -- GetRocketExpeditionStatus(rocket)


  -- rewrite colonist leavingmars
  -- had to re-write whole code since the delay in finding and calling leavingmars is too variable.
  -- use old code when not AT_enabled
  -- taken from colonist.lua
  local Old_Colonist_LeavingMars = Colonist.LeavingMars
  function Colonist:LeavingMars(rocket)
    -- simple way to reuse commands in a function
    local function CleanupLeavingColonist(colonist, rocket)
        SelectionRemove(colonist)
        DiscardNewObjsNotif(g_OverstayingTourists, colonist, colonist:GetMapID() or MainMapID)
        RebuildInfopanel(colonist)
        Msg("ColonistLeavingMars", colonist, rocket)
        DoneObject(colonist)
    end -- local function CleanupLeavingColonist

    -- short circuit if not a tourist rocket
    if g_AT_modEnabled and rocket.AT_enabled then
      self.leaving = true
      self:SetDome(false)
      self:ClearDetrimentalStatusEffects()
      self:ClearTransportRequest()
      table.insert(rocket.departures, self)

      self:PushDestructor(function(self)
        self.leaving = false
        table.remove_entry(rocket.departures, self)
        rocket.AT_leaving_colonists = ((rocket.departures and #rocket.departures or 0)+(rocket.boarding and #rocket.boarding or 0)+(rocket.boarded and #rocket.boarded or 0))
      end) -- self:PushDestructor

      if not self:GotoBuildingSpot(rocket, rocket.drone_entry_spot) -- the colonist cannot reach the rocket, don't try to pass through objects, mountains or walk above ground...
        or not IsValid(rocket) or not rocket:IsBoardingAllowed() then -- rocket already left
        self:PopDestructor()
        self.leaving = false
        table.remove_entry(rocket.departures, self)
        rocket.AT_leaving_colonists = ((rocket.departures and #rocket.departures or 0)+(rocket.boarding and #rocket.boarding or 0)+(rocket.boarded and #rocket.boarded or 0))
        if self.traits.Tourist then
          table.insert(rocket.boarded, self)
          DiscardNewObjsNotif(g_OverstayingTourists, self, self:GetMapID() or MainMapID)
        end -- if self.traits.Tourist
        Msg("ColonistLeavingMars", self, rocket)
        DoneObject(self)
        return
      end -- self:GotoBuildingSpot

      self:PopDestructor()
      self:PushDestructor(function(self)
        -- if the rocket is still waiting for something, hop on
        -- this part executes when the colonist has boarded the rocket
        if lf_printcolonist then print(string.format("Colonist leaving on rocket: %s", rocket.name)) end
        table.remove_entry(rocket.departures, self)
        table.insert(rocket.boarding, self)

        rocket:LeadIn(self, rocket.waypoint_chains.rocket_entrance[1])

        -- remove from boarding list (ramp leading to rocket)
        table.remove_entry(rocket.boarding, self)
        table.insert(rocket.boarded, self)

        CleanupLeavingColonist(self, rocket)

        -- colonist has boarded rocket
        -- the 'if' is just in case user toggled the AT rocket while colonist was walking to rocket, will throw errors otherwise
        -- NOTE: these vars will not tick up if colonist was already going to rocket in OLD pushdestructor from original function
        --       in that case we update these stats in ATtoggleAutoExport instead
        if rocket.AT_enabled then
          rocket.AT_boarded_colonists = #rocket.boarded or 0 -- var holds the colonists that boarded
          rocket.AT_departures = #rocket.boarded or 0        -- change the departure count now, instead of waiting for takeoff shows as they walk in
          -- rocket.AT_departures = rocket.AT_boarded_colonists --legacy pre tourist patch code - leave it
        end -- if rocket.AT_enabled

      end) -- self:PushDestructor
      self:PopAndCallDestructor()
    else
      -- call original code
      return Old_Colonist_LeavingMars(self, rocket)
    end -- if rocket.AT_enabled
  end -- Colonist:LeavingMars(rocket)


  -- re-write so we can intercept code
  -- run this once rocket reaches earth
  -- arrive_on_earth is for AT to execute only when reaching earth, not in original code
  local Old_RocketBase_ClearDepartures = RocketBase.ClearDepartures
  function RocketBase:ClearDepartures(arrive_on_earth)
    if not g_AT_modEnabled then return Old_RocketBase_ClearDepartures(self) end -- short circuit

    if (not self.AT_enabled) and ((not g_AT_Options.ATpreventDepart) or (g_AT_NumOfTouristRockets < 1)) then
      return Old_RocketBase_ClearDepartures(self)
    end -- if not self.AT_enabled

    if arrive_on_earth then
      self.departures = nil
      self.boarding = nil
      self.boarded = nil
    end -- if arrive_on_earth
  end -- function RocketBase:ClearDepartures()


  -- re-write RocketBase:StartDepartureThread()
  -- its called during refueling and is very annoying its now a thread.
  -- putting it back to one call only for Tourism rockets
  -- plus they fucked it up with a generate departure call twice
  local Old_RocketBase_StartDepartureThread = RocketBase.StartDepartureThread
  function RocketBase:StartDepartureThread()
    if not g_AT_modEnabled then return Old_RocketBase_StartDepartureThread(self) end -- short circuit

    -- add code to exclude foreign trade rockets and trade rockets
    if IsKindOfClasses(self, "RocketExpedition", "ForeignTradeRocket", "TradeRocket", "SupplyPod", "ArkPod", "DropPod", "RefugeeRocket", "ForeignAidRocket", "RocketBuildingBase")
    then return end -- short circuit for invalid rocket types

    if (not self.AT_enabled) and ((not g_AT_Options.ATpreventDepart) or (g_AT_NumOfTouristRockets < 1)) then
      if lf_print then print("- StartDepartureThread executing for non AT rocket -") end
      return Old_RocketBase_StartDepartureThread(self)
    end -- if not self.AT_enabled

    if lf_print then print("- StartDepartureThread executing once for AT rocket -") end
    if not IsValidThread(self.departure_thread) then self.departure_thread = false end -- cosmetic
    if self.AT_enabled then self:GenerateDepartures(true, true) end -- earthsick and tourists but only for AT rockets
  end --function RocketBase:StartDepartureThread()


  -- re-write generate departures to exclude non AT rockets
  -- had to re-write whole code since the delay in finding and calling leavingmars is too variable.
  -- use old code when not AT_enabled
  -- taken from rocket.lua / Tourism patch changed its code location, now in file SupplyRocket.lua
  -- Update for Tourism patch
  local Old_SupplyRocket_GenerateDepartures = SupplyRocket.GenerateDepartures
  function SupplyRocket:GenerateDepartures(count_earthsick, count_tourists)
    if not g_AT_modEnabled then return Old_SupplyRocket_GenerateDepartures(self) end -- short circuit

    -- if not a tourism rocket or we dont have tourism rockets or we dont prevent departures - run original code
    if (not self.AT_enabled) and ((not g_AT_Options.ATpreventDepart) or (g_AT_NumOfTouristRockets < 1)) then
      return Old_SupplyRocket_GenerateDepartures(self, count_earthsick, count_tourists)
    end -- if not self.AT_enabled

    -- if rocket is an AT rocket or ATpreventDepart is false or there is no tourism rockets
    if self.AT_enabled then
      if lf_print then print(string.format("--- GenerateDepartures is running on rocket %s - Count Earthsick: %s   Count Tourists: %s   --- ", self.name, tostring(count_earthsick), tostring(count_tourists))) end

      -- foreign trade rockets, refugee rockets, and trade rockets cannot fly colonists so they are always can_fly_colonists = false
      -- self.departures is still unknown,  they seem to add and remove them in Colonist:LeavingMars
      if not self.can_fly_colonists or self.departures then
        self.AT_GenDepartRan = true  -- allow depart thread to continue
        return -- dont gather departures now
      end -- if not self.can_fly_colonists

      --setup variables
      if not self.departures then
        self.departures = {}
      end -- if not self
      if not self.boarding then
        self.boarding = {}
      end -- if not self
      if not self.boarded then
        self.boarded = {}
      end -- if not self

      local capacity = Min(g_Consts.MaxColonistsPerRocket, g_AT_Options.ATMaxTourists)  -- passenger capacity
      local domes = self.city.labels.Dome or empty_table
      local earthsick = {} -- new for tourist patch
      local tourists = {}  -- new for tourist patch
      local list = {}      -- total list of onboard passangers
      local max_walk_dist = g_AT_Options.ATmax_walk_dist * const.ColonistMaxDomeWalkDist
      if lf_print then print("- Checking for suitable colonists to leave") end
      for i = 1, #domes do
        local dome = domes[i]
        local suitable
        if lf_print then print("- Checking dome: "..dome.name) end
        for _, c in ipairs(IsValid(dome) and dome.labels.Colonist or empty_table) do
          if c:CanChangeCommand() and (count_earthsick and c.status_effects.StatusEffect_Earthsick or (count_tourists and c.traits.Tourist and c.sols > g_Consts.TouristSolsOnMarsMin)) then
            if lf_print then print("- Tourist/Earthsick passed Check now testing distance") end
            suitable = ATcheckDist(self:GetMapID() or MainMapID, self, dome, max_walk_dist)
            if lf_print then print("- CP1 reached") end
            -- if can reach rocket and rocket has space
            if suitable and #list < capacity then
              if lf_print then print("- CP2 Suitable reached") end
              list[#list + 1] = c
              if c.traits.Tourist then
                tourists[#tourists + 1] = c
              else
                earthsick[#earthsick + 1] = c
              end -- if c.traits.Tourist
              c:SetCommand("LeavingMars", self)
            elseif not suitable then
              if lf_print then print("- Tourist/Earthsick FAILED testing distance") end
            elseif #list < capacity then
              if lf_print then print("- Rocket Capacity reached - No more passengers accepted") end
            end -- if suitable
          end -- if c:CanChangeCommand
        end -- for _
      end -- for i

      if #list > 0 then
        self.AT_leaving_colonists = #list -- set the expected colonists that are leaving on tourism rocket
        if count_earthsick and #earthsick > 0 then
          AddOnScreenNotification("LeavingMars", false, {colonists_count = #earthsick}, earthsick, self:GetMapID())
        end -- if count_earthsick
        if count_tourists and #tourists > 0 then
          AddOnScreenNotification("LeavingMarsTourists", false, {tourists_count = #tourists}, tourists, self:GetMapID())
          PlayFX("UINotificationResearchComplete") -- add some noise, jeez the devs couldnt be bothered for some soundfx here.
        end -- if count_tourists
        --AddOnScreenNotification("LeavingMars", false, {colonists_count = #list}, list)
      end -- if #list

      self.AT_GenDepartRan = true  -- allow depart thread to continue
    end -- if self.AT_enabled
  end  -- SupplyRocket:GenerateDepartures()


end -- OnMsg.ClassesGenerate()

-----------------------------------------------------------------------------------------------------------------------------------------
function OnMsg.ToggleLFPrint(modname, lfvar)
  -- use Msg("ToggleLFPrint", "AT") to toggle
  if modname == "AT" and (not lfvar) then
    lf_print = not lf_print
    print(string.format("Toggle lf_print for %s: %s", modname, lf_print))
  end -- if

   if modname == "AT" and (lfvar == "colonist") then
    lf_printcolonist = not lf_printcolonist
    print(string.format("Toggle %s for %s: %s", lfvar, modname, lf_printcolonist))
  end -- if

   if modname == "AT" and (lfvar == "distance") then
    lf_printdistance = not lf_printdistance
    print(string.format("Toggle %s for %s: %s", lfvar, modname, lf_printdistance))
  end -- if

end -- OnMsg.ToggleLFPrint(modname)
