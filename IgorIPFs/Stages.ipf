#pragma rtGlobals=1		// Use modern global access method.
#pragma version= 5.1		// modification date 2016/10/13 by Jamie Boyd
#pragma IgorVersion=6.2
#include "GUIPList"
#include "GUIPControls"

// Designed to work with the  VDT2 XOP for serial devices, or the ASIUSBez XOP for ASI devices plugged into USB
// This procedure will compile without any of the VDT, VDT2, or ASIUSBez XOPs, but each
// stage encoder procedure will need to be written specifically for one or the other of these.

// The idea is that the control panel that this general procedure makes works with multiple specific procedures, 
// each targeting a different stage encoder, as long as the procedures for the stage encoder follow a few rules:
// StageStartStage will make a packages folder named after the stage encoder procedure and populate it with:
// 1) global string for the name of the port used by the stage encoder
// 2) global variables for capabilities for XY, Z, and Axial movement, motorization, ability to set PID values, and  if it is a USB or serial device:
// hasXY, hasZ, hasAx, hasMotor, hasPID, isUSB
// Although it is possible to use a single procedure with devices of different functionality and read the functionality after initialization,
// StageStartStage makes the control panel before intitialization, so each procedure must set functionality with hard-coded globals
// I recommend setting globals from  static constants, which are easily modified
// 3) global variables for distances from zero:
// XDistanceFromZero, YdistanceFomzero, zDistanceFromZero.
// 4) and, for motorized devices, increments for step movements, polarity (left vs right), and whether manual movement is Locked:
// XstepSize, YstepSize, ZstepSize, xPol, yPol, zPol, isLocked
// 5) a variable for whether or not any of the axes are moving, which your procedure should set if it wants to return while axes are still moving

// Make your stage setup, update, and move functions conform to the templates below.
// Return axes values in pass-by-reference parameters and set the global variables as well.

Menu "Macros"
	"Open Stage and Focus Panel",/Q,StageStart()	
end

//*******************NEMONIC CONSTANTS FOR STAGE MOVEMENTS********************************
// When moving, function can either: assume stage will get there, and return immediately; not return until requested position has been verified; set a background task to monitor position
CONSTANT kStagesReturnNow =0
CONSTANT kStagesReturnLater =1
CONSTANT kStagesReturnBkg =2
 // to pass absolute value to move to an absolute location
CONSTANT kStagesIsAbs =0
// to pass relative value to move in either direction
CONSTANT kStagesIsRelNeg =-1
CONSTANT kStagesIsRelPos =1
//****************************************************************************************************************************************************
//*******************Templates for functions which all stage encoder procedures are expected to provide********************************
//****************************************************************************************************************************************************
// Template for function to set global variables for the Stage encoder. The globals will be
// made by StageMakeGlobals procedure
Function StageInitGlobals_Template ()
	return 0
end

//*************************************************************************************************
// Template for function to add special controls for a particular stage encoder to a control panel
// X and Y offset refer to point offsets to position controls on control panel
Function StageAddControls_Template (xOffset, yOffset, thePanel)
	variable xOffset, yOffset
	string thePanel
	return 0
end

//*************************************************************************************************
//Template for Stage Setup functions
Function StageSetUpPort_Template (thePortName)
	string thePortName // Name of the serial port or ASI-USB device
	return 0
end

//*************************************************************************************************
//Template for Stage Close functions
Function StageClose_Template ()
	return 0
end

//*************************************************************************************************
// Template for Stage Update functions - the funcref should never resolve to this template function
Function StageUpdate_Template (xS, yS, zS, aS)
	variable &xS, &yS, &zS,  &aS 
	// variables that will hold the retreived absolute positions. When you pass them, have the ones you want updated as real numbers, and ones
	// you don't want updated as NaN. Not all encoders can check for each axis independently.
	
	xS = Nan;yS = Nan;zS=Nan; aS = Nan
	doAlert 0, "You do not have stage encoders configured properly."
	return 1
end

//*************************************************************************************************
// Template for Stage Move  function, which stage procedures for controllable stages must provide
// the funcref should never resolve to this template function
Function StageMove_Template (moveType, returnWhen, xS, yS, zS, aS)
	variable moveType//  0 if requesting movement to an absolute position. -1 or 1 if requesting movement relative to current location, 1 for positive movement, -1 for negative movement
	variable returnWhen // 0 to return immediately without checking that movement finishes, 1 to wait until movement is finished to return, 2 to return immediately but set a bkg task that updates position
	variable  &xS, &yS, &zS, &aS// variables that are non-NaN for requested axes, and will hold the retreived absolute positions
	
	xS = Nan;yS = Nan;zS=Nan;aS=Nan
	doAlert 0, "You do not have stage encoders configured properly."
	return 0
end

//*********************************************************************************************************************************************************************
//****************Templates for various functions which stage procedures may or may not provide, depending on their feature set***********************
//*********************************************************************************************************************************************************************
// Template for function to start/stop a bkg task to automatically update the positions
Function StageSetAuto_Template (turnOn)
	variable turnOn // if turnOn is non-zero, start the task, if it is zero, stop the task
	
	return 0
end

//*************************************************************************************************
// Template for stage set increment functions for movable stages
// If the stage encoder does not support saving increments on the encoder, they are still saved in the global variables
Function StageSetInc_Template ([xVal, yVal, zVal, aVal])
	variable xVal, yVal, zVal, aVal // variables for requested increment. You can set increment for one, two,  three, or four axes at a time
	
	return 0
end

//*************************************************************************************************
// Template for function to set zero position, i.e., zero the stage encoders for all supported axes
// Takes no arguments and returns no value
Function StageSetzero_Template ()
	
	return 0
end

//*************************************************************************************************
// Template for function to reset I/O, clearing any buffers
Function StageResetIO_Template ()
	
	return 0
end

//*************************************************************************************************
// Template for function to lock joystick to stop manual movement of stage encoder
Function StageSetManual_template (doLock)
	variable doLock //1 to lock manual movement of stage, 0 to unlock
	
	return 0
end

//*************************************************************************************************
// Template for function to add special controls for a particular stage encoder to the PID panel
// X and Y offset refer to point offsets to position controls on control panel
// returns the amount of extra vertical space it added
Function StageAddPIDControls_Template (Axis, xOffset, yOffset, thePanel)
	string Axis // X, Y, or Z will be called indepentently
	variable xOffset, yOffset
	string thePanel
	
	return 0
end


//*************************************************************************************************
// Template for function to fetch PID values for a single axis
// Set pS, iS, dS initally to 1 to fetch value for that PID, or 0 to not fetch
Function StageFetchPID_Template (theAxis, pS, iS, dS)
	string theAxis // X, Y, Z, or A (for axial)
	variable &pS, &iS, &dS  // variables that will hold the retreived PID values.
	
	pS = Nan;iS = Nan;dS=Nan
	doAlert 0, "You do not have stage encoders configured properly."
	return 1
