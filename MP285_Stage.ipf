#pragma rtGlobals=1		// Use modern global access method.
#pragma version= 1.0		// modification date Sep 11 2009 by Jamie Boyd
#pragma IgorVersion=6.1
#include "Stages"

// MP285 requires the VDT2 XOP

// Works with the Sutter Instrument MP-285 Micromanipulator System 
// Because stage encoders can be mounted in various configurations, going more negative along the X-axis, e.g., may not always
// correspond to going left as viewed through the microscope. And the Z-encoder may be mounted on left or right side, which could change polarity.
// Therefore, we need some constants for the various directions for use with left/right, forward/back, and up/down buttons on the control panel :
// Flip the constants between 1 and -1 to change the polarity
STATIC CONSTANT kMP285xPol = -1
STATIC CONSTANT kMP285yPol = 1
STATIC CONSTANT kMP285zPol = -1
// Step sizes for XY and Z movement (resolution in meters per microstep)
STATIC CONSTANT kMP285XYstepSize = 1e-07
STATIC CONSTANT kMP285ZstepSize = 1e-08


//*********************************************************************************************
//********* Utilties to convert floating point values to/from the 4 byte  two's complement used by the MP-285***************
//*********************************************************************************************

// Convert 4 bytes, least significant to highest, using 2's complement, to a standard floating point value
// also converts from microsteps (10 steps/micron) to metres
// Last modified July 02 by Jamie Boyd 
Function From4b2cToFlt (b0, b1, b2, b3, stepSize)
	variable b0, b1, b2, b3, stepSize
	
	variable/D theVal= b0 + (b1*256)+ (b2*65536) + (b3* 16777216)
	if ((b3&128) != 0) // negative number, use 2's complement
		variable/D the2CVal
		variable iBit
		for (the2CVal =0, iBit = 0; iBit < 32; iBit += 1)
			//is bit set?
			if ((theVal & 2^iBit) == 0) // the bit is not set
				the2CVal += 2^iBit
			endif	
		endfor
		theVal = -(the2CVal + 1)
	endif
	// convert to meters
	return theVal * stepSize
end

//*********************************************************************************************
// converts a standard floating point value  to four bytes, using 2's complement notation
// Also converts from meters to microSteps (10 steps/micron)
Function FromFltTo2c4B (theVal, b0, b1, b2, b3, stepSize)
	variable theVal, &b0, &b1, &b2, &b3, stepSize
	
	variable isNeg =0
	if (theVal < 0)
		isNeg =1
	endif
	// convert to steps
	theVal = round (theVal/stepSize)
	if (theVal < 0) // convert to 2's complement
		variable the2CVal, iBit
		theVal *= -1
		for (the2CVal =0, iBit = 0; iBit < 32; iBit += 1)
			//is bit set?
			if ((theVal & 2^iBit) == 0) // the bit is not set
				the2CVal += 2^iBit
			endif	
		endfor
		theVal = the2CVal + 1
	endif
	// Set bytes
	b0 =  mod (theVal, 256)
	b1= mod (floor (theVal/256), 256 )
	b2 =  mod (floor (theVal/65536), 256)
	b3 =  mod (floor (theVal/16777216), 256)
end

//*******************************************************************************
// Make/Set global variables
// these are created by Stage_MakeGlobals and we could just NVAR them, but one may want to use MP285 procedure
// independent of Stages procedure, so it doesn't hurt to make them again
Function StageInitGlobals_MP285 ()

	if (!(datafolderExists ("root:packages:")))
		newDataFolder root:packages:
	endif 
	if (!(datafolderExists ("root:packages:MP285:")))
		newdatafolder root:packages:MP285
	endif
	// string for port name - will be set by user from popmenu which calls StageSetUpPort_MP285
	string/G root:packages:MP285:thePort
	// MP285 has 3 all 3 axes
	variable/G root:packages:MP285:hasXY = 1
	variable/G root:packages:MP285:hasZ = 1
	// No axial positioning
	variable/G  root:packages:MP285:hasAx = 0
	// Is motorized
	variable/G root:packages:MP285:hasMotor = 1
	// No PID settings, but might someday put in code for setting acceleration, max speed, etc
	variable/G root:packages:MP285:hasPID=0
	// Serial device, not USB
	variable/G root:packages:MP285:isUSB = 0
	// variables for distances from 0 and increments
	variable/G  root:packages:MP285:xStepSize =10e-06
	variable/G  root:packages:MP285:yStepSize= 10e-06
	variable/G  root:packages:MP285:xDistanceFromHome
	variable/G  root:packages:MP285:yDistanceFromHome
	variable/G  root:packages:MP285:xPol = kMP285xPol
	variable/G  root:packages:MP285:yPol = kMP285yPol
	variable/G  root:packages:MP285:zStepSize= 1e-06
	variable/G  root:packages:MP285:zDistanceFromHome
	variable/G  root:packages:MP285:zPol = kMP285zPol
	// variable for abort, for procedures with wait
	variable/G root:packages:MP285:doAbort = 0
