#pragma rtGlobals=3			// Use modern global access method.
#pragma version= 2.0		// modification date 2025/12/15 by Jamie Boyd
#pragma IgorVersion=8.05	// so we can use threaded version of VDT2  -------MS2000_Stage requires the VDT2 XOP----------
#include "Stages"
#include "GUIPMath"			// for 2's complement

#define MS2000_DEBUG			// prints info to history for debugging

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
STATIC CONSTANT kMS2000xMIN = -5e-03
STATIC CONSTANT kMS2000xMAX = 5e-03
STATIC CONSTANT kMS2000yMIN = -5e-03
STATIC CONSTANT kMS2000yMAX = 5e-03
STATIC CONSTANT kMS2000zMIN = -5e-04
STATIC CONSTANT kMS2000zMax = 5e-04

// constants for axis resolution (minimum step size in metres)
CONSTANT  kMS2000XYstepSize = 1e-07
CONSTANT  kMS2000ZstepSize = 1e-07

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

// Special 2 byte control commands (no need for terminator character - nothing returned)
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
//BYTES 4 thru 9: Data Bytes, mostly in 2's compliment form in the order of:
// Least Significant Byte, Middle Byte, Most Significant Byte
//LAST BYTE: The ASCII colon character (: = dec 58) flags the end of the serial command

// Commmand:				Code:	DataSize:	Returns:
// Read Status			63		0			66 (B) if axis is busy, else 98 (b) if not busy
// Read Motor Position	97		3			current stage position in two's compliment form using 3 bytes in tenths of microns
// Read Motor Position	108		3			3 bytes  of stage position (see command 97) plus 1 byte status code (see command 126)
// 		and Status
// Read Status Byte		126		1			one byte, which can be broken down into 8 bits that represent the following internal flags:
//												Bit 0: 0 = No Motor Signal, 1 = Motor Signal (i.e., axis is moving)
//												Bit 1: Always 1, as servos cannot be turned off
//												Bit 2: 0 = Pulses Off, 1 = Pulses On
//												Bit 3: 0 = Joystick/Knob disabled, 1 = Joystick/Knob enabled
//												Bit 4: 0 = motor not ramping, 1 = motor ramping
//												Bit 5: 0 = ramping up, 1= ramping down
//												Bit 6: Upper limit switch: 0 = open, 1 = closed
//												Bit 7: Lower limit switch: 0 = open, 1 = closed
// Start / Enable Motor		71		0			Nothing returned. Used to turn on / start / enable the motor for an axis								
//Joystick Enable			74		0			// Nothing returned
//Joystick Disable			75		0			// Nothing returned
// Move to target position	84		3			// Nothing returned  example Command: 24 84 03 160 134 01 58
// Increment Move Up		43		0			// nothing returned example command: 24 43 0 58
// Increment Move Down	45		0			// nothing returned example command: 24 45 0 58
// Write Increment Value	68		3			// nothing returned. example command: 24 68 03 160 134 01 58
// Read Increment Value	100		3			//current increment setting. 3 byte two's compliment number in tenths of a micron. Example command: 24 100 03 58

STATIC CONSTANT HALT_CHAR = 		92		// char2num ("\\")
STATIC CONSTANT ZERO_CHAR =		90		// char2Num ("Z")
STATIC CONSTANT RETURN_CHAR =		13		// char2num ("\r")
STATIC CONSTANT COMMAND_END = 	58		// char2num (":")
STATIC CONSTANT AXIS_BUSY = 		66		// char2num ("B") for busy reply to GET_STATUS
STATIC CONSTANT AXIS_FREE	=		98		// char2num ("b") for not busy reply to GET_STATUS

STATIC CONSTANT HIGH_LEVEL = 		65
STATIC CONSTANT LOW_LEVEL = 		66
STATIC CONSTANT RESET_MS2000 =	82

STATIC CONSTANT X_AXIS = 			24
STATIC CONSTANT Y_AXIS = 			25
STATIC CONSTANT Z_AXIS = 			26

