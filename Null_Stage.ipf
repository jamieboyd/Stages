#pragma rtGlobals=3		// Use modern global access method.
#pragma version= 2.0	// Last Modified 2025/12/15 by Jamie Boyd - new version with thread support
#pragma IgorVersion=8.05

#define STAGE_IS_THREADED

STATIC CONSTANT kNullHasXY = 1
STATIC CONSTANT kNullHasZ = 1
STATIC CONSTANT kNullHasAx =0
STATIC CONSTANT kNullHasMotor = 1
STATIC CONSTANT kNullXMIN = -5e-03
STATIC CONSTANT kNullXMAX = 5e-03
STATIC CONSTANT kNullYMIN = -5e-03
STATIC CONSTANT kNullYMAX = 5e-03
STATIC CONSTANT kNullxyStepSize = 1e-07
STATIC CONSTANT kNullZstepSize = 2.5e-07
STATIC CONSTANT kNullAxstepSize = 1e-06
STATIC CONSTANT kNullXpol = 1
STATIC CONSTANT kNullYpol = 1
STATIC CONSTANT kNullZpol = 1
STATIC CONSTANT kNullAxpol = 1
STATIC CONSTANT kNullZMIN = -2e-03
STATIC CONSTANT kNullZMAX = 2e-03
STATIC CONSTANT kNullAxMIN = 0
STATIC CONSTANT kNullAxMAX = 3e-03

STATIC CONSTANT kNullHasPID =1
CONSTANT kNullxPIDpDef = 2000
CONSTANT kNullxPIDiDef = 5
CONSTANT kNullxPIDdDef = 2
CONSTANT kNullyPIDpDef = 2000
CONSTANT kNullyPIDiDef = 5
CONSTANT kNullyPIDdDef = 2
CONSTANT kNullzPIDpDef = 2000
CONSTANT kNullzPIDiDef = 5
CONSTANT kNullzPIDdDef = 2
CONSTANT kNullaPIDpDef = 2000
CONSTANT kNullaPIDiDef = 5
CONSTANT kNullaPIDdDef = 2

//*******************************************************************************
// Initialize global variables that were created by Stage_MakeGlobals 
// Last Modified 2025/11/26 by Jamie Boyd - new version with config in waves
Function StageInitGlobals_null ()

	WAVE Properties =  root:packages:null:Properties
	WAVE polarity =  root:packages:null:Polarity
	WAVE PIDdefault = root:packages:null:PIDdefault
	WAVE stepSize = root:packages:null:StepSize
	Properties [%has_XY] = kNullHasXY
	if ((knullhasXY) && (kNullHasMotor))
		Properties [%min_X] = kNullXMIN
		Properties [%max_X] = kNullXMAX
		Properties [%min_Y] = kNullYMIN
		Properties [%max_Y] = kNullYMAX
		Properties [%res_XY] = kNullxyStepSize
		polarity[%X] = kNullXpol
		polarity[%Y] = kNullYpol
	endif
	Properties [%has_Z] = kNullHasZ
	if ((kNullHasZ) && (kNullHasMotor))
		Properties [%min_Z] = kNullZMIN
		Properties [%max_Z] = kNullZMAX
		Properties [%res_Z] = kNullZStepSize
		polarity[%Z] = kNullZpol
	endif
	Properties [%has_Ax] = kNullHasAx
	if ((kNullHasAx) && (kNullHasMotor))
		Properties [%min_Ax] = kNullAxMIN
		Properties [%max_Ax] = kNullAxMAX
		Properties [%res_Ax] = kNullAxStepSize
		polarity[%A] = kNullAxpol
	endif
	Properties [%has_Mtr] = kNullHasMotor
	if (kNullHasMotor)
		Properties[%has_PID] = 1
		Properties [%has_Lock] =1
	endif
	Properties [%has_PID] = kNullHasPID
	if (kNullHasPID)
		PIDdefault[%X] [%P] = kNullxPIDpDef
		PIDdefault[%X] [%I] = kNullxPIDiDef
		PIDdefault[%X] [%D] = kNullxPIDdDef
		PIDdefault[%Y] [%P] = kNullyPIDpDef
		PIDdefault[%Y] [%I] = kNullyPIDiDef
		PIDdefault[%Y] [%D] = kNullyPIDdDef
		if(kNullHasZ)
			PIDdefault[%Z] [%P] = kNullzPIDpDef
			PIDdefault[%Z] [%I] = kNullzPIDiDef
			PIDdefault[%Z] [%D] = kNullzPIDdDef
		endif
		if(kNullHasAx)
			PIDdefault[%A] [%P] = kNullaPIDpDef
			PIDdefault[%A] [%I] = kNullaPIDiDef
			PIDdefault[%A] [%D] = kNullaPIDdDef
		endif
	endif
	if (kNullHasXY)
		StepSize [%X] = 10*kNullxyStepSize
		StepSize [%Y] = 10*kNullxyStepSize
	endif
	if (kNullHasZ)
		StepSize [%Z] = 4*kNullzStepSize
	endif
	if (kNullHasAx)
		StepSize [%A] = 4*kNullaxStepSize
	endif
	
