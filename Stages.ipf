#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#pragma rtGlobals=3
#pragma version= 6				// the threaded version
#pragma IgorVersion=8.05		// need threaded version of VDT2 XOP
#include "GUIPList"
#include "GUIPControls"
#include <SaveRestoreWindowCoords>

// Modified: 2025/12/19 by Jamie Boyd - making threads work
// Modified: 2025/10/29 by Jamie Boyd - using threads for reading and moving
// Modified: 2025/07/08 by Jamie Boyd - Use new GUIPSetVar routines
// Modified: 2025/07/07 by Jamie Boyd - removed reference to VDT and ASIUSBez

// Designed to work with the VDT2 XOP for serial control

// The idea is that the control panel that this general procedure makes works with multiple specific procedures,
// each targeting a different stage encoder, as long as the procedures for the stage encoder implements the
// functions in the provided template functions

// **************************** Select Threaded or Unthreaded use *********************************
// You can choose whether the stage is run in threaded mode or not by leaving exactly one of the following two lines uncommented
//#define STAGE_IS_THREADED
#undef STAGE_IS_THREADED

// update interval,in seconds, for background updating of position from bkgTask or thread
CONSTANT kAUTO_UPDATE_INT = 0.3333		// 3 times a second

//******************* MNEMONIC CONSTANTS FOR STAGE MOVEMENT VERIFICATION ********************************
CONSTANT kStagesReturnNow =0	// stage function assume stage will get there, and returns immediately
CONSTANT kStagesReturnAfter = 1	// stage function does not return until after requested position has been verified. if threaded, thread will block until verified 
CONSTANT kStagesReturnBkg = 2	// a bkg task will be started to monitor position (unthreaded) or thread will monitor position without blocking (threaded)

//******************* MNEMONIC CONSTANTS FOR axis Bits ********************************
CONSTANT kXbit = 1
CONSTANT kYbit = 2
CONSTANT kZbit = 4
CONSTANT kAbit = 8 


// ***********************************************************************************************
// menu items for Stages, the threaded version has an extra item to kill the thread
// Note use of #ifdef for conditional compilation of code for threaded versus nonthreaded version. Used extensivelyin following code
#ifdef STAGE_IS_THREADED
Menu "Macros"
	Submenu "Stages"
		"Open Stage and Focus Panel",/Q,StageStart()
		"Stop Thread", /Q, StageStopThread()
	end
end
#else
Menu "Macros"
	"Open Stage and Focus Panel",/Q,StageStart()
end
#endif

// To write a procedure for a stage controller device, implement the following templates, as appropriate

//****************************************************************************************************************************************************
//***************************************Templates for Initialization functions **********************************************************************
//****************************************************************************************************************************************************
// Template for function to set global variables for the Stage encoder.
// The globals will be made by StageMakeGlobals procedure
Function StageInitGlobals_Template()
	return 0
end

//*************************************************************************************************
//Template for Stage Setup function - Stage procedure will open and initialize serial port with correct Baud and other settings
Function StageSetUpPort_Template(thePortName)
	string thePortName // Name of the serial port
end


//*************************************************************************************************
//Template for Stage Close functions -  Stage procedure will close the port, do anything else it needs to do
Function StageClose_Template(thePortName)
	string thePortName // Name of the serial port
end


//**********************************************************************************************************************************
//******************* Templates for Threadsafe functions for things that can be done from the thread *******************************
//**********************************************************************************************************************************

//*************************************************************************************************
// Template for function to reset I/O, clearing any buffers
Threadsafe Function StageResetIO_Template(thePortName, Properties)
	string thePortName // Name of the serial port
	WAVE Properties
end


//*************************************************************************************************
// Template for function to set zero position, i.e., zero the stage encoders for all supported axes
Threadsafe Function StageSetZero_Template(thePort, selectedForCMD, DistsFromZero, Zeros, Properties)
	string thePort
	WAVE selectedForCMD
	WAVE DistsFromZero
	WAVE Zeros
	WAVE Properties
end


//*************************************************************************************************
// Template for Stage Update functions - the funcref should never resolve to this template function
Threadsafe Function StageUpdate_Template(thePort, selectedForCMD, DistsFromZero, Zeros, Properties)
	string thePort
	WAVE selectedForCMD
	WAVE DistsFromZero
	WAVE Zeros
	WAVE Properties

	print "You do not have stage encoders configured properly."
end


//*************************************************************************************************
// Template for Stage Move function that moves a step relative to current position, which stage procedures for controllable stages must provide
// if they don't support relative movement, use DistsFromZero to translate into absolute movement
// the funcref should never resolve to this template function
Threadsafe Function StageMoveRel_Template(thePort, doVerify, selectedForCMD, StepSize, DistsFromZero, Properties)
	String thePort
	Variable doVerify		// 0 to not verify movement, just assume we do.
	WAVE selectedForCMD
	Wave StepSize
	WAVE DistsFromZero
	WAVE Properties

	print "You do not have stage encoders configured properly."
end


//*************************************************************************************************
// Template for Stage Move function that moves to an absolute position, which stage procedures for controllable stages must provide
// the funcref should never resolve to this template function
Threadsafe Function StageMoveAbs_Template(thePort, doVerify, selectedForCMD, MoveTo, DistsFromZero, Properties)
	String thePort
	variable doVerify
	Wave selectedForCMD
	WAVE MoveTo
	WAVE DistsFromZero
	WAVE Properties

	print "You do not have stage encoders configured properly."
end

//*************************************************************************************************
// Template for a function that reports which axes have been moved to their target locations
// to be used by the thread. Can also be called from the moveRel, moveAbs functions, and from background function
// returns a bitwise combo of active axes 1=x, 2=y, 4=Z, 8=A
Threadsafe Function StageMonitorFunc_Template(thePort, axesBits, MoveTo, DistsFromZero)
	String thePort
	variable axesBits	//bitwise combo of axes that need checking 1=x, 2=y, 4=Z, 8=A
	WAVE MoveTo
	WAVE DistsFromZero
end


// ************************************************************************************************************
// Template for a special background task for use with threaded stage operation. You need to occasionally "touch"
// the waves in the datafolder for the stage in order for the values in the control panel to be updated.
// Adding zero to any point in the wave is an adequate way to do this
// Not needed if you can live with the control panel being out of date
// FYI: bringing another window to the front, then bringing the control panel to the front again will also update control panel values
Function StageBkgTouch_Template(WMS)
	STRUCT WMBackgroundStruct &WMS
end


//**********************************************************************************************************************************
//************************* Support for background tasks when Stage is not threaded ***********************************************
//**********************************************************************************************************************************


// ******************************************************************************
// Template for a function that uses a background task to continuously update axes positions, for non-threaded use,
Function StageBkgUpdate_Template(bks)
	STRUCT StageBkgStruct &bks
end

// ******************************************************************************
// Template for function that uses a background task to continuously update axes positions, for non-threaded use,
Function StageBkgMonitor_Template(bks)
	STRUCT StageBkgStruct &bks
end

//*******************************************************************************
// structure for background function with extra fields for monitoring positions
// Last modified 2025/11/26 by Jamie Boyd
STRUCTURE StageBkgStruct
STRUCT WMBackgroundStruct WMS
uint32 axesBits		// bitwise combo of axes to monitor, 1=X, 2=Y, 4=Z, 8=Ax
float targets [4]	//when monitoring position, the coordinates we are approaching, X,Y,Z,A
EndStructure


//*********************************************************************************************************************************************************************
//****************Templates for various functions which stage procedures may or may not provide, depending on their feature set***********************
//*********************************************************************************************************************************************************************


//*************************************************************************************************
// Template for optional function to add special controls for a particular stage encoder to a control panel
// X and Y offset refer to point offsets to position controls on control panel
Function StageAddControls_Template(xOffset, yOffset, thePanel)
	variable xOffset, yOffset
	string thePanel
end

// *********************************************************************************************
// Template for Setting increment for steps, used when stored on the stage encoder
ThreadSafe Function StageSetStepIncr_Template(thePort, selectedForCMD, StepSize, Properties)
	string thePort
	WAVE selectedForCMD
	WAVE StepSize
	WAVE Properties
end


// *********************************************************************************************
// Template for Getting increment for steps, used when stored on the stage encoder
ThreadSafe Function StageGetStepIncr_Template(thePort, selectedForCMD, StepSize, Properties)
	string thePort
	WAVE selectedForCMD
	WAVE StepSize
	WAVE Properties
end


//*************************************************************************************************
// Template for function to lock joystick to stop manual movement of stage encoder
Threadsafe Function StageSetManual_template(thePort, doLock, Properties)
	string thePort
	variable doLock //1 to lock manual movement of stage, 0 to unlock
	WAVE Properties
end



//*************************************************************************************************
// Template for function to add special controls for a particular stage encoder to the PID panel
// X and Y offset refer to point offsets to position controls on control panel
// returns the amount of extra vertical space it added. The function needs to resize the control panel as needed
Function StageAddPIDControls_Template(Axis, xOffset, yOffset, thePanel)
	string Axis // X, Y, or Z will be called indepentently
	variable xOffset, yOffset
	string thePanel

	return 1
end


//*************************************************************************************************
// Template for function to fetch PID values
Threadsafe Function StageFetchPID_Template(thePort, SelectedForCMD, PIDget, Properties)
	string thePort
	WAVE SelectedForCMD
	WAVE PIDGet
	Wave Properties
	print "You do not have PID functions configured properly"
	return 1
end

//*************************************************************************************************
// Template for function to set PID values
Threadsafe Function StageSetPID_Template(thePort, SelectedForCMD, PIDset, Properties)
	string thePort
	WAVE SelectedForCMD
	WAVE PIDset
	WAVE Properties

	return 1
end


// *************************************************** Functions for Stage Management ***********************************************
// These functions are used to manage all stages. The are called from the Stage Control Panel, and can also be called from User code
// ***************************************************************************************************************************