end

//*************************************************************************************************
// Template for function to set PID values for a single axis. Set 1, 2, or 3 of the PID components at once
Function StageSetPID_Template (theAxis, [pS, iS, dS])
	string theAxis // X, Y, Z, or A (for axial)
	variable pS, iS, dS  // the PID values to set
	
	doAlert 0, "You do not have stage encoders configured properly."
	return 1
end


//****************************************************************************************************************************************************
// Lists Stage Encoder files in user procedures folder and associated device preferences
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
// Makes a panel for a given stage encoder, with customizations for the encoder
// Last modified 2015/04/12 by Jamie Boyd
Function StageStartStage(theStageEncoder, [thePort])
	String theStageEncoder
	String thePort
	
	//If panel exists, bring it to the front and exit
	Dowindow/F $theStageEncoder + "_Controls"
	if (V_Flag ==1)
		return 0
	endif
	// Check for packages folder and Stages folder 
	if (!(DataFolderExists ("root:packages:Stages")))
		if (!(datafolderExists ("root:packages:")))
			newdatafolder root:packages
		endif
		// Save current data folder
		string savedfolderStr = getdatafolder (1)
		// packages folder for Stages
		NewDataFolder/O/S root:packages:Stages
		// Check for ASIUSBInit function and call it to make a list of available devices, so list can appear in popup menus
		if ( exists ("ASIUSBInit") == 3)
			execute "ASIUSBInit ()" // use execute to prevent compilation error if not present. I know, it's such an Igor 5 thing to do
		endif
		setdataFolder $savedfolderStr
		doUpdate
	endif
	// Make global variables folder for this stage encoder
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
		if (!(ParamIsDefault(thePort )))
			Execute/P/Q "StagePortProc(\"" + theStageEncoder + "\", \"" + thePort +  "\")" 
		endif
	endif
end


//*********************************************************************************************
// Makes globals for the chosen Stage encoder
// Last Modified 2015/04/12 by Jamie Boyd
Function StageMakeGlobals (theStageEncoder)
	string theStageEncoder
	
	if(!(dataFolderExists ("root:packages:" + theStageEncoder)))
		if (!(datafolderExists ("root:packages:")))
			newdatafolder root:packages
		endif
		newDataFolder $"root:packages:" + theStageEncoder
		// name of serial port (or ASI USB device)
		string/G $"root:packages:" + theStageEncoder + ":thePort"
		// distances from 0
		variable/G  $"root:packages:" + theStageEncoder + ":xDistanceFromZero"
		variable/G  $"root:packages:" + theStageEncoder + ":yDistanceFromZero"
		variable/G  $"root:packages:" + theStageEncoder + ":zDistanceFromZero"
		variable/G  $"root:packages:" + theStageEncoder + ":aDistanceFromZero"
		// Min and maximum allowable travel
		variable/G $"root:packages:" + theStageEncoder + ":xyMIN" = -50e-03
		variable/G $"root:packages:" + theStageEncoder + ":xyMAX" = 50e-03
		variable/G $"root:packages:" + theStageEncoder + ":zMIN" = -5e-03
		variable/G $"root:packages:" + theStageEncoder + ":zMAX" = 5e03
		variable/G $"root:packages:" + theStageEncoder + ":aMIN" = -5e-03
		variable/G $"root:packages:" + theStageEncoder + ":aMAX" = 5e03
		// Step sizes
		variable/G $"root:packages:" + theStageEncoder + ":xStepSize"
		variable/G $"root:packages:" + theStageEncoder + ":yStepSize"
		variable/G $"root:packages:" + theStageEncoder + ":zStepSize"
		variable/G $"root:packages:" + theStageEncoder + ":aStepSize"
		// Polarity
		variable/G $"root:packages:" + theStageEncoder + ":xPol" 
		variable/G $"root:packages:" + theStageEncoder + ":yPol"
		variable/G $"root:packages:" + theStageEncoder + ":zPol"
		variable/G $"root:packages:" + theStageEncoder + ":aPol"
		// resolutions (minimum possible step)
		variable/G $"root:packages:" + theStageEncoder + ":xyRes"
		variable/G $"root:packages:" + theStageEncoder + ":zRes"
		variable/G $"root:packages:" + theStageEncoder + ":aRes"
		// capabilities
		variable/G $"root:packages:" + theStageEncoder + ":isUSB"
		variable/G $"root:packages:" + theStageEncoder + ":hasLock"
		variable/G $"root:packages:" + theStageEncoder + ":isLocked"
		variable/G $"root:packages:" + theStageEncoder + ":hasXY"
		variable/G $"root:packages:" + theStageEncoder + ":hasZ"
		variable/G $"root:packages:" + theStageEncoder + ":hasAx"
		variable/G $"root:packages:" + theStageEncoder + ":hasMotor"
		variable/G $"root:packages:" + theStageEncoder + ":hasAuto"
		variable/G $"root:packages:" + theStageEncoder + ":autoON"
		variable/G $"root:packages:" + theStageEncoder + ":hasPID"
		// PID settings
		variable/G $"root:packages:" + theStageEncoder + ":xPIDp"
		variable/G $"root:packages:" + theStageEncoder + ":xPIDi"
		variable/G $"root:packages:" + theStageEncoder + ":xPIDd"
		variable/G $"root:packages:" + theStageEncoder + ":yPIDp"
		variable/G $"root:packages:" + theStageEncoder + ":yPIDi"
		variable/G $"root:packages:" + theStageEncoder + ":yPIDd"
		variable/G $"root:packages:" + theStageEncoder + ":zPIDp"
		variable/G $"root:packages:" + theStageEncoder + ":zPIDi"
		variable/G $"root:packages:" + theStageEncoder + ":zPIDd"
		variable/G $"root:packages:" + theStageEncoder + ":aPIDp"
		variable/G $"root:packages:" + theStageEncoder + ":aPIDi"
		variable/G $"root:packages:" + theStageEncoder + ":xPIDpDef"
		variable/G $"root:packages:" + theStageEncoder + ":xPIDiDef"
		variable/G $"root:packages:" + theStageEncoder + ":xPIDdDef"
		variable/G $"root:packages:" + theStageEncoder + ":yPIDpDef"
		variable/G $"root:packages:" + theStageEncoder + ":yPIDiDef"
		variable/G $"root:packages:" + theStageEncoder + ":yPIDdDef"
		variable/G $"root:packages:" + theStageEncoder + ":zPIDpDef"
		variable/G $"root:packages:" + theStageEncoder + ":zPIDiDef"
		variable/G $"root:packages:" + theStageEncoder + ":zPIDdDef"
		variable/G $"root:packages:" + theStageEncoder + ":aPIDpDef"
		variable/G $"root:packages:" + theStageEncoder + ":aPIDiDef"
		variable/G $"root:packages:" + theStageEncoder + ":aPIDdDef"
		// for showing activity status
		variable/G $"root:packages:" + theStageEncoder + ":isBusy"
	endif
