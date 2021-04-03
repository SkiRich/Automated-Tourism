# Automated Tourism
## v1.11.1 04/01/2021 3:37:35 PM
#### Changed
- ATsetupVariables(rocket, init)
 - added kill to threads in init, just in case and moved AT_enabled = nil to last place
 - modified AT_leaving_colonists and AT_boarded_colonists to match existing stats in case boarding was alreading happening

- ATflashStatus(rocket, status1, status2, enable) - added rocket var check
- rocket:AttachSign(true, "SignTradeRocket") -- all instances now use true/false instead of variable, no need to reference var
- moved threadlimits vars into threads
- ATtoggleAutoExport()
 - new logic, count variables if departures already exist

- function ATcountTouristsOnEarth() - made global
- function ATreplaceRocketLogo(rocket, reset, resetAll, applyAll)
 - doing a test for entites now, just in case of attach loss

- xTemplate - optimizations
- changed all threads to make sure they run IsValid and/or a threadlimit countdown, to prevent runaway threads
- function RocketExpedition:Takeoff() - added countdown status to commit rocket
- various minor code tweaks for improved execution and logic
- on first run dump resources before toggling auto export - panels

#### Added
- various ModLog messages
- validity checks in function ATejectColonists(rocket)
- added AT_firstRun variable to AT stack
- auto attach code to entities in function ATreplaceRocketLogo(rocket, reset, resetAll, applyAll)

#### Removed
- localized functions in threads
- localized global vars in threads

#### Fixed Issues
- loosing thread handles
- wrong statistics if initiating AT and there are departures already boarded
- errors thrown when new logo entity attach is missing
- localized functions in threads throwing errors when loading save and thread still running - GameTime()

#### Open Issues

#### Deprecated

#### Todo

--------------------------------------------------------
## v1.11 03/31/2021 3:25:36 PM
#### Changed
- .gitignore to not git new images and entities
- g_AT_Options - added option for logo replacement
- changes references to g_AT_Options to local options in WaitForModConfig
- function OnMsg.LoadGame() in Init file to change all AT rocket logos
- WaitForModConfig - set new variable

#### Added
- Tour Company logo files and entities - decal
- rocket.AT_oldDecal to variables in rocket
- function ATreplaceRocketLogo(rocket, reset, resetAll, applyAll)

--------------------------------------------------------
## v1.10.0 03/29/2021 2:50:13 AM
#### Changed
- OnMsg.RocketReachedEarth(rocket) now cleares all the variables for departures
- all instances of AT_departures uses #boarded instead to stay in sync with original source
- function Colonist:LeavingMars(rocket)
 - added a check to the lower variables run in the pushdestructor code - just in case
- xtemplate to use new toggle function
- g_ATLoaded to g_At_modEnabled, moved it to Init file as well
- function DroneControl:OnSelected() - better logic if mod enabled
- function WaitForModConfig() - functions and messages in WaitForModConfig for enable disable mod

#### Added
- local ATcolonistGenTraits table
- function ATejectColonists(rocket)
- function RocketExpedition:Takeoff() - rewrite
- function SupplyRocket:ATtoggleAutoExport()  - new function used in panels
 - uses a delay to prevent takeoff if colonists are walking to a rocket, has a timer
- g_AT_modEnabled to all re-written class functions
- g_AT_RocketCheckComplete to let processes know this is done
- function OnMsg.CityStart() to init file for setup of init variables
- functions and messages in WaitForModConfig for enable disable mod
- function ATWarnATrocketsEnabled(num_rockets) for Mod config warning

#### Removed
- unused variables

#### Fixed Issues
- ejecting colonists from expedition and trade rockets
- fix rocket takeoff when colonists are en route to board on first nominated tourism rocket.

--------------------------------------------------------
## v1.9.1 03/28/2021 3:19:03 PM
#### Changed
- function ATStartDepartureThreads()
 - made global and moved to Init file
 - added Trade and ForeignTrade rocket checks
- function ATStopDepartureThreads(rocket)
 - made global and moved to Init file
- Mod Config Reborn entry for ATpreventDepart
 - added start/stop departure threads.
 - added Trade and ForeignTrade rocket checks
- function RocketBase:OnDemolish()
 - added kill of departure thread to prevent memory leaks