STATIC CONSTANT IS_BUSY = 		63		// X_AXIS IS_BUSY COMMAND_END								returns B or b
STATIC CONSTANT GET_POS =			97		// X_AXIS GET_POS 03 COMMAND_END							returns 3 bytes (position of axis in 2's complement)
STATIC CONSTANT GET_STATUS =		126		// X_AXIS GET_STATUS COMMAND_END							returns 1 byte (status byte)
STATIC CONSTANT GET_POS_STATUS =	108		// X_AXIS GET_POS_STATUS 03 COMMAND_END				returns 3 bytes positon data followed by status byte
STATIC CONSTANT 	MOV_POS =			84		// X_AXIS MOV_POS 03 lsb mb msb COMMAND_END			returns nothing - moves axis to requested position
STATIC CONSTANT GET_INCR = 		100		// X_AXIS GET_INCR 03 COMMAND_END						returns 3 bytes (increment for relative move in 2's complement)
STATIC CONSTANT SET_INCR=			68		// X_AXIS SET_INCR 03 lsb mb msb COMMAND_END			returns nothing	 - sets increment
STATIC CONSTANT MOV_INCR_UP =		43		// 	X_AXIS MOV_INCR_UP 0 COMMAND_END						returns nothing - moves axis more positive by a step
STATIC CONSTANT MOV_INCR_DWN =	45		// 	X_AXIS MOV_INCR_DWN 0 COMMAND_END					returns nothing - moves axis more negative by a step
STATIC CONSTANT ENABLE_MANUAL =	74		// 	X_AXIS ENABLE_MANUAL 0 COMMAND_END					returns nothing
STATIC CONSTANT DISABLE_MANUAL =	75		// 	X_AXIS DISABLE_MANUAL 0 COMMAND_END					returns nothing

//*********************************************************************************************  
// Convert 3 bytes, least significant to highest, using 2's complement, to a standard floating point
// Last modified 2025/12/15 by Jamie Boyd
Threadsafe Function From3b2cToFlt (lsb, mb, msb)
	variable lsb, mb, msb
	
	make/FREE/n=3 byteWave
	byteWave [0] = lsb
	byteWave [1] = mb
	byteWave [2] = msb
	return GUIP2CBytesToVal(byteWave)
end

//*********************************************************************************************
// converts a standard floating point number to three bytes, using 2's complement notation
// Last Modified 2025/12/15 by Jamie Boyd
Threadsafe Function FromFltTo3b2c (theVal,lsb, mb, msb)
	variable theVal, &lsb, &mb, &msb
	
	make/FREE/n=3 byteWave
	GUIPValTo2CBytes(round (theVal), byteWave)
	// Set bytes
	lsb = byteWave [0]
	mb = byteWave [1]
	msb =  byteWave [2]
end

//*********************************************************************************************
// Stage functions for Applied Scientific's MS-2000 motorized stage encoders. Moves, sets increments, etc.
//*******************************************************************************

//*******************************************************************************
// Set global variables
// these waves are created by Stage_MakeGlobals 
// Last Modified 2025/12/15 by Jamie Boyd
Function StageInitGlobals_MS2000 ()
	
	WAVE Properties =  root:packages:MS2000:Properties
	WAVE Polarity =  root:packages:MS2000:Polarity
	WAVE StepSize =  root:packages:MS2000:StepSize
	Properties [%has_XY] = kMS2000hasXY
	Properties [%has_Z] = kMS2000hasZ
	Properties [%has_Mtr] = 1
	Properties [%has_PID] = 0
	Properties [%has_Lock] = 1
	Properties [%res_XY] = kMS2000XYstepSize
	Properties [%res_Z] = kMS2000ZstepSize
	Properties [%min_X] = kMS2000xMIN
	Properties [%max_X] = kMS2000xMAX
	Properties [%min_Y] = kMS2000YMIN
	Properties [%max_Y] = kMS2000YMAX
	polarity[%X] = kMS2000Xpol
	polarity[%Y] = kMS2000Ypol
	polarity[%Z] = kMS2000Zpol
	StepSize [%X] = kMS2000XYstepSize * 10
	StepSize [%Y] = kMS2000XYstepSize * 10
	StepSize [%Z] = kMS2000ZstepSize
end

//*********************************************************************************************
// Opens the serial port for use with MS2000
// Last Modified 2025/12/15 by Jamie Boyd
Function StageSetUpPort_MS2000 (thePortName)
	string thePortName
	
	// Configure port, open it, and clear buffer
	VDT2/P = $PossiblyQuoteName (thePortName) baud=19200, stopbits=1, databits=8, parity=0, in=0, out=0, buffer=4096
	VDTOpenPort2 $PossiblyQuoteName (thePortName)
	//Clear buffer 
	vdt2/P =$possiblyquotename (thePortName) killio
	//switch to low level commandset
	VDTWriteBinary2/TYPE=72 /O=1 255, LOW_LEVEL
