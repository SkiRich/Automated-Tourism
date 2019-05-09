-- Code developed for Incubator
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- You may not copy it, package it, or claim it as your own.
-- Created May 1st, 2019
-- Updated May 5th, 2019


local lf_print = false -- Setup debug printing in local file
                       -- Use if lf_print then print("something") end

local StringIdBase = 17764702300 -- Automated Tourism    : 702300 - 702499 File Starts at 50-99:  Next is 50
local steam_id = "1736068322"
local mod_name = "Automated Tourism"
local ModConfig_id = "1542863522"
local ModConfigWaitThread = false
g_ModConfigLoaded = false


-- wait for mod config to load or fail out and use defaults
local function WaitForModConfig()
	if (not ModConfigWaitThread) or (not IsValidThread(ModConfigWaitThread)) then
		ModConfigWaitThread = CreateRealTimeThread(function()
	    if lf_print then print(string.format("%s WaitForModConfig Thread Started", mod_name)) end
      local Sleep = Sleep
      local TableFind  = table.find
      local ModsLoaded = ModsLoaded
      local threadlimit = 120  -- loops to wait before fail and exit thread loop
 		  while threadlimit > 0 do
 		  	--check to make sure another mod didn't already set g_ModConfigLoaded
 			  if not g_ModConfigLoaded then
 			  	g_ModConfigLoaded = TableFind(ModsLoaded, "steam_id", ModConfig_id) or false
 			  end -- if not g_ModConfigLoaded
 			  if g_ModConfigLoaded and ModConfig:IsReady() then
 			  	-- if ModConfig loaded and is in ready state then set as true
 			  	g_ModConfigLoaded = true
 			  	break
 			  else
 			    Sleep(500) -- Sleep 1/2 second
 			  end -- if g_ModConfigLoaded
 			  threadlimit = threadlimit - 1
 		  end -- while
      if lf_print then print(string.format("%s WaitForModConfig Thread Continuing", mod_name)) end

      -- See if ModConfig is installed and any defaults changed
      if g_ModConfigLoaded and ModConfig:IsReady() then

		    g_AT_Options.ATdismissMsg = ModConfig:Get("Automated_Tourism", "ATdismissMsg")
		    if not g_AT_Options.ATdismissMsg then
		    	g_AT_Options.ATnoticeDismissTime = -1
		    else
		    	g_AT_Options.ATnoticeDismissTime = ModConfig:Get("Automated_Tourism", "ATnoticeDismissTime") * 1000
		    end -- if not g_AT_Options.ATdismissMsg

		    g_AT_Options.ATmaxTourists     = ModConfig:Get("Automated_Tourism", "ATmaxTourists")
        g_AT_Options.ATvoyageWaitTime  = ModConfig:Get("Automated_Tourism", "ATvoyageWaitTime")
        g_AT_Options.ATrecallRadius    = ModConfig:Get("Automated_Tourism", "ATrecallRadius")
        g_AT_Options.ATearlyDepartures = ModConfig:Get("Automated_Tourism", "ATearlyDepartures")

        ModLog(string.format("%s detected ModConfig running - Setup Complete", mod_name))
      else
      	-- PUT MOD DEFAULTS HERE OR SET THEM UP BEFORE RUNNING THIS FUNCTION ---

    	  if lf_print then print(string.format("**** %s - Mod Config Never Detected On Load - Using Defaults ****", mod_name)) end
    	  ModLog(string.format("**** %s - Mod Config Never Detected On Load - Using Defaults ****", mod_name))
      end -- end if g_ModConfigLoaded
      if lf_print then print(string.format("%s WaitForModConfig Thread Ended", mod_name)) end
		end) -- thread
	else
		if lf_print then print(string.format("%s Error - WaitForModConfig Thread Never Ran", mod_name)) end
		ModLog(string.format("%s Error - WaitForModConfig Thread Never Ran", mod_name))
	end -- check to make sure thread not running
end -- WaitForModConFig

---------------------------------------------- OnMsgs -------------------------------------------------------------------