- function RocketBase:StartDepartureThread()
 - only start on supply rockets.

#### Added
- class check to function ATStopDepartureThreads(rocket)

#### Removed
- function ATunloadResources(rocket) - function was not used and remmed out for a while

#### Fixed Issues
- loading a save with an AT rocket running and other rockets still have departure threads
- cycling MCR option for enabling tourists to use any rocket would need to wait for a new rocket since threasds where not running.

#### Open Issues

#### Deprecated

#### Todo
- something with colonists boarded on rockets you send on expeditions.

--------------------------------------------------------
## v1.9.0 03/26/2021 9:22:14 PM
#### Changed
- Moved templates from ipBuilding[1] to customSupplyRocket[1] so I could rearrange button
- ATcheckDist(bld1, bld2)  only needed to return one parameter.
- OnMsg.RocketLaunched(rocket)  added:
  - added rocket:StopDepartureThread() -- just in case fix to make sure thread is dead.
  - shrunk the sleep thread time for faster catch
  - added parameters to rocket:GenerateDepartures(true, true)
- function ATcalcTourismDollars() added celebrityFunds

- function SupplyRocket:GenerateDepartures(count_earthsick, count_tourists)
  - added various Tito variables and code

- function Colonist:LeavingMars(rocket)
 - new tourist applicants are generated by the ratings system in HolidayRating:RewardApplicants(rating, tourist)

- function Colonist:LeavingMars(rocket)
 - fixed some missing items and variables
 - removed code to generate new applicants

- AT Panels moved from ipBuilding to customSupplyRocket
 - fix button position
 - stop and start departure threads with button

- adjusted function ATcalcTouristsInRange(rocket) to count from 1-5 and then 6+
- adjusted text in function ATtouristInRangeText(rocket) to reflect 1-5 and 6+

- change status icons to new tourist icon
- various cosmetic things and better notes

#### Added
- function SupplyRocket:UIOpenTouristOverview(...) -- rewrite to fix
- function SupplyRocket:OnModifiableValueChanged(prop, old_val, new_val)
  - fucking devs forgot to add this to the new code.  assholes

- function SupplyRocket:UIOpenTouristOverview(...)
 - fix for broken code released by said assholes

- function Colonist:LeavingMars(rocket)
 - added some new stuff from tito for Overstaying colonists

- function RocketBase:StartDepartureThread() re-write
 - needed to intercept this to return it to old behaviour prior to tito for tourism rockets

- function RocketBase:ClearDepartures(arrive_on_earth)  - re-write to intercept
 - code to consider AT rockets

- function ATStopDepartureThreads(rocket)
- function ATStartDepartureThreads()

- added celebrityFunds to ATcalcTourismDollars()
- added check in infopanel for can_fly_colonists
- added new icon for tourists in infopanels

#### Fixed Issues
- button off screen
- fix for broken source code from devs on Tourist Overview screen
- fixed no departing tourist issue when AT is running

#### Deprecated
- new tourist applicants are generated by the ratings system in HolidayRating:RewardApplicants(rating, tourist)

#### Open Issues
- fix payment system

#### Todo


--------------------------------------------------------

## v1.8.4 03/17/2021 2:34:46 PM

#### Removed
- removed all code for colonist suicides since devs put out hotfix for Tito 3/17/2021

--------------------------------------------------------
## v1.8.3 03/15/2021 9:29:44 PM
#### Changed
- replaced the following classes with RocketBase
local Old_SupplyRocket_IsRocketLanded = SupplyRocket.IsRocketLanded
function SupplyRocket:IsRocketOnMars()
function SupplyRocket:OnDemolish()

#### Added
- Colonist:LogStatClear(log, ...)
- function Colonist:AddToLog
- local function LogCheck
- new variables to function SupplyRocket:GenerateDepartures(count_earthsick, count_tourists)

#### Removed

#### Fixed Issues
- Suicidal tourists due to log issue with logstatclear
- Tito patch code changes
- nil check in function SupplyRocket:GenerateDepartures(count_earthsick, count_tourists) line 634

#### Open Issues

#### Deprecated

#### Todo

--------------------------------------------------------
## v1.8.2 09/21/2020 2:01:58 PM
#### Changed
- AT_2Panels.lua line 50 test for nil first before execute line 50

