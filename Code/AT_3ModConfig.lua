-- Code developed for Automated Tourism
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- If you are an Aboslute Games developer looking at this, just go away.  You suck at development.
-- You may not copy it, package it, or claim it as your own.
-- Created May 1st, 2019
-- Updated March 28th, 2021


local lf_print = false -- Setup debug printing in local file
                       -- Use if lf_print then print("something") end

local StringIdBase = 17764702300 -- Automated Tourism    : 702300 - 702499 File Starts at 50-99:  Next is 77
local steam_id = "1736068322"
local mod_name = "Automated Tourism"
local ModConfig_id = "1542863522"
local ModConfigWaitThread = false
local ModDir = CurrentModPath
local iconATnoticeIcon = ModDir.."UI/Icons/ATNoticeIcon.png"
local imageATrockets   = ModDir.."UI/Messages/AT_Rockets_Takeoff.png"
local msgModEnabled  = T{StringIdBase + 72, "Automatic Tourism is enabled"}
local msgModDisabled = T{StringIdBase + 73, "Automatic Tourism is disabled"}
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

        g_AT_Options.ATMaxTourists     = ModConfig:Get("Automated_Tourism", "ATMaxTourists")
        g_AT_Options.ATvoyageWaitTime  = ModConfig:Get("Automated_Tourism", "ATvoyageWaitTime")
        g_AT_Options.ATrecallRadius    = ModConfig:Get("Automated_Tourism", "ATrecallRadius")
        g_AT_Options.ATearlyDepartures = ModConfig:Get("Automated_Tourism", "ATearlyDepartures")
        g_AT_Options.ATstripSpecialty  = ModConfig:Get("Automated_Tourism", "ATstripSpecialty")
        g_AT_Options.ATpreventDepart   = ModConfig:Get("Automated_Tourism", "ATpreventDepart")
        g_AT_Options.ATfoodPerTourist  = ModConfig:Get("Automated_Tourism", "ATfoodPerTourist")

        -- g_AT_modEnabled g_AT_NumOfTouristRockets enable mod checks
        local tick = 0 -- wait up to 120 seconds for this
        while (not g_AT_RocketCheckComplete) and (tick < 1200) do
          Sleep (100) -- wait until check is complete
          tick = tick + 1
        end -- while

        local AT_modEnabled = ModConfig:Get("Automated_Tourism", "AT_modEnabled")
        if (AT_modEnabled ~= g_AT_modEnabled) and (g_AT_NumOfTouristRockets > 0) then
          -- g_AT_modEnabled is default true, non-persistent on any game load
          -- cannot set mod disabled if there are tourist rockets running, reset MCR to enabled
          ModConfig:Set("Automated_Tourism", "AT_modEnabled", true, "reset")
        elseif (AT_modEnabled ~= g_AT_modEnabled) and (g_AT_NumOfTouristRockets < 1) then
          g_AT_modEnabled = AT_modEnabled
        end -- if (AT_modEnabled ~= g_AT_modEnabled)

        -- Send a notification message about status
        local msg
        if g_AT_modEnabled then
          msg = msgModEnabled
        else
          msg = msgModDisabled
        end --if g_AT_modEnabled
        AddCustomOnScreenNotification("AT_Notice", T{StringIdBase + 50, "Automatic Tourism"}, msg, iconATnoticeIcon, nil, {expiration = g_AT_Options.ATnoticeDismissTime})
        PlayFX("UINotificationResearchComplete")

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

local function ATWarnATrocketsEnabled(num_rockets)
  CreateRealTimeThread(function()
      local params = {
            title = T{StringIdBase + 74, "Warning"},
             text = T{StringIdBase + 75, "You cannot disable Automated Tourism Mod while rockets are set to Automated.<newline>You have <number> automated rockets flying.", number = num_rockets or 0},
          choice1 = T{StringIdBase + 76, "OK"},
            image = imageATrockets,
            start_minimized = false,
      } -- params
      local choice = WaitPopupNotification(false, params)
  end ) -- CreateRealTimeThread
end -- function end

---------------------------------------------- OnMsgs -------------------------------------------------------------------