end

//*********************************************************************************************
//Returns a list of available serial ports for use with stage encoders using VDTGetPortList and VDTGetPortList2
// Last Modified 2015/04/12 by Jamie Boyd
Function/S StageListPorts ()
	
	string returnStr = ""
	if (exists("VDT2" ) == 4)
		execute "VDTGetPortList2" // Use "Execute" so procedure will compile with VDT or VDT2 xop or neither 
	elseif (exists("VDT" ) == 4)
		execute "VDTGetPortList"
	endif
	SVAR/Z S_VDT = :S_VDT
	if (SVAR_EXISTS (S_VDT))
		returnStr = S_VDT
	endif
	return returnStr  
end

//*******************************************************************************
// Opens a control panel for common stage related functions
// Has controls for both reading and setting stage coordinates
// Last Modified 2015/04/12 by Jamie Boyd
Function StageMakePanel (theStageEncoder) 
	string theStageEncoder
	
	//If panel exists, bring it to the front and exit
	Dowindow/F $theStageEncoder + "_Controls"
	if (V_Flag ==1)
		return 0
	endif
	// Go to the folder, for ease of programming
	string savedFolder = getdatafolder (1)
	setdatafolder  $"root:packages:" + theStageEncoder
	// Reference the globals for capabilities
	NVAR hasXY
	NVAR hasZ
	NVAR hasAx
	NVAR hasMotor
	NVAR hasLock
	NVAR hasAuto
	NVAR hasPID
	NVAR isUSB
	SVAR thePort
	// How wide do we need to make the panel? 
	variable nAxes = 2*hasXY + hasZ + hasAx
	variable panelW = 159 + nAxes * 140
	NewPanel /K=1 /W=(2,44, (2 + panelW), 198) as "Stage/Focus Controls-" + theStageEncoder
	DoWindow/C $theStageEncoder + "_Controls"
	modifypanel fixedsize = 1
	// Options are always at left, followed by boxes for varying numbers of axes
	GroupBox OptionsGrp,pos={1,2},size={158,153},title="Options",fSize=16,fStyle=1
	// Set zero
	Button StageSetzeroButton,pos={6,28},size={62,20},proc=StageSetzeroProc,title="Set zero"
	Button StageSetzeroButton,help={"Sets all of the axes position values to 0."}
	// Update position values
	Button UpdateButton,pos={71,28},size={46,20},proc=StageUpdateButtonProc,title="Update "
	Button UpdateButton,help={"Gets the current position values for all axes."}
	// Auto update position Values in a bkg task
	if (hasAuto)
		NVAR autoON
		CheckBox autoCheck,pos={117,31},size={40,14},proc=StageAutoCheckProc,title="Auto"
		CheckBox autoCheck variable=autoON
		CheckBox autoCheck,value= 0,help={"Starts/Stops a background task to automatically update positions."}
	endif
	// Open PID Panel
	if (hasPID)
		Button PIDButton,pos={132,74},size={26,20},proc=StagePIDButtonProc,title="PID"
		Button PIDButton,help={"Opens a panel where proportional-integral-derivative settings for this encoder can be adjusted. Use at your own risk."}
	endif
	// Reset IO for serial - 
	if (!(isUSB))
		Button ResetIOButton,pos={6,50},size={65,20},proc=StageResetIOProc,title="Clear buffer"
		Button ResetIOButton,help={"Clears spurious characters that may be remaining in the serial port input/output buffer."}
	endif
	// Toggle maual
	if ((hasMotor) && (hasLock))
		NVAR isLocked
		CheckBox ManualToggleCheck,pos={74,53},size={80,14},proc=StageSetManualCheckProc,title="Manual Lock"
		CheckBox ManualToggleCheck,variable= isLocked
		CheckBox ManualToggleCheck, help = {"Inactivates manual, but not computer controlled, movement on all axes."}
	endif
	// Popup and titlebox for serial port/USB device - slightly different for USB vs serial devices
	string portList = ""
	PopupMenu thePortPopup pos={6,72},size={59,21}, mode=0, proc=Stages_PortPopMenuProc
	TitleBox thePortTitle, pos={81,72}, size={38,21}, variable = thePort
	if (isUSB)
		PopupMenu thePortPopup value =#"root:packages:Stages:S_ASIUSBDevList", title="Device:", help = {"Choose an ASI USB device to use as this stage encoder."}
		TitleBox thePortTitle help = {"Shows the ASI USB device selected as this stage encoder."} 
		SVAR/Z USBlist = root:Packages:Stages:S_ASIUSBDevList
		if (SVAR_Exists(USBlist))
			portList = USBlist
		endif
	else
		PopupMenu thePortPopup, value= #"stageListPorts()",  title="Port:", help = {"Choose a serial port to use with this stage encoder."}
		TitleBox thePortTitle help = {"Shows the serial port used by this stage encoder."}
		portList =StageListPorts ()
	endif
	// Activity indicator for this stage encoder, have to use execute to make dependency formula
	ValDisplay isBusyValDisp,pos={6,133},size={56,18},title="Activity", help = {"\"Glows\" orange when stage is active."}
	ValDisplay isBusyValDisp,limits={-1,1,0},barmisc={0,0},mode= 1,highColor= (65280,21760,0),lowColor= (56576,56576,56576)
	string commandStr = "ValDisplay isBusyValDisp value=root:packages:" + theStageEncoder + ":isBusy"
	execute commandStr
	// button to save a formatted string containing positions
	Button SavePosButton,pos={63,130},size={48,20},proc=StageSavePosButtonProc,title="Sv Pos"
	Button SavePosButton, help = {"Opens a dialog to save current stage position for later recall."}
	if (hasMotor)
		PopupMenu StageGoToPopMenu,pos={112,130},size={39,21},proc=StageGoToSavedPopMenuProc,title="Go"
		PopupMenu StageGoToPopMenu,help={"Sends the stage to the selcted saved position."}
		PopupMenu StageGoToPopMenu,mode=0,value=# "StageListSavedPos() + \"\\\\M1(-;Edit Position Wave\""
	endif
	//Add axes as required: all controls are placed with x-position relative to an offset
	variable xOffset=159
	// first comes XY Stage
	if (hasXY)
		NVAR xStepSize
		NVAR yStepSize
		NVAR xyMIN
		NVAR xyMAX
		NVAR xyRes
		GroupBox StageGroup,pos={(xOffset),2},size={278,153},title="Stage/XY",fSize=16,fStyle=1
		if (hasMotor)
			Button StageXYGoToZeroButton,pos={(xOffset + 87),126},size={74,21},proc=StageGoToZeroProc,title="Go to Zero"
		endif
		// X
		TitleBox XTitle,pos={(xOffset + 8),36},size={15,24},title="X",fSize=20,frame=0,fStyle=1
		SetVariable XDistanceSetVar,pos={(xOffset + 4),101},size={134,16}, title="From zero", fSize=12, format="%.2W0Pm"
		SetVariable XDistanceSetVar,value= $"root:Packages:" + theStageEncoder + ":XDistanceFromZero", limits={-INF, inf, 0}
		if (hasMotor)
			SetVariable XDistanceSetVar, proc=GUIPSIsetVarProc
			SetVariable XDistanceSetVar,userdata=  "StageSetDistanceProc;" + num2str (xyMin) + ";" + num2str (xyMax)+ ";;"
			Button XleftStepButton,pos={(xOffset + 33),28},size={88,20},proc=StageStepButtonProc,title="Left 1 step"
			Button XrightStepButton,pos={(xOffset + 33),51},size={88,20},proc=StageStepButtonProc,title="Right 1 Step"
			SetVariable XstepSizeSetvar,pos={(xOffset + 4),80},size={134,16},proc=GUIPSIsetVarProc,title="Step Size"
			SetVariable XstepSizeSetvar,userdata=  "StageSetIncProc;" + num2str (xyRes)+ ";" + num2str ((xyMax-xyMin)/10) + ";autoInc;"
			SetVariable XstepSizeSetvar,format="%.2W0Pm", fSize=12
			SetVariable XstepSizeSetvar,limits={-inf, inf, xStepSize},value= $"root:Packages:" + theStageEncoder  + ":xStepSize"
		else // no motor
			SetVariable XDistanceSetVar, noedit=1
		endif
		xOffset += 136
		// Y
		TitleBox YTitle,pos={(xOffset + 8),36},size={15,24},title="Y",fSize=20,frame=0,fStyle=1
		SetVariable YDistanceSetVar,pos={(xOffset + 4),101},size={134,16},title="From zero",  fSize=12, format="%.2W0Pm"
		SetVariable YDistanceSetVar value= $"root:Packages:" + theStageEncoder + ":YDistanceFromZero", limits={-INF, inf, 0}
		if (hasMotor)
			SetVariable YDistanceSetVar,proc=GUIPSIsetVarProc
			SetVariable YDistanceSetVar,userdata=  "StageSetDistanceProc;" +  num2str (xyMin) + ";" + num2str (xyMax) + ";;"
			Button YForwardStepButton,pos={(xOffset + 33),28},size={88,20},proc=StageStepButtonProc,title="Forward 1 Step"
			Button YBackStepButton,pos={(xOffset + 33),51},size={88,20},proc=StageStepButtonProc,title="Back 1 Step"
			SetVariable YStepSizeSetVar,pos={(xOffset + 4),80},size={134,16},proc=GUIPSIsetVarProc,title="Step Size"
			SetVariable YStepSizeSetVar,userdata=  "StageSetIncProc;" + num2str (xyres)+ ";" + num2str ((xyMax-xyMin)/10) + ";autoInc;"
			SetVariable YStepSizeSetVar,format="%.2W0Pm", fSize=12
			SetVariable YStepSizeSetVar,limits={-inf,inf,yStepSize},value= $"root:Packages:" + theStageEncoder + ":YstepSize"
		else
			SetVariable YDistanceSetVar, noedit =1
		endif
		xOffset += 141
	endif
	// Add Z controls, if present
	if (hasZ)
		NVAR zStepSize
		NVAR zMIN
		NVAR zMax
		NVAR zRes
		GroupBox FocusGroup,pos={(xOffset),2},size={142,153},title="Focus/Z",fSize=16,fStyle=1
		TitleBox Ztitle,pos={(xOffset + 4),36},size={15,24},title="Z",fSize=20,frame=0,fStyle=1
		SetVariable ZDistanceSetVar,pos={(xOffset + 4),101},size={134,16}, title="From zero", fSize=12, format="%.2W0Pm"
		SetVariable ZDistanceSetVar value= $"root:Packages:" + theStageEncoder + ":ZDistanceFromZero", limits={-INF, inf, 0}
		if (hasMotor)
			SetVariable ZDistanceSetVar,proc=GUIPSIsetVarProc
			SetVariable ZDistanceSetVar,userdata=  "StageSetDistanceProc;" +  num2str (zMin) + ";" + num2str (zMax) + ";;"
			Button ZUpStepButton,pos={(xOffset + 33),28},size={88,20},proc=StageStepButtonProc,title="Up 1 Step"
			Button ZDownStepButton,pos={(xOffset + 33),51},size={88,20},proc=StageStepButtonProc,title="Down 1 Step"
			SetVariable ZStepSizeSetVar,pos={(xOffset + 4),80},size={134,16},proc=GUIPSIsetVarProc,title="Step Size"
			SetVariable ZStepSizeSetVar,userdata=  "StageSetIncProc;" + num2str (zRes)+  ";" + num2str ((zMax-zMin)/10) + ";autoInc;"
			SetVariable ZStepSizeSetVar,format="%.1W0Pm", fSize=12
			SetVariable ZStepSizeSetVar,limits={0,inf,zStepSize},value= $"root:Packages:" + theStageEncoder + ":ZstepSize"
			Button ZGoToZeroButton,pos={(xOffset + 34),126},size={74,21},proc=StageGoToZeroProc,title="Go to Zero"
		else
			SetVariable ZDistanceSetVar, noedit =1
		endif
		xOffset += 142
	endif
	// Add Axial controls, if Present
	if (hasAx)
		NVAR aStepSize
		NVAR axMIN = $"root:packages:" + theStageEncoder + ":axMIN"
		NVAR axMax = $"root:packages:" + theStageEncoder + ":axMAX"
		GroupBox AxisGroup,pos={(xOffset),2},size={142,153},title="Axial",fSize=16,fStyle=1
		TitleBox Axtitle,pos={(xOffset + 4),36},size={15,24},title="Ax",fSize=20,frame=0,fStyle=1
		SetVariable axDistanceSetVar,pos={(xOffset + 4),101},size={134,16}, title="From zero", fSize=12, format="%.2W0Pm"
		SetVariable axDistanceSetVar value= $"root:Packages:" + theStageEncoder + ":axDistanceFromZero", limits={-INF, inf, 0}
		if (hasMotor)
			SetVariable axDistanceSetVar,proc=GUIPSIsetVarProc
			SetVariable axDistanceSetVar,userdata=  "StageSetDistanceProc;" +  num2str (axMin) + ";" + num2str (axMax) + ";;"
			Button axOutStepButton,pos={(xOffset + 33),28},size={88,20},proc=StageStepButtonProc,title="Out 1 Step"
			Button axInStepButton,pos={(xOffset + 33),51},size={88,20},proc=StageStepButtonProc,title="In 1 Step"
			SetVariable aStepSizeSetVar,pos={(xOffset + 4),80},size={134,16},proc=GUIPSIsetVarProc,title="Step Size"
			SetVariable aStepSizeSetVar,userdata=  "StageSetIncProc;" + num2str (aStepSize)+ ";autoInc;"
			SetVariable aStepSizeSetVar,format="%.1W0Pm", fSize=12
			SetVariable aStepSizeSetVar,limits={0,inf,aStepSize},value= $"root:Packages:" + theStageEncoder + ":aStepSize"
			Button axGoToZeroButton,pos={(xOffset + 34),126},size={74,21},proc=StageGoToZeroProc,title="Go to Zero"
		else
			SetVariable axDistanceSetVar, noedit =1
		endif
	endif
	setdatafolder $SavedFolder
	// invite stage encoder to put up any special controls it has
	Funcref StageAddControls_Template StageAddFunc = $"StageAddControls_" + theStageEncoder
	StageAddFunc (7, 95, theStageEncoder + "_Controls") // 7,95 are X and Y offset to where special controls can be placed
	// Set hook function to close port when panel is closed
	setwindow $theStageEncoder + "_Controls"  hook(QHook )=StageClosePortAndPanel
	// Check serial ports/USB devices and set port/device if only one is found
	variable Numports = ItemsInList (portList)
	switch (numports)
		case 0:	// no ports/devices found
			if (isUSB)
				doalert 0, "No ASI USB devices were found, so stage/focus controls can not be used. Try a Serial Port stage procedure instead."
			else
				doalert 0, "No Serial Ports were found, so stage/focus controls can not be used. Try the ASI-USB stage procedure instead."
			endif
			DoWindow/K $theStageEncoder + "_Controls"
			return 1
			break
		case 1:	// one  port/device found. No need to make user choose, choose for user 
			StagePortProc(theStageEncoder, stringfromlist (0, portList, ";")) 
			break
		default:	// more than one serial port.
			if (isUSB)
				thePort = "SELECT DEVICE"
			else
				thePort = "SELECT PORT"
			endif
			break
	endswitch