end

//*********************************************************************************************
// Port closing function for MS2000, tells VDT2 to close the serial port
// Last Modified 2025/12/15 by Jamie Boyd
Function StageClose_MS2000 (thePortName)
	string thePortName // Name of the serial port
	
	CtrlNamedBackground BKG_MS2000, STOP
	VDTGetPortList2
	if (findListItem (thePortName, S_VDT, ";") > -1)
		VDTClosePort2 $PossiblyQuoteName (thePortName)
	endif
end
	return 0
end


//*******************************************************************************
// add to the stage control panel things specific to MS2000
// Adds a reset button, a stop button, and a button to get step sizes
// Last Modified 2025/12/19 by Jamie Boyd
Function StageAddControls_MS2000 (hOffset, vOffset, thePanel)
	variable hOffset, vOffset
	string thePanel

	if (cmpstr (thePanel, stringfromlist (0, winlist (thePanel, ";", "WIN:65"), ";")) == 0) 
		Button ResetButton,win =$thePanel, pos={hOffset,vOffset},size={40,20},proc=StageReset_MS2000ButtonProc,title="Reset"
		Button ResetButton,win =$thePanel, help={"Resets the MS-2000. Equivalent to pressing the reset button on the encoder box."}
		Button StopButton,win =$thePanel, pos={hOffset + 43, vOffset},size={40,20},proc=StageStop_MS2000ButtonProc,title="Stop"
		Button StopButton,win =$thePanel, help={"Immediately halts movement on all axes of MS-2000."}
		Button GetStepSizesButton,win =$thePanel,pos={hOffset + 85,vOffset},size={60.00,30.00},title= "Get\rStep Sizes"
		Button GetStepSizesButton,win =$thePanel,title="Step Sizes", proc=StageGetStepSize_MS2000ButtonProc
		Button GetStepSizesButton,win =$thePanel, help={"Fetches values for step sizes for axes from MS-2000."}
	endif
end


//*******************************************************************************
// button procedure resets MS2000 and re-selects low-level command set
// Last Modified 2025/12/15 by Jamie Boyd
Function StageReset_MS2000ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			SVAR thePort = root:packages:MS2000:thePort
			//Clear buffer 
			vdt2/P =$possiblyquotename (thePort) killio
			VDTWriteBinary2/P =$possiblyquotename (thePort)/TYPE=72 /O=1 255, RESET_MS2000
			VDTWriteBinary2/P =$possiblyquotename (thePort)/TYPE=72 /O=1 255, LOW_LEVEL
			break
	endswitch
	return 0
End


//*******************************************************************************
// Stop button procedure
// Last Modified 2025/12/15 by Jamie Boyd
Function StageStop_MS2000ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			// switch to high-level format - doesn't appear to be a way to do this with low-level commandset
			SVAR thePort = root:packages:MS2000:thePort
			WAVE Properties = root:packages:MS2000:Properties
			VDTWriteBinary2/P =$possiblyquotename (thePort)/TYPE=72 /O=1 255, HIGH_LEVEL
			VDTWriteBinary2/P =$possiblyquotename (thePort)/TYPE=72 /O=1 HALT_CHAR, RETURN_CHAR
			string readStr
			vdtread2/o=1/T= "\n" readStr // read result (:A\r), which we ignore
			if (!(V_VDT))
				Properties[%ERR] = 1
#ifdef MS2000_DEBUG
				printf "MS000 Stop failed to return result.\r"
#endif
				return 1
			endif
			// switch back to low-level command set
			VDTWriteBinary2/P =$possiblyquotename (thePort)/TYPE=72 /O=1 255, LOW_LEVEL
		break
	endswitch
	return 0
End