end

//*******************************************************************************
// add to the stage control panel things specific to MP285
// Adds a reset button and a stop button
Function StageAddControls_MP285 (hOffset, vOffset, thePanel)
	variable hOffset, vOffset
	string thePanel

	//add a reset button to the control panel, if it exists
	if (cmpstr (thePanel, stringfromlist (0, winlist (thePanel, ";", "WIN:65"), ";")) == 0) 
		button StopButton, win =$thePanel, pos = {hOffset + 100, vOffset}, size = {40,20}
		button StopButton ,win = $thePanel,  title="Stop", proc=StageStop_MP285ButtonProc
		button ResetButton ,win =$thePanel, pos = {hOffset, vOffset}, size = {95,20}
		button ResetButton ,win = $thePanel,  title="Reset MP285", proc=StageReset_MP285ButtonProc
		// Make control panel a progress window 
		DoUpdate /W=$thePanel /E=1
	endif
end

//*********************************************************************************************
// Opens the serial port for use with MP285 and  gets some initial values
Function StageSetUpPort_MP285 (thePortName)
	string thePortName
	
	// Configure port, open it, and select it for command operations
	VDT2/P = $PossiblyQuoteName (thePortName) baud=9600, stopbits=1, databits=8, parity=0, in=0, out=0, buffer=4096
	VDTOpenPort2 $PossiblyQuoteName (thePortName)
	VDTOperationsPort2 $PossiblyQuoteName (thePortName)
	//Clear buffer
	vdt2 /P =$possiblyquotename(thePortName) killio
	// Do an initial update
	variable xS, yS, zS, AxS
	StageUpDate_MP285 (xS, yS, zS, AxS)
end

//*********************************************************************************************
// Reset I/O function for MP285, clears any pending serial commands
Function StageResetIO_MP285 ()
	
	NVAR isBusyG = root:packages:Stages:isBusy
	NVAR isBusy = root:packages:MP285:isBusy
	SVAR thePortName = root:packages:MP285:thePort
	vdt2/P =$possiblyquotename (thePortName) killio
	isBusy = 0
	isBusyG =0
	return 0
end

//*********************************************************************************************
// Port closing function for MP285, tells VDT2 to close the serial port
Function StageClose_MP285 ()

	SVAR thePortName = root:packages:MP285:thePort
	VDTGetPortList2
	if (findListItem (thePortName, S_VDT, ";") > -1)
		VDTClosePort2 $PossiblyQuoteName (thePortName)
	endif
	NVAR isBusy = root:packages:MP285:isBusy
	isBusy = 0
	return 0
end

//*********************************************************************************************
// Stage update function for MP-285
Function StageUpDate_MP285 (xS, yS, zS, AxS)
	variable &xS, &yS, &zS, &AxS
	
	// Globals
	NVAR isBusyG = root:packages:Stages:isBusy // VDT2 operations port is busy with another task
	NVAR isBusy = root:packages:MP285:isBusy // MP285 is busy processing a command
