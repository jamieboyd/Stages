#pragma rtGlobals=1		// Use modern global access method.
#pragma version= 4.0		// modification date Dec 06 2010 by Jamie Boyd
#pragma IgorVersion=6.1  // Uses named background task
#include "Stages"

// Procedures for using an ASI positioning device through the USB port. Uses the Windows-only ASIUSBez XOP to interact with the
//  Windows-only library ASIUSB1.lib, so both these files need to be installed, plus the USB drivers for the MS-2000. See the help file
//  for the ASIUSBez XOP for details on installation. Do not use this procedure with the Mac OS X version of Igor.

// The MS-2000 can have a Z attached or not, and be used with the same controller. No sense controlling an axis that is not attached,
// so use this constant to tell if MS2000USB has Z motor/encoder attached.
STATIC CONSTANT kMS2000USBHasZ = 1
STATIC CONSTANT kMS2000USBHasXY = 1
// Because stage encoders can be mounted in various configurations, going more negative along the X-axis, e.g., may not always
// correspond to going left as viewed through the microscope. And the Z-encoder may be mounted on left or right side, which could change polarity.
// Therefore, we need some constants for the various directions, so the left button goes left, e.g., regardless of whether the numbers are increasing or decreasing
STATIC CONSTANT kMS2000USBxPol = -1
STATIC CONSTANT kMS2000USByPol = 1
STATIC CONSTANT kMS2000USBzPol = -1
// Flip the constants from 1 to -1 to change the polarity
//Note that on the back of the MS-2000 controller box, two DIP switches, 7 and 8, control the polarity of the Y and X axes respectively.
// Set the DIP switches correctly for use with the joystick first, then change the constants appropriately.

// variables for maximum and minimum distance from 0 for XY and Z, changes these as appropriate
STATIC CONSTANT kMS2000USBxyMIN = -50e-03
STATIC CONSTANT kMS2000USBxyMAX = 50e-03
STATIC CONSTANT kMS2000USBzMIN = -5e-03
STATIC CONSTANT kMS2000USBzMAX = 5e-03

// resolution (minimum step size) for XY and Z movements
CONSTANT  kMS2000USBXYstepSize = 1e-07
CONSTANT  kMS2000USBZstepSize = 1e-07

//*********************************************************************************************
// Stage functions for Applied Scientific's MS-2000 motorized stage encoders. Moves, sets increments, etc.
//*******************************************************************************
//*******************************************************************************
// Make/Set global variables
// these are created by Stage_MakeGlobals and we could just NVAR them, but one may want to use MS2000USB procedure
// independent of Stages procedure, so it doesn't hurt to make them again
Function StageInitGlobals_MS2000USB ()

	if (!(datafolderExists ("root:packages:")))
		newDataFolder root:packages:
	endif 
	if (!(datafolderExists ("root:packages:MS2000USB:")))
		newdatafolder root:packages:MS2000USB
	endif
	// string for port name - will be set by user from popmenu which calls StageSetUpPort_MS2000USB
	string/G root:packages:MS2000USB:thePort
	// Read XY- and  Z-capability from static contstant at top of file
	variable/G root:packages:MS2000USB:hasXY = 1
	variable/G root:packages:MS2000USB:hasZ = kMS2000USBhasZ
	// No axial positioning
	variable/G  root:packages:MS2000USB:hasAx = 0
	// Is motorized
	variable/G root:packages:MS2000USB:hasMotor = 1
	// has autoUpdate capability
	variable/G  root:packages:MS2000USB:hasAuto = 1
	variable/G  root:packages:MS2000USB:autoON
	// No PID settings
	variable/G root:packages:MS2000USB:hasPID=0
	// USB Device
	variable/G root:packages:MS2000USB:isUSB = 1
	// variables for distances from 0 and increments and polarity
	variable/G  root:packages:MS2000USB:xStepSize =(10 * kMS2000USBXYstepSize)
	variable/G  root:packages:MS2000USB:yStepSize= (10 * kMS2000USBXYstepSize)
	variable/G  root:packages:MS2000USB:xDistanceFromZero
	variable/G  root:packages:MS2000USB:yDistanceFromZero
	variable/G  root:packages:MS2000USB:xPol = kMS2000USBxPol
	variable/G  root:packages:MS2000USB:yPol = kMS2000USByPol
	variable/G  root:packages:MS2000USB:xyRes = kMS2000USBXYstepSize
	variable/G  root:packages:MS2000USB:xyMIN = kMS2000USBXYMIN
	variable/G  root:packages:MS2000USB:xyMAX = kMS2000USBXYMAX
	if (kMS2000USBhasZ)
		variable/G  root:packages:MS2000USB:zStepSize= (10 * kMS2000USBZstepSize)
		variable/G  root:packages:MS2000USB:zDistanceFromZero
		variable/G  root:packages:MS2000USB:zPol = kMS2000USBzPol
		variable/G  root:packages:MS2000USB:zRes = kMS2000USBZstepSize
		variable/G  root:packages:MS2000USB:zMIN = kMS2000USBZMIN
		variable/G  root:packages:MS2000USB:zMAX = kMS2000USBZMAX
	endif
	// variable for abort, for procedures with wait
	variable/G root:packages:MS2000USB:doAbort = 0
	// variable for business
	variable/G root:packages:MS2000USB:isBusy =0
