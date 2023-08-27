#pragma rtGlobals=1		// Use modern global access method.
#pragma version= 1.0		// modification date Sep 29 2010 by Jamie Boyd
#pragma IgorVersion=6.1	// 6.1 because of  use of background task. Could switch to Igor 5.05 compatible background task management
#include "Stages"

//MS2000 requires the VDT2 XOP

// MS2000_Stage works with ASI controllers that can drive a motorized  XY-stage, a stand-alone motorized focus (MFC-2000), 
// or both XY and Z. Use these constant to indicate if your MS2000 controller has XY and/or Z motor/encoder attached.
STATIC CONSTANT kMS2000hasXY = 1
STATIC CONSTANT kMS2000hasZ = 1

// Because stage encoders can be mounted in various configurations, going more negative along the X-axis, e.g., may not always
// correspond to going left as viewed through the microscope. And the Z-encoder may be mounted on left or right side, which could change polarity.
// Therefore, we need some constants for the various directions for use with left/right, forward/back, and up/down buttons on the control panel :
STATIC CONSTANT kMS2000xPol = -1
STATIC CONSTANT kMS2000yPol = 1
STATIC CONSTANT kMS2000zPol = 1
// Flip the constants from 1 to -1 to change the polarity
//Note that on the back of the MS-2000 controller box, two DIP switches, 7 and 8, control the polarity of the Y and X axes respectively.
// Set the DIP switches correctly for use with the joystick first, then change the constants appropriately.

//  Constants for maximum values which user can request from distance from home setvars
STATIC CONSTANT kMS2000xyMIN = -5e-03
STATIC CONSTANT kMS2000xyMAX = 5e-03
STATIC CONSTANT kMS2000zMIN = -5e-04
STATIC CONSTANT kMS2000zMax = 5e-04

// constants for axis resolution (minimum step size)
CONSTANT  kMS2000XYstepSize = 1e-07
CONSTANT  kMS2000ZstepSize = 1e-07

//  Constant for doing autoupdating
STATIC CONSTANT  kMS2000doAuto = 1

// For most things, the low level command set is used (see below) . For things not provided in the low-level commandset,
// a quick switch is made to high level set and then back

// Information gleaned from MS2000 manual
//The serial RS-232 interface is used to hook up the MS-2000 and MFC-2000 to a PC with a
//protocol that imitates the Ludl Low Level command set. The purpose of the low level protocol is
//to provide a simple interface between a PC program and the MS-2000 and the MFC-2000,
//without ASCII conversion. The high level protocol is designed to allow direct human interface
//capability by displaying all numbers and commands in ASCII characters. The high level format
//is slow due to the extended transmission of ASCII characters as well as the time consumed
//converting back and forth from 3 byte memory stored numbers and multiple byte ASCII
//character numbers stored in strings. The low level format deals strictly with numbers that
//identify modules, commands, data_size, and data represented in 1 to 6 bytes in 2's compliment
//form.

// Special 2 byte control commands (no need for terninator character)
// 255 65 Switch to High Level Command Format
// 255 66 Switch to Low Level Command Format
// 255 82 Reset Controller

//NOTE: These commands apply to MS-2000 Controller firmware version 3.2 and forward.
//The low level format is formed by the following 8 bit bytes:
//BYTE1: Axis Identification
//X Axis:		24
//Y Axis:		25
//Z Axis		26

//BYTE2: Command
//BYTE3: Number of data bytes to be exchanged for this command
//BYTES 4 thru 9: Data Bytes, mostly in 2's compliment form in the order of: Least Significant
//Byte, Middle Byte, Most Significant Byte
//LAST BYTE: The ASCII colon character (: = dec 58) flags the end of the serial command

// Commmand:			Code:	DataSize:	Returns:
// Read Status			63		0			66 (B) if axis is busy, else 98 (b) if not busy
// Read Motor Position	97		3			current stage position in two's compliment form using 3 bytes in tenths of microns
// Read Motor Position	108		3			3 bytes  of stage position (see command 97) plus 1 byte status code (see command 126)
// 	and Status
// Read Status Byte		126		1			one byte, which can be broken down into 8 bits that represent the following internal flags:
//											Bit 0: 0 = No Motor Signal, 1 = Motor Signal (i.e., axis is moving)
//											Bit 1: Always 1, as servos cannot be turned off
//											Bit 2: 0 = Pulses Off, 1 = Pulses On
//											Bit 3: 0 = Joystick/Knob disabled, 1 = Joystick/Knob enabled
//											Bit 4: 0 = motor not ramping, 1 = motor ramping
//											Bit 5: 0 = ramping up, 1= ramping down
//											Bit 6: Upper limit switch: 0 = open, 1 = closed
//											Bit 7: Lower limit switch: 0 = open, 1 = closed
// Start / Enable Motor		71		0			Nothing returned. Used to turn on / start / enable the motor for an axis								
//Joystick Enable			74		0			// Nothing returned
//Joystick Disable			75		0			// Nothing returned
// Move to target position	84		3			// Nothing returned  example Command: 24 84 03 160 134 01 58
// Increment Move Up		43		0			// nothing returned example command: 24 43 0 58
// Increment Move Down	45		0			// nothing returned example command: 24 45 0 58
// Write Increment Value	68		3			// nothing returned. example command: 24 68 03 160 134 01 58
// Read Increment Value	100		3			//current increment setting. 3 byte two's compliment number in tenths of a micron. Example command: 24 100 03 58