#### Fixed Issues
- Getting error when demolishing rocket that is not a tourism rocket, error line 50 nil compare


--------------------------------------------------------
## v1.8.1 01/25/2020 2:38:25 PM
#### Changed
- ModConfig option description for recall radius
- OnMsg.RocketLanded(rocket) added code for AT_RecallRadiusMode

#### Added
- Code in OnMsg.RocketLanded(rocket) to check for radius mode first then mod config global option

#### Removed

#### Fixed Issues
- Landed rockets not respecting setting for tourism boundary radius circle

#### Open Issues

#### Deprecated

#### Todo

--------------------------------------------------------
## v1.8.0 08/07/2019 10:02:35 PM
#### Changed
- upticking AT_departed at colonist entry point
- changed some syntax on mod cbonfig option for recall radius
- Rolloverhint to allow for toggle of recall radius show/no show
- added xTemplateFunc to template to toggle individual recall boundaries
- added new variable AT_RecallRadiusMode

#### Fixed Issues
- departures should uptick since you can toggle AT and have the boarded get zeroed.

--------------------------------------------------------
## v1.7.0 07/06/2019 1:11:23 AM
#### Changed
- OnMsg.RocketLaunchFromEarth(rocket)
  - added variables for food per tourist
- ATControlVer = "v1.14"
- changed nil order of ATsetupVariables(rocket, init) to remove threads first

#### Added
- g_AT_Options.ATfoodPerTourist
- mod config options for ATfoodPerTourist
- added check for AT_enabled to new vars in OnContextUpdate to prevent adding vars to non AT rockets

--------------------------------------------------------
## v1.6.2 07/05/2019 9:44:33 PM
#### Changed
- local ResolvePos = function(bld1, bld2)
  - was missing reference to invalid_pos

#### Fixed Issues
- ResolvePos was missing reference to InvalidPos()

--------------------------------------------------------
## v1.6.1 06/26/2019 2:12:29 AM
#### Changed
- function ATtoggleTouristBoundary(rocket, state)
  - using new tourist boundary radius
- SupplyRocket:GenerateDepartures()
  - changed IsInWalkingDistance for new custom function ATcheckDist
- added options to ToggleLFPrint
- function ATcalcTouristsInRange(rocket)

#### Added
- local lf_printdistance for debugging distance prints
- g_AT_Options.ATmax_walk_dist     = 2,
- local ResolvePos = function(bld1, bld2)  direct copy from dome.lua
- function ATcheckDist(bld1, bld2, distance)  a custom replacement for IsInWalkingDistance's Checkdist
-   function SupplyRocket:IsRocketOnMars() -- not used for now but keeping it.
- local max_walk_dist = g_AT_Options.ATmax_walk_dist * const.ColonistMaxDomeWalkDist



#### Removed

#### Fixed Issues

#### Open Issues

#### Deprecated

#### Todo

--------------------------------------------------------
## v1.6.0 06/22/2019 2:03:47 AM
#### Changed
- ticked up the template number
- renumbered StringIdBase numbers

#### Added
- New statistics in rollovertext
- function ATtouristInRangeText(rocket)
- function ATcalcTouristsInRange(rocket)

--------------------------------------------------------
## v1.5.0 06/20/2019 6:21:15 PM
#### Changed
- calculations of departures no longer use rocket.departure table for rocket.AT_departure
- rocket.AT_departure now calculated on RocketLaunched()
- OnMsg.RocketReachedEarth(rocket)
- Colonist:LeavingMars(rocket) now checks for rocket to avoid errors when abandoning colonists on mars.
- Updated XTemplat verion
- Added check in OnContextUpdated for nil new variables
- various StringIdBase changes


#### Added
- full rewrite of function Colonist:LeavingMars(rocket)
- full rewrite of function SupplyRocket:GenerateDepartures()
- print debug - lf_printcolonist
- rocket.AT_leaving_colonists    = 0      -- var holds the colonists wanting to leave
- rocket.AT_boarded_colonists    = 0      -- var holds the colonists that boarded
- changed wait delay to 1 second when checking for GenerateDepartures()
- added sleep pause after check for GenerateDepartures runs to allow leaving colonists to register
- added Boarding Tourists Section idATboardingSection to template
- added code to flash warning when almost departed
- added new status warnflash
- added new status disembark