end

//*************************************************************************************************
// hook function to close the serial port when the panel is closed, although igor will do this when it quits, so is only needed if you want to use the serial port with another
// program while Igor is still running, or use a different encoder/port combination.
Function StageClosePortAndPanel(s)
	STRUCT WMWinHookStruct &s
	
	string theEncoder = stringfromlist (0, s.winName, "_")
	switch(s.eventCode)
		case 2: // Handle Kill
			// Call Stage's closeport function
			FuncRef StageClose_Template StageCloseFunc =  $"StageClose_" + theEncoder
			StageCloseFunc ()
			// Kill packages folder for this encoder
			KillDataFolder/Z $"root:packages:" + theEncoder
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
			String thePort = pa.popStr
			//Control panel is named for the stageEncoder procedure
			string theStageEncoder = stringfromlist (0, pa.win, "_")
			StagePortProc(theStageEncoder, thePort)
			break
	endswitch
	return 0
End

//*********************************************************************************************
//When a serial port is selected, sets the global string to the selected value, and tries to initialize the stage encoder
// Last Modified Sep 29 2010 by Jamie Boyd
Function StagePortProc(theStageEncoder, thePort)
	String theStageEncoder
	String thePort
	
	// Save port name in global string in pakages folder for this stage procedure
	SVAR thePortName = $"root:packages:" + theStageEncoder + ":thePort"
	thePortName = thePort
	Funcref StageSetupPort_Template StageSetupPortFunc = $"StageSetUpPort_" + theStageEncoder
	StageSetupPortFunc (thePort) // initilaize the encoder with the chosen port, do whatever needs to be done for this device
	// do an initial update
	STRUCT WMButtonAction ba
	ba.eventCode = 2
	ba.win = theStageEncoder + "_Controls"
	StageUpdateButtonProc(ba)