STATIC CONSTANT kMS2000debug = 0 // prints info to history for debugging

//*********************************************************************************************
// Convert 3 bytes, least significant to highest, using 2's complement, to a standard floating point
// Also converts from tenths of a micron microsteps to meters
// Last modified Sep 28 2010 by Jamie Boyd
Function From3b2cToFlt (b0, b1, b2)
	variable b0, b1, b2
	
	variable theVal= b0 + (b1*256)+ (b2*65536)
	if (b2&128) // negative number, use 2's complement
		return -(2^24 - theVal)/1e07
	else
		return theVal/1e07
	endif
end

//*********************************************************************************************
// converts a standard floating point number to three bytes, using 2's complement notation
// Also converts from meters to tenths of a micron microsteps
// Last Modified Sep 28 2010 by Jamie Boyd
Function FromFltTo3b2c (theVal, b0, b1, b2)
	variable theVal, &b0, &b1, &b2
	
	// convert to tenths of micron
	theVal = round (theVal * 1e07)
	if (theVal < 0) // convert to 2's complement
		theVal = 2^24 + theVal
	endif
	// Set bytes
	b0 =  mod (theVal, 256)
	b1= mod (floor (theVal/256), 256 )
	b2 =  mod (floor (theVal/65536), 256)
end

//*********************************************************************************************
// Stage functions for Applied Scientific's MS-2000 motorized stage encoders. Moves, sets increments, etc.
//*******************************************************************************

//*******************************************************************************
// Make/Set global variables
// these are created by Stage_MakeGlobals and we could just NVAR them, but one may want to use MS2000 procedure
// independent of Stages procedure, so it doesn't hurt to make them again
// Last Modified Sep 28 by Jamie Boyd
Function StageInitGlobals_MS2000 ()

	if (!(datafolderExists ("root:packages:")))
		newDataFolder root:packages:
	endif 
	if (!(datafolderExists ("root:packages:MS2000:")))
		newdatafolder root:packages:MS2000
	endif
	// string for port name - will be set by user from popmenu which calls StageSetUpPort_MS2000
	string/G root:packages:MS2000:thePort
	// Read XY- and  Z-capability from static contstant at top of file
	variable/G root:packages:MS2000:hasXY = kMS2000hasXY
	variable/G root:packages:MS2000:hasZ = kMS2000hasZ
	// No axial positioning
	variable/G  root:packages:MS2000:hasAx = 0
	// Is motorized, and has manual lock
	variable/G root:packages:MS2000:hasMotor = 1
	variable/G root:packages:MS2000:hasLock = 1
	variable/G root:packages:MS2000:isLocked=0
	// amenable to auto-updating
	variable/G root:packages:MS2000:hasAuto =1
	variable/G root:packages:MS2000:autoON
	// Panel for PID stuff
	variable/G root:packages:MS2000:hasPID=1
	// Serial device, not USB
	variable/G root:packages:MS2000:isUSB = 0
	// variables for distances from 0 and increments
	if (kMS2000hasXY)
		variable/G  root:packages:MS2000:xStepSize =10e-06
		variable/G  root:packages:MS2000:yStepSize= 10e-06
		variable/G  root:packages:MS2000:xDistanceFromZero
		variable/G  root:packages:MS2000:yDistanceFromZero
		variable/G  root:packages:MS2000:xPol = kMS2000xPol
		variable/G  root:packages:MS2000:yPol = kMS2000yPol
		variable/G root:packages:MS2000:xyMin = kMS2000xyMIN
		variable/G root:packages:MS2000:xyMax = kMS2000xyMAX
		variable/G root:packages:MS2000:xyRes = kMS2000XYstepSize
	endif
	if (kMS2000hasZ)
		variable/G  root:packages:MS2000:zStepSize= 1e-06
		variable/G  root:packages:MS2000:zDistanceFromZero
		variable/G  root:packages:MS2000:zPol = kMS2000zPol
		variable/G root:packages:MS2000:zMIN = kMS2000zMIN
		variable/G root:packages:MS2000:zMax = kMS2000zMAX
		variable/G root:packages:MS2000:zRes = kMS2000ZstepSize
	endif
	// variable for status
	variable/G root:packages:MS2000:isBusy
end