end


//*******************************************************************************
// Demonstrates how to add to the stage control panel things specific to a Stage procedure
// here we add a stop button and a reset button
Function StageAddControls_null(hOffset, vOffset, thePanel)
	variable hOffset, vOffset
	string thePanel

	//add a reset button to the control panel, if it exists
	if (cmpstr (thePanel, stringfromlist (0, winlist (thePanel, ";", "WIN:65"), ";")) == 0) 
		button StopButton, win =$thePanel, pos = {hOffset + 100, vOffset}, size = {40,20}
		button StopButton ,win = $thePanel,  title="Stop", proc=Stage_nullButtonProc
		button ResetButton ,win =$thePanel, pos = {hOffset, vOffset}, size = {95,20}
		button ResetButton ,win = $thePanel,  title="Reset null", proc=Stage_nullButtonProc
	endif
end

//*******************************************************************************
// Even a NULL button gotta do something
Function Stage_nullButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			doalert 0, ba.ctrlname + "doesn't actually do anuthing, it's NULL."
			break
	endswitch
	return 0
End


//*********************************************************************************************
// Opens the serial port for use with null and  gets some initial values
Function StageSetUpPort_null (thePortName)
	string thePortName
	
	// Configure port, open it, and select it for command operations
	// Set increment values to those loaded from global variables
	// do an initial update
end

//*********************************************************************************************
// Reset I/O function for null, clears any pending commands
Threadsafe Function StageResetIO_null(thePortName, Properties)
	string thePortName // Name of the serial port
	WAVE Properties
end

//*********************************************************************************************
// Port closing function for null
Function StageClose_null (thePortName)
	string thePortName // Name of the serial port
end

//*********************************************************************************************
// Stage set Zero function sets current stage location to zero, saving coordinates in Zeros wave
// Last Modied 2025/11/26 by Jamie Boyd
Threadsafe Function StageSetZero_null  (thePort, selected, DistsFromZero, Zeros, Properties)
	string thePort
	WAVE Selected
	WAVE DistsFromZero
	WAVE Zeros
	WAVE Properties

	sleep/S 0.25
	if (Selected [%X])
		Zeros [%X] = DistsFromZero [%X]; DistsFromZero [%X] =0
	endif
	if (Selected [%Y])
		Zeros [%Y] = DistsFromZero [%Y]; DistsFromZero [%Y] =0
	endif
	if (Selected [%Z])
		Zeros [%Z] = DistsFromZero [%Z]; DistsFromZero [%Z] =0
	endif
	if (Selected [%A])
		Zeros [%A] = DistsFromZero [%A]; DistsFromZero [%A] =0
	endif
end


//*********************************************************************************************
// Stage update function gets current stage location. For null, we use a random value bounded by max range
// Last Modied 2025/11/26 by Jamie Boyd
Threadsafe Function StageUpDate_Null (thePort, Selected, DistsFromZero, Zeros, Properties)
	string thePort
	WAVE Selected
	WAVE DistsFromZero
	WAVE Zeros
	WAVE Properties
	
	sleep/S 0.25
	if (Properties[%has_XY])
		DistsFromZero [%X] = enoise(Properties[%max_X]) - Zeros [%X]
		DistsFromZero [%Y] = enoise(Properties[%max_Y]) - Zeros [%Y]
	endif
	if (Properties[%has_Z])
		DistsFromZero [%Z] = enoise(Properties[%max_Z]) - Zeros [%Z]
	endif
	if (Properties[%has_Ax])
		DistsFromZero [%A] = enoise(Properties[%max_Ax]) - Zeros [%A]
	endif
end


//*********************************************************************************************
// Stage set step increment for null does nothing because values in waves in data folder have already been changed
// Last Modied 2025/11/27 by Jamie Boyd
Threadsafe Function StageSetStepIncr_null (thePort, selected, StepSize, Properties)
	string thePort
	WAVE Selected
	WAVE StepSize
	WAVE Properties
	
	sleep/S 0.25