//*******************************************************************************
// Gets step size increments for all axes from stage encoder, and updates the
// StepSize wave. Most encoders don't store step sizes so we make a special
// button for it for the MS-20000
// Last Modified 2025/12/19 by Jamie Boyd
Function StageGetStepSize_MS2000ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR thePort = root:packages:MS2000:thePort
			WAVE Properties = root:packages:MS2000:Properties
			WAVE stepsize = root:packages:MS2000:StepSize
			WAVE selectedForCMD = root:packages:MS2000:selectedForCMD
			NVAR stageIsThreaded = root:packages:MS2000:stageIsThreaded
			selectedForCMD =0
			if (Properties [%has_XY])
				selectedForCMD [%X] =1
				selectedForCMD [%Y] =1
			endif
			if (Properties [%has_Z])
				selectedForCMD [%Z] =1
			endif
			if (stageIsThreaded)
				NVAR threadID = $"root:packages:MS2000:stageThread"
				newdatafolder/s :tdata
				variable/G theCmdG = kThreadGetMvIncr
				duplicate selectedForCMD selectedG
				WAVEClear selectedG
				ThreadGroupPutDF threadID, :
			else
				StageGetStepIncr_MS2000 (thePort, selectedForCMD, StepSize, Properties)
			endif
			break
	endswitch
	return 0
End


//*********************************************************************************************
// Reset I/O function for MS2000, clears any pending commands
// Last Modified 2025/12/15 by Jamie Boyd
Threadsafe Function StageResetIO_MS2000 (thePort, Properties)
	string thePort // Name of the serial port
	WAVE Properties
	
	vdt2/P =$possiblyquotename (thePort) killio
	Properties [%ERR] = 0
	// Ensure using low-level command set
	VDTWriteBinary2/P =$possiblyquotename (thePort)/TYPE=72 /O=1 255, LOW_LEVEL
end


//*******************************************************************************
// Sets the current position to be Zero, i.e.distance from home = 0
// Last Modified 2025/12/15 by Jamie Boyd
Threadsafe Function StageSetZero_MS2000 (thePort, DistsFromZero, Zeros, Properties)
	string thePort
	WAVE DistsFromZero
	WAVE Zeros
	WAVE Properties

	// switch to high-level format - doesn't appear to be a way to do this with low-level commandset
	VDTWriteBinary2/P =$possiblyquotename (thePort)/TYPE=72/O=1 255, HIGH_LEVEL
	VDTWriteBinary2/P =$possiblyquotename (thePort)/TYPE=72/O=1 ZERO_CHAR, RETURN_CHAR
	string readStr
	vdtread2/o=1/T= "\n" readStr // read result, which we ignore
	if (!(V_VDT))
		Properties[%ERR] = 1
#ifdef MS2000_DEBUG
		printf "MS000 Set Zero failed to return result.\r"
#endif
		return 1
	endif
	// switch back to low-level command set
	vdt2 /P = $possiblyquotename (thePort) killio
	VDTWriteBinary2/P =$possiblyquotename (thePort)/TYPE=72 /O=1 255, LOW_LEVEL
	// Update displayed positions
	DistsFromZero =0
End


//*********************************************************************************************
// Stage update function for Applied Scientific's MS-2000 stage encoders
// Last Modified 2025/12/15 by Jamie Boyd
Threadsafe Function StageUpdate_MS2000 (thePort, selectedForCMD, DistsFromZero, Zeros, Properties)
	string thePort
	WAVE selectedForCMD
	WAVE DistsFromZero
	WAVE Zeros
	WAVE Properties
	
	// value is returned in 3 bytes
	variable lsb, mb, msb
	// get X axis
	if (selectedForCMD [%X])
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  X_AXIS, GET_POS, 3, COMMAND_END
		VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
	if (V_VDT != 3)
		Properties[%ERR] = 1
#ifdef MS2000_DEBUG
		printf "MS000 Stage Update X axis failed to return result.\r"
#endif
		return 1
	endif
		DistsFromZero[%X] = From3b2cToFlt (lsb, mb, msb) * kMS2000XYstepSize
	endif
	
	// get Y axis
	if (selectedForCMD [%Y])
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Y_AXIS, GET_POS, 3, COMMAND_END
		VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
		if (V_VDT != 3)
			Properties[%ERR] = 1
#ifdef MS2000_DEBUG
			printf "MS000 Stage Update Y axis failed to return result.\r"
#endif
			return 1
		endif
		DistsFromZero[%Y] = From3b2cToFlt (lsb, mb, msb) * kMS2000XYstepSize