end 


//*******************************************************************************
//------------------Controls for Options Section-----------------------------------------
//*******************************************************************************
// Calls the stage encoder's update function to get latest stage coodinates
// Update func must be modeled after StageUpdateTemplate
Function StageUpdateButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			variable xS=1, yS=1, zS=1, aS=1
			funcref  StageUpdate_Template UpdateStage=$"StageUpDate_" + theStageEncoder
			UpdateStage (xS, yS, zS, aS)
			// No need to update global variables on control panel with xS, yS, and zS
			// as the UpdateStage procedure should do this
			break
	endswitch
	return 0
End

//*******************************************************************************
// Turns on and off a background task to monitor stage position
// Last modified jun 29 2009 by Jamie Boyd
Function StageAutoCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			string theStageEncoder = stringfromlist (0, cba.win, "_")
			funcref  StageSetAuto_Template SetAuto=$"StageSetAuto_" + theStageEncoder
			SetAuto (checked)
			break
	endswitch
	return 0
End

//*******************************************************************************
// Calls the stage encoder's setzero procedure.
// Set zero procedure takes no arguments and returns no results
Function StageSetzeroProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			variable xS, yS, zS
			funcref  StageSetzero_Template SetzeroProc=$"StageSetzero_" + theStageEncoder
			SetzeroProc ()
			break
	endswitch
	return 0
End

//*******************************************************************************
// Turns manual control on or off, so no bumping during crucial experimental sequence
// Uses stage encoder procedures StageSetManual_ function.
// Last Modified Jun 02 2009 by Jamie Boyd
Function StageSetManualCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			string theStageEncoder = stringfromlist (0, cba.win, "_")
			funcref  StageSetManual_Template SetManualStage=$"StageSetManual_" + theStageEncoder
			SetManualStage (checked)
			break
	endswitch

	return 0
End

//*******************************************************************************
//Clears any pending I/O on the serial port used for the focus motor, in case there any errors 
// Last modified jun 21 2009 by Jamie Boyd
Function StageResetIOProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			funcref StageResetIO_Template ResetIO = $"StageResetIO_" + theStageEncoder
			ResetIO ()
			break
	endswitch
	return 0
End

//*******************************************************************************
//--------------------functions for controls that move the stage------------------------------
// For move controls, default is to return immediately, and assume we got there. Shift key held down will will only return when position has been obtained
// Command/ctrl will set a background task to monitor position. 
//*******************************************************************************
// Goes to zero position for X,Y and Z
// Last Modified Nov 25 2010 by Jamie Boyd
Function StageGoToZeroProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			variable xS=NaN,yS=NaN,zS=NaN, aS=NaN
			strswitch (ba.ctrlName)
				case "StageXYGoToZeroButton":
					xS =0
					yS =0
					break
				case "ZGoToZeroButton":
					zS=0
					break
				case "axGoToZeroButton":
					aS =0
					break
				default:
					doAlert 0, "The StageGoToZeroProc was not expecting a control names \"" + ba.ctrlName + "\"."
					return 1
					break
			endswitch
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			funcRef StageMove_Template StageMove = $"StageMove_" + theStageEncoder
			variable returnWhen =kStagesReturnNow
			if (ba.eventMod & 2)
				returnWhen = kStagesReturnLater
			elseif (ba.eventmod & 8)
				returnWhen = kStagesReturnBkg
			endif
			StageMove (0,returnWhen,xS,yS,zS,aS)
			break
	endswitch
	return 0