//	if (isBusyG)
//		return 1
//	endif
//	// update status of business variables
//	isBusyG =1
	isBusy = 1;doupdate
	NVAR LastX = root:packages:MP285:xDistanceFromHome
	NVAR LastY = root:packages:MP285:yDistanceFromHome
	NVAR hasZ = root:packages:MP285:hasZ 
	NVAR LastZ = root:packages:MP285:zDistanceFromHome
	//  Select MP285 port for command line operations
	SVAR thePortName = root:packages:MP285:thePort
	VDTOperationsPort2 $PossiblyQuoteName (thePortName)
	// value is returned in 4 bytes
	variable b0, b1, b2, b3
	// write "c\R' to get values dumped to buffer
	VDTWrite2  /O=1 "c\r"
	// read X values
	VDTReadBinary2/Q/O=1 /TYPE=72 b0, b1, b2,b3
	xS =  From4b2cToFlt (b0, b1, b2, b3,kMP285XYstepSize)
	LastX = xS
	// read Y values
	VDTReadBinary2/Q/O=1 /TYPE=72 b0, b1, b2, b3
	yS =  From4b2cToFlt (b0, b1, b2, b3,kMP285XYstepSize)
	LastY = yS
	// get Z axis
	VDTReadBinary2/Q/O=1 /TYPE=72 b0, b1, b2, b3
	zS =  From4b2cToFlt (b0, b1, b2, b3,kMP285ZstepSize)
	Lastz = zS
	// Read  in the carriage return byte to clear the buffer
	VDTReadBinary2/Q/O=1 /TYPE=72 b0
	//	printf "The X axis is at %.2W1Pm.\r", xS
	//	printf "The Y axis is at %.2W1Pm.\r", yS
	//	printf "The Z axis is at %.2W1Pm.\r", ZS
	isBusyG = 0
	isBusy = 0
	return 0
end

//***********************************************************************************	
// function to turn ON/Off bkg task that periodically updates axes values
Function StageSetAuto_MP285 (turnOn)
	variable turnOn
	
	if (turnOn)
		CtrlNamedBackground MP285BkgUpdate proc= MP285_BkgUpdate, period=15, burst=0, START
	else
		CtrlNamedBackground MP285BkgUpdate, STOP
	endif
end

//***********************************************************************************	
// BackGround function that periodically updates axes values
Function MP285_BkgUpdate (bks)
	STRUCT  WMBackgroundStruct&bks
	
	// Globals
	NVAR isBusy = root:packages:MP285:isBusy
	if (isBusy) 
		return 0
	else
		variable xS, yS, zS, AxS
		StageUpDate_MP285 (xS, yS, zS, AxS)
		return 0
	endif
end

//***********************************************************************************	
// Stage move function for MP-285
Function StageMove_MP285 (isRelative, returnNow, xS, yS, zS, AxS,  [xVal, yVal, zVal, AxVal])
	variable isRelative  //  0 if requesting movement to an absolute position. 1 or 2 (to also set new increment)  if requesting positive movement relative to current location,
	//  -1 or -2 (to also set new increment) for negative increment. MP-285 doesn't storeincrement on the machine, so ignore the setting new increment part
	variable returnNow //0 to wait until movement is finished to return, 1 to return immediately, 2 to return immediately but set a background task to monitor position til it gets where it should be
	variable  &xS, &yS,&zS, &AxS // variables that will hold the retreived absolute positions
	variable xVal, yVal, zVal, AxVal // variables for requested position. You can use one, two, or three at a time
	
	// Globals