#### Removed

#### Fixed Issues
- still inaccurate departures.  grabbing #departures too soon.  Now using calculated colonists.

#### Open Issues

#### Deprecated

#### Todo

--------------------------------------------------------
## v1.4.2 06/19/2019 10:30:33 PM
#### Changed
- RocketLanded()
- AT_last_arrival_time moved a bit later in RocketLanded()

#### Added
- Check for passengers on arrival.  Delay depaturetime calc so we get unified colonist mars time.
- var init and nil for AT_GenDepartRan

#### Fixed Issues
- Colonist departures somewhat skewed since departure time was too early.

--------------------------------------------------------
## v1.4.1 06/18/2019 7:25:43 PM
#### Changed
- OnMsg.RocketLanded(rocket)
  - using new code to wait for GenerateDepartures
  - using new calc code for voyages
- OnMsg.RocketLaunchFromEarth(rocket)
  - using new calc code for voyages
- thread uses local variable now

#### Added
- function OnMsg.ToggleLFPrint(modname)
- added wait code and var for GenerateDepartures in onrocketlanded
- added rocket names to lf prints

#### Fixed Issues
- calculating number of departures was incorrect if colonists boarded too fast.
- fixed calculations for next voyage time in rocket landed and rocket leaving earth when using mod config options
- altered ATcalcDepartureTime(rocket) to use proper calculations.

--------------------------------------------------------
## v 1.4.0 06/05/2019 12:11:50 AM

#### Added
- function DroneControl:OnSelected()
  - when a tourist rocket is selected highlight all the tourists colony wide

--------------------------------------------------------
## v1.3.0 05/29/2019 7:47:56 PM
#### Changed
- OnMsg.LoadGame()
  - added code to calc g_AT_NumOfTouristRockets
- function ATsetupVariables(rocket, init)
  - added g_AT_NumOfTouristRockets = g_AT_NumOfTouristRockets + 1 (and the reverse when false)

#### Added
- ATpreventDepart = true to g_AT_Options
- g_AT_NumOfTouristRockets to keep track of rockets
- function ATcountATrockets()
  - counts the number of AT rockets in game
- re-write for function SupplyRocket:GenerateDepartures()
- new mod config option ATpreventDepart

#### Removed

#### Fixed Issues
- colonists leaving on other rockets other than AT rockets

--------------------------------------------------------
## v1.2.0 05/28/2019 1:46:26 AM
#### Changed
- OnMsg.RocketLaunchFromEarth(rocket) - strip specializations
- ATsetupVariables(rocket, init)  - leave departures.
- changed function function ATfindReferences(objStartPt, objType, tId)
  - now uses ATfindReferences() inistead of indexes
- new control version v1.7

#### Added
- code to strip applicants of specializations
- added modconfig options for ATstripSpecialty
- added function ATfindReferences(objStartPt, objType, tId)
  - searches for corresponding obj in templates instead of assuming index

#### Fixed Issues
- tourist colonists were arriving with specialities throwing off specialist counts.

--------------------------------------------------------
## v1.1.2 05/22/2019 11:00:14 PM
#### Changed
- SupplyRocket:OnDemolish() - removed call to function ATsetButtonStatus since we are in the process of demolishing, this has already been done.

#### Fixed Issues
- Rockets were not demolishing

--------------------------------------------------------
## v1.1.1 05/20/2019 4:26:25 AM
#### Changed

#### Added
- Added SupplyPod to clas lookup to fix legacy games.

#### Fixed Issues
- legacy saves use SupplyPod and where still undemolishable.

--------------------------------------------------------
## v1.1 05/19/2019 3:25:39 PM
#### Changed
- OnMsg.RocketLanded(rocket) - added ReturnStockpiledResources
- changed template to return stockpiled stuuf on toggle.
- Template version to v1.5

#### Added
- ReturnStockpiledResources() to departure code to make sure we can launch.
- local function ATfixupSaves()

#### Fixed Issues
- rockets waiting to unload resources