end

//*******************************************************************************
// add to the stage control panel things specific to MS2000 when used with USB
// Adds a reset button
Function StageAddControls_MS2000USB (hOffset, vOffset, thePanel)
	variable hOffset, vOffset
	string thePanel

	//add a stop button to the control panel, if it exists
	if (cmpstr (thePanel, stringfromlist (0, winlist (thePanel, ";", "WIN:65"), ";")) == 0) 
		button StopButton, win =$thePanel, pos = {hOffset, vOffset}, size = {40,20}
		button StopButton ,win = $thePanel,  title="Stop", proc=StageStop_MS2000USBbuttonProc
		// add an Init ASI button
		button InitButton, win =$thePanel, pos = {hOffset + 42, vOffset}, size = {56,20}
		button InitButton ,win = $thePanel,  title="Re-Init ASI", proc=StageInit_MS2000USBbuttonProc
		// Make control panel a progress window 
		DoUpdate /W=$thePanel /E=1
	endif
end


//*********************************************************************************************
// Opens a USB connection with MS2000USB and  gets some initial values
Function StageSetUpPort_MS2000USB (thePortName)
	string thePortName
	
	variable devNum = str2num (theportName [0]) // First character is device number
	if (devnum == 0)
		doalert 0, "The chosen device was not found in the list of ASI devices."
		return 1
	endif
	// Open the device
	ASIUSBOpen(devNum)
	// Do an initial update
	variable xS, yS, zS, axS
	StageUpDate_MS2000USB (xS, yS, zS, axS)
end

//*********************************************************************************************
// Port closing function for MS2000 when used with USB
Function StageClose_MS2000USB (thePortName)
	string thePortName
	
	variable devNum = str2num (stringfromlist (0, thePortName, " "))
	ASIUSBClose(devNum)
end

//*********************************************************************************************
// Stage update function for MS2000 when used with USB
Function StageUpDate_MS2000USB (xS, yS, zS, axS)
	variable &xS, &yS, &zS, &axS
	
	// Globals
	NVAR isBusy = root:packages:MS2000USB:isBusy // MS2000 is busy processing a command
	if (isBusy)
		return 1
	endif
	// update status of business variables
	isBusy = 1;doupdate
	NVAR hasXY =  root:packages:MS2000USB:hasXY
	NVAR hasZ = root:packages:MS2000USB:hasZ 
	NVAR LastX = root:packages:MS2000USB:xDistanceFromZero
	NVAR LastY = root:packages:MS2000USB:yDistanceFromZero
	NVAR LastZ = root:packages:MS2000USB:zDistanceFromZero
	SVAR thePort = root:packages:MS2000USB:thePort
	variable devNum = str2num (stringfromlist (0, thePort, " "))
	if (hasZ)
		ASIUSBGetXYZ(devNum, xS, yS, zS)
	else
		ASIUSBGetXY(devNum, xS, yS)
	endif
	lastX = xS
	lastY = yS
	if (hasZ)
		LastZ = zS
	else
		zS = LastZ
	endif
//	printf "The X axis is at %.2W1Pm.\r", xS
//	printf "The Y axis is at %.2W1Pm.\r", yS
//	printf "The Z axis is at %.2W1Pm.\r", ZS
	isBusy = 0
	return 0
end

//***********************************************************************************	
// function to turn ON/Off bkg task that periodically updates axes values
Function StageSetAuto_MS2000USB (turnOn)
	variable turnOn
	
	if (turnOn)
		CtrlNamedBackground MS2000USBUpdate proc= MS2000USB_BkgUpdate, period=30, burst=0, START
	else
		CtrlNamedBackground MS2000USBUpdate, STOP
	endif
end

