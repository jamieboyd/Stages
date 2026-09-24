#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method.
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#pragma IgorVersion=8.05		// Uses threadsafe VDT2 extension first shipped with Igor 8.05

#pragma version= 2.1			// Last Modified 2026/09/22 by Jamie Boyd


//  MicroCode2 requires the  VDT2 extension

// These Stage functions are for Boeckeler MicroCode II model 2-MR or 3-MR stage encoders
// The 2-MR has only X and Y encoders, No Z, while the 3-MR has a Z-axis. Neither is  motorized
// Use this constant to tell if the Microcode II has Z encoder.
STATIC CONSTANT kMicroCodehasZ = 0


// Constant to set if we want the stage to be used in threaded mode
STATIC CONSTANT kMicroCodeIsThreaded = 0

//*********************************************************************************************
// Stage setup function - sets globals for capabilities
// Last Modified 2026/09/17 by Jamie Boyd
Function StageInitGlobals_MicroCode2 ()
	
	WAVE Properties =  root:packages:MicroCode2:Properties
	Properties [%has_XY] = 1
	Properties [%has_Z] = kMicroCodehasZ
	NVAR stageIsThreaded =  root:packages:MicroCode2:stageIsThreaded
	stageIsThreaded = kMicroCodeIsThreaded
end


//*********************************************************************************************	
// Open the given serial port for use with MicroCode2
// Last Modified 2025/11/26 by Jamie Boyd
Function StageSetUpPort_MicroCode2 (thePortName)
	string thePortName // string containing name of serial port encoders are plugged into
	
	VDT2/P=$PossiblyQuoteName (thePortName) baud=9600, databits=7, in=0, out=0, parity=0, stopbits=1
	VDTOpenPort2 $PossiblyQuoteName (thePortName)
end


//*********************************************************************************************
// Reset I/O function for MicroCode2, clears any pending serial commands in serial buffers
// and clears the error display
// Last Modified 2025/11/26 by Jamie Boyd
Threadsafe Function StageResetIO_MicroCode2 (thePortName)
	string thePortName
	
	vdt2/P =$possiblyquotename (thePortName) killio
end


//*********************************************************************************************
// Port closing function for MicroCode2, tells VDT2 to close the serial port, called when panel is closed
Function StageClose_MicroCode2 (thePortName)
	String thePortName
	
	VDTGetPortList2
	if (findListItem (thePortName, S_VDT, ";") > -1)
		VDTClosePort2 $PossiblyQuoteName (thePortName)
	endif
	return 0
end

//*********************************************************************************************
// MicroCode2 has a physical zero button, but we can also zero in software by saving locations in Zeros wave 
// Last Modified 2025/11/26 by Jamie Boyd
Threadsafe Function StageSetZero_MicroCode2 (thePortName, Selected, DistsFromZero, Zeros)
	string thePortName
	WAVE Selected
	WAVE DistsFromZero
	WAVE Zeros

	variable xS, yS, zS
	vdtwrite2/P =$possiblyquotename (thePortName)/O = 2 "\r"
	if (kMicroCodehasZ)
		VDTRead2/P =$possiblyquotename (thePortName)/O=2 xS, yS, zS
		if (V_VDT < 3)
			return 1
			xS=nan;yS=Nan;zS=Nan
		endif
	else
		VDTRead2/P =$possiblyquotename (thePortName)/O=2 xS, yS
		if (V_VDT < 2)
			return 1
			xS=nan;yS=Nan;zS=Nan
		endif
	endif
	// microcode returns values in mm and we want metres
	if (Selected [%X])
		Zeros [%X] = xS/1E03
		DistsFromZero [%X] = 0
	endif
	if (Selected [%Y])
		Zeros [%Y] = yS/1E03
		DistsFromZero [%Y] = 0
	endif
	if (Selected[%Z])
		Zeros [%Z] = zS/1E03
		DistsFromZero [%Z]=0
	endif
	return 0
end

//*********************************************************************************************
// Update Function gets stage positions from all axes - MicroCode2 can not get data from a single axis
// Last Modified 2025/11/26 by Jamie Boyd
threadsafe Function StageUpDate_MicroCode2 (thePort, Selected, DistsFromZero, Zeros)
	string thePort
	WAVE Selected
	WAVE DistsFromZero
	WAVE Zeros
	
	variable xS, yS, zS
	vdtwrite2/P =$possiblyquotename (thePort)/O = 2 "\r"
	if (kMicrocodehasZ)
		VDTRead2/P =$possiblyquotename (thePort)/O=2 xS, yS, zS
		if (V_VDT < 3)
			xS=nan;yS=Nan;zS=Nan
			return 1
		endif
	else
		VDTRead2/P =$possiblyquotename (thePort)/O=2 xS, yS
		if (V_VDT < 2)
			xS=nan;yS=Nan;zS=Nan
			return 1
		endif
	endif
	// microcode returns values in mm and we want metres
	DistsFromZero[0] = (xS/1E03) - Zeros [0]
	DistsFromZero[1] = (yS/1E03) - Zeros [1]
	if (kMicroCodehasZ)
		DistsFromZero[2] = (zS/1E03) - Zeros [2]
	endif
	return 0
end