//*******************************************************************************
// add to the stage control panel things specific to MS2000
// Adds a reset button and a stop button
// Last Modified Sep 29 2010 by Jamie Boyd
Function StageAddControls_MS2000 (hOffset, vOffset, thePanel)
	variable hOffset, vOffset
	string thePanel

	//add a reset button and a stop button to the control panel
	if (cmpstr (thePanel, stringfromlist (0, winlist (thePanel, ";", "WIN:65"), ";")) == 0) 
		Button ResetButton,win =$thePanel, pos={hOffset,vOffset},size={40,20},proc=StageReset_MS2000ButtonProc,title="Reset"
		Button ResetButton,win =$thePanel, help={"Resets the MS-2000. Equivalent to pressing the reset button on the encoder box."}
		Button StopButton,win =$thePanel, pos={hOffset + 43, vOffset},size={40,20},proc=StageStop_MS2000ButtonProc,title="Stop"
		Button StopButton,win =$thePanel, help={"Immediately halts movement on all axes."}
	endif
end

//*********************************************************************************************
// Opens the serial port for use with MS2000
// Last Modified Sep 28 2010 by Jamie Boyd
Function StageSetUpPort_MS2000 (thePortName)
	string thePortName
	
	// Configure port, open it, and select it for command operations
	VDT2/P = $PossiblyQuoteName (thePortName) baud=19200, stopbits=1, databits=8, parity=0, in=0, out=0, buffer=4096
	VDTOpenPort2 $PossiblyQuoteName (thePortName)
	VDTOperationsPort2 $PossiblyQuoteName (thePortName)
	//Clear buffer and switch to low level commandset
	StageResetIO_MS2000 ()
	VDTWriteBinary2/TYPE=72 /O=1 255, 66
	// Set increment values to those loaded from global variables
	NVAR xStepSize = root:packages:MS2000:xStepSize
	NVAR yStepSize = root:packages:MS2000:yStepSize
	NVAR hasZ = root:packages:MS2000:hasZ
	if (hasZ)
		NVAR zStepSize = root:packages:MS2000:zStepSize
		StageSetInc_MS2000 (xVal=xStepSize, yval=yStepSize, zVal=zStepSize)
	else
		StageSetInc_MS2000 (xVal=xStepSize, yval=yStepSize)
	endif	
end

//*********************************************************************************************
// Reset I/O function for MS2000, clears any pending commands
Function StageResetIO_MS2000 ()
	
	CtrlNamedBackground MS2000BkgAutoUpdate, STOP
	CtrlNamedBackground MS2000BkgScan, STOP
	NVAR isBusy = root:packages:MS2000:isBusy
	isBusy =1;doUpdate
	SVAR thePortName = root:packages:MS2000:thePort
	vdt2/P =$possiblyquotename (thePortName) killio
	isBusy = 0
	return 0
end

//*********************************************************************************************
// Port closing function for MS2000, tells VDT2 to close the serial port
Function StageClose_MS2000 ()
	
	CtrlNamedBackground MS2000BkgAutoUpdate, STOP
	CtrlNamedBackground MS2000BkgScan, STOP
	SVAR thePortName = root:packages:MS2000:thePort
	VDTGetPortList2
	if (findListItem (thePortName, S_VDT, ";") > -1)
		VDTClosePort2 $PossiblyQuoteName (thePortName)
	endif
	return 0
end

//*******************************************************************************
// button procedure resets MS2000 and re-selects low-level command set
Function StageReset_MS2000ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			NVAR isBusy = root:packages:stages:isBusy
			isBusy=1;doUpdate
			StageResetIO_MS2000 ()
			// reset MS-2000
			VDTWritebinary2/TYPE=72 /O=1 255, 82 // reset MS-2000
			VDTWriteBinary2/TYPE=72 /O=1 255, 66 // select low-level command-set
			SVAR thePort = root:packages:MS2000:thePort
			StageSetUpPort_MS2000 (thePort)
			isBusy = 0
			break
	endswitch
	return 0
End

//*******************************************************************************
// Stop button procedure
Function StageStop_MS2000ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			// switch to high-level format - doesn't appear to be a way to do this with low-level commandset
			SVAR thePort = root:packages:MS2000:thePort
			VDTOperationsPort2 $PossiblyQuoteName (thePort)
			VDTWriteBinary2/TYPE=72 /O=1 255, 65
			VDTWrite2  /O=1 "Halt\r"
			string readStr
			vdtread2/o=1/T= "\n\r" readStr // read result, which we ignore
			//Clear buffer and stop background tasks
			StageResetIO_MS2000 ()
			// switch back to low-level command set
			VDTWriteBinary2/TYPE=72 /O=1 255, 66
			NVAR isBusy = root:packages:stages:isBusy
			isBusy = 0
		break
	endswitch
	return 0
End