--------------------------------------------------------
## v1.0.1 05/18/2019 4:03:22 AM
#### Changed
- SupplyRocket:OnDemolish() added check for class type
- Added class types of ArkPod and DropPod instead of SupplyPod
- made ATsetupVariables() and ATsetButtonStatus() global
- Control verion is 1.4

#### Fixed Issues
- AT showing up in supply pods and supply pods where not able to be demolished.

--------------------------------------------------------
## v1.0 Release 05/09/2019 8:32:43 PM
#### Changed
- Added condition to button and section to check what type of rocket it is.
- Bad var ATMaxTourists was mispelled
#### Fixed Issues
- tourism button and section showing up on trade and expedition rockets.
- Max colonists not being used due to spelling mistake in modconfig options

--------------------------------------------------------
## v0.10 05/09/2019 12:50:03 AM
#### Changed
- various places for flashing status
- AT_thread to AT_depatures_thread

#### Added
- ATflashStatus(rocket, status1, status2, enable)
- checkdepart status
- check to see if we left anyone behind (on rocket launch)
- AT_status_thread

--------------------------------------------------------
## v0.09 05/08/2019 3:32:27 AM
#### Changed
- ATGetDateTime(currentTime, futureTime) to ATConvertDateTime(currentTime)
  - also tweaked early arrivals and sleep times

#### Added
- Boarding departures status
- Departing tourists status

#### Removed

#### Fixed Issues
- bad convertion of date and time from gametime.  Needed to account for Sol 1 Hour 06:00

#### Open Issues

#### Deprecated

#### Todo
- Add tourist location to Command Center

--------------------------------------------------------
## v0.08 05/07/2019 4:46:45 AM
#### Changed
- Moved rewritten classes to ClassesGenerate()
- Streamlined SupplyRocket.OnDemolish
- ATsetupVariables(rocket, init)
  - now full nil
  - aded missing vars and fixed mispelled vars
- updated control ver to 1.1
- took ATsetupVariables(rocket, true) out of oncontextupdate and moved to onpress

#### Added
- rewrite of GetRocketExpeditionStatus(rocket)
- rewrite of SupplyRocket:IsRocketLanded()
- Early departures vars and mod config to allow for rockets to leave early if voyages exist
  - ATearlyDepartures
- created OnMsg.ClassesGenerate() section
- added control var to idATSection (rocket.AT_next_voyage_time)

#### Removed

#### Fixed Issues
- can select a tourist rocket in expedition view - changed to disabled
- init vars in ATsetupVariables(rocket, init) incorrect, fixed

#### Open Issues

#### Deprecated

#### Todo

--------------------------------------------------------
## v0.07 05/06/2019 8:44:19 PM
#### Changed
- global variables now in table

#### Added
- mod config options
- change dismiss time

--------------------------------------------------------
## v0.06 05/06/2019 2:03:27 AM

#### Added
- Added on screen notificaction for landed, leaving earth, and leaving mars

#### Todo
- Mod config Options
  - show/no show tourist range
  - notice dismiss time
  - notices
  - max tourist

--------------------------------------------------------
## v0.05 05/05/2019 6:57:21 PM

#### Added
- ATcalcTourismDollars()
- added total tourism funding

#### Todo
- on screen notifications

--------------------------------------------------------
## v0.04 05/04/2019 9:52:28 PM

#### Added
- local function ATsetupVariables(rocket, init)
- local Old_SupplyRocket_OnDemolish = SupplyRocket.OnDemolish
- Finished ip status section

#### Todo

- on screen notifications

--------------------------------------------------------
## v0.03 05/04/2019 5:03:27 PM
#### Changed
- disable all buttons except priority

#### Added
- function ATsetButtonStatus(ref, state) to AT_2Panels
- function ATtoggleTouristBoundary(rocket, state)

#### Todo
- clear stat variables
- ip status section
- status hint for amount of tourists waiting
- on screen notifications
- icon for status section

--------------------------------------------------------
## v0.2 05/04/2019 3:45:23 AM

#### Added
- automated departure mechanism complete
- automated calculations for departures

#### Todo
- clear stat variables
- ip status section
- circle radius for landing
- sign for rocket
- status hint for amount of tourists waiting
- on screen notifications

--------------------------------------------------------
## v0.1 05/01/2019 1:45:02 AM

- Initial Commit

--------------------------------------------------------