//***********************************************************************************	
// BackGround function that periodically updates axes values
Function MS2000USB_BkgUpdate (bks)
	STRUCT  WMBackgroundStruct&bks
	
	// Globals
	NVAR isBusy = root:packages:MS2000USB:isBusy
	if (isBusy)
		return 0
	else
		variable xS, yS, zS, AxS
		StageUpDate_MS2000USB (xS, yS, zS, AxS)
		return 0
	endif
end

//***********************************************************************************	
// Stage move function for Applied Scientific's MS-2000 stage encoders
// Procedure to move stage to New Location. 
// Last Modified Oct 14 2010 by Jamie Boyd
Function StageMove_MS2000USB(moveType, returnWhen, xS, yS, zS, aS)
	variable moveType  //  0 if requesting movement to an absolute position. 1  if requesting positive movement relative to current location,
						//  -1  for negative movement relative to current location
	variable returnWhen //0 to to return immediately , 1 to wait until movement is finished to return, 2 to monitor position with bkg task
	variable  &xS, &yS,&zS, &aS // variables that will hold the retreived absolute positions

	// Globals
	NVAR isBusy = root:packages:MS2000USB:isBusy
	if (isBusy)
		return 1
	endif
	isBusy=1;doupdate
	NVAR LastX = root:packages:MS2000USB:xDistanceFromZero
	NVAR LastY = root:packages:MS2000USB:yDistanceFromZero
	NVAR hasZ = root:packages:MS2000USB:hasZ
	SVAR thePort = root:packages:MS2000USB:thePort
	variable devNum = str2num (stringfromlist (0, thePort, " "))
	
	if ((moveType == kStagesIsRelPos) || (moveType == kStagesIsRelNeg))
		// requesting a movement relative to current location
		// do X
		if (numtype (xS) == 0)
			// use move step function
			NVAR polarityMult = root:packages:MS2000USB:xPol
			xS *= (polarityMult * moveType)
			if (returnWhen == kStagesReturnNow)
				LastX += xS
			endif
		else
			xS =0
		endif
		// doY
		if (numtype (yS) == 0)
			// use move step function
			NVAR polarityMult = root:packages:MS2000USB:yPol
			yS *= (polarityMult * moveType)
			if (returnWhen == kStagesReturnNow)
				LastY += yS
			endif
		else
			yS =0
		endif
		// do Z, and finally, move the stage
		if ((hasZ) && (numtype (zS) == 0))
			NVAR LastZ = root:packages:MS2000USB:zDistanceFromZero
			// use move step function
			NVAR polarityMult = root:packages:MS2000USB:zPol
			zS *= (polarityMult * moveType)
			if (returnWhen == kStagesReturnNow)
				LastZ +=zS
			endif
		else
			zS =0
		endif
		ASIUSBMovRelXYZ(devNum, xS, yS, zS)
	else // absolute movement
		// X
		if (numtype (xS) == 0)
			if (returnWhen == kStagesReturnNow)
				LastX = xS
			endif
		else
			xS = lastX
		endif
		// Y
		if (numtype (yS) == 0)
			if (returnWhen == kStagesReturnNow)
				LastY = yS
			endif
		else
			yS = lastY
		endif
		// Z
		if ((numtype (zS) == 0) && (hasZ))
			NVAR LastZ = root:packages:MS2000USB:zDistanceFromZero
			if (returnWhen == kStagesReturnNow)
				LastZ = zS
			endif
		else
			zS = lastZ
		endif
		ASIUSBMovAbsXYZ(devNum, xS, yS, zS)
	endif
	
	// return now or wait till movement is finished?
	switch (returnWhen)
		case kStagesReturnLater: // return after movement is finished
			// wait till stage is no longer busy by continually requesting status
			NVAR doABort = root:packages:MS2000USB:doAbort 
			do
			while ((ASIUSBIsBusy(devNum) ==66) && (!(doABort)))
			// set global values for position
			if (hasZ)
				ASIUSBGetXYZ(devNum, xS, yS, zS)
			else
				ASIUSBGetXY(devNum, xS, yS)
			endif
			lastX = xS
			lastY = yS
			if (hasZ)
				LastZ = zS
			else
				zS = LastZ
			endif
			isBusy = 0
			break
		case kStagesReturnNow:  // return now - return values assuming we get where we are asked to go
			isBusy = 0
			break
		case kStagesReturnBkg: // return now with background task
			NVAR doAbort = root:packages:MS2000USB:doAbort
			doAbort = 0
			// Start background task
			CtrlNamedBackground MS2000USBbkgScan proc= MS2000USB_BkgScan, period=15, burst=0, START
			isBusy = 0
			break
	endSwitch
	//	printf "The X axis is at %.2W1Pm.\r", xS
	//	printf "The Y axis is at %.2W1Pm.\r", yS
	//	printf "The Z axis is at %.2W1Pm.\r", ZS
	return 0