//*********************************************************************************************
// Stage update function for Applied Scientific's MS-2000 stage encoders
// Last Modified Sep 29 2010 by Jamie Boyd
Function StageUpDate_MS2000 (xS, yS, zS, aS)
	variable &xS, &yS, &zS, &aS
	
	// Globals
	NVAR isBusy = root:packages:MS2000:isBusy // MS2000 is busy processing a command
	if (isBusy)
		return 0
	endif
	// update status of business variables
	isBusy = 1
	// value is returned in 3 bytes
	variable b0, b1, b2
	// get X axis
	NVAR hasXY = root:packages:MS2000:hasXY
	if ((hasXY) && (numtype (xS) ==0))
		VDTWriteBinary2 /TYPE=72 /O=1  24, 97, 03, 58
		VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2
		xS =  From3b2cToFlt (b0, b1, b2)
		NVAR LastX = root:packages:MS2000:xDistanceFromZero
		LastX = xS
	endif
	// get Y axis
	if ((hasXY) && (numType (yS) ==0))
		VDTWriteBinary2 /TYPE=72 /O=1  25, 97, 03, 58
		VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2
		yS =  From3b2cToFlt (b0, b1, b2)
		NVAR LastY = root:packages:MS2000:yDistanceFromZero	
		lastY = yS
	endif
	// get Z axis
	NVAR hasZ = root:packages:MS2000:hasZ 
	if ((hasZ) && (numtype (zS) ==0))
		VDTWriteBinary2 /TYPE=72 /O=1  26, 97, 03, 58
		VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2
		NVAR LastZ = root:packages:MS2000:zDistanceFromZero
		zS = From3b2cToFlt (b0, b1, b2)
		LastZ = zS
	endif
	if (kMS2000debug)
		if (hasXY)
			printf "The X axis is at %.2W1Pm.\r", xS
			printf "The Y axis is at %.2W1Pm.\r", yS
		endif
		if (hasZ)
			printf "The Z axis is at %.2W1Pm.\r", ZS
		endif
	endif
	isBusy = 0
	return 0
end

//***********************************************************************************	
// function to turn ON/Off bkg task that periodically updates axes values
Function StageSetAuto_MS2000 (turnOn)
	variable turnOn
	
	if (turnOn)
		CtrlNamedBackground MS2000BkgAutoUpdate proc= MS2000_BkgAutoUpdate, period=15, burst=0, START
	else
		CtrlNamedBackground MS2000BkgAutoUpdate, STOP
	endif
end

//***********************************************************************************	
// BackGround function that periodically updates axes values
Function MS2000_BkgAutoUpdate (bks)
	STRUCT  WMBackgroundStruct&bks
	
	variable xS, yS, zS, aS
	StageUpDate_MS2000 (xS, yS, zS, aS)
	return 0
end

//***********************************************************************************	
// Sets a fixed increment for moving MS200 stage encoder. Value is stored in the stage encoder. 
// Last Modified Sep 29 2010 by Jamie Boyd
Function StageSetInc_MS2000 ([xVal, yVal, zVal, AxVal])
	variable xVal, yVal, zVal, AxVal // variables for requested increment. You can set one, two, or three at a time
	
	NVAR isBusy = root:packages:MS2000:isBusy // MS2000 is busy processing a command
	if (isBusy)
		return 0
	endif
	// update status of business variables
	isBusy = 1;doupdate
	variable b0, b1, b2
	// do X?
	NVAR hasXY = root:packages:MS2000:hasXY
	if ((!(ParamIsDefault(xVal))) && hasXY)
		FromFltTo3b2c (xVal, b0, b1, b2)
		VDTWriteBinary2 /TYPE=72 /O=1  24, 68, 03, b0, b1, b2, 58
		if (kMS2000debug)
			//Read back Increment Value
			VDTWriteBinary2 /TYPE=72 /O=1  24, 100, 3, b0, b1, b2, 58
			printf "The X-axis increment value is %.2W1Pm.\r", From3b2cToFlt (b0, b1, b2)
		endif
	endif
	// Y 
	if ((!(ParamIsDefault(yVal))) && hasXY)
		FromFltTo3b2c (yVal, b0, b1, b2)
		VDTWriteBinary2 /TYPE=72 /O=1  25, 68, 03, b0, b1, b2, 58
		if (kMS2000debug)
			//Read back Increment Value
			VDTWriteBinary2 /TYPE=72 /O=1  25, 100, 3, b0, b1, b2, 58
			printf "The Y-axis increment value is %.2W1Pm.\r", From3b2cToFlt (b0, b1, b2)
		endif
	endif
	// Z 
	NVAR hasZ = root:packages:MS2000:hasZ 
	if ((!(ParamIsDefault(zVal))) && hasZ)
		FromFltTo3b2c (zVal, b0, b1, b2)
		VDTWriteBinary2 /TYPE=72 /O=1  26, 68, 03, b0, b1, b2, 58
		if (kMS2000debug)
			//Read back Increment Value
			VDTWriteBinary2 /TYPE=72 /O=1  26, 100, 3, b0, b1, b2, 58
			printf "The Z-axis increment value is %.2W1Pm.\r", From3b2cToFlt (b0, b1, b2)
		endif
	endif
	isBusy =0
