#pragma rtGlobals=1		// Use modern global access method.#include "TabControlUtil"#include "SaveGetWindowSize"#include "Backgrounder"//last modified:Nov 30 2005//   a = axis  (x/Y/Z/A)//   d = digit//   s = sign//   //   Move//   a M A sddddd.d		Absolute position	(-9999.9 to 9999.9 �m)//   a M R sddddd.d		Relative Position	(-9999.9 to 9999.9 �m)//   a M H 				Home//   //   Set//   a S Z			current position = 0//   a S H			Home equal to current position//   //   a S P ddddd 		Proportional PID coefficient [400]	(0 to 32767)//   a S I dddddd		Integral PID coefficient [500]		(0 to 32767)//   a S D ddddd		Derivative PID coefficient [200]	(0 to 32767)//   //   a S S ddd		Deriviative sampling interval [0]	(0 -255)//   a S L ddd		Integral Limit [1000]				(0 too 32767)//   a S A dddddddddd	Acceleration [1000000]			(0 to 10737418230//   a S V dddddddddd	Velocity [5000000]				(0 to 10737418230//   //   Transmit											Reply//   a T C 			Current poition (�m)				a T C [sddddd.d]//   a T H			Home Position (�m)				a T H [sddddd.d]//   a T E			End Switches Status						Front	Back//   													0	Off		Off//   													1	On 		Off//   													2	Off		On//   													3	On		On//   //   a T P 			Proportional PID coefficient			a T P [ddddd]//   a T I			Integral PID coefficient				a T I [ddddd]//   a T D			Derivative PID coefficient			a T D [ddddd]//   //   a T S 			Deriviative sampling interval		a T S [ddd]//   aTS L 			Integral Limit						a T LL [ddd]//   a T A 			Acceleration						a T A [dddddddddd]//   a T V 			Velocity								a T V [dddddddddd]//   //   Global//   * M M 			Mode: Manual//   * M A			Mode: Auto//   * O F			Turn off all DCMotors by applying zero drive//   * I D			" XYZA Positioner ver 1.0 " and Soft Reset//   * T C			Toggle on/off transmit XYZA current positions//Procedures for controlling the serial port-driven Positioner programmed by Pawel at the SFU machine shop.// This one controls X,Y,Z, and A (axial) dimensions. All values are in microns//Requires the  VDT XOP (use VDT instead of VDT 2 so it can be used on OS 9, bleah)// Notes:// No handshaking. Device echoes character input, so be sure to turn local echo offmenu "Macros"	subMenu "Position Encoder"	"Open Position Encoder", E4729_OpenPanel ()	"Re-Initialize Encoder", E4729_Initialize ()	"Clear the Serial Port Buffer", CleartheBuffer()	"Reset to Defaults",  ResetToDefaults ()	endendFunction ClearTheBuffer ()		execute "VDT killio"endFunction ResetToDefaults ()	SVAR tempChar = root:packages:PE:tempChar	string CommandStr = "VDTWrite \"*ID\""	execute commandstr	CleartheBuffer ()end	Function E4729_OpenPanel ()		//if panel exists, bring it to the front and we are done	dowindow/F PE_Panel	if (V_Flag == 1)		return -1	endif	//panel not found so reinitialize	if (!(datafolderExists ("root:Packages")))		NewDataFolder root:packages	endif	if (!(datafolderExists ("root:packages:PE")))		newdatafolder root:packages:PE		string/G root:packages:PE:E4729SerialPort		string/G root:packages:PE:tempChar		variable/G root:packages:PE:xpos, root:packages:PE:ypos, root:packages:PE:zpos, root:packages:PE:apos		variable/G root:packages:PE:xhome, root:packages:PE:yhome, root:packages:PE:zhome, root:packages:PE:ahome		variable/G root:packages:PE:xP, root:packages:PE:yP, root:packages:PE:zP, root:packages:PE:aP		variable/G root:packages:PE:xI, root:packages:PE:yI, root:packages:PE:zI, root:packages:PE:aI		variable/G root:packages:PE:xD, root:packages:PE:yD, root:packages:PE:zD, root:packages:PE:aD		variable/G root:packages:PE:xS, root:packages:PE:yS, root:packages:PE:zS, root:packages:PE:aS		variable/G root:packages:PE:xL, root:packages:PE:yL, root:packages:PE:zL, root:packages:PE:aL		variable/G root:packages:PE:xA, root:packages:PE:yA, root:packages:PE:zA, root:packages:PE:aA		variable/G root:packages:PE:xV, root:packages:PE:yV, root:packages:PE:zV, root:packages:PE:aV	endif		execute "VDTGetPortList"	SVAR S_VDT =S_VDT	SVAR portnameG = root:packages:PE:E4729SerialPort	string thePort	variable Numports = ItemsInList (S_VDT)	switch (numports)		case 0:	// no serial ports found			doalert 0, "No serial ports were found, so E4729 positioner can not be used."			return 2			break		case 1:	// one serial port found. No need to make user choose, but sill put up the menu and the titlebox showing the port			portnameG = stringfromlist (0, S_VDT)			E4729_Initialize ()			break		default:	// more than one serial port. Put up a menu so user can choose.			prompt thePort "Which serial port is connected to the E-4729 positioner?"			doprompt "Choose a serial port", thePort			if (V_Flag)				doalert 0, "No poisitioning for you."				return -1			endif			PortNameG = thePort			E4729_Initialize ()	endswitch	execute "PE_Panel()"end//*******************************************************************************// Opens the chosen serial port (the name is stored in a global string) with the correct settingsFunction E4729_Initialize ()		SVAR portname =  root:packages:PE:E4729SerialPort			string commandStr	// Open the port with the correct settings	sprintf commandStr  "VDTOperationsPort %s", PossiblyQuoteName(portname)	execute commandStr	sprintf commandStr "VDT /P=%s baud=9600, stopbits=1, databits=8, parity=0, in=0, out=0, buffer=4096, echo =0", PossiblyQuoteName(portname)	execute commandStr	sprintf commandStr "VDTOpenPort %s", PossiblyQuoteName(portName)	execute commandStrendWindow PE_Panel() : Panel	PauseUpdate; Silent 1		// building window...	NewPanel /K=1 /W=(1131,726,1673,940) as "E-4729"	SetVariable xPosSetVar,pos={18,9},size={121,18},proc=XYZASetVarProc,title="xPos"	SetVariable xPosSetVar,fSize=12,value= root:packages:PE:xpos	SetVariable yPosSetVar,pos={144,11},size={121,18},proc=XYZASetVarProc,title="yPos"	SetVariable yPosSetVar,fSize=12,value= root:packages:PE:ypos	SetVariable zPosSetVar,pos={274,9},size={121,18},proc=XYZASetVarProc,title="zPos"	SetVariable zPosSetVar,fSize=12,value= root:packages:PE:zpos	SetVariable aPosSetVar,pos={401,8},size={121,18},proc=XYZASetVarProc,title="aPos"	SetVariable aPosSetVar,fSize=12,value= root:packages:PE:apos	Button GetXYZAButton,pos={8,50},size={146,20},proc=GetXYZAButtonProc,title="Re-Synch to Device"	SetVariable xPSetVar,pos={17,109},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable xPSetVar,value= root:packages:PE:xP	SetVariable yPSetVar,pos={109,109},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable yPSetVar,value= root:packages:PE:yP	SetVariable zPSetVar,pos={194,109},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable zPSetVar,value= root:packages:PE:zP	SetVariable aPSetVar,pos={283,109},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable aPSetVar,value= root:packages:PE:aP	Button PIDResynchButton,pos={393,166},size={111,19},proc=PIDResynchProc,title="Re-Synch PID"	SetVariable xISetVar,pos={20,135},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable xISetVar,value= root:packages:PE:xI	SetVariable yISetVar,pos={110,134},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable yISetVar,value= root:packages:PE:yI	SetVariable zISetVar,pos={202,130},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable zISetVar,value= root:packages:PE:zI	SetVariable aISetVar,pos={295,135},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable aISetVar,value= root:packages:PE:aI	SetVariable xDSetVar,pos={19,160},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable xDSetVar,value= root:packages:PE:xD	SetVariable yDSetVar,pos={111,161},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable yDSetVar,value= root:packages:PE:yD	SetVariable zDSetVar,pos={202,160},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable zDSetVar,value= root:packages:PE:zD	SetVariable aDSetVar,pos={291,162},size={83,18},proc=PIDSetVarProc,fSize=12	SetVariable aDSetVar,value= root:packages:PE:aDEndMacroFunction GetXYZAButtonProc(ctrlName) : ButtonControl	String ctrlName	execute "VDT killio"	NVAR xpos = root:packages:PE:xpos	NVAR yPos = root:packages:PE:ypos	NVAR zPos =root:packages:PE:zpos	NVAR aPos = root:packages:PE:apos	SVAR tempChar = root:packages:PE:tempChar	string CommandStr = "VDTWrite \"XTC\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nXTC= %f",xpos		CommandStr = "VDTWrite \"YTC\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nYTC= %f",ypos		CommandStr = "VDTWrite \"ZTC\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nZTC= %f",zpos		CommandStr = "VDTWrite \"ATC\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nATC= %f",aposEndFunction XYZASetVarProc(ctrlName,varNum,varStr,varName) : SetVariableControl	String ctrlName	Variable varNum	String varStr	String varName		string CommandStr = ctrlname [0] + "MA " + num2str (varNum)	sprintf commandstr "VDTWrite \"%s\"", CommandStr	execute commandstr	SVAR tempChar = root:packages:PE:tempChar	tempchar = ""	execute"VDTRead /O=1 root:packages:PE:tempChar"	variable checkVar	sscanf tempchar, "  READY> " + ctrlname [0] + "MA %f",checkVar	if (abs (checkVar - VarNum) > 0.2)		doalert 0, "uh oh. You asked for " + num2str (varNum) + " and you got " + num2str (checkVar) + "."	endifEndFunction PIDSetVarProc(ctrlName,varNum,varStr,varName) : SetVariableControl	String ctrlName	Variable varNum	String varStr	String varName		string CommandStr = ctrlname [0] + "S" +  ctrlname [1] + " " + num2str (varNum)	sprintf commandstr "VDTWrite \"%s\"", CommandStr	execute commandstr	SVAR tempChar = root:packages:PE:tempChar	tempchar = ""	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	print tempchar		variable checkVar		sscanf tempchar, "READY> xSx > " + ctrlname [0] + "MA %f",checkVar//	if (abs (checkVar - VarNum) > 0.2)//		doalert 0, "uh oh. You asked for " + num2str (varNum) + " and you got " + num2str (checkVar) + "."//	endifEndFunction PIDResynchProc(ctrlName) : ButtonControl	String ctrlName	execute "VDT killio"	SVAR tempChar = root:packages:PE:tempChar	NVAR xP= root:packages:PE:xP	string CommandStr = "VDTWrite \"XTP\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nXTP= %f",xP		NVAR yP =root:packages:PE:yP	CommandStr = "VDTWrite \"YTP\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nYTP= %f",yP		NVAR zP = root:packages:PE:zP	CommandStr = "VDTWrite \"ZTP\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nZTP= %f",zP		NVAR aP =root:packages:PE:aP	CommandStr = "VDTWrite \"ATP\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nATP= %f",aP		NVAR xI =root:packages:PE:xI	CommandStr = "VDTWrite \"XTI\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nXTI= %f",xI	NVAR yI=root:packages:PE:yI	CommandStr = "VDTWrite \"YTI\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nYTI= %f",yI		NVAR zI =root:packages:PE:zI	CommandStr = "VDTWrite \"ZTI\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nZTI= %f",zI		NVAR aI = root:packages:PE:aI	CommandStr = "VDTWrite \"ATI\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nATI= %f",aI		NVAR xD =root:packages:PE:xD	CommandStr = "VDTWrite \"XTD\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nXTD= %f",xD		NVAR yD = root:packages:PE:yD	CommandStr = "VDTWrite \"YTD\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nYTD= %f",yD		NVAR zD = root:packages:PE:zD	CommandStr = "VDTWrite \"ZTD\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nZTD= %f",zD		NVAR aD = root:packages:PE:aD	CommandStr = "VDTWrite \"ATD\""	execute commandstr	// this thing returns 2 lines, throw the first away	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	execute"VDTRead/t=\"\n\" /O=1 root:packages:PE:tempChar"	sscanf tempchar, "\nATD= %f",aD	End