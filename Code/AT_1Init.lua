-- Code developed for Incubator
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- You may not copy it, package it, or claim it as your own.
-- Created May 1st, 2019
-- Updated May 22nd, 2019


local lf_print = false -- Setup debug printing in local file
                       -- Use if lf_print then print("something") end

-- global variable to contain AT options
g_AT_Options = {
	ATdismissMsg        = true,
	ATnoticeDismissTime = 20 * 1000, -- 20 seconds the dismiss time for notifications
	ATMaxTourists       = 20,        -- Maximum number of tourists per rocket
	ATvoyageWaitTime    = 5,         -- Wait this amount of sols between voyages
	ATrecallRadius      = true,      -- display recall radius on landed rocket
	ATearlyDepartures   = true,      -- allow for earlier departures when voyages waiting
} -- g_AT_Options

-- Save game fixup variables
g_AT_fixupVer = "v1.0"
GlobalVar("g_AT_currentFixupVer", "0")

local StringIdBase = 17764702300 -- Automated Tourism    : 702300 - 702499 File Starts at 300-349:  Next is 7
local ModDir = CurrentModPath
local iconATnoticeIcon = ModDir.."UI/Icons/ATNoticeIcon.png"


-- return sol, hour and minute of curreentTime as a string
-- currentTime   : GameTime var
function ATConvertDateTime(currentTime)
	local deltaTime = (currentTime or GameTime()) + (6 * const.HourDuration) + const.DayDuration
	local sol    = (deltaTime / const.DayDuration)
	local hour   = ((deltaTime % const.DayDuration) / const.HourDuration)
	local minute = ((deltaTime % const.DayDuration) % const.HourDuration) / const.MinuteDuration
	return string.format("Sol: %s Time: %02d:%02d", sol, hour, minute)
end -- ATConvertDateTime()