end


//***********************************************************************************	
// Stage move function for Applied Scientific's MS-2000 stage encoders
// Last Modified Sep 29 2010 by Jamie Boyd
Function StageMove_MS2000 (moveType, returnWhen, xS, yS, zS, aS)
	variable moveType  //  0 if requesting movement to an absolute position. 1  if requesting positive movement relative to current location,
						//  -1  for negative movement relative to current location
	variable returnWhen //0 to to return immediately , 1 to wait until movement is finished to return, 2 to monitor position with bkg task
	variable  &xS, &yS,&zS, &aS // variables that will hold the retreived absolute positions
	
	// Globals
	NVAR isBusy = root:packages:MS2000:isBusy
	if (isBusy)
		return 1
	endif
	isBusy=1;doupdate
	// bitwise variable for which axes to do in a loop, or a background tassk
	variable/G root:packages:MS2000:axisBits
	NVAR axisBits = root:packages:MS2000:axisBits
	axisBits = 0
	// current position of each axis
	NVAR hasXY = root:packages:MS2000:hasXY
	if (hasXY)
		NVAR LastX = root:packages:MS2000:xDistanceFromzero
		NVAR LastY = root:packages:MS2000:yDistanceFromzero
	endif
	NVAR hasZ = root:packages:MS2000:hasZ
	if (hasZ)
		NVAR LastZ = root:packages:MS2000:zDistanceFromzero
	endif
	// the three bytes to read/writre and a statrus byte
	variable  b0, b1, b2, bStatus
	// do each axis in turn
	// X
	if ((hasXY) && (numtype (xS) ==0))
		axisBits += 1
		if ((moveType == kStagesIsRelPos) || (moveType == kStagesIsRelNeg))
			// requesting a movement relative to current location
			// use move step function, but first check step size and set increment if needed
			NVAR xStepSize = root:packages:MS2000:xStepSize
			if (xS != xStepSize)
				StageSetInc_MS2000 (xVal=xS)
			endif
			// Up increment or down increment?
			NVAR polarityMult = root:packages:MS2000:xPol
			xS *= (polarityMult * moveType)
			if (xS > 0) // move up 1 increment
				VDTWriteBinary2 /TYPE=72 /O=1 24, 43, 0, 58
			else // move down one increment
				VDTWriteBinary2 /TYPE=72 /O=1 24, 45, 0, 58
			endif
			// if returning now, assume we got there
			if (returnWhen == kStagesReturnNow)
				LastX += xS
			endif
		else // moving to an absolute location
			FromFltTo3b2c (xS, b0, b1, b2)
			VDTWriteBinary2 /TYPE=72 /O=1  24, 84, 03, b0, b1, b2, 58
			// if returning now, assume we got there
			if (returnWhen == kStagesReturnNow)
				LastX  = xS
			endif
		endif
	endif
	// Y
	if ((hasXY) && (numtype (yS) ==0))
		axisBits += 2
		if ((moveType == kStagesIsRelPos) || (moveType == kStagesIsRelNeg))
			// requesting a movement relative to current location
			// use move step function, but first check step size and set increment if needed
			NVAR yStepSize = root:packages:MS2000:yStepSize
			if (yS != yStepSize)
				StageSetInc_MS2000 (yVal=yS)
			endif
			// Up increment or down increment?
			NVAR polarityMult = root:packages:MS2000:yPol
			yS *= (polarityMult * moveType)
			if (yS > 0) // move up 1 increment
				VDTWriteBinary2 /TYPE=72 /O=1 25, 43, 0, 58
			else // move down one increment
				VDTWriteBinary2 /TYPE=72 /O=1 25, 45, 0, 58
			endif
			// if returning now, assume we got there
			if (returnWhen == kStagesReturnNow)
				LastY += yS
			endif
		else // moving to an absolute location
			FromFltTo3b2c (yS, b0, b1, b2)
			VDTWriteBinary2 /TYPE=72 /O=1 25, 84, 03, b0, b1, b2, 58
			// if returning now, assume we got there
			if (returnWhen == kStagesReturnNow)
				LastY  = yS
			endif
		endif
	endif
	// Z
	if ((hasZ) && (numtype (zS) ==0))
		axisBits += 4
		if ((moveType == kStagesIsRelPos) || (moveType == kStagesIsRelNeg))
			// requesting a movement relative to current location
			// use move step function, but first check step size and set increment if needed
			NVAR zStepSize = root:packages:MS2000:zStepSize
			if (zS != zStepSize)
				StageSetInc_MS2000 (zVal=zS)
			endif
			// Up increment or down increment?
			NVAR polarityMult = root:packages:MS2000:zPol
			zS *= (polarityMult * moveType)
			if (zS > 0) // move up 1 increment
				VDTWriteBinary2 /TYPE=72 /O=1 26, 43, 0, 58
			else // move down one increment
				VDTWriteBinary2 /TYPE=72 /O=1 26, 45, 0, 58
			endif
			// if returning now, assume we got there
			if (returnWhen == kStagesReturnNow)
				LastZ += zS
			endif
		else // moving to an absolute location
			FromFltTo3b2c (zS, b0, b1, b2)
			VDTWriteBinary2 /TYPE=72 /O=1 26, 84, 03, b0, b1, b2, 58
			// if returning now, assume we got there
			if (returnWhen == kStagesReturnNow)
				LastZ  = zS
			endif
		endif
	endif
	isBusy = 0
	// either set a background task or a loop to get stage coordinates
	if ((returnWhen == kStagesReturnLater) || (returnWhen == kStagesReturnBkg))
		isBusy = 1
		// set up background task or loop
		if (returnWhen == kStagesReturnBkg)
			CtrlNamedBackground MS2000BkgScan proc= MS2000_BkgScanToPos, period=15, burst=0, START
		elseif (returnWhen ==kStagesReturnLater)
			do
				if (axisBits&1) // X axis requested
					VDTWriteBinary2 24, 63, 0, 58
					VDTReadBinary2/O=1 /TYPE=72 bStatus
					if ((bStatus) == 98) // b for not Busy
						axisBits -= 1
					endif
				endif
				if (axisBits&2) // y axis requested
					VDTWriteBinary2 25, 63, 0, 58
					VDTReadBinary2/O=1 /TYPE=72 bStatus
					if ((bStatus) == 98) // b for not Busy
						axisBits -= 2
					endif
				endif
				if (axisBits&4) // z axis requested
					VDTWriteBinary2 26, 63, 0, 58
					VDTReadBinary2/O=1 /TYPE=72 bStatus
					if ((bStatus) == 98) // b for not Busy
						axisBits -= 4
					endif
				endif
			while (axisBits > 0)
			// Get axes positions
			if (hasXY)
				VDTWriteBinary2 /TYPE=72 /O=1  24, 97, 03, 58
				VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2
				LastX =  From3b2cToFlt (b0, b1, b2)
				VDTWriteBinary2 /TYPE=72 /O=1  25, 97, 03, 58
				VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2
				LastY =  From3b2cToFlt (b0, b1, b2)
			endif
			if (hasZ)
				NVAR LastZ = root:packages:MS2000:ZDistanceFromZero
				VDTWriteBinary2 /TYPE=72 /O=1  26, 97, 03, 58
				VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2
				LastZ =  From3b2cToFlt (b0, b1, b2)
			endif
			isBusy = 0
		endif
	endif
	return 0
