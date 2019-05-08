-- Code developed for Incubator
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- You may not copy it, package it, or claim it as your own.
-- Created May 1st, 2019
-- Updated May 5th, 2019


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


local StringIdBase = 17764702300 -- Automated Tourism    : 702300 - 702499 File Starts at 300-349:  Next is 7
local ModDir = CurrentModPath
local iconATnoticeIcon = ModDir.."UI/Icons/ATNoticeIcon.png"


-- return sol, hour and minute of futureTime
function ATGetDateTime(currentTime, futureTime)
	local UICity = UICity
	local deltaTime = futureTime - currentTime
	local sol = deltaTime / const.DayDuration
	local newsol = UICity.day + sol
	local hour = deltaTime % const.DayDuration / const.HourDuration
	local newhour = UICity.hour + hour
	if newhour >= 24 then
		newhour = newhour - 24
		newsol = newsol + 1
	end -- if newhour
	return string.format("Sol: %s Time: %02d:%02d", newsol, newhour, UICity.minute)
end -- ATGetDateTime()


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
  	rocket.AT_departuretime = rocket.AT_last_arrival_time + (12 * const.HourDuration) -- wait 1/2 day to depart since we got departures
  	rocket.AT_have_departures = true
  end -- rocket.AT_departures

  -- add departure time text
  rocket.AT_departuretimeText = ATGetDateTime(rocket.AT_last_arrival_time, rocket.AT_departuretime)

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

--------------------------------------------------------- OnMsgs --------------------------------------------------------


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
  	if IsValidThread(rocket.AT_thread) then DeleteThread(rocket.AT_thread) end

  	-- create thread to wait before launch up to 5 days if no tourists departing
  	rocket.AT_thread = CreateGameTimeThread(function()
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
  			  Sleep(10000) -- sleep 10 seconds at a time
  		  end -- while GameTime
  		  -- call tourists to rocket
  		  rocket.departures = nil -- nil out departures to have GenerateDepartures execute
  		  rocket:GenerateDepartures()
  		  -- wait 60 seconds then reset departure time and have_departures if there are departures
  		  Sleep(60000)
  		  -- if we have departures then reset last arrival time to now so we can recalculate departure time properly
  		  if #rocket.departures > 0 then rocket.AT_last_arrival_time = GameTime() end
  		  ATcalcDepartureTime(rocket)
  		end -- if not rocket.AT_have_departures

  		if rocket.AT_have_departures then
  			rocket.AT_status = "waitdepart"
  			-- if we have departures then reset and start countdown
  		  if lf_print then print(string.format("Rocket has %s departures, departing %s", #rocket.departures, rocket.AT_departuretimeText)) end
  		  while (GameTime() < rocket.AT_departuretime) do
  			  Sleep(10000) -- sleep 10 seconds at a time
  		  end -- while GameTime
  	  end -- if rocket.AT_have_departures

  		if lf_print then print("Rocket ready to depart") end
  		if rocket.AT_enabled then rocket:ToggleAutoExport() end -- turn on auto launch sequence, check to make sure still a tourist rocket
  	end) -- AT_thread

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
      rocket.AT_next_voyage_timeText = ATGetDateTime(rocket.AT_last_voyage_time, rocket.AT_next_voyage_time)

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
  	ATsetButtonStatus(self, true) -- reset original butons back on
  	ATsetupVariables(rocket, false) -- clear all AT vars
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
