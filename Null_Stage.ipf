#pragma rtGlobals=1		// Use modern global access method.
#pragma version= 1.0		// modification date Oct 04 2010 by Jamie Boyd
#pragma IgorVersion=5.05
#include "Stages"

STATIC CONSTANT kNullHasXY = 1
STATIC CONSTANT kNullHasZ = 1
STATIC CONSTANT kNullHasAx =0
STATIC CONSTANT kNullHasMotor = 1
STATIC CONSTANT kNullHasPID =1
STATIC CONSTANT kNullisUSB = 0
STATIC CONSTANT kNullXYMIN = -5e-03
STATIC CONSTANT kNullXYMAX = 5e-03
STATIC CONSTANT kNullxyStepSize = 1e-07
STATIC CONSTANT kNullZstepSize = 2.5e-07
STATIC CONSTANT kNullAxstepSize = 1e-06
STATIC CONSTANT kNullXpol =1
STATIC CONSTANT kNullYpol =1
STATIC CONSTANT kNullZpol =1
STATIC CONSTANT kNullAxpol =1
STATIC CONSTANT kNullZMIN = -2e-03
STATIC CONSTANT kNullZMAX = 2e-03
STATIC CONSTANT kNullAxMIN = 0
STATIC CONSTANT kNullAxMAX = 3e-03

//*******************************************************************************
// Make/Set global variables
// these are created by Stage_MakeGlobals and we could just NVAR them, but one may want to use null procedure
// independent of Stages procedure, so it doesn't hurt to make them again
// Last Modifies Sep 07 2010 by Jamie Boyd
Function StageInitGlobals_null ()

	if (!(datafolderExists ("root:packages:")))
		newDataFolder root:packages:
	endif 
	if (!(datafolderExists ("root:packages:null:")))
		newdatafolder root:packages:null
	endif
	// string for port name - will be set by user from popmenu which calls StageSetUpPort_null
	string/G root:packages:null:thePort
	// Read XY-, Z-, and Axial capability from static contstant at top of file
	variable/G root:packages:null:hasXY = knullhasXY
	variable/G root:packages:null:hasZ = knullhasZ
	variable/G  root:packages:null:hasAx = kNullHasAx
	// Is motorized ?
	variable/G root:packages:null:hasMotor = kNullHasMotor
	// has PID settings ?
	variable/G root:packages:null:hasPID=kNullHasPID
	// Serial device, or  USB ?
	variable/G root:packages:null:isUSB = kNullisUSB
	// variables for distances from 0 and increments
	if (knullhasXY)
		variable/G  root:packages:null:xDistanceFromZero
		variable/G  root:packages:null:yDistanceFromZero
		if (kNullHasMotor)
			variable/G  root:packages:null:xStepSize =kNullxyStepSize
			variable/G  root:packages:null:yStepSize= kNullXYStepSize
			variable/G  root:packages:null:xPol =kNullXpol
			variable/G  root:packages:null:yPol=kNullYpol
			variable/G root:packages:null:xyMIN = kNullXYMIN
			variable/G root:packages:null:xyMAX=kNullXYMAX
		endif
	endif
	if (knullhasZ)
		variable/G  root:packages:null:zDistanceFromZero
		if  (kNullHasMotor)
			variable/G  root:packages:null:zStepSize= kNullZstepSize
			variable/G  root:packages:null:zRes = kNullZstepSize
			variable/G  root:packages:null:zPol=kNullZPol
			variable/G root:packages:null:zMIN = kNullZMIN
		variable/G root:packages:null:zMAX=kNullZMAX
		endif
	endif
	if (knullhasAx)
		variable/G  root:packages:null:AxDistanceFromZero
		if  (kNullHasMotor)
			variable/G  root:packages:null:AxStepSize= kNullAxStepSize
			variable/G  root:packages:null:axPol=kNullaxPol
			variable/G root:packages:null:axMIN = kNullaxMIN
			variable/G root:packages:null:axMAX=kNullaxMAX
		endif
	endif
	// variable for abort, for procedures with wait
	variable/G root:packages:null:doAbort = 0
end

//*******************************************************************************
// add to the stage control panel things specific to null
// Adds a reset button
Function StageAddControls_null (hOffset, vOffset, thePanel)
	variable hOffset, vOffset
	string thePanel

	//add a reset button to the control panel, if it exists
	if (cmpstr (thePanel, stringfromlist (0, winlist (thePanel, ";", "WIN:65"), ";")) == 0) 
		button StopButton, win =$thePanel, pos = {hOffset + 100, vOffset}, size = {40,20}
		button StopButton ,win = $thePanel,  title="Stop", proc=StageStop_nullButtonProc
		button ResetButton ,win =$thePanel, pos = {hOffset, vOffset}, size = {95,20}
		button ResetButton ,win = $thePanel,  title="Reset null", proc=StageReset_nullButtonProc
		// Make control panel a progress window  - not on Igor 5 you don't
		//DoUpdate /W=$thePanel /E=1
	endif
end

//*********************************************************************************************
// Opens the serial port for use with null and  gets some initial values
Function StageSetUpPort_null (thePortName)
	string thePortName
	
	// Configure port, open it, and select it for command operations
	// Set increment values to those loaded from global variables
	// do an initial update
	return 0
end

//*********************************************************************************************
// Reset I/O function for null, clears any pending commands
Function StageResetIO_null ()
	
	return 0