//*********************************************************************************************
// Makes globals for the chosen Stage encoder,but does not give inital values, individual stage procedure does that in its StageInitGlobals
// Last modified 2025/11/25 by Jamie Boyd - uses waves not global variables for most configuration values
Function StageMakeGlobals(theStageEncoder)
	string theStageEncoder

	if(!(dataFolderExists ("root:packages:" + theStageEncoder)))
		if (!(datafolderExists ("root:packages:")))
			newdatafolder root:packages
		endif
		newDataFolder/O $"root:packages:" + theStageEncoder
	endif
	// name of serial port
	string/G $"root:packages:" + theStageEncoder + ":thePort"
	// absolute Zero, for Stage encoders that do not have a zero command, we store position here
	make/o/n=4  $"root:packages:" + theStageEncoder + ":absoluteZero"
	WAVE absoluteZero=$"root:packages:" + theStageEncoder + ":absoluteZero"
	absoluteZero =0
	// distances from 0
	make/o/n=4  $"root:packages:" + theStageEncoder + ":DistanceFromZero"
	WAVE dist=$"root:packages:" + theStageEncoder + ":DistanceFromZero"
	// selected wave, used to indicate if an axis is selected for a command
	make/o/n=4  $"root:packages:" + theStageEncoder + ":selectedForCMD"
	WAVE selected=$"root:packages:" + theStageEncoder + ":selectedForCMD"
	// requsted move position
	make/o/n=4  $"root:packages:" + theStageEncoder + ":MoveTo"
	WAVE moveTo=$"root:packages:" + theStageEncoder + ":MoveTo"
	// step size
	make/o/n=4  $"root:packages:" + theStageEncoder + ":StepSize"
	WAVE StepSize=$"root:packages:" + theStageEncoder + ":StepSize"
	// polarity - used for left, right, and up, down step buttons
	make/o/n=4  $"root:packages:" + theStageEncoder + ":Polarity"
	WAVE polarity=$"root:packages:" + theStageEncoder + ":Polarity"
	setDimLabel 0, 0, X, absoluteZero, dist, StepSize, polarity, moveTo, selected
	setDimLabel 0, 1, Y, absoluteZero, dist, StepSize, polarity, moveTo, selected
	setDimLabel 0, 2, Z, absoluteZero, dist, StepSize, polarity, moveTo, selected
	setDimLabel 0, 3, A, absoluteZero, dist, StepSize, polarity, moveTo, selected
	// properties and error
	make/o/n=21 $"root:packages:" + theStageEncoder + ":properties"
	WAVE propWave = $"root:packages:" + theStageEncoder + ":properties"
	propWave=0
	propWave [9,12] = -INF		// default minimum range limits
	propWave [13,16] = INF		// default maximum range limits
	setDimLabel 0, 0, has_XY, propWave
	setDimLabel 0, 1, has_Z, propWave
	setDimLabel 0, 2, has_Ax, propWave
	setDimLabel 0, 3, has_Mtr, propWave
	setDimLabel 0, 4, has_PID, propWave
	setDimLabel 0, 5, has_Lock, propWave
	setDimLabel 0, 6, res_XY, propWave
	setDimLabel 0, 7, res_Z, propWave
	setDimLabel 0, 8, res_Ax, propWave
	setDimLabel 0, 9, min_X, propWave
	setDimLabel 0, 10, min_Y, propWave
	setDimLabel 0, 11, min_Z, propWave
	setDimLabel 0, 12, min_Ax, propWave
	setDimLabel 0, 13, max_X, propWave
	setDimLabel 0, 14, max_Y, propWave
	setDimLabel 0, 15, max_Z, propWave
	setDimLabel 0, 16, max_Ax, propWave
	setDimLabel 0, 17, is_Locked, propWave
	setDimLabel 0, 18, is_auto, propWave
	setDimLabel 0, 19, ERR, propWave
	setDimLabel 0, 20, BUSY, propWave
	// PID settings (for set, get, and default)
	make/o/n=(4,3)  $"root:packages:" + theStageEncoder + ":PIDget"
	WAVE PIDget = $"root:packages:" + theStageEncoder + ":PIDget"
	make/o/n=(4,3)  $"root:packages:" + theStageEncoder + ":PIDdefault"
	WAVE PIDdefault = $"root:packages:" + theStageEncoder + ":PIDdefault"
	setDimLabel 0, 0, X, PIDget, PIDdefault
	setDimLabel 0, 1, Y, PIDget, PIDdefault
	setDimLabel 0, 2, Z, PIDget, PIDdefault
	setDimLabel 0, 3, A, PIDget, PIDdefault
	setDimLabel 1, 0, P, PIDget, PIDdefault
	setDimLabel 1, 1, I, PIDget, PIDdefault
	setDimLabel 1, 2, D, PIDget, PIDdefault
#ifdef STAGE_IS_THREADED
	// thread group number for this stage
	variable/G $"root:packages:" + theStageEncoder + ":stageThread"
	variable/G $"root:packages:" + theStageEncoder + ":stageIsThreaded" = 1
#else
	variable/G $"root:packages:" + theStageEncoder + ":stageIsThreaded" = 0
#endif
end


//*********************************************************************************************
// Sets the global string for serial port to the selected value, and tries to initialize the stage encoder with the port
// Last Modified 2025/12/03 by Jamie Boyd
Function StagePortProc(theStageEncoder, thePortName)
	String theStageEncoder
	String thePortName

	// Save port name in global string in pakages folder for this stage procedure
	SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
	thePort = thePortName
	Funcref StageSetupPort_Template StageSetupPortFunc = $"StageSetUpPort_" + theStageEncoder
	StageSetupPortFunc (thePort) // initilaize the encoder with the chosen port, do whatever needs to be done for this device
	// Do an initial position update and get step increments from encoder (if encoder stores step increments)
	WAVE DistanceFromZero= $"root:packages:" + theStageEncoder + ":DistanceFromZero"
	WAVE Zeros= $"root:packages:" + theStageEncoder + ":AbsoluteZero"
	WAVE StepSize = $"root:packages:" + theStageEncoder + ":StepSize"
	WAVE Properties =  $"root:packages:" + theStageEncoder + ":properties"
	WAVE selectedForCMD=  $"root:packages:" + theStageEncoder + ":selectedForCMD"
	selectedForCMD = 0
	if (Properties [%has_XY])
		selectedForCMD [%X] =1
		selectedForCMD [%Y] =1
	endif
	if (Properties [%has_Z])
		selectedForCMD [%Z] =1
	endif
	if (Properties [%has_Ax])
		selectedForCMD [%A] =1
	endif
#ifdef STAGE_IS_THREADED
	// start Thread running task
	WAVE PIDget = $"root:packages:" + theStageEncoder + ":PIDget"
	NVAR theThread = $"root:packages:" + theStageEncoder + ":stageThread"
	variable result=ThreadGroupRelease(theThread, 0)
	theThread = threadGroupCreate(1)
	ThreadStart theThread, 0, StagePThread (theStageEncoder, DistanceFromZero, Zeros, StepSize, PIDget, Properties)
	// tell thread what port to use
	newdatafolder/s :tdata
	variable/G theCmdG = kThreadSetPort
	string/G thePortG = thePort
	ThreadGroupPutDF theThread, :
	// do an initial update
	newdatafolder/s :tdata
	variable/G theCmdG = kThreadGetPos
	duplicate selectedForCMD selectedG
	WaveClear selectedG
	ThreadGroupPutDF theThread, :
	// Get step increments from encoder
	newdatafolder/s :tdata
	variable/G theCmdG = kThreadGetMvIncr
	duplicate selectedForCMD selectedForCMDG
	duplicate StepSize StepSizeG
	WAVEClear selectedForCMDG, StepSizeG
	ThreadGroupPutDF theThread, :
	// Start touchy background task
	//funcref StageBkgTouch_Template toucher = $"StageBkgTouch_" +  theStageEncoder
	string funcName="StageBkgTouch_" +  theStageEncoder
	string taskName="touchTask_" + theStageEncoder
	CtrlNamedBackground $taskName, proc = $funcName , period = ceil(kAUTO_UPDATE_INT * 60), burst = 0, start
#else
	// do initial update
	funcref  StageUpdate_Template StageUpdate=$"StageUpdate_" + theStageEncoder
	StageUpdate(thePort, selectedForCMD, DistanceFromZero, Zeros, Properties)
	// Get increments
	Funcref StageGetStepIncr_Template StageGetStepIncr = $"StageGetStepIncr_" + theStageEncoder
	StageGetStepIncr(thePort, selectedForCMD, StepSize, Properties)
#endif

end


// *******************************************************************************
// Stage update procedure, updates selected axes
// last modified: 2025/12/19 by Jamie Boyd
Function StageUpdate(theStageEncoder, AxisBits, waitForResult)
	String theStageEncoder
	variable AxisBits
	variable waitForResult
	
	WAVE Properties = $"root:packages:" + theStageEncoder + ":Properties"
	WAVE selected=$"root:packages:" + theStageEncoder + ":selectedForCMD"
	selected = 0
	if (AxisBits & kXbit)
		selected [%X] = 1
	endif
	if (AxisBits & kYbit)
		selected [%Y] = 1
	endif
	if (AxisBits & kZbit)
		selected [%Z] = 1
	endif
	if (AxisBits & kAbit)
		selected [%A] = 1
	endif
#ifdef STAGE_IS_THREADED
	NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
	newdatafolder/s :tdata
	variable/G theCmdG = kThreadGetPos
	duplicate selected selectedG
	WAVEClear selectedG
	ThreadGroupPutDF threadID, :
	if (waitForResult)  // if threaded, it will take time for result to be placed in Distance wave
		do
			sleep/S 0.05
		while (Properties [%BUSY])
	endif
#else
	SVAR thePort =  $"root:packages:" + theStageEncoder + ":thePort"
	WAVE DistanceFromZero= $"root:packages:" + theStageEncoder + ":DistanceFromZero"
	WAVE Zeros= $"root:packages:" + theStageEncoder + ":AbsoluteZero"
	funcref  StageUpdate_Template StageUpdate=$"StageUpdate_" + theStageEncoder
	StageUpdate(thePort, Selected, DistanceFromZero, Zeros, Properties)
#endif
end

// *******************************************************************************
// Gets current axis position by reading from global wave in data folder
// last modified: 2025/12/19 by Jamie Boyd
Function StageGetAxisPos (theStageEncoder, AxisStr)
	string theStageEncoder
	String AxisStr // one of X,Y,Z,A
	
	WAVE DistanceFromZero= $"root:packages:" + theStageEncoder + ":DistanceFromZero"
	return DistanceFromZero[%$AxisStr]
end
	
// *******************************************************************************
// Turns auto-updating of position on or off
// last modified: 2025/12/19 by Jamie Boyd
Function StageSetAuto(theStageEncoder, autoIsOn)
	string theStageEncoder
	variable autoIsOn
	
#ifdef STAGE_IS_THREADED
	NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
	newdatafolder/s :tdata
	if (autoIsOn)
		variable/G theCmdG = kThreadSetAuto
	else
		variable/G theCmdG = kThreadUnSetAuto
	endif
	ThreadGroupPutDF threadID, :
#else
	string procName = "StageBkgUpdate_" + theStageEncoder
	string bkgName= "BkgUpdate_" + theStageEncoder
	if (autoIsOn)
		CtrlNamedBackground $bkgName, proc = $procName, period = (kAUTO_UPDATE_INT * 60), burst = 0, start
	else
		CtrlNamedBackground $bkgName, stop
	endif
#endif
end

// *******************************************************************************
// Zeros the selected axes
// last modified: 2025/12/19 by Jamie Boyd
Function StageSetZero(theStageEncoder, axesBits, waitForResult)
	string theStageEncoder
	variable axesBits
	variable waitForResult
	
	WAVE selected =  $"root:packages:" + theStageEncoder + ":selectedForCMD"
	selected = 0
	if (axesBits & kXbit)
		selected [%X] = 1
	endif
	if (axesBits & kYbit)
		selected [%Y] = 1
	endif
	if (axesBits & kZbit)
		selected [%Z] = 1
	endif
	if (axesBits & kAbit)
		selected [%A] = 1
	endif
#ifdef STAGE_IS_THREADED
	NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
	newdatafolder/s :tdata
	variable/G theCmdG = kThreadSetZero
	duplicate selected selectedG
	WAVEClear selectedG
	ThreadGroupPutDF threadID, :
	if (waitForResult)  // if threaded, it will take time for result to be placed in Distance wave
		do
			sleep/S 0.05
		while (Properties [%BUSY])
	endif
#else
	SVAR thePort =  $"root:packages:" + theStageEncoder + ":thePort"
	WAVE DistanceFromZero= $"root:packages:" + theStageEncoder + ":DistanceFromZero"
	WAVE Zeros= $"root:packages:" + theStageEncoder + ":AbsoluteZero"
	WAVE Properties = $"root:packages:" + theStageEncoder + ":Properties"
	funcref StageSetzero_Template SetZeroProc=$"StageSetzero_" + theStageEncoder
	SetZeroProc (thePort, selected, DistanceFromZero, Zeros, Properties)
#endif
end

// *******************************************************************************
// Clears any pending I/O on the serial port used for the device, in case there any errors
// last modified: 2025/12/19 by Jamie Boyd
Function StageResetIO(theStageEncoder)
	string theStageEncoder
	
	SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