end

//***********************************************************************************	
// BackGround function that checks periodically to see if axes are still in motion
Function MS2000_BkgScanToPos(bks)
	STRUCT  WMBackgroundStruct&bks
	
	NVAR axisBits =  root:packages:MS2000:AxisBIts
	//  Select MS2000 port for command line operations
	SVAR thePortName = root:packages:MS2000:thePort
	VDTOperationsPort2 $PossiblyQuoteName (thePortName)
	// bytes for position and status
	variable b0, b1, b2, bStatus
	if (axisBits&1) // X axis requested
		VDTWriteBinary2 24, 63, 0, 58
		VDTReadBinary2/O=1 /TYPE=72 bStatus
		if ((bStatus) == 98) // b for not Busy
			axisBits -= 1
		endif
	endif
	if (axisBits&2) // y axis requested
		VDTWriteBinary2 25, 63, 0, 58
		VDTReadBinary2/O=1 /TYPE=72 bStatus
		if ((bStatus) == 98) // b for not Busy
			axisBits -= 2
		endif
	endif
	if (axisBits&4) // z axis requested
		VDTWriteBinary2 26, 63, 0, 58
		VDTReadBinary2/O=1 /TYPE=72 bStatus
		if ((bStatus) == 98) // b for not Busy
			axisBits -= 4
		endif
	endif
	// Are we still moving?
	if (axisBits > 0)
		return 0 // so bkg task is continued
	else // no longer busy. get axes positions and return 1 stop stop BGK task
		NVAR hasXY = root:packages:MS2000:hasXY
		if (hasXY)
			NVAR LastX = root:packages:MS2000:xDistanceFromZero
			VDTWriteBinary2 /TYPE=72 /O=1  24, 97, 03, 58
			VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2
			LastX =  From3b2cToFlt (b0, b1, b2)
			NVAR Lasty = root:packages:MS2000:YDistanceFromZero
			VDTWriteBinary2 /TYPE=72 /O=1  25, 97, 03, 58
			VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2
			LastY =  From3b2cToFlt (b0, b1, b2)
		endif
		NVAR hasZ = root:packages:MS2000:hasZ
		if (hasZ)
			NVAR LastZ = root:packages:MS2000:ZDistanceFromZero
			VDTWriteBinary2 /TYPE=72 /O=1  26, 97, 03, 58
			VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2
			LastZ =  From3b2cToFlt (b0, b1, b2)
		endif
		NVAR isBusy = root:packages:MS2000:isBusy // will be moving if this task is called
		isBusy =0 // MS2000 is no longer moving
		return 1
	endif