end

//*********************************************************************************************
// Port closing function for null
Function StageClose_null ()

	return 0
end

//*********************************************************************************************
// Stage update function returns current stage location 
// Last Modied Aug 19 2010 by Jamie Boyd
Function StageUpDate_Null (xS, yS, zS, axS)
	variable &xS, &yS, &zS,  &axS 
	
	// Globals
	NVAR isBusy = root:packages:null:isBusy // null is busy processing a command
	isBusy = 1;doUpdate
	if (numtype (xS) == 0)
		NVAR xDistFromZero = root:Packages:Null:XdistancefromZero
		xS=xDistFromZero
	endif
	if (numtype (yS) ==0)
		NVAR yDistFromZero = root:Packages:Null:YdistancefromZero
		yS=yDistFromZero
	endif
	if (numtype (zS) == 0)
		NVAR zDistFromZero = root:Packages:Null:ZdistancefromZero
		zS=zDistFromZero
	endif
	if (numtype (xS) == 0)
		NVAR axDistFromZero = root:Packages:Null:axdistancefromZero
		axS=axDistFromZero
	endif
	isBusy = 0
	return 0
end

//***********************************************************************************	
// Stage move function
Function StageMove_Null (moveType, returnWhen, xS, yS, zS, AxS)
	variable moveType  //  0 if requesting movement to an absolute position. 1 if requesting positive relative move, -1 for negative relative move
	variable returnWhen //0 to return immediately, 1 to wait until movement is finished to return, 2 to set a background task. 
						// But Null always returns immediately
	variable  &xS, &yS, &zS, &AxS // variables that will hold the retreived absolute positions
	
	NVAR isBusy= root:packages:Null:isBusy
	if (isBusy)
		return 1
	endif
	isBusy = 1;doupdate
	NVAR hasXY = root:packages:null:hasXY
	NVAR hasZ = root:packages:null:hasZ
	NVAR hasAx = root:packages:null:hasAx
	NVAR LastX = root:packages:null:xDistanceFromzero
	NVAR LastY = root:packages:null:yDistanceFromzero
	NVAR LastZ = root:packages:null:zDistanceFromzero
	NVAR LastAx = root:packages:null:axDistanceFromzero
	// X 
	if (numtype (xS) == 0)
		// If is relative, account for polarity
		if (moveType != 0)
			NVAR polarityMult = root:packages:null:xPol
			xS *= (polarityMult * moveType)
			LastX += xS
		else
			LastX = xS
		endif
	endif
	// Y
	if (numtype (yS) == 0)
		// If is relative, account for polarity
		if (moveType != 0)
			NVAR polarityMult = root:packages:null:yPol
			yS *= (polarityMult * moveType)
			LastY += yS
		else
			LastY= yS
		endif
	endif
	//
	if (numtype (zS) ==0)
		// If is relative, account for polarity
		if (moveType != 0)
			NVAR polarityMult = root:packages:null:zPol
			zS *= (polarityMult * moveType)
			LastZ += zS
		else
			Lastz= zS
		endif
	endif
	// axial
	if (numtype (axS) == 0)
		// If is relative, account for polarity
		if (moveType != 0)
			NVAR polarityMult = root:packages:null:axPol
			axS *= (polarityMult * moveType)
			LastAx+= axS
		else
			LastAx= AxS
		endif
	endif
	isBusy = 0
	return 0
end

//***********************************************************************************	
// Sets a fixed increment for stage encoder.
Function StageSetInc_Null ([xVal, yVal, zVal, axVal])
	variable xVal, yVal, zVal, axVal // variables for requested increment. You can set one, two, or three at a time
	
	NVAR hasXY = root:packages:null:hasXY
	NVAR hasZ = root:packages:null:hasZ
	NVAR hasAx =  root:packages:null:hasAx
	if (hasXY == 1)
		// X 
		if (!(ParamIsDefault(xVal)))
			NVAR xStepSize = root:packages:null:xStepSize
			xStepSize = xVal
		endif
		// Y 
		if (!(ParamIsDefault(yVal)))
			NVAR yStepSize = root:packages:null:yStepSize
			yStepSize = yVal
		endif
	endif
	// Z
	if ((!(ParamIsDefault(zVal))) && (hasZ))
		NVAR zStepSize = root:packages:null:zStepSize
		zStepSize = zVal
	endif
	// axial
	if ((!(ParamIsDefault(axVal))) && (hasAx))
		NVAR axStepSize = root:packages:null:axStepSize
		axStepSize = axVal
	endif
end

//***********************************************************************************
// returns 1 if stage is busy, else 0. Null is never busy
function StageisBusy_null ()
	return 0
end

//*******************************************************************************
// Sets the current position to be Zero
Function StageSetZero_null()

	NVAR xDistancefromZero =root:packages:null:XdistancefromZero
	xDistancefromZero = 0
	NVAR yDistancefromZero =root:packages:null:ydistancefromZero
	yDistancefromZero = 0
	NVAR zDistancefromZero =root:packages:null:zdistancefromZero
	zDistancefromZero = 0
End

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
			NVAR doAbort = root:packages:null:doAbort
			doAbort = 1
		break
	endswitch
	return 0
End


//*******************************************************************************
// Enables or disables manual movement of stage
Function StageSetManual_null (manualLock)
	variable manualLock // 1 to lock, 0 to unlock

end