#ifdef STAGE_IS_THREADED
	NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
	newdatafolder/s :tdata
	variable/G theCmdG = kThreadResetIO
	ThreadGroupPutDF threadID, :
#else
	WAVE properties= $"root:packages:" + theStageEncoder + ":Properties"
	funcref StageResetIO_Template ResetIO = $"StageResetIO_" + theStageEncoder
	ResetIO (thePort, properties)
#endif
end

// *******************************************************************************
// enables or disables manual movemet of stage with joystick
// last modified: 2025/12/19 by Jamie Boyd
Function StageSetManual(theStageEncoder, setLock)
	string theStageEncoder
	variable setLock
	
#ifdef STAGE_IS_THREADED
	NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
	newdatafolder/s :tdata
	if (setLock)
		variable/G theCmdG = kThreadSetLock
	else
		variable/G theCmdG = kThreadUnSetLock
	endif
	ThreadGroupPutDF threadID, :
#else
	SVAR thePort =  $"root:packages:" + theStageEncoder + ":thePort"
	WAVE Properties =  $"root:packages:" + theStageEncoder + ":properties"
	funcref StageSetManual_template SetManualProc=$"StageSetManual_" + theStageEncoder
	SetManualProc (thePort, setLock, Properties)
#endif
end

// *******************************************************************************
// Sets the step size that will be used for the StageStep procedure, for movements relative to the current position
// last modified: 2025/12/19 by Jamie Boyd
function StageSetIncrement(theStageEncoder, AxisStr, Increment, doWait)
	string theStageEncoder
	string AxisStr			// One of X, Y, Z, or A
	variable increment		// step size, in metres. Always positive
	variable doWait
	
	WAVE selected = $"root:packages:" + theStageEncoder + ":selectedForCMD"
	WAVE StepSize = $"root:packages:" + theStageEncoder + ":stepSize"
	selected = 0
	selected [%$AxisStr] = 1
	StepSize [%$AxisStr] = Increment
#ifdef STAGE_IS_THREADED
	NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
	newdatafolder/s :tdata
	variable/G theCmdG = kThreadSetMvIncr
	duplicate selected selectedG
	WAVEClear selectedG
	duplicate stepSize, stepSizeG
	WAVEClear stepSizeG
	ThreadGroupPutDF threadID, :
	if (waitForResult)  // if threaded, it will take time for result to be placed in Distance wave
		do
			sleep/S 0.05
		while (Properties [%BUSY])
	endif
#else
	SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
	WAVE Properties =  $"root:packages:" + theStageEncoder + ":properties"
	funcRef StageSetStepIncr_Template StageSetInc = $"StageSetStepIncr" + theStageEncoder
	StageSetInc (thePort, selected, StepSize, Properties)
#endif
end


// *******************************************************************************
// Gets the step size set on the Device for selected axes, and writes them to the StepSizes wave
// last modified: 2025/12/19 by Jamie Boyd
function StageGetIncrement (theStageEncoder, AxisBits, Increment, doWait)
	string theStageEncoder
	variable axisBits
	variable increment
	variable doWait
	
	WAVE selected = $"root:packages:" + theStageEncoder + ":selectedForCMD"
	selected = 0
	if (AxisBits & kXbit)
		selected [%X] = 1
	endif
	if (AxisBits & kYbit)
		selected [%Y] = 1
	endif
	if (AxisBits & kZbit)
		selected [%Z] = 1
	endif
	if (AxisBits & kAbit)
		selected [%A] = 1
	endif
	
#ifdef STAGE_IS_THREADED
	NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
	newdatafolder/s :tdata
	variable/G theCmdG = kThreadGetMvIncr
	duplicate selected selectedG
	WAVEClear selectedG
	ThreadGroupPutDF threadID, :
	if (waitForResult)  // if threaded, it will take time for result to be placed in incremenr wave
		do
			sleep/S 0.05
		while (Properties [%BUSY])
	endif
#else
	SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
	WAVE Properties =  $"root:packages:" + theStageEncoder + ":properties"
	WAVE StepSize = $"root:packages:" + theStageEncoder + ":stepSize"
	funcRef StageGetStepIncr_Template StageSetInc = $"StageSetStepIncr" + theStageEncoder
	StageSetInc (thePort, selected, StepSize, Properties)
#endif
end

// *******************************************************************************
// Gets axis stepSize by reading from global wave in data folder
// last modified: 2025/12/19 by Jamie Boyd
Function StageGetAxisStepSize(theStageEncoder, AxisStr)
	string theStageEncoder
	String AxisStr // one of X,Y,Z,A
	
	WAVE StepSize = $"root:packages:" + theStageEncoder + ":StepSize"
	return StepSize[%$AxisStr]
end


// *******************************************************************************
// Commands the Device to move theAxis a single step, size defined by StageSetIncrement, 
// in the positive or negative direction
// last modified: 2025/12/19 by Jamie Boyd
Function StageStep(theStageEncoder, theAxis, Direction, returnWhen)
	String theStageEncoder
	String theAxis		// one of X,Y,Z,A
	variable Direction  // must be +1 (positive going step) or  -1 (negative going step)
	variable returnWhen
	// set selected axis in selected wave and set polarity
	WAVE Selected =  $"root:packages:" + theStageEncoder + ":selectedForCMD"
	WAVE Polarity = $"root:packages:" + theStageEncoder + ":Polarity"
	Selected = 0
	selected [%$theAxis] = Polarity[%$theAxis] * Direction		
#ifdef STAGE_IS_THREADED
	NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
	newdatafolder/s :tdata
	variable/G returnWhenG = returnWhen
	variable/G theCmdG = kThreadDoStep
	duplicate selected selectedG
	WaveClear selectedG
	ThreadGroupPutDF threadID, :
#else
	funcRef StageMoveRel_Template StageMoveRel = $"StageMoveRel_" + theStageEncoder
	SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
	WAVE Properties =  $"root:packages:" + theStageEncoder + ":properties"
	WAVE StepSize = $"root:packages:" + theStageEncoder + ":stepSize"
	WAVE DistsFromZero = $"root:packages:" + theStageEncoder + ":DistanceFromZero"
	StageMoveRel (thePort, returnWhen, Selected, StepSize, DistsFromZero, Properties)
	if (returnWhen == kStagesReturnBkg)
		string procName = "StageBkgMonitor_" + theStageEncoder
		string bkgName= "BkgMonitor_" + theStageEncoder
		CtrlNamedBackground $bkgName, proc = $procName, period = (kAUTO_UPDATE_INT * 60), burst = 0, start
	endif
#endif
end

// *******************************************************************************
// Commands the Device to move selected axes to an absolute position, i.e., defined as
// distance from the axis 0 position
// last modified: 2025/12/19 by Jamie Boyd
Function StagesSetAbs(theStageEncoder, axisBits, moveToWave, returnWhen)
	string theStageEncoder
	variable axisBits		// bit wise combination, X = 1, Y = 2, Z = 4, A = 8 
	WAVE moveToWave			// 4 point wave with dimension labels X, Y, Z, and A
	variable returnWhen
	
	// selected
	WAVE selected = $"root:packages:" + theStageEncoder + ":selectedForCMD"
	selected =0
	if (axisBits & kXbit)
		selected [%X] =1
	endif
	if (axisBits & kYbit)
		selected [%Y] =1
	endif
	if (axisBits & kZbit)
		selected [%Z] =1
	endif
	if (axisBits & kAbit)
		selected [%A] =1
	endif
#ifdef STAGE_IS_THREADED
	NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
	newdatafolder/s :tdata
	variable/G returnWhenG = returnWhen
	variable/G theCmdG = kThreadGoToPos
	duplicate selected selectedG
	duplicate moveToWave moveToG
	WaveClear selectedG ,moveToG
	ThreadGroupPutDF threadID, :
#else
	funcref StageMoveAbs_Template StageMoveAbs = $"StageMoveAbs_" + theStageEncoder
	SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
	WAVE Properties =  $"root:packages:" + theStageEncoder + ":Properties"
	WAVE DistsFromZero = $"root:packages:" + theStageEncoder + ":DistanceFromZero"
	StageMoveAbs (thePort,returnWhen, selected, moveToWave, DistsFromZero, Properties)
	if (returnWhen == kStagesReturnBkg)
		string procName = "StageBkgMonitor_" + theStageEncoder
		string bkgName= "BkgMonitor_" + theStageEncoder
		CtrlNamedBackground $bkgName, proc = $procName, period = (kAUTO_UPDATE_INT * 60), burst = 0, start
	endif
#endif
end

// *******************************************************************************
// Commands the Device to move selected a single axis to an absolute position, 
// i.e., defined as distance from the axis 0 position
// last modified: 2025/12/19 by Jamie Boyd
Function StagesSetAbsAxis(theStageEncoder, anAxis, moveToPos, returnWhen)
	string theStageEncoder
	string anAxis
	variable moveToPos
	variable returnWhen
	
	variable AxisBits
	strswitch (anAxis)
		case "X":
			AxisBits = kXbit
			break
		case "Y":
			AxisBits = kYbit
			break	
		case "Z":
			AxisBits = kZbit
			break
		case "A":
			AxisBits = kAbit
			break	
	endSwitch
	make/FREE/n=4 moveTo
	moveTo[%$anAxis] = moveToPos
	StagesSetAbs (theStageEncoder, axisBits, moveTo, returnWhen)
end


// ***************************************************************************************************
// ************* Interface code for making and running the Stage Control panel ***********************
// ***************************************************************************************************

//*******************************************************************************************************
// Lists Stage Encoder files in user procedures folder
// Last Modified 2016/10/13 by Jamie Boyd - Added listing of shortcuts that look like stage encoders
function/S StageListEncoders ()

	PathInfo Stages
	if (V_Flag == 0)
		NewPath/q/O Stages,SpecialDirPath("Igor Pro User Files", 0, 0, 0 ) + "User Procedures:Stages:"
	endif
	PathInfo StagesPrefs
	if (V_Flag == 0)
		NewPath/C/Q/O StagesPrefs SpecialDirPath("Preferences" , 0, 0, 0) + "Stages"
	endif
	string emptyFolderStr =  "\\M1(No Stage encoder procedures found."
	string fileAliasExt = ".lnk"
	if (cmpStr ( IgorInfo (2), "Macintosh") ==0)
		fileAliasExt = "alis"
	endif
	string procList = "", Files = GUIPListFiles ("Stages",  ".ipf", "*_Stage.ipf", 12, "") + GUIPListFiles ("Stages",  fileAliasExt, "*_Stage - Shortcut.lnk", 12, "")
	if (cmpstr (Files, "") == 0)
		return emptyFolderStr
	endif
	string afile, aStage
	variable numfiles = itemsinlist (Files), ii, lastPnt
	for (ii=0;ii<numfiles;ii+=1)
		afile= (stringfromlist (ii, Files))
		lastPnt = strlen (aFile) -1
		if ((cmpstr (aFile[lastPnt-5, lastPnt],  "_Stage")) != 0)
			continue
		endif
		aStage = aFile[0, lastPnt-6]
		procList += aStage + ";"
	endfor
	if (strlen (procList) < 2)
		procList = "\\M1( No Stage encoder procedures found."
	endif
	return procList
end

//*********************************************************************************************
// Loads a stage encoder procedure chosen by user and opens a control panel for it.
// also returns the name of the selected encoder
// Last Modified 2015/04/12 by Jamie Boyd
Function/S StageStart()

	string theStageEncoder
	Prompt theStageEncoder, "Choose a Stage Encoder", popup, StageListEncoders ()
	DoPrompt /HELP="Loads a Stage Encoder procedure and makes a simple control panel for it." "Choose a Stage Encoder", theStageEncoder
	if (V_Flag == 1)
		return ""
	endif
	StageStartStage (theStageEncoder)
	return theStageEncoder