#ifdef MS2000_DEBUG
		printf "The Y axis is at %.3W1Pm.\r", DistsFromZero[%Y]
#endif
	endif
	// get Z axis
	if (selectedForCMD [%Z])
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Z_AXIS, GET_POS, 3, COMMAND_END
		VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
		if (V_VDT != 3)
			Properties[%ERR] = 1
#ifdef MS2000_DEBUG
			printf "MS000 Stage Update Z axis failed to return result.\r"
#endif
			return 1
		endif
		DistsFromZero[%Z] = From3b2cToFlt (lsb, mb, msb) * kMS2000ZstepSize
#ifdef MS2000_DEBUG
		printf "The Z axis is at %.3W1Pm.\r", DistsFromZero[%Z]
#endif
	endif
end


//*********************************************************************************************
// Background task function to update stage positions for Applied Scientific's MS-2000 stage encoders
// for use when Stage is not threaded
// Last Modified 2025/12/15 by Jamie Boyd
Function StageBkgUpdate_MS2000(bks)
	STRUCT StageBkgStruct &bks
	
	// NOT threadsafe, so we can reference globals
	WAVE Properties =  root:packages:MS2000:Properties
	WAVE Selected = root:packages:MS2000:selectedForCMD
	WAVE DistsFromZero = root:packages:MS2000:DistanceFromZero
	SVAR thePort = root:packages:MS2000:thePort
	// when starting, set starting conditions in update struct
	if (bks.WMS.started)
		bks.WMS.started = 0
		bks.axesBits = 0
		if (Selected [%X])
			bks.axesBits += 1
		endif
		if  (Selected [%Y])
			bks.axesBIts += 2
		endif
		if (Selected [%Z])
			bks.axesBits += 4
		endif
	else
		// value is returned in 3 bytes
		variable lsb, mb, msb
		// get X axis
		if (bks.axesBits & 1)
			VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  X_AXIS, GET_POS, 3, COMMAND_END
			VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
			if (V_VDT != 3)
				Properties[%ERR] = 1
				return 1
			endif
			DistsFromZero[%X] = From3b2cToFlt (lsb, mb, msb) * kMS2000XYstepSize
		endif
		
		// get Y axis
		if (bks.axesBits & 2)
			VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Y_AXIS, GET_POS, 3, COMMAND_END
			VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
			if (V_VDT != 3)
				Properties[%ERR] = 1
				return 1
			endif
			DistsFromZero[%Y] = From3b2cToFlt (lsb, mb, msb) * kMS2000XYstepSize
		endif
		// get Z axis
		if (bks.axesBits & 4)
			VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Z_AXIS, GET_POS, 3, COMMAND_END
			VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
			if (V_VDT != 3)
				Properties[%ERR] = 1
				return 1
			endif
			DistsFromZero[%Z] = From3b2cToFlt (lsb, mb, msb) * kMS2000ZstepSize
		endif
	endif
	return 0
end


//*************************************************************************************************
//Function for checking approach to a position, so we can call it from bkg or move functions
//Last Modified 2025/12/17 by Jamie Boyd
Threadsafe Function StageMonitorFunc_MS2000(thePort, axesBits, MoveTo, DistsFromZero)
	string thePort
	variable axesBits
	WAVE MoveTo
	WAVE distsFromZero
	
	// bytes for position and status
	variable lsb, mb, msb, statusByte
	// X axis
	if (axesBits & 1)
		VDTWriteBinary2/P=$possiblyquotename (thePort)/TYPE =72 /O=1 X_AXIS, IS_BUSY, 0, COMMAND_END
		VDTReadBinary2/P=$possiblyquotename (thePort)/TYPE=72/O=1 statusByte
		if (statusByte == AXIS_FREE)
			axesBits = axesBits & ~1
			VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  X_AXIS, GET_POS, 3, COMMAND_END
			VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
			if (V_VDT != 3)
				return 16
			endif
			DistsFromZero[%X] = From3b2cToFlt (lsb, mb, msb) * kMS2000XYstepSize
		endif
	endif
	// Y axis
	if (axesBits & 2)
		VDTWriteBinary2 Y_AXIS, IS_BUSY, 0, COMMAND_END
		VDTReadBinary2/O=1 /TYPE=72 statusByte
		if (statusByte == AXIS_FREE)
			axesBits = axesBits & ~2
			VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Y_AXIS, GET_POS, 3, COMMAND_END
			VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
			if (V_VDT != 3)
				return 16
			endif
			DistsFromZero[%Y] = From3b2cToFlt (lsb, mb, msb) * kMS2000XYstepSize
		endif
	endif
	// Z axis
	if (axesBits & 4)
		VDTWriteBinary2 Z_AXIS, IS_BUSY, 0, COMMAND_END
		VDTReadBinary2/O=1 /TYPE=72 statusByte
		if (statusByte == AXIS_FREE)
			axesBits = axesBits & ~4
			VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Z_AXIS, GET_POS, 3, COMMAND_END
			VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
			if (V_VDT != 3)
				return 16
			endif
			DistsFromZero[%Z] = From3b2cToFlt (lsb, mb, msb) * kMS2000ZstepSize
		endif
	endif
	return axesBits