end

//***********************************************************************************	
// returns 1 if stage is finished moving, else 0
Function MS2000USB_BkgScan (bks)
	STRUCT  WMBackgroundStruct&bks
	
	// Are we still busy? Have we been aborted?
	NVAR doAbort = root:packages:MS2000USB:doAbort
	NVAR isBusy = root:packages:MS2000USB:isBusy
	SVAR thePort = root:packages:MS2000USB:thePort
	variable devNum = str2num (stringfromlist (0, thePort, " "))
	isBusy = 1
	if (doAbort)
		isBusy = 0
		return 1
	endif
	if (ASIUSBIsBusy(devNum)==66)
		return 0 // so bkg task is continued
	else // no longer busy.Do an update and return 1 to stop BGK task
		NVAR hasXY =  root:packages:MS2000USB:hasXY
		NVAR hasZ = root:packages:MS2000USB:hasZ 
		NVAR LastX = root:packages:MS2000USB:xDistanceFromZero
		NVAR LastY = root:packages:MS2000USB:yDistanceFromZero
		NVAR LastZ = root:packages:MS2000USB:zDistanceFromZero
		variable xS, yS, zS
		if (hasZ)
			ASIUSBGetXYZ(devNum, xS, yS, zS)
		else
			ASIUSBGetXY(devNum, xS, yS)
		endif
		lastX = xS
		lastY = yS
		if (hasZ)
			LastZ = zS
		else
			zS = LastZ
		endif
		CtrlNamedBackground MS2000USBbkgScan  STOP
		isBusy = 0
		return 1
	endif
end

//***********************************************************************************	
// Sets a fixed increment for moving MS200 stage encoder. Stores increments in globals as storing values in the stage encoder
// is not currently supported under USB
Function StageSetInc_MS2000USB ([xVal, yVal, zVal, axVal])
	variable xVal, yVal, zVal, axVal // variables for requested increment. You can set one, two, or three at a time
	
	// Globals
	NVAR hasZ = root:packages:MS2000USB:setsZ
	// X 
	if (!(ParamIsDefault(xVal)))
		NVAR xStepSize = root:packages:MS2000USB:xStepSize
		xStepSize = xVal
	endif
	// Y 
	if (!(ParamIsDefault(yVal)))
		NVAR yStepSize = root:packages:MS2000USB:yStepSize
		yStepSize = yVal
	endif
	// Z 
	if ((!(ParamIsDefault(zVal))) && (hasZ))
		NVAR zStepSize = root:packages:MS2000USB:zStepSize
		zStepSize = zVal
	endif
end

//*******************************************************************************
// Sets the current position to be zero
Function StageSetZero_MS2000USB()
	
	NVAR isBusy = root:packages:MS2000USB:isBusy
	if (isBusy)
		return 1
	endif
	isBusy = 1;doupdate
	SVAR thePort = root:packages:MS2000USB:thePort
	variable devNum = str2num (stringfromlist (0, thePort, " "))
	ASIUSBSetZero(devNum)
	NVAR hasXY =  root:packages:MS2000USB:hasXY
	NVAR hasZ = root:packages:MS2000USB:hasZ 
	NVAR LastX = root:packages:MS2000USB:xDistanceFromZero
	NVAR LastY = root:packages:MS2000USB:yDistanceFromZero
	NVAR LastZ = root:packages:MS2000USB:zDistanceFromZero
	variable xS, yS, zS
	if (hasZ)
		ASIUSBGetXYZ(devNum, xS, yS, zS)
	else
		ASIUSBGetXY(devNum, xS, yS)
	endif
	lastX = xS
	lastY = yS
	if (hasZ)
		LastZ = zS
	else
		zS = LastZ
	endif
	isBusy = 0;doupdate
End

//*******************************************************************************
Function StageStop_MS2000USBbuttonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			// Halt!
			SVAR thePort = root:packages:MS2000USB:thePort
			variable devNum = str2num (stringfromlist (0, thePort, " "))
			ASIUSBHalt(devNum)
			// stop background task, if it is going
			CtrlNamedBackground MS2000USBbkgScan STOP
			// we are not longer busy
			NVAR isBusy = root:packages:MS2000USB:isBusy
			isBusy = 0
		break
	endswitch
	return 0
End

//*******************************************************************************
Function StageInit_MS2000USBbuttonProc (ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
		// re-initialize ASIUSB devices
		ASIUSBInit()
		break
	endswitch
	return 0
End