-- Code developed for Incubator
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- You may not copy it, package it, or claim it as your own.
-- Created May 1st, 2019
-- Updated May 1st, 2019


local lf_print = true -- Setup debug printing in local file
                       -- Use if lf_print then print("something") end


local StringIdBase = 17764702300 -- Automated Tourism    : 702300 - 702499 File Starts at 0-399:  Next is 1
local steam_id = "0"
local mod_name = "Automated Tourism"

-- calculate departure time
local function ATcalcDepartureTime(rocket)
  rocket.AT_departures = (rocket.departures and #rocket.departures) or 0

  if rocket.AT_departures == 0 then
  	rocket.AT_departuretime = rocket.AT_last_arrival_time + (5 * const.DayDuration) -- wait 5 days to depart if no immediate departures
  	rocket.AT_have_departures = false
  else
  	rocket.AT_departuretime = rocket.AT_last_arrival_time + (12 * const.HourDuration) -- wait 1/2 day to depart since we got departures
  	rocket.AT_have_departures = true
  end -- rocket.AT_departures

  -- add departure time text
  rocket.AT_departuretimeText = ATGetDateTime(rocket.AT_last_arrival_time, rocket.AT_departuretime)

end -- ATcalcDepartureTime()

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

--------------------------------------------------------- OnMsgs --------------------------------------------------------

function OnMsg.RocketReachedEarth(rocket)
	if lf_print and rocket.AT_enabled then print("Tourist Rocket Reached Earth") end

end -- OnMsg.RocketReachedEarth(rocket)


function OnMsg.RocketLanded(rocket)
	if lf_print and rocket.AT_enabled then print("Tourist Rocket Landed On Mars") end

  if rocket.AT_enabled then
  	rocket.AT_last_arrival_time = GameTime()

    -- if a thread is already running then delete it (should never happen)
  	if IsValidThread(rocket.AT_thread) then DeleteThread(rocket.AT_thread) end

  	-- create thread to wait before launch up to 5 days if no tourists departing
  	rocket.AT_thread = CreateGameTimeThread(function()
  		if rocket.auto_export then rocket:ToggleAutoExport() end -- turn off auto launch sequence

      -- wait 60 seconds to calculate departure time due to landing delay
      -- GenerateDepartures() is called automatically upon landing a rocket so we dont need to call it now
      rocket.AT_departures = 0
      rocket.AT_departuretime = ""
      rocket.AT_departuretimeText = ""
      Sleep(60000)
      if lf_print then print("Calculating departure time") end

      -- set departure time and have_depatures
      ATcalcDepartureTime(rocket)

  		if not rocket.AT_have_departures then
  			-- if not departures
  			if lf_print then print(string.format("Rocket waiting until %s - No current departures", rocket.AT_departuretimeText)) end
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
  	  local capacity = Min(g_Consts.MaxColonistsPerRocket, 20) -- set capacity to the smaller of current allowed passengers or 20
      local applicantPool = g_ApplicantPool
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
      rocket.AT_last_voyage_time = GameTime()
      rocket.AT_next_voyage_time = rocket.AT_last_voyage_time + (5 * const.DayDuration)
      rocket.AT_next_voyage_timeText = ATGetDateTime(rocket.AT_last_voyage_time, rocket.AT_next_voyage_time)

    else
    	if lf_print and rocket.AT_enabled then print(string.format("Last tourist rocket was %.2f sols ago.  Not sending new tourists.", (GameTime() - rocket.AT_last_voyage_time + 0.00)/const.DayDuration)) end
    end --if (not rocket.AT_last_voyage_time)

  else
  	-- short circuit if not a tourist rocket
  	if lf_print then print("Launched rocket is not a tourist rocket")	end
  end -- if rocket.AI_enabled

end -- OnMsg.RocketLaunchFromEarth(rocket )