end

//***********************************************************************************	
// BackGround function for monitoring going to target we do a little more than check
// for position matching target, we first wait until axis is no longer moving, then get pos
// Last Modified 2025/12/15 by Jamie Boyd
Function StageBkgMonitor_MS2000(bks)
	STRUCT StageBkgStruct &bks
	
	// NOT threadsafe, so we can reference globals
	WAVE Properties =  root:packages:MS2000:Properties
	WAVE Selected = root:packages:MS2000:selectedForCMD
	WAVE MoveTo = root:packages:MS2000:MoveTo
	WAVE DistsFromZero = root:packages:MS2000:DistanceFromZero
	SVAR thePort = root:packages:MS2000:thePort
	// when starting, set starting conditions in update struct
	if (bks.WMS.started)
		bks.WMS.started = 0
		bks.axesBits = 0
		if (Selected [%X])
			bks.axesBits += 1
			bks.targets[0] = MoveTo[%X]
		endif
		if  (Selected [%Y])
			bks.axesBIts += 2
			bks.targets[1] = MoveTo[%Y]
		endif
		if (Selected [%Z])
			bks.axesBits += 4
			bks.targets[2] = MoveTo[%Z]
		endif
	else
		bks.axesBits = StageMonitorFunc_MS2000 (thePort, bks.axesBits, MoveTo, DistsFromZero)
		switch (bks.axesBits)
			case 16:
				Properties[%ERR] = 1
			case 0:
				return 1
				break
			default:
				return 0
				break
		endswitch
	endif
end


// *********************************************************************************************
// Function for Setting increment for steps, used when stored on the stage encoder
// Last modified 2025/12/17 by Jamie Boyd
ThreadSafe Function StageSetStepIncr_MS2000 (thePort, selectedForCMD, StepSize, Properties)
	string thePort
	WAVE selectedForCMD
	WAVE StepSize
	WAVE Properties
	
	// value is converted to 3 bytes
	variable lsb, mb, msb
	if (selectedForCMD [%X])
		// Set X Axis step size values
		FromFltTo3b2c ((StepSize[%X]/kMS2000XYstepSize),lsb, mb, msb)
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  X_AXIS, SET_INCR, 03, lsb, mb, msb, COMMAND_END
	endif
	if (selectedForCMD [%Y])
		// Set Y Axis step size values
		FromFltTo3b2c ((StepSize[%Y]/kMS2000XYstepSize),lsb, mb, msb)
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Y_AXIS, SET_INCR, 03, lsb, mb, msb, COMMAND_END
	endif
	if (selectedForCMD [%Z])
		// Set Z Axis step size values
		FromFltTo3b2c ((StepSize[%Z]/kMS2000ZstepSize),lsb, mb, msb)
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Z_AXIS, SET_INCR, 03, lsb, mb, msb, COMMAND_END
	endif
	