end

//****************************************************************************************************************************************************
// Makes a panel for a given stage encoder, with customizations for the encoder, makes globals, and starts thread
// Last Modified 2025/11/26 by Jamie Boyd, moved variablesinto waves that can be shared with the thread
Function StageStartStage(theStageEncoder, [thePort])
	String theStageEncoder
	String thePort

	//If panel exists, bring it to the front and exit
	Dowindow/F $theStageEncoder + "_Controls"
	if (V_Flag ==1)
		return 0
	endif
	// Make global variables folder for this stage encoder - also starts thread and saves thread name in a global variable
	StageMakeGlobals (theStageEncoder)
	// Load the procedure, if not already loaded, and execute the Stage Panel function
	if (exists ("StageSetUpPort_" + theStageEncoder) == 6) // procedure is already loaded
		FUNCREF StageInitGlobals_Template StageInitGlobals= $"StageInitGlobals_" + theStageEncoder
		StageInitGlobals ()
		StageMakePanel (theStageEncoder)
	else // need to load and compile procedures first
		Execute/P/Q "INSERTINCLUDE \"" + theStageEncoder + "_Stage\""  //e.g., MS2000_Stage.ipf
		Execute/P/Q "COMPILEPROCEDURES "
		Execute/P/Q "StageInitGlobals_" + theStageEncoder + "()"
		Execute/P/Q "StageMakePanel(\"" + theStageEncoder + "\")"
	endif
	if (!(ParamIsDefault(thePort )))
		Execute/P/Q "StagePortProc(\"" + theStageEncoder + "\", \"" + thePort +  "\")"
	endif
end


//*********************************************************************************************
//Returns a list of available serial ports for use with stage encoders using VDTGetPortList2
// Last Modified 2025/11/28 by Jamie Boyd
Function/S StageListPorts ()
	string returnStr=""
	VDTGetPortList2/SCAN
	return S_VDT
end


//*******************************************************************************
// Opens a control panel for common stage related functions
// Has controls for both reading and setting stage coordinates
// Last modified 2025/11/26 by Jamie Boyd - uses waves instead of variables
// modified 2025/07/08 by Jamie Boyd - use new GUIPSIsetVarEnable function
Function StageMakePanel (theStageEncoder)
	string theStageEncoder

	//If panel exists, bring it to the front and exit
	Dowindow/F $theStageEncoder + "_Controls"
	if (V_Flag ==1)
		return 0
	endif
	variable optionsBoxWidth = 159
	variable AxisBoxWidth = 152
	variable BoxHeight = 152
	// Reference the string for port name and the wave for properties
	SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
	WAVE Properties = $"root:packages:" + theStageEncoder + ":Properties"
	WAVE distanceFromZero =$"root:packages:" + theStageEncoder + ":DistanceFromZero"
	WAVE StepSize = $"root:packages:" + theStageEncoder + ":stepSize"
	WAVE moveTo = $"root:packages:" + theStageEncoder + ":MoveTo"
	// How wide do we need to make the panel?
	variable nAxes = 2*Properties[%has_XY] + Properties[%has_Z] + Properties[%has_Ax]
	variable panelW = optionsBoxWidth + nAxes * AxisBoxWidth
	NewPanel /K=1 /W=(2, 44, (2 + panelW), 198) as "Stage/Focus Controls-" + theStageEncoder
	DoWindow/C $theStageEncoder + "_Controls"
	modifypanel fixedsize = 1
	// Options are always at left, followed by boxes for varying numbers of axes
	GroupBox OptionsGrp,pos={1,2},size={optionsBoxWidth,BoxHeight},title="Options",fSize=16,fStyle=1
	// Update position values
	Button UpdateButton,pos={4.00,24.00},size={56.00,24.00},proc=StageUpdateButtonProc
	Button UpdateButton,title="Update",fSize=14
	Button UpdateButton,help={"Gets the current position values for all axes."}
	// Auto update position Values in a bkg task
	CheckBox autoCheck,pos={62,28},size={42,15},proc=StageAutoCheckProc,title="Auto"
	CheckBox autoCheck, wave= properties[%is_auto]
	CheckBox autoCheck,value= 0,help={"Starts/Stops a background task (or thread) to automatically update positions."}
	// Set zero
	Button StageSetzeroButton,pos={115,24},size={40,20},proc=StageSetzeroButtonProc,title="Zero"
	Button StageSetzeroButton,help={"Sets current position as 0 reference position for all of the axes."}
	// Popup and titlebox for serial port
	string portList = ""
	PopupMenu thePortPopup pos={4,54},size={59,21}, mode=0, proc=Stages_PortPopMenuProc
	TitleBox thePortTitle, pos={53,56}, size={38,21}, variable = thePort
	PopupMenu thePortPopup, value= #"stageListPorts()",  title="Port:", help = {"Choose a serial port to use with this stage encoder."}
	TitleBox thePortTitle help = {"Shows the serial port used by this stage encoder."}
	portList =StageListPorts ()
	// Clear serial buffer button
	Button ResetIOButton,pos={99.00,53.00},size={56.00,20.00},proc=StageResetIOButtonProc,title="Clear Buf"
	Button ResetIOButton,help={"Clears spurious characters that may be remaining in the serial port input/output buffer."}
	// Toggle maual
	if ((Properties[%has_Mtr]) && (Properties[%has_Lock]))
		CheckBox ManualToggleCheck,pos={5,80},size={84,15},proc=StageSetManualCheckProc,title="Manual Lock"
		CheckBox ManualToggleCheck,wave= Properties[%is_Locked]
		CheckBox ManualToggleCheck, help = {"Inactivates manual, but not computer controlled, movement on all axes."}
	endif
	// Open PID Panel
	if (Properties[%has_PID])
		Button PIDButton,pos={105.00,76.00},size={48.00,20.00},proc=StagePIDButtonProc ,title="Set PID"
		Button PIDButton,help={"Opens a panel where proportional-integral-derivative settings for this encoder can be adjusted. Use at your own risk."}
	endif
	// Error indicator for this stage encoder, have to use execute to make dependency formula
	ValDisplay hasErrValDisp,pos={6,133},size={48,18},title="error", help = {"\"Glows\" orange when stage has an error, usually serial port error."}
	ValDisplay hasErrValDisp,limits={-1,1,0},barmisc={0,0},mode= 1,highColor= (65280,21760,0),lowColor= (56576,56576,56576)
	string pathstr= "root:packages:" + theStageEncoder + ":properties[%ERR]"
	string commandStr = "ValDisplay hasErrValDisp value=" + pathstr
	execute commandStr
	// button to save a formatted string containing positions
	Button SavePosButton,pos={63,130},size={48,20},proc=StageSavePosButtonProc,title="Sv Pos"
	Button SavePosButton, help = {"Opens a dialog to save current stage position for later recall."}
	if (Properties[%has_Mtr])
		PopupMenu StageGoToPopMenu,pos={114,130},size={39,21},proc=StageGoToSavedPopMenuProc,title="Go"
		PopupMenu StageGoToPopMenu,help={"Sends the stage to the selcted saved position."}
		PopupMenu StageGoToPopMenu,mode=0,value=# "StageListSavedPos() + \"\\\\M1(-;Edit Position Wave\""
	endif
	//Add axes as required: all controls are placed with x-position relative to an offset
	variable xOffset = optionsBoxWidth
	// first comes XY Stage
	if (Properties[%has_XY])
		GroupBox StageXYGroup,pos={(xOffset),2},size={(2*AxisBoxWidth),boxHeight},title="Stage/XY",fSize=16,frame=1,fStyle=1
		// X Position
		TitleBox XTitle,pos={(xOffset + 4),20},size={15,24},title="X",fSize=20,frame=0,fStyle=1
		SetVariable XDistanceSetVar,pos={(xOffset+20),24.00},size={121.00,22.00}
		SetVariable XDistanceSetVar,title="Pos",value=DistanceFromZero[%X],fSize=14, noedit=1
		GUIPSIsetVarEnable ("", "XDistanceSetVar", "", -INF, INF, 0, 0, 0, 3, "m")
		// Y Position
		TitleBox YTitle,pos={(xOffset + 144),20.00},size={12.00,28.00},title="Y",fSize=20, frame=0,fStyle=1
		SetVariable YDistanceSetVar, pos={(xOffset + 159),24.00},size={114.00,22.00}
		SetVariable YDistanceSetVar,title="Pos",value=DistanceFromZero[%Y],fSize=14, noedit=1
		GUIPSIsetVarEnable ("", "YDistanceSetVar", "", -INF, INF, 0, 0, 0, 3, "m")
		if (Properties[%has_Mtr])
			// X steps
			Button XrightStepButton,pos={(xOffset + 33),50.00},size={88.00,20.00},proc=StageStepButtonProc
			Button XrightStepButton,title="Right 1 Step"
			Button XleftStepButton,pos={(xOffset + 33),73.00},size={88.00,20.00},proc=StageStepButtonProc
			Button XleftStepButton,title="Left 1 step"
			// X step size setvar
			SetVariable XstepSizeSetvar,pos={(xOffset + 2),97.00},size={134.00,18.00},title="Step Size",value=StepSize[%X],fSize=12
			GUIPSIsetVarEnable ("", "XstepSizeSetvar", "StageSetIncSetvarProc", Properties[%res_XY], INF, Properties[%res_XY], 1, Properties[%res_XY], 2, "m")
			// Y steps
			Button YForwardStepButton,pos={(xOffset + 169),50.00},size={88.00,20.00},proc=StageStepButtonProc
			Button YForwardStepButton,title="Forward 1 Step"
			Button YBackStepButton,pos={(xOffset + 169),73.00},size={88.00,20.00},proc=StageStepButtonProc
			Button YBackStepButton,title="Back 1 Step"
			// Y step size setvar
			SetVariable YstepSizeSetvar,pos={(xOffset + 143),97.00},size={134.00,18.00},title="Step Size",value=StepSize[%Y],fSize=12
			GUIPSIsetVarEnable ("", "YstepSizeSetvar", "StageSetIncSetvarProc", Properties[%res_XY], INF, Properties[%res_XY], 1, Properties[%res_XY], 2, "m")
			// XY go to
			Button XYGoToButton,pos={(xOffset + 2), 129.00},size={39.00,20.00},proc=StagesSetAbsButtonProc,title="Go To"
			SetVariable XGoToSetVar,pos={(xOffset + 46),130.00},size={106.00,18.00},fSize=12, value=moveTo[%X]
			GUIPSIsetVarEnable ("", "XGoToSetVar", "", Properties[%min_X], Properties[%max_X], 0, 0, 0, 3, "m")
			SetVariable YGoToSetVar,pos={(xOffset + 160),130.00},size={114.00,18.00}, fSize=12,value=moveTo[%Y]
			GUIPSIsetVarEnable ("", "YGoToSetVar", "", Properties[%min_Y], Properties[%max_Y], 0, 0, 0, 3, "m")
		endif
		xOffset += 2*AxisBoxWidth
	endif
	// Add Z controls, if present
	if (Properties[%has_Z])
		GroupBox FocusGroup,pos={(xOffset),2},size={AxisBoxWidth,BoxHeight},title="Focus/Z",fSize=16,fStyle=1
		TitleBox ZTitle,pos={(xOffset + 4),20},size={15,24},title="Z",fSize=20,frame=0,fStyle=1
		SetVariable ZDistanceSetVar,pos={(xOffset+20),24.00},size={121.00,22.00}
		SetVariable ZDistanceSetVar,title="Pos",value=DistanceFromZero[%Z],fSize=14, noedit=1
		GUIPSIsetVarEnable ("", "ZDistanceSetVar", "", -INF, INF, 0, 0, 0, 3, "m")
		if (Properties[%has_Mtr])
			Button ZUpStepButton,pos={(xOffset + 33), 50},size={88.00,20.00},proc=StageStepButtonProc
			Button ZUpStepButton,title="Up 1 Step"
			Button ZDownStepButton,pos={(xOffset + 33),73.00},size={88.00,20.00},proc=StageStepButtonProc
			Button ZDownStepButton,title="Down 1 Step"
			SetVariable ZStepSizeSetVar,pos={(xOffset + 4),97.00},size={134.00,18.00}
			SetVariable ZStepSizeSetVar,title="Step Size", fsize=12,value=StepSize[%Z]
			GUIPSIsetVarEnable("", "ZstepSizeSetvar", "StageSetIncSetvarProc", Properties[%res_Z], INF, Properties[%res_Z], 1, Properties[%res_Z], 2, "m")
			Button ZGoToButton,pos={(xOffset + 2), 129.00},size={39.00,20.00},proc=StagesSetAbsButtonProc,title="Go To"
			SetVariable ZGoToSetVar,pos={(xOffset + 46),130.00},size={106.00,18.00},fSize=12, value=MoveTo[%Z]
			GUIPSIsetVarEnable("", "ZGoToSetVar", "", Properties[%min_Z], Properties[%max_Z], 0, 0, 0, 3, "m")
		endif
		xOffset += AxisBoxWidth
	endif
	// Add Axial controls, if Present
	if (Properties[%has_Ax])
		GroupBox AxisGroup,pos={(xOffset),2},size={AxisBoxWidth,boxHeight},title="Axial",fSize=16,fStyle=1
		TitleBox Axtitle,pos={(xOffset + 4),20},size={15,24},title="A",fSize=20,frame=0,fStyle=1
		SetVariable AxDistanceSetVar,pos={(xOffset + 20),24},size={121, 22}
		SetVariable AxDistanceSetVar, title="Pos", value= DistanceFromZero[%A], fSize=14, noedit=1
		GUIPSIsetVarEnable("", "AxDistanceSetVar", "", -INF, INF, 0, 0, 0, 3, "m")
		if (Properties[%has_Mtr])
			Button AxOutStepButton,pos={(xOffset + 33), 50},size={88.00,20.00},proc=StageStepButtonProc
			Button AxOutStepButton,title="Out 1 Step"
			Button AxInStepButton,pos={(xOffset + 33),73.00},size={88.00,20.00},proc=StageStepButtonProc
			Button AxInStepButton,title="In 1 Step"
			SetVariable AxStepSizeSetVar,pos={(xOffset + 4),97.00},size={134.00,18.00}
			SetVariable AxStepSizeSetVar,title="Step Size", fsize=12,value=StepSize[%A]
			GUIPSIsetVarEnable("", "AxstepSizeSetvar", "StageSetIncSetvarProc", Properties[%res_Ax], INF, Properties[%res_Ax], 1,  Properties[%res_Ax], 2, "m")
			Button AxGoToButton,pos={(xOffset + 2), 129.00},size={39.00,20.00},proc=StagesSetAbsButtonProc,title="Go To"
			SetVariable AxGoToSetVar,pos={(xOffset + 46),130.00},size={106.00,18.00},fSize=12, value=MoveTo[%A]
			GUIPSIsetVarEnable("", "AxGoToSetVar", "", Properties[%min_Ax], Properties[%max_Ax], 0, 0, 0, 2, "m")
			xOffset += AxisBoxWidth
		endif
	endif
	// invite stage encoder to put up any special controls it has
	Funcref StageAddControls_Template StageAddFunc = $"StageAddControls_" + theStageEncoder
	StageAddFunc(4, 97, theStageEncoder + "_Controls") // 4,97 are X and Y offset to where special controls can be placed
	DoUpdate /W=$theStageEncoder + "_Controls" /E=1
	// Set hook function to close port when panel is closed
	setwindow $theStageEncoder + "_Controls"  hook(QHook)=StageClosePortAndPanel
	WC_WindowCoordinatesRestore(theStageEncoder + "_Controls")
	// Check serial ports and set port if only one is found
	variable Numports = ItemsInList (portList)
	switch (numports)
		case 0:	// no ports/devices found
			doalert 0, "No Serial Ports were found, so stage/focus controls can not be used."
			DoWindow/K $theStageEncoder + "_Controls"
			return 1
			break
		case 1:	// one  port/device found. No need to make user choose, choose for user
			StagePortProc(theStageEncoder, stringfromlist (0, portList, ";"))
			break
		default:	// more than one serial port.
			thePort = "SELECT PORT"
			break
	endswitch