//	NVAR isBusyG = root:packages:Stages:isBusy
	NVAR isBusy = root:packages:MP285:isBusy
	if (isBusy)
		return 1
	endif
	isBusy=1;doupdate
	NVAR LastX = root:packages:MP285:xDistanceFromHome
	NVAR LastY = root:packages:MP285:yDistanceFromHome
	NVAR LastZ = root:packages:MP285:zDistanceFromHome
	//  Select MP285 port for command line operations
	SVAR thePortName = root:packages:MP285:thePort
	VDTOperationsPort2 $PossiblyQuoteName (thePortName)
	// the four bytes for each axis
	variable b0x, b1x, b2x,b3x, b0y, b1y, b2y,b3y, b0z, b1z, b2z, b3z
	if (isRelative != 0) //  then requesting a movement relative to current position, need to translate to absolute values
		if (isRelative > 0) 
			xVal = paramisdefault (xVal) ? LastX : LastX + xVal
			yVal = paramisDefault (yVal) ? LastY :  LastY  + yVal
			zVal = ParamIsDefault (zVal) ? LastZ : LastZ + zVal
		else
			xVal = paramisdefault (xVal) ? LastX : LastX - xVal
			yVal = paramisDefault (yVal) ? LastY : LastY - yVal
			zVal = ParamIsDefault (zVal) ? LastZ : LastZ - zVal
		endif
	else // requesting absolute position
		xVal = paramisdefault (xVal) ? LastX : xVal
		yVal = paramisDefault (yVal) ? LastY : yVal
		zVal = ParamIsDefault (zVal) ? LastZ : zVal
	endif
	// Translate floating point values to 4 byte 
	FromFltTo2c4B (xVal, b0x, b1x, b2x, b3x,kMP285XYstepSize)
	FromFltTo2c4B (yVal, b0y, b1y, b2y, b3y,kMP285XYstepSize)
	FromFltTo2c4B (zVal, b0z, b1z, b2z, b3z,kMP285ZstepSize)
	// Request the new values, starting with "m", ASCII 190, and ending with "return" ASCII 13
	VDTWriteBinary2/O=1/TYPE=72 109, b0x, b1x, b2x, b3x, b0y, b1y, b2y, b3y, b0z, b1z, b2z, b3z,13
	// Read  in the carriage return byte to clear the buffer
	VDTReadBinary2/Q/O=1 /TYPE=72 b0x
	// return now or wait till movement is finished?
	variable AxisBIts = (!(paramisDefault (xVal))) + 2*(!(paramisDefault (yVal))) + 4*(!(paramisDefault (zVal)))
	NVAR doABort = root:packages:MP285:doAbort 
	switch (returnNow)
		case 0: // return after movement is finished. Wait till stage is no longer busy by continually requesting status
			doAbort = 0
			variable err = 5e-7 // acceptable error for positioning, 0.5 microns
			variable toDo
			do
				if (doAbort)
					// send contol character, ASCII 3, and  "return" ASCII 13
					VDTWriteBinary2/TYPE=72 /O=1 3, 13
					// read back carriage return to clear buffer
					variable b0
					VDTReadBinary2/Q/O=1 /TYPE=72 b0
					doAbort = 0
					isBusy = 0
					return 1
					break
				endif
				toDo = AxisBits
				StageUpDate_MP285 (xS, yS, zS, AxS)
				if (AxisBIts & 1)
					if ((xS + err > xVal) && (xS - err < xVal)) 
						toDo -= 1
					endif
				endif
				if (AxisBIts & 2)
					if ((yS + err > yVal) && (yS - err < yVal)) 
						toDo -= 2
					endif
				endif
				if (AxisBIts & 4)
					if ((zS + err > zVal) && (zS - err < zVal)) 
						toDo -= 4
					endif
				endif
			while (toDo) 
			isBusy = 0
			break
		case 1:// return now - return values assuming we get where we are asked to go
			LastX = xVal
			xS = xVal
			lastY = yVal
			yS = yVal
			lastZ = zVal
			zS = zVal
			isBusy = 0
			break
		case 2: // return now with background task
			// Start background task collecting data. make global for what is moving
			// Make globals for positions
			variable/G root:packages:MP285:reqAxis = AxisBIts
			if (AxisBits & 1)
				Variable/G root:packages:MP285:reqX = xVal
			endif
			if (AxisBits & 2)
				Variable/G root:packages:MP285:reqY = yVal
			endif
			if (AxisBits & 4)
				Variable/G root:packages:MP285:reqz = zVal
			endif
			CtrlNamedBackground MP285BkgScan proc= MP285_BkgScan, period=15, burst=0, START
//			isBusyG=0 // Set global serial is busy to 0, but Leave MP285 isBusy set high
			break
	endswitch
	return 0
end