function OnMsg.ModConfigReady()
  local StringIdBase = 17764702300 -- Automated Tourism

    -- Register this mod's name and description
    ModConfig:RegisterMod("Automated_Tourism", -- ID
        T{StringIdBase + 50, "Automated Tourism"}, -- Optional display name, defaults to ID
        T{StringIdBase + 51, "Options for Automated Tourism"} -- Optional description
    )

    ModConfig:RegisterOption("Automated_Tourism", "AT_modEnabled", {
        name = T{StringIdBase + 52, "Enable Automated Tourism Mod and Fixes: "},
        desc = T{StringIdBase + 53, "Enable Automated Tourism completly including fixes or disable and return functions to original game code."},
        type = "boolean",
        default = true,
        order = 1
    })

    ModConfig:RegisterOption("Automated_Tourism", "ATdismissMsg", {
        name = T{StringIdBase + 54, "Auto dismiss notification: "},
        desc = T{StringIdBase + 55, "Auto dismiss Automated Tourism messages.  Set the time below."},
        type = "boolean",
        default = true,
        order = 2
    })

    ModConfig:RegisterOption("Automated_Tourism", "ATnoticeDismissTime", {
        name = T{StringIdBase + 56, "Auto dismiss notification time in seconds:"},
        desc = T{StringIdBase + 57, "The number of seconds to keep notifications on screen before dismissing."},
        type = "number",
        default = 20,
        min = 1,
        max = 200,
        step = 1,
        order = 3
    })

    -- ATMaxTourists
    ModConfig:RegisterOption("Automated_Tourism", "ATMaxTourists", {
        name = T{StringIdBase + 58, "Maximum tourists per rocket:"},
        desc = T{StringIdBase + 59, "The maximum number of tourists a rocket can load (if rocket capacity allows)"},
        type = "number",
        default = 20,
        min = 1,
        max = 50,
        step = 1,
        order = 4
    })

    -- ATvoyageWaitTime
    ModConfig:RegisterOption("Automated_Tourism", "ATvoyageWaitTime", {
        name = T{StringIdBase + 60, "Wait time between voyages:"},
        desc = T{StringIdBase + 61, "The minimum sols to wait between voyages."},
        type = "number",
        default = 5,
        min = 1,
        max = 50,
        step = 1,
        order = 5
    })

    -- ATrecallRadius
    ModConfig:RegisterOption("Automated_Tourism", "ATrecallRadius", {
        name = T{StringIdBase + 62, "Globally show tourist recall radius:"},
        desc = T{StringIdBase + 63, "Globally show the tourist recall radius circle around the rocket.<newline>Individual rocket settings override this setting."},
        type = "boolean",
        default = true,
        order = 6
    })

    -- ATearlyDepartures
    ModConfig:RegisterOption("Automated_Tourism", "ATearlyDepartures", {
        name = T{StringIdBase + 64, "Allow early departures:"},
        desc = T{StringIdBase + 65, "Set departure time to the next voyage time, if voyage is already set."},
        type = "boolean",
        default = true,
        order = 7
    })

    -- g_AT_Options.ATstripSpecialty
    ModConfig:RegisterOption("Automated_Tourism", "ATstripSpecialty", {
        name = T{StringIdBase + 66, "Strip tourist specialization:"},
        desc = T{StringIdBase + 67, "Remove any specialities for arriving tourists since they dont work anyway."},
        type = "boolean",
        default = true,
        order = 8
    })

    -- g_AT_Options.ATpreventDepart
    ModConfig:RegisterOption("Automated_Tourism", "ATpreventDepart", {
        name = T{StringIdBase + 68, "Prevent departures on non tourist rockets:"},
        desc = T{StringIdBase + 69, "Prevents tourists from leaving Mars on non tourist rockets when at least one Tourist Rocket is running."},
        type = "boolean",
        default = true,
        order = 9
    })

    -- g_AT_Options.ATfoodPerTourist
    ModConfig:RegisterOption("Automated_Tourism", "ATfoodPerTourist", {
        name = T{StringIdBase + 70, "Amount of food each tourist brings to Mars:"},
        desc = T{StringIdBase + 71, "The amount of food each tourist brings to Mars."},
        type = "number",
        default = 1,
        min = 0,
        max = 5,
        step = 1,
        order = 10
    })