end


//*********************************************************************************************
// Stage get step increment for null does nothing
// Last Modied 2025/11/27 by Jamie Boyd
Threadsafe Function StageGetStepIncr_null (thePort, selected, StepSize, Properties)
	string thePort
	WAVE Selected
	WAVE StepSize
	WAVE Properties
	
	sleep/S 0.25
end

//*******************************************************************************
// Enables or disables manual movement of stage. null does nothing here
// Last Modied 2025/11/27 by Jamie Boyd
Threadsafe Function StageSetManual_null (thePort, isOnNotOff, Properties)
	string thePort
	variable isOnNotOff
	WAVE Properties
	
	sleep/S 0.25
end


//***********************************************************************************	
// Stage moves defined step size relative to current position function
// Last Modied 2025/11/26 by Jamie Boyd
Threadsafe Function StageMoveRel_null (thePort, verify, Selected, StepSize, DistsFromZero, Properties)
	String thePort
	variable verify
	WAVE Selected
	WAVE StepSize
	WAVE DistsFromZero
	WAVE Properties
	
	sleep/S 0.25
	
	if (Selected[%X])
		DistsFromZero [%X] += StepSize[%X] * Selected[%X]
	endif
	if (Selected[%Y])
		DistsFromZero [%Y] += StepSize[%X] * Selected[%Y]
	endif
	if (Selected[%Z])
		DistsFromZero [%Z] += StepSize[%Z] * Selected[%Z]
	endif
	if (Selected[%A])
		DistsFromZero [%A] += StepSize[%A] * Selected[%A]
	endif
end


//***********************************************************************************	
// Stage move to absolute position function
// Last Modied 2025/11/26 by Jamie Boyd
Threadsafe Function StageMoveAbs_null (thePort, verify, selectedForCMD, MoveTo, DistsFromZero, Properties)
	String thePort
	Variable verify
	Wave selectedForCMD
	WAVE MoveTo
	WAVE DistsFromZero
	WAVE Properties
	 
	sleep/S 0.25
	if (selectedForCMD[%X])
		DistsFromZero [%X]=MoveTo[%X]
		DistsFromZero [%Y]=MoveTo[%Y]
	endif
	
	if (selectedForCMD[%Z])
		DistsFromZero [%Z]=MoveTo[%Z]
	endif
	
	if (selectedForCMD[%A])
		DistsFromZero [%A]=MoveTo[%A]
	endif
	
end


//*************************************************************************************************
// function to fetch PID values
// Set pS, iS, dS initally to 1 to fetch value for that PID, or 0 to not fetch
Threadsafe Function StageFetchPID_null (thePort, SelectedForCMD, PIDget, Properties)
	string thePort
	WAVE SelectedForCMD
	WAVE PIDGet
	Wave Properties
	
end

//*************************************************************************************************
// Template for function to set PID values
Threadsafe Function StageSetPID_null (thePort, SelectedForCMD, PIDset, Properties)
	string thePort
	WAVE SelectedForCMD
	WAVE PIDset
	WAVE Properties
	
	
end


//*******************************************************************************
// Reset stage encoder
Function StageReset_nullButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			break
	endswitch
	return 0
End


//*******************************************************************************
// Stop stage encoder
Function StageStop_nullButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up

		break
	endswitch
	return 0
End


//*********************************************************************************************
// background function that updates stage positions from all axes
// Last Modified 2025/11/26 by Jamie Boyd
Function StageBkgUpdate_null(WMS)
	STRUCT WMBackgroundStruct &WMS
	
	SVAR thePort =  root:packages:null:thePort
	WAVE Selected = root:packages:null:selectedForCMD
	WAVE DistanceFromZero= root:packages:null:DistanceFromZero
	WAVE Zeros= root:packages:null:AbsoluteZero
	WAVE Properties =  root:packages:null:properties
	StageUpDate_Null (thePort, Selected, DistanceFromZero, Zeros, Properties)
	return 0
end



//*********************************************************************************************
// background function that touches waves in data folder so values on control panel are updated
Function StageTouch_null(WMS)
	STRUCT WMBackgroundStruct &WMS
	
	WAVE DistanceFromZero= root:packages:null:DistanceFromZero
	WAVE Properties =  root:packages:null:properties
	WAVE stepSize = root:packages:null:stepSize
	DistanceFromZero [%A] += 0
	StepSize [%A] += 0
	Properties [%has_Ax] += 0
	return 0
end