-- calculate departure time
local function ATcalcDepartureTime(rocket)
  rocket.AT_departures = (rocket.departures and #rocket.departures) or 0

  if rocket.AT_departures == 0 then
  	--no deparures then wait 5 days
  	rocket.AT_departuretime = rocket.AT_last_arrival_time + (g_AT_Options.ATvoyageWaitTime * const.DayDuration) -- wait 5 days to depart if no immediate departures
  	rocket.AT_have_departures = false
  	-- check for early departures if voyages exist
  	if g_AT_Options.ATearlyDepartures and rocket.AT_next_voyage_time and (rocket.AT_next_voyage_time <= rocket.AT_departuretime) then
  		rocket.AT_departuretime = rocket.AT_next_voyage_time
  	end -- if g_AT_Options.ATearlyDepartures
  else
	  -- if we have departures then reset last arrival time to now so we can recalculate departure time properly
  	rocket.AT_departuretime = GameTime() + (12 * const.HourDuration) -- wait 1/2 day to depart since we got departures
  	rocket.AT_have_departures = true
  end -- rocket.AT_departures

  -- add departure time text
  rocket.AT_departuretimeText = ATConvertDateTime(rocket.AT_departuretime)

end -- ATcalcDepartureTime()


-- toggle the tourist recall boundary circle
function ATtoggleTouristBoundary(rocket, state)

  	-- setup rocket recall tourist boundary
    if state and (not rocket.AT_touristBoundary) then
      rocket.AT_touristBoundary = Circle:new()
      rocket.AT_touristBoundary:SetPos(rocket:GetPos())
      rocket.AT_touristBoundary:SetRadius(const.ColonistMaxDepartureRocketDist)
      rocket.AT_touristBoundary:SetColor(white)
    end -- if not rocket.touristBoundary

	  -- turn off boundary
		if (not state) and rocket.AT_touristBoundary and IsValid(rocket.AT_touristBoundary) then
			DoneObject(rocket.AT_touristBoundary)
			rocket.AT_touristBoundary = false
		end -- if rocket.AT_touristBoundary
end -- ATtoggleTouristBoundary(rocket, state)

--[[
-- not used at this time. using ReturnStockpiledResources()
-- force the unloading of resources on departure so we dont wait for unload if storage is full
function ATunloadResources(rocket)
	local storedResources = {}
	local resources = rocket.resource or empty_table
	for i = 1, #resources do
		storedResources[(resources[i])] = rocket["GetStored_"..(resources[i])](rocket)
	end -- for i
	--ex(storedResources)
end -- ATunloadResources()
]]--


-- function that fixes various save game issues.
local function ATfixupSaves()
	-- if we got things to fix update the ver
	if g_AT_currentFixupVer ~= g_AT_fixupVer then
		g_AT_currentFixupVer = g_AT_fixupVer

		-- fix for stuck rockets waiting to unload cargo
		-- do this once and never again since its fixed going forward in templates
		local rockets = UICity and UICity.labels.SupplyRocket or empty_table
		for i = 1, #rockets do
			if rockets[i].AT_enabled and (rockets[i].status == "launch suspended") and (rockets[i]:GetStoredAmount() > 0) then
				rockets[i]:ToggleAutoExport()
				rockets[i]:ReturnStockpiledResources()
				rockets[i]:ToggleAutoExport()
		  end -- if rockets[i].AT_enabled
		end -- for i
	end -- if g_AT_currentFixupVer
end -- ATfixupSave()

--------------------------------------------------------- OnMsgs --------------------------------------------------------

function OnMsg.LoadGame()
	ATfixupSaves()
end -- OnMsg.LoadGame()


function OnMsg.RocketReachedEarth(rocket)
	if lf_print and rocket.AT_enabled then print("Tourist Rocket Reached Earth") end

	if rocket.AT_enabled then
     -- clear departure variables
    rocket.AT_departures = 0
	end -- if rocket.AT_enabled

end -- OnMsg.RocketReachedEarth(rocket)


function OnMsg.RocketLaunched(rocket)
	if lf_print and rocket.AT_enabled then print("Tourist Rocket Launched from Mars") end

	if rocket.AT_enabled then
     -- turn off tourist recall boundary
    ATtoggleTouristBoundary(rocket, false)
    rocket.AT_departuretimeText = ""
    -- recalc departures in case we depart and leave someone behind
  	if rocket.departures and #rocket.departures > 0 then rocket.AT_departures = rocket.AT_departures - #rocket.departures end

    -- notification of rocket launch
    local msg = T{StringIdBase + 2, "Departures: <count>", count = rocket.AT_departures}
    AddCustomOnScreenNotification("AT_Notice_Leaving", T{StringIdBase + 1, "Tourist Rocket Leaving"}, msg, iconATnoticeIcon, nil, {cycle_objs = {rocket}, expiration = g_AT_Options.ATnoticeDismissTime})
    PlayFX("UINotificationResearchComplete", rocket)

    -- determing status
    local tt = 0 < (rocket.custom_travel_time_earth or 0) and rocket.custom_travel_time_earth or g_Consts.TravelTimeMarsEarth
    if (rocket.AT_next_voyage_time > 0) and (rocket.AT_next_voyage_time  >= (GameTime() + tt)) then
    	if lf_print then print("Status set to flytoearth") end
    	rocket.AT_status = "flytoearth"
    else
    	if lf_print then print("Status set to pickup") end
    	rocket.AT_status = "pickup"
    end -- if (rocket.AT_nextvoyage_time > 0) -- determine status

	end -- if rocket.AT_enabled
end -- OnMsg.RocketLaunched(rocket)


function OnMsg.RocketLanded(rocket)
	if lf_print and rocket.AT_enabled then print("Tourist Rocket Landed On Mars") end

  if rocket.AT_enabled then
  	rocket.AT_last_arrival_time = GameTime()
  	rocket.AT_status = "landed"

  	-- setup rocket recall tourist boundary
    if g_AT_Options.ATrecallRadius then ATtoggleTouristBoundary(rocket, true) end

    -- notification of rocket landed
    local msg = T{StringIdBase + 4, "Arrivals: <count>", count = rocket.AT_arriving_tourists}
    AddCustomOnScreenNotification("AT_Notice_Landed", T{StringIdBase + 3, "Tourist Rocket Landed"}, msg, iconATnoticeIcon, nil, {cycle_objs = {rocket}, expiration = g_AT_Options.ATnoticeDismissTime})
    PlayFX("UINotificationResearchComplete", rocket)

    -- if a thread is already running then delete it (should never happen)
  	if IsValidThread(rocket.AT_depart_thread) then DeleteThread(rocket.AT_depart_thread) end

  	-- create thread to wait before launch up to 5 days if no tourists departing
  	rocket.AT_depart_thread = CreateGameTimeThread(function()
  		if rocket.auto_export then rocket:ToggleAutoExport() end -- turn off auto launch sequence
  		rocket:AttachSign(rocket.AT_enabled, "SignTradeRocket")

      -- wait 60 seconds to calculate departure time due to landing delay
      -- GenerateDepartures() is called automatically upon landing a rocket so we dont need to call it here
      rocket.AT_departures = 0
      --~ set an on screen message here for arriving tourists
      rocket.AT_arriving_tourists = 0
      rocket.AT_departuretime = ""
      rocket.AT_departuretimeText = ""
      Sleep(60000)
      if lf_print then print("Calculating departure time") end

      -- set departure time and have_depatures
      ATcalcDepartureTime(rocket)

  		if not rocket.AT_have_departures then
  			-- if not departures
  			if lf_print then print(string.format("Rocket waiting until %s - No current departures", rocket.AT_departuretimeText)) end
  			rocket.AT_status = "waitdepart"
  		  while (GameTime() < rocket.AT_departuretime) do
  			  Sleep(2000) -- sleep 2 seconds at a time
  		  end -- while GameTime
  		  -- call tourists to rocket
  		  ATflashStatus(rocket, "checkdepart", "waitdepart", true)
  		  rocket.departures = nil -- nil out departures to have GenerateDepartures execute
  		  rocket:GenerateDepartures()
  		  -- wait 3 seconds then reset departure time and have_departures if there are departures
  		  if lf_print then print("Sleeping 3 seconds") end
  		  Sleep(3000)
  		  ATcalcDepartureTime(rocket)
  		end -- if not rocket.AT_have_departures

  		if rocket.AT_have_departures then
  			ATflashStatus(rocket) -- kill status thread if it exists
  			rocket.AT_status = "boarding"
  			-- if we have departures then reset and start countdown
  		  if lf_print then print(string.format("Rocket has %s departures, departing %s", #rocket.departures, rocket.AT_departuretimeText)) end
  		  while (GameTime() < rocket.AT_departuretime) do
  			  Sleep(2000) -- sleep 2 seconds at a time
  		  end -- while GameTime
  	  end -- if rocket.AT_have_departures

  		if lf_print then print("Rocket ready to depart") end

  		ATflashStatus(rocket) -- kill status thread if it exists (possible set in oncontextupdate if tourists did board)
  		rocket.AT_status = "departing"
  		rocket:ReturnStockpiledResources() -- dump any resources on landing pad so we can launch
  		if rocket.AT_enabled then rocket:ToggleAutoExport() end -- turn on auto launch sequence, check to make sure still a tourist rocket
  	end) -- AT_depart_thread

  end -- if AT_enabled

end -- OnMsg.RocketLanded(rocket)


function OnMsg.RocketLaunchFromEarth(rocket)
	if lf_print and rocket.AT_enabled then print("Tourist Rocket Launched from Earth") end

	if rocket.AT_enabled then
		-- make sure last voyage was at least 5 sols ago
		if (not rocket.AT_last_voyage_time) or (rocket.AT_last_voyage_time + (5 * const.DayDuration) <= GameTime()) then

		  if lf_print and rocket.AT_enabled then print("Last tourist rocket older than 5 days, picking up new tourists.") end

  	  -- gather new tourists
  	  local UICity   = UICity
  	  local capacity = Min(g_Consts.MaxColonistsPerRocket, g_AT_Options.ATMaxTourists) -- set capacity to the smaller of current allowed passengers or 20
      local applicantPool = g_ApplicantPool or ""
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
        cargo[1] = {
          class = "Passengers",
          amount = count,
          applicants_data = tourists
        }
        cargo[2] = {
          class = "Food",
          amount = MulDivRound(count, g_Consts.FoodPerRocketPassenger, const.ResourceScale)
        }
      end -- if #tourists

      -- load up the tourists and set last voyage time
      if lf_print then print(string.format("Sending tourist rocket with %s tourists", #tourists)) end
      rocket.cargo = cargo
      rocket.AT_arriving_tourists = #tourists
      rocket.AT_status = "flyingtourists"
      rocket.AT_last_voyage_time = GameTime()
      rocket.AT_next_voyage_time = rocket.AT_last_voyage_time + (5 * const.DayDuration)
      rocket.AT_next_voyage_timeText = ATConvertDateTime(rocket.AT_next_voyage_time)

    else
    	if lf_print and rocket.AT_enabled then print(string.format("Last tourist rocket was %.2f sols ago.  Not sending new tourists.", (GameTime() - rocket.AT_last_voyage_time + 0.00)/const.DayDuration)) end
      rocket.AT_status = "flyingempty"
    end --if (not rocket.AT_last_voyage_time)

    -- notification of rocket leaving earth
    local msg = T{StringIdBase + 6, "On Board: <count>", count = rocket.AT_arriving_tourists}
    AddCustomOnScreenNotification("AT_Notice_Voyage", T{StringIdBase + 5, "Tourist Rocket En Route"}, msg, iconATnoticeIcon, nil, {cycle_objs = {rocket}, expiration = g_AT_Options.ATnoticeDismissTime})
    PlayFX("UINotificationResearchComplete", rocket)

  else
  	-- short circuit if not a tourist rocket
  	if lf_print then print("Launched rocket is not a tourist rocket")	end
  end -- if rocket.AI_enabled

end -- OnMsg.RocketLaunchFromEarth(rocket)


function OnMsg.ClassesGenerate()

  -- re-write OnDemolish to make sure vars, threads and other items are killed
  local Old_SupplyRocket_OnDemolish = SupplyRocket.OnDemolish
  function SupplyRocket:OnDemolish()
  	local rocket = self
  	if not IsKindOfClasses(rocket, "RocketExpedition", "ForeignTradeRocket", "TradeRocket", "SupplyPod", "ArkPod", "DropPod") then
  	  -- ATsetButtonStatus(rocket, true) -- reset original buttons back on -- no need to do this since we are in the process of demolishing the rocket
  	  ATsetupVariables(rocket, false) -- clear all AT vars
  	end --if not IsKindOfClasses
  	return Old_SupplyRocket_OnDemolish(self) -- call original function
  end -- SupplyRocket:OnDemolish()

  -- rewrite old function to exclude tourist rockets from expeditions
  local Old_SupplyRocket_IsRocketLanded = SupplyRocket.IsRocketLanded
  function SupplyRocket:IsRocketLanded()
  	if self.AT_enabled then return false
  		                 else return Old_SupplyRocket_IsRocketLanded(self) end
  end -- SupplyRocket:IsRocketLanded()

  -- add tourist rocket status to rockets in send expedition view
  local Old_GetRocketExpeditionStatus = GetRocketExpeditionStatus
  function GetRocketExpeditionStatus(rocket)
    if rocket.AT_enabled then
      return T(StringIdBase + 115, "Tourist rocket")
    end
    return Old_GetRocketExpeditionStatus(rocket)
  end -- GetRocketExpeditionStatus(rocket)


end -- OnMsg.ClassesGenerate()