#ifdef MS2000_DEBUG
	//Read back Increment Value
	if (selectedForCMD [%X])		
		VDTWriteBinary2 /P=$possiblyquotename (thePort) /TYPE=72 /O=1  X_AXIS, GET_INCR, 03, COMMAND_END
		VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
		if (V_VDT != 3)
			Properties[%ERR] = 1
			printf "MS000 Stage Fetch X step size failed to return result.\r"
			return 1
		endif
		printf "The X-axis increment value is %.3W1Pm.\r", (From3b2cToFlt (lsb, mb, msb) * kMS2000XYstepSize)
	endif
	
	if (selectedForCMD [%Y])		
		VDTWriteBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72  Y_AXIS, GET_INCR, 03, COMMAND_END,
		VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
		if (V_VDT != 3)
			Properties[%ERR] = 1
			printf "MS000 Stage Fetch Y step size failed to return result.\r"
			return 1
		endif
		printf "The Y-axis increment value is %.2W1Pm.\r", (From3b2cToFlt (lsb, mb, msb) * kMS2000XYstepSize)
	endif
	
	if (selectedForCMD [%Z])		
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Z_AXIS, GET_INCR, 03, COMMAND_END
		VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
		if (V_VDT != 3)
			Properties[%ERR] = 1
			printf "MS000 Stage Fetch Z step size failed to return result.\r"
			return 1
		endif
		printf "The Z-axis increment value is %.2W1Pm.\r", (From3b2cToFlt (lsb, mb, msb) * kMS2000ZstepSize)
	endif
#endif
end

// *********************************************************************************************
// Functon for Getting increment for steps, used when stored on the stage encoder
// Last modified 2025/12/17 by Jamie Boyd
ThreadSafe Function StageGetStepIncr_MS2000 (thePort, selectedForCMD, StepSize, Properties)
	string thePort
	WAVE selectedForCMD
	WAVE StepSize
	WAVE Properties
	
	// value is returned in 3 bytes
	variable lsb, mb, msb
	if (selectedForCMD [%X])
		// Get X Axis step size values
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  X_AXIS, GET_INCR, 03, COMMAND_END
		VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
		if (V_VDT != 3)
			Properties[%ERR] = 1
#ifdef MS2000_DEBUG
			printf "MS000 Stage Fetch X step size failed to return result.\r"
#endif
			return 1
		endif
		stepsize[%X] = From3b2cToFlt (lsb, mb, msb) * kMS2000XYstepSize
	endif
	if (selectedForCMD [%Y])
		// get Y axis
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Y_AXIS, GET_INCR, 03, COMMAND_END
		VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
		if (V_VDT != 3)
			Properties[%ERR] = 1
#ifdef MS2000_DEBUG
			printf "MS000 Stage Fetch Y step size failed to return result.\r"
#endif
			return 1
		endif
		stepsize[%Y] = From3b2cToFlt (lsb, mb, msb) * kMS2000XYstepSize
	endif
	//Get Z axis
	if (selectedForCMD [%Z])
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Z_AXIS, GET_INCR, 03, COMMAND_END
		VDTReadBinary2/P=$possiblyquotename (thePort)/O=1 /TYPE=72 lsb, mb, msb
		if (V_VDT != 3)
			Properties[%ERR] = 1
#ifdef MS2000_DEBUG
			printf "MS000 Stage Fetch Z step size failed to return result.\r"
#endif
			return 1
		endif
		stepsize[%Z] = From3b2cToFlt (lsb, mb, msb) * kMS2000ZstepSize
	endif
	return 0	
end


//*************************************************************************************************
// moves MS2000 stage a step up or down relative to current position. Step size is stored on MS-2000
// Last modified: 2025/12/17 by Jamie Boyd
Threadsafe Function StageMoveRel_MS2000 (thePort, doVerify, selectedForCMD, StepSize, DistsFromZero, Properties)
	String thePort
	Variable doVerify		// 0 to not verify movement, just assume we get there.
	WAVE selectedForCMD
	Wave StepSize
	WAVE DistsFromZero
	WAVE Properties

	variable AxesBits =0
	if (selectedForCMD [%X] == 1) // up
		AxesBits += 1
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1 X_AXIS, MOV_INCR_UP, 0, COMMAND_END
	elseif (selectedForCMD [%X] == -1) // down
		AxesBits += 1
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1 X_AXIS, MOV_INCR_DWN, 0, COMMAND_END
	endif

	if (selectedForCMD [%Y] == 1) // up
		AxesBits += 2
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1 Y_AXIS, MOV_INCR_UP, 0, COMMAND_END
	elseif (selectedForCMD [%Y] == -1) // down
		AxesBits += 2
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1 Y_AXIS, MOV_INCR_DWN, 0, COMMAND_END
	endif

	if (selectedForCMD [%Z] == 1) // up
		AxesBits += 4
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1 Z_AXIS, MOV_INCR_UP, 0, COMMAND_END
	elseif (selectedForCMD [%Z] == -1) // down
		AxesBits += 4
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1 Z_AXIS, MOV_INCR_DWN, 0, COMMAND_END
	endif

	Switch (doVerify)
		case kStagesReturnNow: // update DistsFromZero to what they should be is move succeeds
			DistsFromZero += (StepSize * selectedForCMD)  // if axis is not selected, selectedForCMD will be zero
			break
		case kStagesReturnAfter: // loop till position acheived. StageMonitorFunc_MS2000 will set DistsFromZero
			do
				sleep /C=-1 /s kAUTO_UPDATE_INT
				axesBits = StageMonitorFunc_MS2000 (thePort, axesBits, DistsFromZero, DistsFromZero)
			while ((axesBits > 0) && (axesBits < 16))  // 16 is code for an error from monitor function
			if (axesBits == 16)
				Properties [%ERR] =1
			endif
			break
		case kStagesReturnBkg:	// return immediately, a thread or a bkg task will be set to monitor position and update DistsFromZero
			break
	endSwitch
