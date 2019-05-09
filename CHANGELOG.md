# Automated Tourism
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