end


//*************************************************************************************************
// hook function to close the serial port when the panel is closed, although Igor will do this when it quits, so is only needed if you want to use the serial port with another
// program while Igor is still running, or use a different encoder/port combination.
Function StageClosePortAndPanel(s)
	STRUCT WMWinHookStruct &s

	string theEncoder = stringfromlist (0, s.winName, "_")
	switch(s.eventCode)
		case 2: // Handle Kill
			WC_WindowCoordinatesSave(s.WinName)
			// Call Stage's closeport function
			FuncRef StageClose_Template StageCloseFunc =  $"StageClose_" + theEncoder
			SVAR thePort =$"root:packages:" + theEncoder + ":thePort"
			StageCloseFunc (thePort)
#ifdef STAGE_IS_THREADED
			// release thread
			NVAR threadID= $"root:packages:" + theEncoder + ":stageThread"
			variable Result = ThreadGroupRelease(threadID)
			if (Result)
				printf "Stage Thread for %s was not stopped.\r", theEncoder
			endif
#endif
			return 1
			break
		default:
			return 0
			break
	endswitch
End


//*********************************************************************************************
//When a serial port is selected, calls StagePortProc with port name
// Last Modified Jul 11 2011 by Jamie Boyd
Function Stages_PortPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			//Control panel is named for the stageEncoder procedure
			string theStageEncoder = stringfromlist (0, pa.win, "_")
			String thePort = pa.popStr
			StagePortProc(theStageEncoder, thePort)
			break
	endswitch
	return 0
End


//*******************************************************************************
//------------------Controls for Options Section--------------------------------
//*******************************************************************************
// Button Procedure for Update - updates ALL the axes 
// Last modified 2025/12/19 by Jamie Boyd
Function StageUpdateButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			WAVE Properties = $"root:packages:" + theStageEncoder + ":Properties"
			variable axisBits = 0
			if (Properties[%has_XY])
				axisBits += (kXbit + kYbit)
			endif
			if (Properties[%has_Z])
				axisBits += kZbit
			endif
			if (Properties[%has_Ax])
				axisBits += kAbit
			endif
			StageUpdate (theStageEncoder, AxisBits, 0)
			break
	endswitch
	return 0
End


//*******************************************************************************
// check box proc for background task to monitor stage position
// Turns on and off stage's background task to monitor stage position, or does it in thread
// Last modified 2025/12/16 by Jamie Boyd
Function StageAutoCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, cba.win, "_")
			StageSetAuto (theStageEncoder, cba.checked)
	endswitch
	return 0
End


//*******************************************************************************
// setZero Button Procedure - sets all axes such that current position is zero position
// Last modified 2025/12/19 by Jamie Boyd
Function StageSetzeroButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			WAVE Properties =  $"root:packages:" + theStageEncoder + ":properties"
			variable axesBits= 0
			if (Properties [%has_XY])
				axesBits += (kXBit + kYbit)
			endif
			if (Properties [%has_Z])
				axesBits += kZbit
			endif
			if (Properties [%has_Ax])
				axesBits += kAbit
			endif
			StageSetZero (theStageEncoder, axesBits, 0)
			break
	endswitch
	return 0
End


//*******************************************************************************
// button procedure for Reset IO Clears any pending I/O on the serial port used for the focus motor, in case there any errors
// Last modified 2025/11/26 by Jamie Boyd
Function StageResetIOButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			StageRestIO (theStageEncoder)
			break
	endswitch
	return 0
End


//*******************************************************************************
//---------------functions for controls for moving motorized stage--------------
// For move controls, default is to return immediately, and assume we got there.
// Shift key held down will only return when position has been obtained
// Command/ctrl will set a background task to monitor position.
//*******************************************************************************


//*******************************************************************************
// CheckBox procedure for disabling manual control so no accidental joystick bumping during crucial experimental sequence
// Last modified 2025/11/27 by Jamie Boyd
Function StageSetManualCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, cba.win, "_")
			StageSetManual (theStageEncoder, cba.checked)
			break
	endswitch
	return 0
End