End

//*******************************************************************************
// Steps stage in predefined increments
// Last Modified Sep 28 2010 by Jamie Boyd
Function StageStepButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			// read stage proc name from control panel
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			variable polarity =1, xS=NaN,yS=NaN,zS=NaN, aS=NaN
			strswitch (ba.ctrlName)
				case "XleftStepButton":
					polarity =-1
				case "XrightStepButton":
					NVAR xStepSize = $"root:packages:" + theStageEncoder + ":xStepSize"
					NVAR xPol = $"root:packages:" + theStageEncoder + ":xPol" 
					polarity *= xPol
					xS = xStepSize
					break
				case "YBackStepButton":
					polarity =-1
				case "YForwardStepButton":
					NVAR yStepSize = $"root:packages:" + theStageEncoder + ":yStepSize"
					NVAR yPol = $"root:packages:" + theStageEncoder + ":yPol" 
					polarity *= yPol
					yS = yStepSize
					break
				case "ZUpStepButton":
					polarity = -1
				case "ZDownStepButton":
					NVAR zstepSize = $"root:packages:" + theStageEncoder + ":zStepSize"
					NVAR zPol = $"root:packages:" + theStageEncoder + ":zPol" 
					polarity *= zPol
					zS = zstepSize
					break
				case "axOutStepButton":
					polarity = -1
				case "axInStepButton":
					NVAR aStepSize =  $"root:packages:" + theStageEncoder + ":aStepSize"
					NVAR aPol = $"root:packages:" + theStageEncoder + ":aPol"		
					polarity *= aPol
					aS = aStepSize
					break
				default:
					doAlert 0, "StageStepButtonProc was not expecting a control named \"" + ba.ctrlName + "\"."
					return 1
					break
			endswitch
			// move the selected axis
			variable returnWhen =kStagesReturnNow
			if (ba.eventMod & 2)
				returnWhen = kStagesReturnLater
			elseif (ba.eventmod & 8)
				returnWhen = kStagesReturnBkg
			endif
			funcRef StageMove_Template StageMove = $"StageMove_" + theStageEncoder
			StageMove (polarity, returnWhen, xS,yS,zS, aS)
	endSwitch
	return 0
End