end

//***********************************************************************************
// returns 1 if stage is busy, else 0. Also refreshes global values on position
function StageisBusy_MS2000 ()
	
	NVAR LastX = root:packages:MS2000:xDistanceFromZero
	NVAR LastY = root:packages:MS2000:yDistanceFromZero
	NVAR hasZ = root:packages:MS2000:hasZ 
	NVAR LastZ = root:packages:MS2000:zDistanceFromZero
	//  Select MS2000 port for command line operations
	SVAR thePortName = root:packages:MS2000:thePort
	VDTOperationsPort2 $PossiblyQuoteName (thePortName)
	variable busy =0, b0, b1, b2, bStatus
	VDTWriteBinary2 24, 108, 03, 58
	VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2, bStatus
	 LastX = From3b2cToFlt (b0, b1, b2)
	busy += (bStatus&1)
	VDTWriteBinary2 25, 108, 03, 58
	VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2, bStatus
	LastX = From3b2cToFlt (b0, b1, b2)
	busy += (bStatus&1)
	if (hasZ)
		VDTWriteBinary2 26, 108, 03, 58
		VDTReadBinary2/O=1 /TYPE=72 b0, b1, b2, bStatus
		LastZ = From3b2cToFlt (b0, b1, b2)
		busy += (bStatus&1)
	endif
	return (busy > 0)
end

//*******************************************************************************
// Sets the current position to be home, i.e.distance from home =0
Function StageSetZero_MS2000()
	
	NVAR isBusy = root:packages:stages:isBusy
	isBusy=1
	//  Select MS2000 port for command line operations
	SVAR thePortName = root:packages:MS2000:thePort
	VDTOperationsPort2 $PossiblyQuoteName (thePortName)
	// switch to high-level format - doesn't appear to be a way to do this with low-level commandset
	VDTWriteBinary2/TYPE=72 /O=1 255, 65
	VDTWrite2  /O=1 "zero\r"
	string readStr
	vdtread2/o=1/T= "\n\r" readStr // read result, which we ignore
	//Clear buffer and switch to low-level command set
	SVAR thePort = root:packages:MS2000:thePort
	vdt2 /P =$possiblyquotename (thePort) killio
	VDTWriteBinary2/TYPE=72 /O=1 255, 66
	// Update positions
	variable xS, yS, zS, aS=NaN
	StageUpDate_MS2000 (xS, yS, zS, aS)
	isBusy = 0
End

//*******************************************************************************
// Enables or disables manual movement of stage
Function StageSetManual_MS2000 (manualLock)
	variable manualLock // 1 to lock, 0 to unlock
	
	NVAR isBusy = root:packages:stages:isBusy
	isBusy=1;doUpdate
	NVAR hasZ = root:packages:MS2000:hasZ
	variable disableBit
	if (manualLock == 1)
		disablebit = 75
	else
		disableBit =74
	endif 
	//  Select MS2000 port for command line operations
	SVAR thePortName = root:packages:MS2000:thePort
	VDTOperationsPort2 $PossiblyQuoteName (thePortName)
	VDTWritebinary2/TYPE=72 /O=1 24, disablebit, 58
	VDTWritebinary2/TYPE=72 /O=1 25, disablebit, 58
	if (hasZ)
		VDTWritebinary2/TYPE=72 /O=1 26, disablebit, 58
	endif
	isBusy = 0
end


Function testINFO ()
	SVAR thePortName = root:packages:MS2000:thePort
	VDTOperationsPort2 $PossiblyQuoteName (thePortName)
	SVAR thePortName = root:packages:MS2000:thePort
	vdt2/P =$possiblyquotename (thePortName) killio
	// switch to high-level format - doesn't appear to be a way to do this with low-level commandset
	VDTWriteBinary2/TYPE=72 /O=1 255, 65
	VDTWrite2  /O=1 "I X\r"
	string readStr, infoStr = ""
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	VDTWrite2  /O=1 "I Y\r"
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	
	VDTWrite2  /O=1 "I Z\r"
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	vdtread2/o=1 readStr
	print readStr
	// switch back to high level
	VDTWriteBinary2/TYPE=72 /O=1 255, 66
end