//*******************************************************************************
// Setvariable Procedure for setting step increments for each step of the stepping buttons.
// Not all stage encoders support storing the increment on the stage encoder, but it is
// always stored in the wave that is linked to the corresponding setvariable controls
// Last modified 2025/11/27 by Jamie Boyd
Function StageSetIncSetvarProc (sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
		case 1: // mouse up
		case 8: // Enter key
			string theStageEncoder = stringfromlist (0, sva.win, "_")
			string AxisStr
			strswitch (sva.ctrlName)
				case "XstepSizeSetvar":
					AxisStr= "X"
					break
				case "YstepSizeSetvar":
					AxisStr= "Y"
					break
				case "zStepSizeSetVar":
					AxisStr= "Z"
					break
				case "axStepSizeSetVar":
					AxisStr= "A"
					break
				default:
					doalert 0, "StageSetIncSetvarProc was not expecting a control named \"" + sva.ctrlname + "\"."
					return 1
					break
			endSwitch
			StageSetIncrement (theStageEncoder, AxisStr, sva.dval, 0)
	endSwitch
	return 0
End


//*******************************************************************************
// Button Proc to Step stage in predefined increments
// Last Modified 2025/11/27 by Jamie Boyd
Function StageStepButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// check for return mode
			variable returnWhen = kStagesReturnNow
			if (ba.eventMod & 2)
				returnWhen = kStagesReturnAfter
			elseif (ba.eventmod & 8)
				returnWhen = kStagesReturnBkg
			endif
			// read stage proc name from control panel
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			variable direction
			string anAxis
			strswitch (ba.ctrlName)
				case "XleftStepButton":
					anAxis = "X"
					direction = -1
					break
				case "XrightStepButton":
					anAxis = "X"
					direction = +1
					break
				case "YBackStepButton":
					anAxis = "Y"
					direction = -1
					break
				case "YForwardStepButton":
					anAxis = "Y"
					direction = +1
					break	
				case "ZDownStepButton":
					anAxis = "Z"
					direction = -1
					break
				case "ZUpStepButton":
					anAxis = "Z"
					direction = +1
					break
				case "AxOutStepButton":
					anAxis = "A"
					direction = -1
					break
				case "AxInStepButton":
					anAxis = "A"
					direction = +1
					break
				default:
					doAlert 0, "StageStepButtonProc was not expecting a control named \"" + ba.ctrlName + "\"."
					return 1
					break
			endswitch
			StageStep (theStageEncoder, anAxis, Direction, returnWhen)
	endSwitch
	return 0
End

//*******************************************************************************
// Button Proc to move stage to absolute position
// Last Modified 2025/11/27 by Jamie Boyd
Function StagesSetAbsButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// check for return mode
			variable returnWhen = kStagesReturnNow
			if (ba.eventMod & 2)
				returnWhen = kStagesReturnAfter
			elseif (ba.eventmod & 8)
				returnWhen = kStagesReturnBkg
			endif
			// read stage proc name from control panel
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			variable axisBits =0
			strswitch (ba.ctrlName)
				case "XYGoToButton":
					axisBits += kXbit + kYbit
					break
				case "ZGoToButton":
					axisBits += kZbit
					break
				case "AxGoToButton":
					axisBits += kAbit
					break
			endSwitch
			WAVE moveToWave = $"root:packages:" + theStageEncoder + ":MoveTo"
			StagesSetAbs (theStageEncoder, axisBits, moveToWave, returnWhen)
		case -1: // control being killed
			break
	endswitch
	return 0
End



//*******************************************************************************
//---------------functions for saving and going to positions --------------
// For go to position button, default is to return immediately, and assume we got there.
// Shift key held down will only return when position has been obtained
// Command/ctrl will set a background task to monitor position.
//*******************************************************************************


//*************************************************************************************************************
// Saves current stage coordinates in a special wave in the Stages folder
// Last modified 2025/11/28 by Jamie Boyd
Function StageSavePosButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// get name of Stage encoder and some info
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			WAVE Properties = $"root:Packages:" + theStageEncoder + ":Properties"
			WAVE DistanceFromZero =  $"root:packages:" + theStageEncoder + ":DistanceFromZero"
			// get name for this set of coordinates, and select axes to save.
			// after the prompt runs, axes to save will be set to 1, either by code or by user choice
			string PosString
			Prompt PosString, "Name for saved coordinates:"
			variable doXY, doZ, doAx
			Prompt doXY, "Save XY Position:",  popup,"Yes;No"
			Prompt doZ, "Save Z Position:",  popup,"Yes;No"
			Prompt doAx "Save Axial Position:", popUp, "Yes;No"
			// Only ask to save things this stage has installed
			if (Properties[%has_XY])
				if (Properties[%has_Z])
					if (Properties[%has_Ax])
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString, doXY, doZ, doAx
					else // has XY and Z, but not axial
						doAx = 2 // Don't save axial
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString, doXY, doZ
					endif
				else // Has XY but not Z
					doZ = 2
					if (Properties[%has_Ax])
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString, doXY, doAx
					else // has XY only
						doXY =1 // of course you are going to save XY  - it's all you have!
						doax =2
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString
					endif
				endif
			else // does not have XY
				doXY =2
				if (Properties[%has_Z])
					if (Properties[%has_Ax]) // has Z and Ax
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString, doZ, doAx
					else // Only has Z
						doZ=1
						doAx=2
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString
					endif
				else // does not have XY or Z
					if (Properties[%has_Ax]) // only has axial - possible?
						doZ=2
						doAx=1
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString
					else // stage encode has no coordinate system
						doAlert 0, "You must have stage enocders configured incorrectly, or are working in unseen dimensions."
						return 1
					endif
				endif
			endif
			if (V_Flag == 1)// user cancelled
				return 1
			endif
			// Find row to insert point
			variable iPos
			wave/z savedPosWave = $"root:packages:" + theStageEncoder + ":SavedPosWave"
			if (!(waveExists (savedPosWave)))
				make/n = (1,4)  $"root:packages:" + theStageEncoder + ":SavedPosWave"
				wave savedPosWave =  $"root:packages:" + theStageEncoder + ":SavedPosWave"
				setdimlabel 1,0, X_Pos savedPosWave
				setdimlabel 1,1, Y_Pos savedPosWave
				setdimlabel 1,2, Z_Pos savedPosWave
				setdimlabel 1,3, axial_Pos savedPosWave
				iPos =0
			else
				variable nPos = dimsize (savedPosWave,0)
				for (iPos =0; iPos < nPos && cmpStr (PosString,  GetDimLabel(savedPosWave, 0, iPos)) != 0 ; iPos += 1)
				endfor
				if (iPos == nPos)
					insertPoints iPos, 1, savedPosWave
				else
					DoAlert 1, "A saved position with the name \"" +PosString + "\" already exists. Overwrite position?"
					if  (V_Flag == 2) // no was clicked
						return 1
					endif
				endif
			endif
			// Fill in data, as requested, or Nans
			SetDimLabel 0,iPos, $cleanupName (PosString, 0),savedPosWave
			if (doXY ==1)
				savedPosWave [iPos] [%X_Pos] = DistanceFromZero[%X]
				savedPosWave [iPos] [%Y_Pos] = DistanceFromZero[%Y]
			else
				savedPosWave [iPos] [%X_Pos] = NaN
				savedPosWave [iPos] [%Y_Pos] = NaN
			endif
			if (doZ ==1)
				savedPosWave [iPos] [%Z_Pos] = DistanceFromZero[%Z]
			else
				savedPosWave [iPos] [%Z_Pos] = Nan
			endif
			if (doAx == 1)
				savedPosWave [iPos] [%axial_pos] = DistanceFromZero[%A]
			else
				savedPosWave [iPos] [%axial_pos] = NaN
			endif
			break
	endswitch
	return 0
End



//*************************************************************************************************************
// Returns a list of saved stage positions. The names of the positions are stored in the rows dimension label
// Last Modified Oct 13 2010 by Jamie Boyd
Function/S StageListSavedPos ()

	string theStageEncoder = stringfromlist (0, stringfromlist (0, WinList("*_Controls", ";", "" ) , "_"))
	string returnStr = ""
	wave/z PosWave = $"root:packages:" + theStageEncoder + ":SavedPosWave"
	if (!(waveExists (posWave)))
		return returnStr
	endif
	variable iPos, nPos = dimsize (poswave, 0)
	for (iPos =0;iPos < nPos; iPos +=1)
		returnStr +=GetDimLabel(PosWave, 0, iPos )  + ";"
	endfor
	return returnStr
end

//*************************************************************************************************************
//Sends the stage to the selected  saved stage position.
// Last Modified 2025/11/28 by Jamie Boyd
Function StageGoToSavedPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, pa.win, "_")
			wave/z PosWave = $"root:packages:" + theStageEncoder + ":SavedPosWave"
			if (!(waveExists (PosWave)))
				doalert 0, "First save some stage positions with the \"Sv Pos\" button."
				return 0
			endif
			// edit Wave?
			if (cmpStr (pa.popStr, "Edit Position Wave") == 0)
				doWindow/F $theStageEncoder + "SavedPos_table"
				if (V_Flag == 1)
					return 0
				else
					edit/K=1 posWave.ld as "Saved Stage Positions " + theStageEncoder
					doWindow/C $theStageEncoder + "SavedPos_table"
					return 0
				endif
			endif
			variable returnWhen = kStagesReturnNow
			if (pa.eventMod & 2)
				returnWhen =kStagesReturnAfter
			elseif (pa.eventmod & 8)
				returnWhen = kStagesReturnBkg
			endif
			SVAR thePort =  $"root:packages:" + theStageEncoder + ":thePort"
			WAVE selectedForCMD =  $"root:packages:" + theStageEncoder + ":selectedForCMD"
			selectedForCMD = 0
			WAVE MoveTo =  $"root:packages:" + theStageEncoder + ":moveTo"
			WAVE DistsFromZero = $"root:packages:" + theStageEncoder + ":DistsFromZero"
			WAVE Properties =  $"root:packages:" + theStageEncoder + ":Properties"
			Variable pos = pa.popNum -1
			if (numtype ( PosWave [pos] [%X_Pos]) ==0)
				selectedForCMD [%X] =1
				MoveTo [%X] =  PosWave [pos] [%X_Pos]
			endif
			if (numtype ( PosWave [pos] [%Y_Pos]) ==0)
				SelectedforCmd [%Y] =1
				MoveTo [%Y] =  PosWave [pos] [%Y_Pos]
			endif
			if (numtype ( PosWave [pos] [%Z_Pos]) ==0)
				SelectedforCmd [%Y] =1
				MoveTo [%Z] =  PosWave [pos] [%Z_Pos]
			endif
			if (numtype ( PosWave [pos] [%axial_Pos]) ==0)
				SelectedforCmd [%A] =1
				MoveTo [%A] =  PosWave [pos] [%axial_Pos]
			endif
#ifdef STAGE_IS_THREADED
			NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
			newdatafolder/s :tdata
			variable/G returnWhenG = returnWhen
			variable/G theCmdG = kThreadGoToPos
			duplicate selectedForCMD SelectedG
			duplicate MoveTo movetoG
			WaveClear SelectedG, movetoG
			ThreadGroupPutDF threadID, :
#else
			funcref StageMoveAbs_Template    StageMoveAbs = $"StageMoveAbs_" + theStageEncoder
			SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
			WAVE Properties =  $"root:packages:" + theStageEncoder + ":Properties"
			WAVE DistsFromZero = $"root:packages:" + theStageEncoder + ":DistanceFromZero"
			StageMoveAbs (thePort,returnWhen, selectedForCMD, moveTo, DistsFromZero, Properties)
#endif
			break
	endswitch
	return 0
End

//*************************************************************************************************************
// ********************************* Code for PID panel and controls ******************************************
//*************************************************************************************************************