//***********************************************************************************	
// BackGround function that checks periodically to see if position has been attained
Function MP285_BkgScan (bks)
	STRUCT  WMBackgroundStruct&bks
	
	NVAR doAbort= root:packages:MP285:doAbort
	NVAR isBusy = root:packages:MP285:isBusy // will be moving if this task is called
	if (doAbort ==1)
		// call code to stop motors
		// send contol character, ASCII 3, and  "return" ASCII 13
		VDTWriteBinary2/TYPE=72 /O=1 3, 13
		// read back carriage return to clear buffer
		variable b0
		VDTReadBinary2/Q/O=1 /TYPE=72 b0
		doAbort = 0
		isBusy =0
		return 1
	endif
	// Get positions
	variable xS, yS, zS, AxS
	StageUpDate_MP285 (xS, yS, zS, AxS)
	// Check to see if we are at requested position
	NVAR AxisBIts = root:packages:MP285:reqAxis
	variable err = 5e-7 // acceptable error for positioning, 0.5 microns
	variable toDo  = AxisBits
	if (AxisBIts & 1)
		NVAR xVal = root:packages:MP285:reqX
		if ((xS + err > xVal) && (xS - err < xVal)) 
			toDo -= 1
		endif
	endif
	if (AxisBIts & 2)
		NVAR yVal = root:packages:MP285:reqY
		if ((yS + err > yVal) && (yS - err < yVal)) 
			toDo -= 2
		endif
	endif
	if (AxisBIts & 4)
		NVAR zVal = root:packages:MP285:reqZ
		if ((zS + err > zVal) && (zS - err < zVal)) 
			toDo -= 4
		endif
	endif
	// Are we still moving?
	if (toDo)
		return 0 // so bkg task is continued
	else // no longer busy. return 1 stop stop BGK task
		isBusy =0 // MP285 is no longer moving
		return 1
	endif
end



//*******************************************************************************
// Sets the current position to be home, i.e.distance from home =0
Function StageSetHome_MP285()
	
	NVAR isBusyG = root:packages:stages:isBusy
	NVAR isBusy = root:packages:stages:isBusy
	if (isBusy)
		return 0
	endif
	isBusy=1; doUpdate
	//isBusyG =1;doUpdate
	//  Select MP285 port for command line operations
	SVAR thePortName = root:packages:MP285:thePort
	VDTOperationsPort2 $PossiblyQuoteName (thePortName)
	// send "o", ASCII 111, and  "return" ASCII 13
	VDTWriteBinary2/O=1 /TYPE=72 111, 13
	// read back carriage return to clear buffer
	variable b0
	VDTReadBinary2/Q/O=1 /TYPE=72 b0
	// set absolute mode (a)
	VDTWriteBinary2/O=1/TYPE=72 97, 13
	VDTReadBinary2/Q/O=1 /TYPE=72 b0
	// send screen update (n)
	VDTWriteBinary2/O=1/TYPE=72 110, 13
	VDTReadBinary2/Q/O=1 /TYPE=72 b0
	// Update positions
	variable xS, yS, zS, AxS
	StageUpDate_MP285 (xS, yS, zS, AxS)
	isBusyG=0
	isBusy = 0
	return 0
End

//*******************************************************************************
// button procedure resets MP285 and re-selects low-level command set
Function StageReset_MP285ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			NVAR isBusyG = root:packages:stages:isBusy
			NVAR isBusy = root:packages:stages:isBusy
			isBusy=1;doUpdate
			//isBusyG =1;doUpdate
			//  Select MP285 port for command line operations
			SVAR thePortName = root:packages:MP285:thePort
			VDTOperationsPort2 $PossiblyQuoteName (thePortName)
			// send "r", ASCII 114, and  "return" ASCII 13
			VDTWritebinary2/TYPE=72 /O=1 114, 13
			// read back carriage return to clear buffer
			variable b0
			VDTReadBinary2/Q/O=1 /TYPE=72 b0
			isBusyG =0
			isBusy = 0
			break
	endswitch
	return 0
End


Function StageStop_MP285ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			SVAR thePort = root:packages:MP285:thePort
			VDTOperationsPort2 $PossiblyQuoteName (thePort)
			// send contol character, ASCII 3, and  "return" ASCII 13
			VDTWriteBinary2/TYPE=72 /O=1 3, 13
			// read back carriage return to clear buffer
			variable b0
			VDTReadBinary2/Q/O=1 /TYPE=72 b0
			// stop background task
			CtrlNamedBackground MP285BkgScan STOP
			NVAR doAbort = root:packages:MP285:doAbort
			doAbort = 0
			NVAR isBusy = root:packages:MP285:isBusy
			isBusy = 0
			NVAR isBusyG = root:packages:Stages:isBusy
			isBusyG = 0
			break
	endswitch
	return 0
End