•testINFO ()
  


  Axis Name    :  X                Limits Status:  
  Input Device :      JS_X [J]       In_Dev Sign  :         1
  Max Lim      :    99.742 [SU]    Min Lim      :  -120.258 [SL] 
  Ramp Time    :        96 (ms)[AC]Max Ramp Stps:        16      
  Run Speed    :   1.11488(mm/s)[S]vmax_enc     :       331      
  Servo Lp Time:         6 (ms)    Ramp Length  :      4800 (enc)
  dv_enc       :        20         LL Axis ID   :        24
  Drift Error  :  0.000500 (mm)[E] enc_drift_err:        24   
  Finish Error :  0.000022 (mm)[PC}enc_finsh_err:         1      
  Backlash     :  0.000000 (mm)[B] enc_backlash :         0   
  Kp           :       100 [KP]    Ki           :        20 [KI]
  Kv           :        26 [KV]    Kd           :         0 [KD]
  Axis Enable  :         3 [MC]    Motor Enable :         0   
  CMD_stat     :   NO_MOVE           Move_stat    :      IDLE
  Current pos  :   -0.0399 (mm)    enc position :     -1979
  Target pos   :   -0.0400 (mm)    enc target   :     -1980
  enc pos error:         3         EEsum        :         0
  Lst Stle Time:       108 (ms)    Av Settle Tim:        90 (ms) 
  Home position:    989.51 (mm)    Motor Signal :       128 (DAC)
  mm/sec/DAC_ct:   0.01300 [D]     Enc Cnts/mm  :  49548.30 [C] 
  Wait Time    :         0 [WT]     Button Enable byte: 31 [BE]  
  



  Axis Name    :  Y                Limits Status: f
  Input Device :      JS_Y [J]       In_Dev Sign  :         1
  Max Lim      :   110.387 [SU]    Min Lim      :  -109.613 [SL] 
  Ramp Time    :        96 (ms)[AC]Max Ramp Stps:        16      
  Run Speed    :   1.11488(mm/s)[S]vmax_enc     :       331      
  Servo Lp Time:         6 (ms)    Ramp Length  :      4800 (enc)
  dv_enc       :        20         LL Axis ID   :        25
  Drift Error  :  0.000500 (mm)[E] enc_drift_err:        24   
  Finish Error :  0.000022 (mm)[PC}enc_finsh_err:         1      
  Backlash     :  0.000000 (mm)[B] enc_backlash :         0   
  Kp           :       100 [KP]    Ki           :        20 [KI]
  Kv           :        26 [KV]    Kd           :         0 [KD]
  Axis Enable  :         3 [MC]    Motor Enable :         0   
  CMD_stat     :   NO_MOVE           Move_stat    :      IDLE
  Current pos  :    0.0104 (mm)    enc position :       513
  Target pos   :    0.0100 (mm)    enc target   :       495
  enc pos error:       -10         EEsum        :         0
  Lst Stle Time:       534 (ms)    Av Settle Tim:        30 (ms) 
  Home position:   1000.84 (mm)    Motor Signal :       128 (DAC)
  mm/sec/DAC_ct:   0.01300 [D]     Enc Cnts/mm  :  49548.30 [C] 
  Wait Time    :         0 [WT]     Button Enable byte: 31 [BE]  
  Button Enable byte: 31 [BE]  
  

  Axis Name    :  Z                Limits Status: E
  Input Device :     WHEEL [J]       In_Dev Sign  :         1
  Max Lim      :   110.006 [SU]    Min Lim      :  -109.994 [SL] 
  Ramp Time    :        48 (ms)[AC]Max Ramp Stps:         8      
  Run Speed    :   0.64320(mm/s)[S]vmax_enc     :        77      
  Servo Lp Time:         6 (ms)    Ramp Length  :       504 (enc)
  dv_enc       :         9         LL Axis ID   :        26
  Drift Error  :  0.000100 (mm)[E] enc_drift_err:         2   
  Finish Error :  0.000055 (mm)[PC}enc_finsh_err:         1      
  Backlash     :  0.000000 (mm)[B] enc_backlash :         0   
  Kp           :       500 [KP]    Ki           :         5 [KI]
  Kv           :       109 [KV]    Kd           :         0 [KD]
  Axis Enable  :         3 [MC]    Motor Enable :         0   
  CMD_stat     :   NO_MOVE           Move_stat    :      IDLE
  Current pos  :   -0.0010 (mm)    enc position :       -19
  Target pos   :   -0.0010 (mm)    enc target   :       -20
  enc pos error:        -2         EEsum        :         0
  Lst Stle Time:        42 (ms)    Av Settle Tim:        42 (ms) 
  Home position:   1000.01 (mm)    Motor Signal :       128 (DAC)
  mm/sec/DAC_ct:   0.00750 [D]     Enc Cnts/mm  :  20000.00 [C] 