//*************************************************************************************************************
// Code to put up a separate panel to adjust PID. For those encoders that support that sort of thing.
// Last Modified 2025/12/01 by Jamie Boyd
Function StagePIDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			WAVE Properties = $"root:packages:" + theStageEncoder + ":Properties"
			if (!(Properties[%has_PID]))
				doAlert 0, "This stage encoder, \"" + theStageEncoder + "\", does not support setting PID."
				return 0
			endif
			doWindow/F $theStageEncoder + "_PID"
			if (V_Flag ==1)
				return 0
			endif
			WAVE PIDGet = $"root:packages:" + theStageEncoder + ":PIDget"
			WAVE Selected = $"root:packages:" + theStageEncoder + ":selectedForCMD"
			//what axes are available?
			variable nAxes = 2*Properties[%has_XY] + Properties[%has_Z] + Properties[%has_Ax]
			// make the panel the calculated size for axes present
			variable panelW = nAxes * 116 + 1
			NewPanel /K=1 /W=(2,44, (panelW), 155) as "PID Settings-" + theStageEncoder
			DoWindow/C $theStageEncoder + "_PID"
			modifypanel fixedsize = 1
			// add controls for each axis
			variable xOffset=1
			if (Properties[%has_XY])
				// Controls for X
				// group box
				GroupBox XGrp,pos={(xOffset),0},size={115,110},title="X PID",fSize=16,fStyle=1
				// set variables for P,I,and D
				SetVariable XPsetVar,pos={(xOffset + 3),26},size={105,16},title="Proportional"
				SetVariable XPsetVar,help={"Weights: the current error. Larger value = faster response, but greater instability and possible oscillation."}
				SetVariable XPsetVar,limits={-inf,inf,0},value= PIDGet[%X][%P]
				SetVariable XIsetVar,pos={(xOffset + 3),44},size={105,16},title="Integral       "
				SetVariable XIsetVar,help={"Weights: the sum of recent errors. Larger values= errors eliminated more quickly, but with larger overshoot.\""}
				SetVariable XIsetVar,limits={-inf,inf,0}, value= PIDGet[%X][%I]
				SetVariable XDsetVar,pos={(xOffset + 3),62},size={105,16},title="Derivative   "
				SetVariable XDsetVar,help={"Weights: rate the error has been changing. Larger value = less overshoot, but slower transient response, possible instability."}
				SetVariable XDsetVar,limits={-inf,inf,0},value = PIDGet[%X][%D]
				// Buttons for Getting and Setting PID from stage encoder and reverting to default values
				Button XPIDgetButton,pos={(xOffset + 4),85},size={28,20},title="Get", proc = Stages_GetPIDButtonProc
				Button XPIDgetButton,help={"Fetches the PID values currently set for the X axis"}
				Button XPIDsetButton,pos={(xOffset + 33),85.00},size={28.00,20.00},proc=Stages_SetPIDButtonProc,title="Set"
				Button XPIDsetButton,help={"Sets the PID values for the X axis"}
				Button XPIDdefaultButton,pos={(xOffset + 63),85.00},size={48.00,20.00},proc=Stages_RevertPIDButtonProc,title="default"
				Button XPIDdefaultButton,help={"Sets the PID values for X axis to default  values stored as constants in the stage-specific procedure file"}
				xOffset += 115
				// Controls for Y
				GroupBox YGrp,pos={(xOffset),0},size={115,110},title="Y PID",fSize=16,fStyle=1
				// set variables for P,I,and D
				SetVariable YPsetVar,pos={(xOffset + 3),26},size={105,16},title="Proportional"
				SetVariable YPsetVar,help={"Weights: the current error. Larger value = faster response, but greater instability and possible oscillation."}
				SetVariable YPsetVar,limits={-inf,inf,0},value= PIDGet[%Y][%P]
				SetVariable YIsetVar,pos={(xOffset + 3),44},size={105,16},title="Integral       "
				SetVariable YIsetVar,help={"Weights: the sum of recent errors. Larger values= errors eliminated more quickly, but with larger overshoot.\""}
				SetVariable YIsetVar,limits={-inf,inf,0}, value= PIDGet[%Y][%I]
				SetVariable YDsetVar,pos={(xOffset + 3),62},size={105,16},title="Derivative   "
				SetVariable YDsetVar,help={"Weights: rate the error has been changing. Larger value = less overshoot, but slower transient response, possible instability."}
				SetVariable YDsetVar,limits={-inf,inf,0},value = PIDGet[%Y][%D]
				// Buttons for Getting and Setting PID from stage encoder and reverting to default values
				Button YPIDgetButton,pos={(xOffset + 4),85},size={28,20},title="Get", proc = Stages_GetPIDButtonProc
				Button YPIDgetButton,help={"Fetches the PID values currently set for the Y axis"}
				Button YPIDsetButton,pos={(xOffset + 33),85.00},size={28.00,20.00},proc=Stages_SetPIDButtonProc,title="Set"
				Button YPIDsetButton,help={"Sets the PID values for the Y axis"}
				Button YPIDdefaultButton,pos={(xOffset + 63),85.00},size={48.00,20.00},proc=Stages_RevertPIDButtonProc,title="default"
				Button YPIDdefaultButton,help={"Sets the PID values for Y axis to default  values stored as constants in the stage-specific procedure file"}
				//pS=1; iS=1; dS=1
				//FetchPID ("Y", pS, iS, dS)
			endif
			if (Properties[%has_Z])
				xOffset += 115
				// group box
				GroupBox ZGrp,pos={(xOffset),0},size={115,110},title="Z PID",fSize=16,fStyle=1
				// Set variables for P, I, and D
				SetVariable ZPsetVar,pos={(xOffset + 3),26},size={105,16},title="Proportional"
				SetVariable ZPsetVar,help={"Weights: the current error. Larger value = faster response, but greater instability and possible oscillation."}
				SetVariable ZPsetVar,limits={-inf,inf,0},value= PIDGet[%Z][%P]
				SetVariable ZIsetVar,pos={(xOffset + 3),44},size={105,16},title="Integral       "
				SetVariable ZIsetVar,help={"Weights: the sum of recent errors. Larger values= errors eliminated more quickly, but with larger overshoot.\""}
				SetVariable ZIsetVar,limits={-inf,inf,0}, value= PIDGet[%Z][%I]
				SetVariable ZDsetVar,pos={(xOffset + 3),62},size={105,16},title="Derivative   "
				SetVariable ZDsetVar,help={"Weights: rate the error has been changing. Larger value = less overshoot, but slower transient response, possible instability."}
				SetVariable ZDsetVar,limits={-inf,inf,0},value = PIDGet[%Z][%D]
				// Buttons for Getting and Setting PID from stage encoder and reverting to default values
				Button ZPIDgetButton,pos={(xOffset + 4),85},size={28,20},title="Get", proc = Stages_GetPIDButtonProc
				Button ZPIDgetButton,help={"Fetches the PID values currently set for the Z axis"}
				Button ZPIDsetButton,pos={(xOffset + 33),85.00},size={28.00,20.00},proc=Stages_SetPIDButtonProc,title="Set"
				Button ZPIDsetButton,help={"Sets the PID values for the Z axis"}
				Button ZPIDdefaultButton,pos={(xOffset + 63),85.00},size={48.00,20.00},proc=Stages_RevertPIDButtonProc,title="default"
				Button ZPIDdefaultButton,help={"Sets the PID values for Z axis to default  values stored as constants in the stage-specific procedure file"}
			endif
			if (Properties[%has_Ax])
				xOffset += 115
				// group box
				GroupBox AxGrp,pos={(xOffset),0},size={115,110},title="Ax PID",fSize=16,fStyle=1
				// Set variables for P, I, and D
				// Set variables for P, I, and D
				SetVariable APsetVar,pos={(xOffset + 3),26},size={105,16},title="Proportional"
				SetVariable APsetVar,help={"Weights: the current error. Larger value = faster response, but greater instability and possible oscillation."}
				SetVariable APsetVar,limits={-inf,inf,0},value= PIDGet[%A][%P]
				SetVariable AIsetVar,pos={(xOffset + 3),44},size={105,16},title="Integral       "
				SetVariable AIsetVar,help={"Weights: the sum of recent errors. Larger values= errors eliminated more quickly, but with larger overshoot.\""}
				SetVariable AIsetVar,limits={-inf,inf,0}, value= PIDGet[%A][%I]
				SetVariable ADsetVar,pos={(xOffset + 3),62},size={105,16},title="Derivative   "
				SetVariable ADsetVar,help={"Weights: rate the error has been changing. Larger value = less overshoot, but slower transient response, possible instability."}
				SetVariable ADsetVar,limits={-inf,inf,0},value = PIDGet[%A][%D]
				// Buttons for Getting and Setting PID from stage encoder and reverting to default values
				Button APIDgetButton,pos={(xOffset + 4),85},size={28,20},title="Get", proc = Stages_GetPIDButtonProc
				Button APIDgetButton,help={"Fetches the PID values currently set for the Axial axis"}
				Button APIDsetButton,pos={(xOffset + 33),85.00},size={28.00,20.00},proc=Stages_SetPIDButtonProc,title="Set"
				Button APIDsetButton,help={"Sets the PID values for the Axial axis"}
				Button APIDdefaultButton,pos={(xOffset + 63),85.00},size={48.00,20.00},proc=Stages_RevertPIDButtonProc,title="default"
				Button APIDdefaultButton,help={"Sets the PID values for Axial axis to default  values stored as constants in the stage-specific procedure file"}
				//FetchPID ("A", pS, iS, dS)
			endif
			break
	endswitch
	return 0
End



//*************************************************************************************************************
// Fetches all P, I, and D values for a single axis, depending on button that calls function
// Last 2025/12/01 by Jamie Boyd
Function Stages_GetPIDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			string thectrlName =  ba.ctrlName
			string theAxis =thectrlName [0]
			SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
			WAVE Selected = $"root:packages:" + theStageEncoder + ":SelectedForCMD"
			Selected = 0
			Selected [%theAxis] = 1
#ifdef STAGE_IS_THREADED
			NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
			newdatafolder/s :tdata
			variable/G theCmdG = kThreadFetchPID
			duplicate Selected SelectedG
			WaveClear SelectedG
			ThreadGroupPutDF threadID, :
#else
			WAVE PIDget =  $"root:packages:" + theStageEncoder + ":PIDget"
			WAVE Properties = $"root:packages:" + theStageEncoder + ":Properties"
			funcref StageFetchPID_Template fetchPID = $"StageFetchPID_" + theStageEncoder
			fetchPID (thePort, Selected, PIDget, Properties)
#endif
			break
	endswitch
	return 0
End


//*************************************************************************************************************
// Sets all P,I, and D values for a single axis, depending on button that calls function
// Last 2025/12/01 by Jamie Boyd
Function Stages_SetPIDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			string thectrlName =  ba.ctrlName
			string theAxis =thectrlName [0]
			SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
			WAVE Selected = $"root:packages:" + theStageEncoder + ":SelectedForCMD"
			WAVE PIDget = $"root:packages:" + theStageEncoder + ":PIDGet"
			Selected = 0
			Selected [%theAxis] = 1
#ifdef STAGE_IS_THREADED
			NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
			newdatafolder/s :tdata
			variable/G theCmdG = kThreadSetPID
			duplicate Selected SelectedG
			duplicate PIDget PIDsetG
			WaveClear SelectedG, PIDsetG
			ThreadGroupPutDF threadID, :
#else
			WAVE Properties = $"root:packages:" + theStageEncoder + ":Properties"
			funcRef StageSetPID_Template SetPID = $"StageSetPID_" + theStageEncoder
			SetPID (thePort, Selected, PIDget, Properties)
#endif
			break
	endswitch
	return 0
End



//*************************************************************************************************************
// Reverts all P,I, and D values for a single axis to default values saved as globals in device-specific procedure file
// Last Modified Sep 13 by Jamie Boyd
Function Stages_RevertPIDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			funcRef StageSetPID_Template SetPID = $"StageSetPID_" + theStageEncoder
			string ctrlName = ba.ctrlname
			string theAxis = ctrlName [0]
			SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
			WAVE Selected = $"root:packages:" + theStageEncoder + ":SelectedForCMD"
			WAVE PIDdefault = $"root:packages:" + theStageEncoder + ":PIDdefault"
			Selected = 0
			Selected [%theAxis] = 1
			WAVE PIDset =  $"root:packages:" + theStageEncoder + ":PIDset"
			PIDset = PIDdefault [%theAxis] [q]
			WAVE Properties = $"root:packages:" + theStageEncoder + ":Properties"
			funcRef StageSetPID_Template SetPID = $"StageSetPID_" + theStageEncoder
			SetPID (thePort, Selected, PIDset, Properties)
			break
	endswitch
	return 0
End


// ***************************************************************************************************
// ***************************** Functions for thread for threaded version *********************************
// ***************************************************************************************************
//******************* MNEMONIC CONSTANTS FOR STAGE COMMANDS FOR THREAD ********************************
CONSTANT kThreadSetPort = 	0
CONSTANT kThreadSetZero =	1
CONSTANT kThreadGetPos = 	2
CONSTANT kThreadGoToPos = 	3
CONSTANT kThreadDoStep = 	4
CONSTANT kThreadGetMvIncr = 	5
CONSTANT kThreadSetMvIncr = 	6
CONSTANT kThreadSetAuto = 	7
CONSTANT kThreadUnSetAuto = 	8
CONSTANT kThreadSetLock = 	9
CONSTANT kThreadUnSetLock =	10
CONSTANT kThreadResetIO = 	11
CONSTANT kThreadSetPID = 	12
CONSTANT kThreadFetchPID =	13

