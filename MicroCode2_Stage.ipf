#pragma rtGlobals=1		// Use modern global access method.
#pragma version= 4.0		// Last Modified Sep 13 2010 by Jamie Boyd
#pragma IgorVersion=6.0 // Uses new background task management

//  MicroCode2 requires the  VDT2 extension

// These Stage functions are for Boeckeler MicroCode II model 2-MR or 3-MR stage encoders
// The 2-MR has only X and Y encoders, No Z, while the 3-MR has a Z-axis. Neither is  motorized
// Use this constant to tell if the Microcode II has Z encoder.
STATIC CONSTANT kMicroCodehasZ = 1

//*********************************************************************************************
// Stage setup function
Function StageInitGlobals_MicroCode2 ()

	// Globals
	if (!(datafolderExists ("root:packages:")))
		newDataFolder root:packages:
	endif 
	if (!(datafolderExists ("root:packages:MicroCode2:")))
		newDataFolder root:packages:MicroCode2:
	endif
	string/G root:packages:MicroCode2:thePort 
	variable/G root:packages:MicroCode2:hasXY = 1
	variable/G root:packages:MicroCode2:hasZ =kMicroCodehasZ
	variable/G  root:packages:MicroCode2:hasAx = 0
	variable/G root:packages:MicroCode2:hasMotor = 0
	variable/G root:packages:MicroCode2:hasAuto =1
	variable/G root:packages:MicroCode2:autoON = 0
	variable/G root:packages:MicroCode2:xDistanceFromZero
	variable/G root:packages:MicroCode2:yDistanceFromZero
	if (kMicroCodehasZ)
		variable/G root:packages:MicroCode2:zDistanceFromZero
	endif
	variable/G root:packages:MicroCode2:isBusy = 0
end

//*********************************************************************************************	
//Open the given serial port for use with MicroCode2
Function StageSetUpPort_MicroCode2 (thePortName)
	string thePortName // string containing name orf serial port encoders are plugged into
	
	VDTOperationsPort2 $PossiblyQuoteName (thePortName)
	VDT2 /P=$PossiblyQuoteName (thePortName) baud=9600, databits=7, in=1, out=1, parity=0, stopbits=1
	VDTOpenPort2 $PossiblyQuoteName (thePortName)
	StageResetIO_MicroCode2 ()
	return 0
end

//*********************************************************************************************
// Reset I/O function for MicroCode2, clears any pending commands
Function StageResetIO_MicroCode2 ()
	
	NVAR isBusy = root:packages:MicroCode2:isBusy
	isBusy = 1;doUpdate
	CtrlNamedBackground MicroCode2BkgUpdate, STOP
	SVAR thePortName = root:packages:MicroCode2:thePort
	vdt2/P =$possiblyquotename (thePortName) killio
	isBusy = 0
	return 0
end

//*********************************************************************************************
// Port closing function for MicroCode2, tells VDT2 to close the serial port, called when panel is closed
Function StageClose_MicroCode2 ()
	
	SVAR thePortName = root:packages:MicroCode2:thePort
	CtrlNamedBackground MicroCode2BkgUpdate, STOP
	VDTGetPortList2
	if (findListItem (thePortName, S_VDT, ";") > -1)
		VDTClosePort2 $PossiblyQuoteName (thePortName)
	endif
	return 0
end

//***********************************************************************************	
// Update function
Function StageUpDate_MicroCode2 (xS, yS, zS, axS)
	variable &xS, &yS, &zS, &axS
	
	// Globals
	NVAR isBusy = root:packages:MicroCode2:isBusy // MicroCode2 is busy processing a command
	isBusy = 1;doupdate
	SVAR thePortName = root:packages:MicroCode2:thePort
	NVAR LastStageX = root:packages:MicroCode2:xDistancefromZero
	NVAR LastStageY = root:packages:MicroCode2:yDistancefromZero
	NVAR hasZ =root:packages:MicroCode2:hasZ
	if (hasZ)
		NVAR LastStageZ = root:packages:MicroCode2:zDistancefromZero
	endif
	vdtwrite2/P =$possiblyquotename (thePortName)/O = 2 "\r"
	if (hasZ)
		VDTRead2/P =$possiblyquotename (thePortName)/O=2 xS, yS, zS
	else
		VDTRead2/P =$possiblyquotename (thePortName)/O=2 xS, yS
	endif
	if (V_VDT < 2)
		VDT2 /P=$PossiblyQuoteName (thePortName) killio
		xS=nan;yS=Nan;zS=Nan
		return 1
	endif
	// microcode returns values in mm and we want metres
	xS /= 1e03
	yS /= 1e03
	LastStageX = xS
	LastStageY = yS
	if (hasZ)
		zS/=1e03
		LastStageZ = zS
	else
		zS = LastStageZ
	endif
	isBusy =0
	return 0
end

//***********************************************************************************	
// function to turn ON/Off bkg task that periodically (4 times per second) updates stage encoder values
Function StageSetAuto_MicroCode2 (turnOn)
	variable turnOn
	
	if (turnOn)
		CtrlNamedBackground MicroCode2BkgUpdate proc= MicroCode2_BkgUpdate, period=15, burst=0, START
	else
		CtrlNamedBackground MicroCode2BkgUpdate, STOP
	endif
end

//***********************************************************************************	
// BackGround function that periodically updates axes values
Function MicroCode2_BkgUpdate (bks)
	STRUCT  WMBackgroundStruct&bks
	
	// Globals
	NVAR isBusy = root:packages:MicroCode2:isBusy
	if (isBusy)
		return 0
	else
		variable xS, yS, zS, AxS
		StageUpDate_MicroCode2 (xS, yS, zS, AxS)
		return 0
	endif
end