//*******************************************************************************
// Sets the increment for each step of the stepping buttons. Not all stage encoders support storing the increment on the 
// stage encoder, but it is always stored in the global variable that is linked to the corresponding setvariable control
// Last Modified Sep 28 2010 by Jamie Boyd
Function StageSetIncProc (sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			string theStageEncoder = stringfromlist (0, sva.win, "_")
			funcRef StageSetInc_Template StageSetInc = $"StageSetInc_" + theStageEncoder
			strswitch (sva.ctrlName)
				case "XstepSizeSetvar":
					StageSetInc (xVal = dval)
					break
				case "YStepSizeSetVar":
					StageSetInc (yVal = dval)
					break
				case "zStepSizeSetVar":
					StageSetInc (zVal = dval)
					break
				case "aStepSizeSetVar":
					StageSetInc (aVal = dval)
					break
				default:
					doalert 0, "StageSetIncProc was not expecting a control named \"" + sva.ctrlname + "\"."
					return 1
					break
			endSwitch
			break
	endswitch
	return 0
End

//*******************************************************************************
// moves the stage to an absolute position given by the variabel controlled by the setvar
// Last Modified Nov 25 2010 by Jamie Boyd
Function StageSetDistanceProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			variable xS=NaN,yS=NaN,zS=NaN, aS=NaN
			strswitch (sva.ctrlName)
				case "XDistanceSetVar":
					xS = sva.dval
					break
				case "YDistanceSetvar":
					yS = sva.dval
					break
				case "zDistanceSetVar":
					zS=sva.dval
					break
				case "axDistanceSetVar":
					aS = sva.dval
					break
				default:
					doalert 0, "StageSetDistanceProc was not expecting a control named \"" + sva.ctrlname + "\"."
					return 1
					break
			endSwitch
			string theStageEncoder = stringfromlist (0, sva.win, "_")
			funcRef StageMove_Template StageMove = $"StageMove_" + theStageEncoder
			variable returnWhen =kStagesReturnNow
			if (sva.eventMod & 2)
				returnWhen = kStagesReturnLater
			elseif (sva.eventmod & 8)
				returnWhen = kStagesReturnBkg
			endif
			StageMove (0,returnWhen,  xS, yS, zS, aS)
			break
	endswitch
	return 0
End

//*************************************************************************************************************
// Saves current stage coordinates in a special wave in the Stages folder
// Last modified Sep 28 2010 by Jamie Boyd
Function StageSavePosButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// get name of Stage encoder and some info
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			NVAR hasXY =$" root:Packages:" + theStageEncoder + ":hasXY"
			NVAR hasZ =$" root:Packages:" + theStageEncoder + ":hasZ"
			NVAR hasAx = $" root:Packages:" + theStageEncoder + ":hasAx"
			// get name for this set of coordinates
			string PosString
			Prompt PosString, "Name for saved coordinates:"
			variable doXY, doZ, doAx
			Prompt doXY, "Save XY Position:",  popup,"Yes;No"
			Prompt doZ, "Save Z Position:",  popup,"Yes;No"
			Prompt doAx "Save Axial Position:", popUp, "Yes;No"
			// Only ask to save things this stage has installed
			if (hasXY)
				if (hasZ)
					if (hasAX)
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString, doXY, doZ, doAx
					else // has XY and Z, but not axial
						doAx =2 // Don't save axial
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString, doXY, doZ
					endif
				else // Has XY but not Z
					doZ = 2
					if (HasAx)
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString, doXY, doAx
					else // has XY only
						doXY =1 // of course you are going to save XY  - it's all you have!
						doax =2
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString
					endif
				endif
			else // does not have XY
				doXY =2
				if (hasZ)
					if (hasAX) // has Z and Ax
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString, doZ, doAx
					else // Only has Z 
						doZ=1
						doAx=2
						DoPrompt /HELP="Saves Current Stage Position for later recall" "Save Coordinates", PosString
					endif
				else // does not have XY or Z 
					if (hasAx) // only has axial - possible?
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
			wave/z PosWave = $"root:packages:" + theStageEncoder + ":SavedPosWave"
			if (!(waveExists (posWave)))
				make/n = (1,4)  $"root:packages:" + theStageEncoder + ":SavedPosWave"
				wave PosWave =  $"root:packages:" + theStageEncoder + ":SavedPosWave"
				setdimlabel 1,0, X_Pos PosWave
				setdimlabel 1,1, Y_Pos PosWave
				setdimlabel 1,2, Z_Pos PosWave
				setdimlabel 1,3, axial_Pos PosWave
				iPos =0
			else
				variable nPos = dimsize (PosWave,0)
				for (iPos =0; iPos < nPos && cmpStr (PosString,  GetDimLabel(PosWave, 0, iPos)) != 0 ; iPos += 1)
				endfor
				if (iPos == nPos)
					insertPoints iPos, 1, PosWave
				else
					DoAlert 1, "A saved position with the name \"" +PosString + "\" already exists. Overwrite position?"
					if  (V_Flag == 2) // no was clicked
						return 1
					endif
				endif
			endif
			// Update the stage and get X, Y, Z, Ax
			variable xS=(doXY ==1 ? 1: Nan), yS=(doXY ==1 ? 1: Nan), zS=(doZ ==1 ? 1: Nan), aS=(doAx ==1 ? 1: Nan)
			funcref  StageUpdate_Template UpdateStage=$"StageUpDate_" + theStageEncoder
			UpdateStage (xS, yS, zS, aS)
			// Fill in data, as requested, or Nans
			SetDimLabel 0,iPos, $cleanupName (PosString, 0),PosWave
			PosWave [iPos] [0] =xS
			PosWave [iPos] [1] = yS
			PosWave [iPos] [2] = zS
			PosWave [iPos] [3] = aS
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
// Last Modified Nov 25 2010 by Jamie Boyd
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
				returnWhen =kStagesReturnLater
			elseif (pa.eventmod & 8)
				returnWhen = kStagesReturnBkg
			endif
			Variable pos = pa.popNum -1
			variable xS= PosWave [pos] [0]
			variable yS =  PosWave [pos] [1]
			variable zS =  PosWave [pos] [2]
			variable aS = PosWave [pos] [3]
			funcRef StageMove_Template StageMove = $"StageMove_" + theStageEncoder
			StageMove (0,returnWhen,xS,yS,zS,aS)
			break
	endswitch
	return 0
End

//*************************************************************************************************************
// Code to put up a separate panel to adjust PID. For those encoders that support that sort of thing.
// Last Modified Sep 29 by Jamie Boyd
Function StagePIDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			NVAR hasPID = $"root:packages:" + theStageEncoder + ":hasPID"
			if (!(hasPID))
				doAlert 0, "This stage encoder, \"" + theStageEncoder + "\", does not support setting PID."
				return 0
			endif
			doWindow/F $theStageEncoder + "_PID"
			if (V_Flag ==1)
				return 0
			endif
			// variables to update each axes as its controls are made
			variable pS, iS, dS
			funcRef StageFetchPID_Template FetchPID = $"StageFetchPID_" + theStageEncoder
			//what axes are available?
			NVAR hasXY = $"root:packages:" + theStageEncoder + ":hasXY"
			NVAR hasZ = $"root:packages:" + theStageEncoder + ":hasZ"
			NVAR hasAx = $"root:packages:" + theStageEncoder + ":hasAx"
			variable nAxes = 2*hasXY + hasZ + hasAx
			// make the panel the calculated size for axes present
			variable panelW = nAxes * 116 + 1
			NewPanel /K=1 /W=(2,44, (panelW), 155) as "PID Settings-" + theStageEncoder
			DoWindow/C $theStageEncoder + "_PID"
			modifypanel fixedsize = 1
			// add controls for each axis
			variable xOffset=1
			if (hasXY)
				// Controls for X
				// group box
				GroupBox XGrp,pos={(xOffset),0},size={115,110},title="X PID",fSize=16,fStyle=1
				// set variables for P,I, and D
				SetVariable XPsetVar,pos={(xOffset + 3),26},size={105,16},title="Proportional"
				SetVariable XPsetVar,help={"Weights: the current error. Larger value = faster response, but greater instability and possible oscillation."}
				SetVariable XPsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":xPIDp", proc=StagePIDSetVarProc
				SetVariable XIsetVar,pos={(xOffset + 3),44},size={105,16},title="Integral       "
				SetVariable XIsetVar,help={"Weights: the sum of recent errors. Larger values= errors eliminated more quickly, but with larger overshoot.\""}
				SetVariable XIsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":xPIDi", proc=StagePIDSetVarProc
				SetVariable XDsetVar,pos={(xOffset + 3),62},size={105,16},title="Derivative   "
				SetVariable XDsetVar,help={"Weights: rate the error has been changing. Larger value= less overshoot, but slower transient response, possible instability."}
				SetVariable XDsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":xPIDd", proc=StagePIDSetVarProc
				// Buttons for Getting PID from stage encoder and reverting to default values
				Button XPIDupdateButton,pos={(xOffset + 4),85},size={50,20},title="Get", proc = Stages_FetchPIDButtonProc
				Button XPIDupdateButton,help={"Fetches the PID values currently set for the X axis"}
				Button XPIDdefaultButton,pos={(xOffset + 61),85},size={50,20},title="default",proc =Stages_RevertPIDButtonProc
				Button XPIDdefaultButton,help={"Sets the PID values for X axis to default  values stored as constants in the stage-specific procedure file"}
				pS=1; iS=1; dS=1
				FetchPID ("X", pS, iS, dS)
				// Controls for Y
				xOffset += 115
				// group box
				GroupBox YGrp,pos={(xOffset),0},size={115,110},title="Y PID",fSize=16,fStyle=1
				// Set variables for P, I, and D
				SetVariable YPsetVar,pos={(xOffset + 3),26},size={105,16},title="Proportional"
				SetVariable YPsetVar,help={"Weights: the current error. Larger value = faster response, but greater instability and possible oscillation."}
				SetVariable YPsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":yPIDp", proc=StagePIDSetVarProc
				SetVariable YIsetVar,pos={(xOffset + 3),44},size={105,16},title="Integral       "
				SetVariable YIsetVar,help={"Weights: the sum of recent errors. Larger values= errors eliminated more quickly, but with larger overshoot.\""}
				SetVariable YIsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":yPIDi", proc=StagePIDSetVarProc
				SetVariable YDsetVar,pos={(xOffset + 3),62},size={105,16},title="Derivative   "
				SetVariable YDsetVar,help={"Weights: rate the error has been changing. Larger value= less overshoot, but slower transient response, possible instability."}
				SetVariable YDsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":yPIDd", proc=StagePIDSetVarProc
				// Buttons for Getting PID from stage encoder and reverting to default values
				Button YPIDupdateButton,pos={(xOffset + 4),85},size={50,20},title="Get", proc = Stages_FetchPIDButtonProc
				Button YPIDupdateButton,help={"Fetches the PID values currently set for the Y axis"}
				Button YPIDdefaultButton,pos={(xOffset + 61),85},size={50,20},title="default",proc =Stages_RevertPIDButtonProc
				Button YPIDdefaultButton,help={"Sets the PID values for Y axis to default  values stored as constants in the stage-specific procedure file"}
				pS=1; iS=1; dS=1
				FetchPID ("Y", pS, iS, dS)
			endif
			if (hasZ)
				xOffset += 115
				// group box
				GroupBox ZGrp,pos={(xOffset),0},size={115,110},title="Z PID",fSize=16,fStyle=1
				// Set variables for P, I, and D
				SetVariable ZPsetVar,pos={(xOffset + 3),26},size={105,16},title="Proportional"
				SetVariable ZPsetVar,help={"Weights: the current error. Larger value = faster response, but greater instability and possible oscillation."}
				SetVariable ZPsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":zPIDp", proc=StagePIDSetVarProc
				SetVariable ZIsetVar,pos={(xOffset + 3),44},size={105,16},title="Integral       "
				SetVariable ZIsetVar,help={"Weights: the sum of recent errors. Larger values= errors eliminated more quickly, but with larger overshoot.\""}
				SetVariable ZIsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":zPIDi", proc=StagePIDSetVarProc
				SetVariable ZDsetVar,pos={(xOffset + 3),62},size={105,16},title="Derivative   "
				SetVariable ZDsetVar,help={"Weights: rate the error has been changing. Larger value= less overshoot, but slower transient response, possible instability."}
				SetVariable ZDsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":zPIDd", proc=StagePIDSetVarProc
				// Buttons for Getting PID from stage encoder and reverting to default values
				Button ZPIDupdateButton,pos={(xOffset + 4),85},size={50,20},title="Get", proc = Stages_FetchPIDButtonProc
				Button ZPIDupdateButton,help={"Fetches the PID values currently set for the Z axis"}
				Button ZPIDdefaultButton,pos={(xOffset + 61),85},size={50,20},title="default",proc =Stages_RevertPIDButtonProc
				Button ZPIDdefaultButton,help={"Sets the PID values for Z axis to default  values stored as constants in the stage-specific procedure file"}
				pS=1; iS=1; dS=1
				FetchPID ("Z", pS, iS, dS)
			endif
			if (hasAx)
				xOffset += 115
				// group box
				GroupBox AxGrp,pos={(xOffset),0},size={115,110},title="Ax PID",fSize=16,fStyle=1
				// Set variables for P, I, and D
				SetVariable APsetVar,pos={(xOffset + 3),26},size={105,16},title="Proportional"
				SetVariable APsetVar,help={"Weights: the current error. Larger value = faster response, but greater instability and possible oscillation."}
				SetVariable APsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":axPIDp", proc=StagePIDSetVarProc
				SetVariable AIsetVar,pos={(xOffset + 3),44},size={105,16},title="Integral       "
				SetVariable AIsetVar,help={"Weights: the sum of recent errors. Larger values= errors eliminated more quickly, but with larger overshoot.\""}
				SetVariable AIsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":axPIDi", proc=StagePIDSetVarProc
				SetVariable ADsetVar,pos={(xOffset + 3),62},size={105,16},title="Derivative   "
				SetVariable ADsetVar,help={"Weights: rate the error has been changing. Larger value= less overshoot, but slower transient response, possible instability."}
				SetVariable ADsetVar,limits={-inf,inf,0},value= $"root:packages:" + theStageEncoder + ":axPIDd", proc=StagePIDSetVarProc
				// Buttons for Getting PID from stage encoder and reverting to default values
				Button APIDupdateButton,pos={(xOffset + 4),85},size={50,20},title="Get", proc = Stages_FetchPIDButtonProc
				Button APIDupdateButton,help={"Fetches the PID values currently set for the Axial axis"}
				Button APIDdefaultButton,pos={(xOffset + 61),85},size={50,20},title="default",proc =Stages_RevertPIDButtonProc
				Button APIDdefaultButton,help={"Sets the PID values for Axial axis to default  values stored as constants in the stage-specific procedure file"}
				pS=1; iS=1; dS=1
				FetchPID ("A", pS, iS, dS)
			endif
			break
	endswitch
	return 0
End

//*************************************************************************************************************
// Sets a single P,I, or D value for a single axis, depending on setvariable that calls function
// Last Modified Sep 13 by Jamie Boyd
Function StagePIDSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			string theStageEncoder = stringfromlist (0, sva.win, "_")
			funcRef StageSetPID_Template SetPID = $"StageSetPID_" + theStageEncoder
			// first letter of ctrlname is axis, 2nd letter is PID
			string ctrlName = sva.ctrlname 
			string theAxis = ctrlname [0]
			string thePID = ctrlname [1]
			strswitch (thePID)
				case "P":
					SetPID (theAxis, pS = sva.dval)
					break
				case "I":
					SetPID (theAxis, iS = sva.dval)
					break
				case "D":
					SetPID (theAxis, dS = sva.dval)
					break
				default:
					doalert 0, "Error from StagePIDSetVarProc: was not expecting a control named \"" + ctrlName + "\"."
					break
			endSwitch
			break
	endswitch
	return 0
End

//*************************************************************************************************************
// Fetches all P,I, and D values for a single axis, depending on button that calls function
// Last Modified Sep 13 by Jamie Boyd
Function Stages_FetchPIDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string theStageEncoder = stringfromlist (0, ba.win, "_")
			funcRef StageFetchPID_Template FetchPID = $"StageFetchPID_" + theStageEncoder
			variable pS=1, iS=1, dS=1
			string ctrlName = ba.ctrlname
			string theAxis = ctrlName [0]
			FetchPID (theAxis, pS, iS, dS)
			// No need to update global variables on control panel with pS, iS, and dS
			// as the UpdateStage procedure should do this
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
			NVAR/Z PIDpDef = $"root:packages:" + theStageEncoder + ":" + theAxis + "PIDpDef"
			NVAR/Z PIDiDef = $"root:packages:" + theStageEncoder + ":" + theAxis + "PIDiDef"
			NVAR/Z PIDdDef =$"root:packages:" + theStageEncoder + ":" + theAxis + "PIDdDef"
			if (((NVAR_EXISTS (PIDpDef)) && (NVAR_EXISTS (PIDpDef))) && (NVAR_EXISTS (PIDiDef)))
				SetPID (theAxis, pS = PIDpDef, iS = PIDiDef, dS =PIDdDef )
			else
				doAlert 0, "Default PID values were not found for the \"" + theAxis + "\" axis."
			endif	
			break
	endswitch
	return 0
End