end


//*************************************************************************************************
// Stage Move function that moves MS2000 axis or axes to an absolute position
// Last modified: 2025/12/17 by Jamie Boyd
Threadsafe Function StageMoveAbs_MS2000 (thePort, doVerify, selectedForCMD, MoveTo, DistsFromZero, Properties)
	String thePort
	variable doVerify
	Wave selectedForCMD
	WAVE MoveTo
	WAVE DistsFromZero
	WAVE Properties
	
	// value is converted to 3 bytes
	variable lsb, mb, msb
	variable axesBits =0
	if (selectedForCMD [%X])
		// Set X Axis position values
		axesBits += 1
		FromFltTo3b2c ((MoveTo[%X]/kMS2000XYstepSize),lsb, mb, msb)
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  X_AXIS, MOV_POS, 03, lsb, mb, msb, COMMAND_END
	endif

	if (selectedForCMD [%Y])
		// Set Y Axis position values
		axesBits += 2
		FromFltTo3b2c ((MoveTo[%Y]/kMS2000XYstepSize),lsb, mb, msb)
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Y_AXIS, MOV_POS, 03, lsb, mb, msb, COMMAND_END
	endif

	if (selectedForCMD [%Z])
		// Set Z Axis position values
		axesBits += 4
		FromFltTo3b2c ((MoveTo[%Z]/kMS2000XYstepSize),lsb, mb, msb)
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1  Z_AXIS, MOV_POS, 03, lsb, mb, msb, COMMAND_END
	endif
	
	if (doVerify == kStagesReturnAfter)
		do
			sleep /C=-1 /s kAUTO_UPDATE_INT
			axesBits = StageMonitorFunc_MS2000 (thePort, axesBits, MoveTo, DistsFromZero)
		while ((axesBits > 0) && (axesBits < 16))
		if (axesBits == 16)
			Properties [%ERR] =1
		endif
	endif
end


//*******************************************************************************
// background function for use with threads so that control panel is updated
// Last Modified 2025/12/17 By Jamie Boyd
Function StageBkgTouch_MS2000 (WMS)
	STRUCT WMBackgroundStruct &WMS
	
	WAVE properties = root:packages:MS2000:properties
	WAVE distsFromZero = root:packages:MS2000:DistanceFromZero
	properties [%has_AX] += 0
	distsFromZero [%A] += 0
end


//*************************************************************************************************
// Enables or disables manual movement of stage
// Last Modified 2025/12/17 by Jamie Boyd
Threadsafe Function StageSetManual_MS2000 (thePort, doLock, Properties)
	string thePort
	variable doLock //1 to lock manual movement of stage, 0 to unlock
	WAVE Properties
	
	variable lockState
	if (doLock)
		lockState = DISABLE_MANUAL
	else
		lockState = ENABLE_MANUAL
	endif
	if (Properties[%has_XY])
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1 X_AXIS, lockState, 0, COMMAND_END
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1 Y_AXIS, lockState, 0, COMMAND_END
	endif
	if (Properties[%has_Z])
		VDTWriteBinary2/P=$possiblyquotename (thePort) /TYPE=72 /O=1 Z_AXIS, lockState, 0, COMMAND_END
	endif
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
