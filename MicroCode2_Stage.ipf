#pragma rtGlobals=3			// Use modern global access method.
#pragma version= 2.0		// Last Modified 2025/11/26 by Jamie Boyd
#pragma IgorVersion=8.05	// Uses threadsafe VDT2 extension first shipped with Igor 8.05


//  MicroCode2 requires the  VDT2 extension

// These Stage functions are for Boeckeler MicroCode II model 2-MR or 3-MR stage encoders
// The 2-MR has only X and Y encoders, No Z, while the 3-MR has a Z-axis. Neither is  motorized
// Use this constant to tell if the Microcode II has Z encoder.
STATIC CONSTANT kMicroCodehasZ = 0

//*********************************************************************************************
// Stage setup function - sets globals for capabilities
// Last Modified 2025/11/26 by Jamie Boyd
Function StageInitGlobals_MicroCode2 ()
	
	WAVE Properties =  root:packages:MicroCode2:Properties
	Properties [%has_XY] = 1
	Properties [%has_Z] = kMicroCodehasZ
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
Threadsafe Function StageResetIO_MicroCode2 (thePortName, Properties)
	string thePortName
	WAVE Properties
	
	vdt2/P =$possiblyquotename (thePortName) killio
	Properties[%ERR] = 0
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
Threadsafe Function StageSetZero_MicroCode2 (thePortName, Selected, DistsFromZero, Zeros, Properties)
	string thePortName
	WAVE Selected
	WAVE DistsFromZero
	WAVE Zeros
	WAVE Properties

	variable xS, yS, zS
	vdtwrite2/P =$possiblyquotename (thePortName)/O = 2 "\r"
	if (Properties[%has_Z])
		VDTRead2/P =$possiblyquotename (thePortName)/O=2 xS, yS, zS
		if (V_VDT < 3)
			Properties[%ERR] = 1
			xS=nan;yS=Nan;zS=Nan
		endif
	else
		VDTRead2/P =$possiblyquotename (thePortName)/O=2 xS, yS
		if (V_VDT < 2)
			Properties[%ERR] = 1
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
threadsafe Function StageUpDate_MicroCode2 (thePort, Selected, DistsFromZero, Zeros, Properties)
	string thePort
	WAVE Selected
	WAVE DistsFromZero
	WAVE Zeros
	WAVE Properties
	
	variable xS, yS, zS
	vdtwrite2/P =$possiblyquotename (thePort)/O = 2 "\r"
	if (Properties [%has_Z])
		VDTRead2/P =$possiblyquotename (thePort)/O=2 xS, yS, zS
		if (V_VDT < 3)
			Properties[%ERR] = 1
			xS=nan;yS=Nan;zS=Nan
		endif
	else
		VDTRead2/P =$possiblyquotename (thePort)/O=2 xS, yS
		if (V_VDT < 2)
			Properties[%ERR] = 1
			xS=nan;yS=Nan;zS=Nan
		endif
	endif
	// microcode returns values in mm and we want metres
	DistsFromZero[0] = (xS/1E03) - Zeros [0]
	DistsFromZero[1] = (yS/1E03) - Zeros [1]
	if (Properties[%has_Z])
		DistsFromZero[2] = (zS/1E03) - Zeros [2]
	endif
//	print "MC2 in the house:" , DistsFromZero[1]
end


//*********************************************************************************************
// background function that updates stage positions for all axes, when not threaded
// Last Modified 2025/11/26 by Jamie Boyd
Function StageBkgUpdate_MicroCode2 (bks)
	STRUCT StageBkgStruct &bks

	SVAR thePort =  root:packages:MicroCode2:thePort
	WAVE Selected = root:packages:MicroCode2:selectedForCMD
	WAVE DistanceFromZero= root:packages:MicroCode2:DistanceFromZero
	WAVE Zeros= root:packages:MicroCode2:AbsoluteZero
	WAVE Properties =  root:packages:MicroCode2:properties
	StageUpDate_MicroCode2 (thePort, Selected, DistanceFromZero, Zeros, Properties)
	return 0
end


//*********************************************************************************************
// background function that touches waves in datafolder so control panel will update when threaded
Function StageBkgTouch_MicroCode2 (WMS)
	STRUCT WMBackgroundStruct &WMS
	
	WAVE properties = root:packages:Null:properties
	WAVE distsFromZero = root:packages:Null:DistanceFromZero
	properties [%ERR] += 0
	distsFromZero [%A] += 0
	return 0
end