function OnMsg.ModConfigReady()

    -- Register this mod's name and description
    ModConfig:RegisterMod("Automated_Tourism", -- ID
        T{StringIdBase + 50, "Automated Tourism"}, -- Optional display name, defaults to ID
        T{StringIdBase + 51, "Options for Automated Tourism"} -- Optional description
    )

    ModConfig:RegisterOption("Automated_Tourism", "ATdismissMsg", {
        name = T{StringIdBase + 52, "Auto dismiss notification: "},
        desc = T{StringIdBase + 53, "Auto dismiss Automated Tourism messages.  Set the time below."},
        type = "boolean",
        default = true,
        order = 1
    })

    ModConfig:RegisterOption("Automated_Tourism", "ATnoticeDismissTime", {
        name = T{StringIdBase + 54, "Auto dismiss notification time in seconds:"},
        desc = T{StringIdBase + 55, "The number of seconds to keep notifications on screen before dismissing."},
        type = "number",
        default = 20,
        min = 1,
        max = 200,
        step = 1,
        order = 2
    })

    -- ATmaxTourists
    ModConfig:RegisterOption("Automated_Tourism", "ATmaxTourists", {
        name = T{StringIdBase + 56, "Maximum tourists per rocket:"},
        desc = T{StringIdBase + 57, "The maximum number of tourists a rocket can load (if rocket capacity allows)"},
        type = "number",
        default = 20,
        min = 1,
        max = 50,
        step = 1,
        order = 3
    })

    -- ATvoyageWaitTime
    ModConfig:RegisterOption("Automated_Tourism", "ATvoyageWaitTime", {
        name = T{StringIdBase + 58, "Wait time between voyages:"},
        desc = T{StringIdBase + 59, "The minimum sols to wait between voyages."},
        type = "number",
        default = 5,
        min = 1,
        max = 50,
        step = 1,
        order = 4
    })

    -- ATrecallRadius
    ModConfig:RegisterOption("Automated_Tourism", "ATrecallRadius", {
        name = T{StringIdBase + 60, "Show tourist recall radius:"},
        desc = T{StringIdBase + 61, "Show the tourist recall radius circle around the rocket."},
        type = "boolean",
        default = true,
        order = 5,
    })

    -- ATearlyDepartures
    ModConfig:RegisterOption("Automated_Tourism", "ATearlyDepartures", {
        name = T{StringIdBase + 62, "Allow early departures:"},
        desc = T{StringIdBase + 63, "Set departure time to the next voyage time, if voyage is already set."},
        type = "boolean",
        default = true,
        order = 6,
    })

end -- ModConfigReady


function OnMsg.ModConfigChanged(mod_id, option_id, value, old_value, token)
  if g_ModConfigLoaded and (mod_id == "Automated_Tourism") and (token ~= "reset") then

  	-- ATdismissMsg
  	if option_id == "ATdismissMsg" then
  		if value then
  			local dismissmsgtime = ModConfig:Get("Automated_Tourism", "ATnoticeDismissTime")
  			g_AT_Options.ATnoticeDismissTime = dismissmsgtime * 1000 -- (msec)
  			g_AT_Options.ATdismissMsg = value
  		else
  			g_AT_Options.ATnoticeDismissTime = -1 -- stay on screen until dismissed
  			g_AT_Options.ATdismissMsg = value
  		end -- if value is true
    end -- ATPdismissMsg

  	-- ATnoticeDismissTime
  	if option_id == "ATnoticeDismissTime" and g_AT_Options.ATdismissMsg then
      g_AT_Options.ATnoticeDismissTime = value * 1000 -- in msecs
    end -- ATPdismissMsg

  	-- ATmaxTourists
  	if option_id == "ATmaxTourists" then
      g_AT_Options.ATmaxTourists = value -- maximum number of tourists per rocket
    end -- ATmaxTourists

  	-- ATvoyageWaitTime
  	if option_id == "ATvoyageWaitTime" then
      g_AT_Options.ATvoyageWaitTime = value -- sols to wait between voyages
    end -- ATvoyageWaitTime

    --ATrecallRadius
  	if option_id == "ATrecallRadius" then
      g_AT_Options.ATrecallRadius = value -- display tourist recall circle
      if not value then
      	-- turn off all recall boundaries
      	local rockets = (UICity and UICity.labels.SupplyRocket) or ""
      	for i = 1, #rockets do
      		if rockets[i].AT_touristBoundary and IsValid(rockets[i].AT_touristBoundary) then ATtoggleTouristBoundary(rockets[i], false) end
      	end -- for i
      else
      	-- turn on all recall boundaries
      	local rockets = (UICity and UICity.labels.SupplyRocket) or ""
      	for i = 1, #rockets do
      		if rockets[i].AT_enabled and not rockets[i].AT_touristBoundary and not IsValid(rockets[i].AT_touristBoundary) then ATtoggleTouristBoundary(rockets[i], true) end
      	end -- for i
      end -- if not value
    end -- ATvoyageWaitTime

    -- ATearlyDepartures
  	if option_id == "ATearlyDepartures" then
      g_AT_Options.ATearlyDepartures = value -- allow early departures
    end -- ATvoyageWaitTime

  end -- if g_ModConfigLoaded
end -- OnMsg.ModConfigChanged


function OnMsg.CityStart()
  WaitForModConfig()
end -- OnMsg.CityStart()


function OnMsg.LoadGame()
  WaitForModConfig()
end -- OnMsg.LoadGame()

local function SRDailyPopup()
    CreateRealTimeThread(function()
        local params = {
              title = "Non-Author Mod Copy",
               text = "We have detected an illegal copy version of : ".. mod_name .. ". Please uninstall the existing version.",
            choice1 = "Download the Original [Opens in new window]",
            choice2 = "Damn you copycats!",
            choice3 = "I don't care...",
              image = "UI/Messages/death.tga",
              start_minimized = false,
        } -- params
        local choice = WaitPopupNotification(false, params)
        if choice == 1 then
        	OpenUrl("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. steam_id, true)
        end -- if statement
    end ) -- CreateRealTimeThread
end -- function end


function OnMsg.NewDay(day)
  if table.find(ModsLoaded, "steam_id", steam_id)~= nil then
    --nothing
  else
    SRDailyPopup()
  end -- SRDailyPopup
end --OnMsg.NewDay(day)