#ifdef STAGE_IS_THREADED
//***********************************************************
// Function for the thread for a threaded stage, receives commands from a queue as they are posted
// Last Modified 2025/12/18 by Jamie Boyd
Threadsafe Function StagePThread(theStageEncoder, DistanceFromZero, Zeros, StepSizes, PIDVals, Properties)
	String theStageEncoder		// name of stage encoder, all functions and datafolders use this name
	WAVE DistanceFromZero		// contains current distances from zero for all axes - only one copy
	WAVE Zeros					// contaons absolute position of zero for all axes, not used if zeroing is done by stage encoder - only one copy
	WAVE stepSizes				// contains current step sizes for all axes - only one copy
	WAVE PIDVals				// contains current PID values for all axes - onlyone copy, shared with thread
	WAVE Properties				// contains info on various properties of stage encoder, for all axes

	String thePort = ""		// serialport used by StageENcoder, set by a call to StagePThread
	// function references for functions provided by stage encoder procedure
	funcref StageSetzero_Template setZero = $"StageSetzero_" + theStageEncoder
	funcref StageUpdate_Template StageUpdate=$"StageUpdate_" + theStageEncoder
	funcref StageSetManual_template SetManualLock=$"StageSetManual_" + theStageEncoder
	funcref StageResetIO_template ResetIO = $"StageResetIO_" + theStageEncoder
	funcRef StageMoveRel_Template StageMoveRel = $"StageMoveRel_" + theStageEncoder
	funcref StageMoveAbs_Template StageMoveAbs = $"StageMoveAbs_" + theStageEncoder
	funcRef StageSetStepIncr_Template StageSetInc = $"StageSetStepIncr_" + theStageEncoder
	funcRef StageGetStepIncr_Template StageGetInc = $"StageGetStepIncr_" + theStageEncoder
	Funcref StageFetchPID_Template StageFetchPID = $"StageFetchPID_"  + theStageEncoder
	Funcref StageSetPID_Template StageSetPID = $"StageSetPID_"  + theStageEncoder
	Funcref StageMonitorFunc_Template StageMonitor = $"StageMonitorFunc_" + theStageEncoder

	// Auto update
	variable autoUpdate=0								// variable used to indicate when autoUpdate (1) or monitor to position (2) is on
	variable autoTodo
	variable autoUpdateBup
	variable autoUpdateMS = kAUTO_UPDATE_INT*1000		// milliseconds between updates when autoUpdate is on, set by constant at top of file

	make/FREE/n=4 autoSelected				// wave for axis selection when autoupdate is on - all available axes are selected
	make/FREE/n=4 localMoveTo
	setDimLabel 0, 0, X, autoSelected,localMoveTo
	setDimLabel 0, 1, Y, autoSelected,localMoveTo
	setDimLabel 0, 2, Z, autoSelected,localMoveTo
	setDimLabel 0, 3, A, autoSelected,localMoveTo


	// infinite loop that gets and processes commands posted to the thread
	for (;;)
		if (autoUpdate)
			DFREF dfr = ThreadGroupGetDFR(0,autoUpdateMS)
			if (!(DataFolderRefStatus(dfr)))				// we don't have a command to process, but it is time to do an update
				if (autoUpdate & 1)
					Properties[%BUSY]=1
					StageUpdate(thePort, autoSelected, DistanceFromZero, Zeros, Properties)
					Properties[%BUSY]=0
				endif
				if (autoUpdate & 2)
					autoToDo = StageMonitor (thePort, autoToDo, localMoveTo, DistanceFromZero)
					if (autoToDo == 0)
						autoUpdate = autoUpdateBup
					endif
				endif
				continue
			endif
		else
			DFREF dfr = ThreadGroupGetDFR(0,INF)	// get the command
			Properties[%BUSY]=1
		endif
		NVAR theCmd = dfr:theCmdG
		Switch (theCmd)
			case kThreadSetAuto:
				if (Properties [%has_XY])
					autoSelected [%X] = 1
					autoSelected [%Y] = 1
				endif
				if (Properties [%has_Z])
					autoSelected [%Z] = 1
				endif
				if (Properties [%has_Ax])
					autoSelected [%A] = 1
				endif
				autoUpdate = autoUpdate | 1
				break
			case kThreadUnSetAuto:
				autoUpdate = autoUpdate & ~1
				break
			case kThreadSetPort:		 // set port used by stage encoder
				SVAR thePortG =  dfr:thePortG
				thePort = thePortG
				//print "thePort = ", thePort
				break
			case kThreadSetZero: 		// set zero position for all axes
				WAVE Selected = dfr:SelectedG
				setZero (thePort, Selected, DistanceFromZero, Zeros, Properties)
				break
			case kThreadResetIO:
				ResetIO (thePort, Properties)
				break
			case kThreadGetPos:			// get position for selected axes
				WAVE Selected = dfr:SelectedG
				StageUpdate (thePort, Selected, DistanceFromZero, Zeros, Properties)
				break
			case kThreadSetLock:
				SetManualLock (thePort, 1, Properties)
				break
			case kThreadUnSetLock:
				SetManualLock (thePort, 0, Properties)
				break
			case kThreadSetMvIncr:
				WAVE Selected = dfr:SelectedG
				WAVE StepSizestoSet = dfr:StepSizesG
				StageSetInc (thePort, selected, StepSizestoSet, Properties)
				break
			case kThreadGetMvIncr:
				StageGetInc (thePort, selected, StepSizes, Properties)
				break
			case kThreadDoStep:
				NVAR returnWhen = dfr:returnWhenG
				WAVE Selected = dfr:SelectedG
				StageMoveRel (thePort, returnWhen, Selected, StepSizes, DistanceFromZero, Properties)
				if (returnWhen == kStagesReturnBkg)		// check with thread
					localMoveTo = DistanceFromZero + StepSizes * Selected
					autoToDo = 0
					if (Selected [%X])
						autoToDo += 1
					endif
					if (Selected [%Y])
						autoToDo += 2
					endif
					if (Selected [%Z])
						autoToDo += 4
					endif
					if (Selected [%A])
						autoToDo += 8
					endif
					autoUpdateBup = (autoUpdate & 1)
					autoUpdate = 2
				endif
				break
			case kThreadGoToPos:
				NVAR returnWhen = dfr:returnWhenG
				WAVE Selected = dfr:SelectedG
				WAVE MoveTo = dfr:MoveToG
				StageMoveAbs (thePort, kStagesReturnNow, Selected, MoveTo, DistanceFromZero, Properties)
				if (returnWhen == kStagesReturnBkg)
					autoToDo = 0
					if (Selected [%X])
						autoToDo += 1
					endif
					if (Selected [%Y])
						autoToDo += 2
					endif
					if (Selected [%Z])
						autoToDo += 4
					endif
					if (Selected [%A])
						autoToDo += 8
					endif
					autoUpdateBup = (autoUpdate & 1)
					autoUpdate = 2
					localMoveTo = MoveTo
				endif
				break
			case kThreadSetPID:
				WAVE Selected = dfr:SelectedG
				WAVE PID_Set = dfr:PID_SetG
				StageSetPID(thePort, Selected, PID_Set, Properties)
				break
			case kThreadFetchPID:
				WAVE Selected = dfr:SelectedG
				StageFetchPID(thePort, Selected, PIDVals, Properties)
				break
		endswitch
		Properties[%BUSY]=0
	endfor
end
#endif

//***********************************************************
// Stops the thread for a threaded stage, sometimes needed when procedures are recompiled while stage is active
// Last Modified 2025/11/26 by Jamie Boyd
Function StageStopThread()
	string theStageEncoder
	string encoderList=StageListOpen()
	variable Nencoders=ItemsInList(encoderList, ";")

	if (Nencoders == 0)
		return 0
	elseif (Nencoders==1)
		theStageEncoder = StringFromList(0, encoderList, ";")
	elseif (Nencoders > 1)
		Prompt theStageEncoder, "Stops a Stage Encoder thread", popup, encoderList
		DoPrompt /HELP="Stops the thread for a stage encoder." "Choose an open Stage Encoder", theStageEncoder
		if (V_Flag == 1)
			return 0
		endif
	endif
	NVAR threadID= $"root:packages:" + theStageEncoder + ":stageThread"
	variable Result = ThreadGroupRelease(threadID)
	if (Result)
		printf "Stage Thread for %s was not stopped.\r", theStageEncoder
	endif
end


//***********************************************************
// Lists stage encoders in use. Normally there is only one in use at a time
// Last Modified 2025/11/26 by Jamie Boyd
Function/S StageListOpen()
	string rList=""
	string aFolder, fList = GUIPListObjs ("root:packages:", 4, "*", 0, "")
	variable ifolder, nFolders = itemsinlist(fList, ";")
	for (ifolder=0;ifolder < nfolders; iFolder +=1)
		aFolder= StringFromList(iFOlder, fList, ";")
		SVAR/z thePort = $"root:packages:" + aFolder + ":thePort"
		if (SVAR_Exists(thePort))
			rList=AddListItem(aFolder, rList, ";")
		endif
	endfor
	return rList
end



// **********************************************************************************************************************
// **************** Some functions for move and update that are more easily called from other code **************
// **********************************************************************************************************************


// **********************************************************************************************************************
// Pass by reference variables. Set ones you don't want updated to NaN. When function returns, values will be updated
// last modified 2025/12/19 by Jamie Boyd
Function Stage_UpdateXYZ (theStageEncoder, xVal, yVal, zVal)
	String theStageEncoder
	Variable &xVal
	variable &yVal
	Variable &zVal

	SVAR thePort = $"root:packages:" + theStageEncoder + ":thePort"
	WAVE selectedForCMD = $"root:packages:" + theStageEncoder + ":selectedForCMD"
	WAVE DistsFromZero = $"root:packages:" + theStageEncoder + ":DistanceFromZero"
	WAVE Zeros = $"root:packages:" + theStageEncoder + ":absoluteZero"
	WAVE Properties =  $"root:packages:" + theStageEncoder + ":Properties"

	if (numtype (xVal) == 0)
		selectedForCMD [%X] = 1
	endif
	if (numtype (yVal) == 0)
		selectedForCMD [%Y] = 1
	endif
	if (numtype (zVal) == 0)
		selectedForCMD [%Z] = 1
	endif

#ifdef STAGE_IS_THREADED
	NVAR threadID = $"root:packages:" + theStageEncoder + ":stageThread"
	newdatafolder/s :tdata
	variable/G theCmdG = kThreadGetPos
	duplicate selectedForCMD selectedG
	WaveClear selectedG
	ThreadGroupPutDF threadID, :
	do
		sleep/S 0.05
	while (Properties [%BUSY])
#else
	funcref  StageUpdate_Template StageUpdate=$"StageUpdate_" + theStageEncoder
	StageUpdate (thePort, selectedForCMD, DistsFromZero, Zeros, Properties)
#endif
	if (numtype (xVal) == 0)
		xVal = DistsFromZero[%X]
	endif
	if (numtype (yVal) == 0)
		yVal = DistsFromZero[%Y]
	endif
	if (numtype (zVal) == 0)
		zVal = DistsFromZero[%Y]
	endif
end

// **********************************************************************************************************************
// Just for XY. Pass by reference for X and Y
// last modified 2025/12/19 by Jamie Boyd
Function Stage_UpdateXY (theStageEncoder, xVal, yVal)
	string theStageEncoder
	Variable &xVal
	variable &yVal

	xval = 1
	yval = 1
	variable zVal = NaN
	Stage_UpdateXYZ (theStageEncoder, xVal, yVal, zVal)
end


// **********************************************************************************************************************
// just for Z. Zval is returned, no need for pass by reference
Function Stage_UpdateZ (theStageEncoder)
	string theStageEncoder

	Variable zVal = 1
	variable xVal = NaN
	variable yVal = Nan
	Stage_UpdateXYZ (theStageEncoder, xVal, yVal, zVal)
	return zVal

end






Function StageGoToXY (theStageEncoder, Xpos, yPos)
	string theStageEncoder
	variable  Xpos, yPos
end

Function StageGoToZ (theStageEncoder, Zpos)
	string theStageEncoder
	variable Zpos
end

Function StageGoToXYZ (theStageEncoder, Xpos, yPos, zPos)
	string theStageEncoder
	variable  Xpos, yPos, zPos
end





Function StageHasError (theStageEncoder)
	string theStageEncoder

end

Function StageRestIO (theStageEncoder)
	string theStageEncoder
end



Function testIt ()
	variable xVal, yVal
	Stage_UpdateXY ("Microcode2", xVal, yVal)
	printf "Y axis is at %.3W1Pm and X axis is at %.3W1Pm\r", yVal, xVal
end