end -- ModConfigReady


function OnMsg.ModConfigChanged(mod_id, option_id, value, old_value, token)
  if g_ModConfigLoaded and (mod_id == "Automated_Tourism") and (token ~= "reset") then

    -- AT_modEnabled
    if option_id == "AT_modEnabled" then
      if value then
        -- enable AT
        -- if true just set it and notify
        g_AT_modEnabled = value
        AddCustomOnScreenNotification("AT_Notice", T{StringIdBase + 50, "Automatic Tourism"}, msgModEnabled, iconATnoticeIcon, nil, {expiration = g_AT_Options.ATnoticeDismissTime})
        PlayFX("UINotificationResearchComplete")
      elseif g_AT_NumOfTouristRockets > 0 then
        -- cant disable AT
        -- cant set it since we are flying AT rockets
        -- reset MCR and msg
        ModConfig:Toggle("Automated_Tourism", "AT_modEnabled", "Reset")
        ATWarnATrocketsEnabled(g_AT_NumOfTouristRockets)
      else
        -- disable AT
        -- if no AT rockets set and notify
        g_AT_modEnabled = value
        AddCustomOnScreenNotification("AT_Notice", T{StringIdBase + 50, "Automatic Tourism"}, msgModDisabled, iconATnoticeIcon, nil, {expiration = g_AT_Options.ATnoticeDismissTime})
        PlayFX("UINotificationResearchComplete")
        ATStartDepartureThreads() -- put them back like normal
      end -- if value
    end -- AT_modEnabled

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

    -- ATMaxTourists
    if option_id == "ATMaxTourists" then
      g_AT_Options.ATMaxTourists = value -- maximum number of tourists per rocket
    end -- ATMaxTourists

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
          if (rockets[i].AT_RecallRadiusMode == "Mod Config Set") and rockets[i].AT_touristBoundary and IsValid(rockets[i].AT_touristBoundary) then ATtoggleTouristBoundary(rockets[i], false) end
        end -- for i
      else
        -- turn on all recall boundaries
        local rockets = (UICity and UICity.labels.SupplyRocket) or ""
        for i = 1, #rockets do
          if (rockets[i].AT_RecallRadiusMode == "Mod Config Set") and rockets[i].AT_enabled and not rockets[i].AT_touristBoundary and not IsValid(rockets[i].AT_touristBoundary) then ATtoggleTouristBoundary(rockets[i], true) end
        end -- for i
      end -- if not value
    end -- ATrecallRadius

    -- ATearlyDepartures
    if option_id == "ATearlyDepartures" then
      g_AT_Options.ATearlyDepartures = value -- allow early departures
    end -- ATearlyDepartures

    -- g_AT_Options.ATstripSpecialty
    if option_id == "ATstripSpecialty" then
      g_AT_Options.ATstripSpecialty = value -- strip specialties
    end -- g_AT_Options.ATstripSpecialty

    --g_AT_Options.ATpreventDepart - default is true
    if option_id == "ATpreventDepart" then
      g_AT_Options.ATpreventDepart = value -- prevent regular rockets from being used by tourists or earthsick
      -- code to start and stop all the generateddeparture threads
      -- default is true - if flipping value to false we need to restart all the threads on non AT rockets
      if not g_AT_Options.ATpreventDepart then
        ATStartDepartureThreads() -- start all departure threads, except on AT_enabled rockets
      else
        ATStopDepartureThreads() -- if flipping value back to true we need to stop any generateddeparture threads
      end -- if not g_AT_Options.ATpreventDepar
    end -- g_AT_Options.ATpreventDepart

    -- g_AT_Options.ATfoodPerTourist
    if option_id == "ATfoodPerTourist" then
      g_AT_Options.ATfoodPerTourist = value -- food per tourist en route to mars
    end -- g_AT_Options.ATfoodPerTourist

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