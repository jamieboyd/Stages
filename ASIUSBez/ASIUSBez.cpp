/*	ASIUSBez.cpp

	An XOP to provide an Igor Pro interface to ASI Imaging USB devices that are
served by the Cypress EZUSB.sys device driver. ASIUSBez uses functions provided 
by the library ASIUSB1.lib.

How To Get ASIUSBez To Work on Windows XP
----------------------------------------
1.  Copy EZUSBWXP.INF to the directory that contains .INF files, usually 
C:\Windows\inf.

2. Ensure that EZUSB.SYS is in the directory that contains .SYS files, 
usually C:\Windows\system32\drivers.

3.  Shut down the computer, ensure that DIP switches 4 & 5 on your MS-2000 
are in the down position, connect the USB cable, and turn on the computer.  
The Windows Plug and Play system will automatically find the "New 
Hardware" and display a dialog.  Select the "Search for a suitable 
driver..." option.  Windows will configure itself, and the system should 
work correctly after that.

4.	Place USB1.dll in the directory C:\WINDOWS\SYSTEM

5.	Place ASIUSBez in the the Igor Extensions folder in the Igor Pro Folder.*/

#include "XOPStandardHeaders.h"			// Include ANSI headers, Mac headers, IgorXOP.h, XOP.h and XOPSupport.h
#include "ASIUSBez.h"					// specific to this XOP
#include "asiusb.h"						// includes for the ASI 
//Globals
HANDLE lpDeviceHandles [6];	// An array of device handles, one for each attached device. Six "should be enough for anybody"
unsigned int DevOpen [6];	// An array where one will correspond to the device being open, and 0 will mean it is closed
unsigned int nDevices =0;	// the number of ASI USB devices attached to the computer, as it is unlikely that all 6 members
							// of the lpDeviceHandles array will be filled. Note that the ASIUSB functions expect device numbers
							// to start from one, while the C-style array of device handles is, of course, indexed from zero
char GlobalDeviceList [400];	// a global string to hold the device list for easy returning from a function
/*****************************************************************************************************************
	ASIUSBInit initializes all ASI USB devices, fulling out the lpDeviceHandles global array, and setting the global
	 variable for number of devices. An Igor global variable is made containing the number of devices and an Igor
	 global string is made containing a list of the names of all of the attached ASI USB devices

*****************************************************************************************************************/
static long
ASIUSBInit(EmptyParamsPtr p)
{
	if (igorVersion < 500)
	{
		p->result = 1;
		return REQUIRES_IGOR_500;
	}
	// try to initialize ASI devices
	long int error;
	char buf[256];
	error = EnumASIControllers(nDevices);
	sprintf(buf, "ASI USB device count = %d"CR_STR,nDevices);
	XOPNotice(buf);
	if (error < 0){
		p->result = 1;
		return ASItoIgErr (error);
	}
	// put number of devices in Igor global variable
	char varName[MAX_OBJ_NAME+1];
	double nDevDbl = nDevices;
	strcpy(varName, "V_ASIUSBDevCnt");
	SetIgorFloatingVar(varName, &nDevDbl, 1);
	// Blank the global string used to store the list of device numbers/names
	GlobalDeviceList [0] = '\0';
	unsigned char position;
	unsigned char ucDevicePosition; // this value is one-based, because GetEnumDeviceId expects one-based values
	LPSTR LPSTRDeviceDescript;
	USB_DEVICE_DESCRIPTOR pvBuffer;
	for (ucDevicePosition = 1; ucDevicePosition <= nDevices ; ucDevicePosition++)
	{
		sprintf(buf, "For ASI Device Number %d"CR_STR,ucDevicePosition);
		XOPNotice(buf);
		error = GetEnumDeviceId(ucDevicePosition,LPSTRDeviceDescript);
		if (error < 0){
			p->result=(ASItoIgErr(error));
			return ASItoIgErr (error);
		}	
		sprintf(buf, "ASI Device Desc= %s"CR_STR, LPSTRDeviceDescript);
		XOPNotice(buf);
		// add description to global string, skipping the first 4 chars, "ASI-", and everything after the device name
		for (position =0; (*(LPSTRDeviceDescript + position) != '-' && position < 26);position++);
		position++;
		for (; (*(LPSTRDeviceDescript + position) != '-' && position < 26);position++);
		memcpy (buf, LPSTRDeviceDescript + 4,(position-4));
		buf [position-4] = '\0';
		sprintf (GlobalDeviceList,"%s%d %s;",GlobalDeviceList,ucDevicePosition,buf);
		error = OpenASIDevice(ucDevicePosition, lpDeviceHandles [ucDevicePosition-1]);
		if (error < 0){
			SetXOPResult (ASItoIgErr (error));
			return ASItoIgErr (error);
		}
		error = GetDeviceDescriptor(&pvBuffer,lpDeviceHandles [ucDevicePosition-1]);
		if (error < 0){
			SetXOPResult (ASItoIgErr (error));
			return ASItoIgErr (error);
		}
		DevOpen [ucDevicePosition] = 1;
		sprintf(buf, "bLength \t\t 0x%02x"CR_STR,pvBuffer.bLength);
		XOPNotice(buf);
		sprintf(buf, "bDescriptorType \t 0x%02x"CR_STR,pvBuffer.bDescriptorType);
		XOPNotice(buf);
		sprintf(buf, "bcdUSB \t\t\t 0x%04x"CR_STR,pvBuffer.bcdUSB);
		XOPNotice(buf);
		sprintf(buf,"bDeviceClass \t\t 0x%02x"CR_STR,pvBuffer.bDeviceClass);
		XOPNotice(buf);
		sprintf(buf,"bDeviceSubClass \t 0x%02x"CR_STR,pvBuffer.bDeviceSubClass);
		XOPNotice(buf);
		sprintf(buf,"bDeviceProtocol \t 0x%02x"CR_STR,pvBuffer.bDeviceProtocol);
		XOPNotice(buf);           
		sprintf(buf,"bMaxPacketSize0 \t 0x%02x"CR_STR,pvBuffer.bMaxPacketSize0);
		XOPNotice(buf);
		sprintf(buf,"idVendor \t\t 0x%04x"CR_STR,pvBuffer.idVendor);
		XOPNotice(buf);
		sprintf(buf,"idProduct \t\t 0x%04x"CR_STR,pvBuffer.idProduct);
		XOPNotice(buf);
		sprintf(buf,"bcdDevice \t\t 0x%04x"CR_STR,pvBuffer.bcdDevice);
		XOPNotice(buf);
		sprintf(buf,"iManufacturer \t\t 0x%02x"CR_STR,pvBuffer.iManufacturer);
		XOPNotice(buf);
		sprintf(buf,"iProduct \t\t 0x%02x"CR_STR,pvBuffer.iProduct);
		XOPNotice(buf);
		sprintf(buf,"iSerialNumber \t\t 0x%02x"CR_STR,pvBuffer.iSerialNumber);
		XOPNotice(buf);
		sprintf(buf,"bNumConfigurations \t 0x%02x"CR_STR,pvBuffer.bNumConfigurations);
		XOPNotice(buf);
	}
	// return the device list in an Igor global string
	strcpy(varName, "S_ASIUSBDevList");
	SetIgorStringVar(varName, GlobalDeviceList, 1);
	p->result = 0;
	return (0);
}


static long
ASIUSBListDevices (ASIUSBListDevParamsPtr p)
{
	if (igorVersion < 500)
	{
		p->result = '\0';
		return REQUIRES_IGOR_500;
	}
	Handle outStr = NewHandle(strlen(GlobalDeviceList));
	memcpy(*outStr, GlobalDeviceList, strlen (GlobalDeviceList));
	p->result = outStr;
	return (0);
}
/*****************************************************************************************************************
Opens the ASI USB device with the given number. Remember that all devices are left in open state by ASIUSBInit
so you shouldn't need to call this function too often
*****************************************************************************************************************/
static long
ASIUSBOpen (ASIUSBDeviceOnlyParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
	if (error < 0){
		DevOpen [(int)p->theDevice -1] = 0;
		return ASItoIgErr (error);
	}
	DevOpen [(int)p->theDevice -1] = 1;
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Closes the ASI USB device with the given Number.
*****************************************************************************************************************/
static long
ASIUSBClose (ASIUSBDeviceOnlyParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	long int error = CloseASIDevice (lpDeviceHandles [(int)p->theDevice-1]);
	if (error < 0){
		DevOpen [(int)p->theDevice -1] = 0;
		p->result = 1;
		return ASItoIgErr (error);
	}
	DevOpen [(int)p->theDevice -1] = 0;
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Updates the X,Y, and Z Axes values of the ASI USB device that is currently open.
*****************************************************************************************************************/
static long
ASIUSBGetXYZ (ASIUSBGetXYZParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	float xValue, yValue, zValue;
	Where (xValue, yValue, zValue, lpDeviceHandles [(int)p->theDevice-1]);
	*p->xValue = xValue/10000000; // divide by 10,000,000 to get metres from 10ths of a micron res
	*p->yValue = yValue/10000000;
	*p->zValue = zValue/10000000;
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Updates only the X and Y Axes of the ASI USB device that is currently open.
*****************************************************************************************************************/
static long
ASIUSBGetXY (ASIUSBGetXYParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	float xPosition, yPosition;
	WhereA  ('X', xPosition,lpDeviceHandles [(int)p->theDevice-1]);
	WhereA  ('Y', yPosition,lpDeviceHandles [(int)p->theDevice-1]);
	*p->xValue = (DOUBLE)xPosition/10000000; // divide by 10,000,000 to get metres from 10th of a micron res
	*p->yValue = (DOUBLE)yPosition/10000000; // divide by 10,000,000 to get metres from 10th of a micron res
	p->result = 0;
	return (0);
}


/*****************************************************************************************************************
Moves the X,Y, and Z axes of the ASI USB device that is currently open to an Absolute Position
*****************************************************************************************************************/
static long
ASIUSBMovAbsXYZ(ASIUSBMovXYZParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	// multiply by 10,000,000 to get 10th of a micron steps from input metres 
	MoveXYZ((float)p->xValue * 10000000, (float)p->yValue * 10000000, (float)p->zValue* 10000000, lpDeviceHandles [(int)p->theDevice-1]);
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Moves the X and Y axes only of the ASI USB device that is currently open to an Absolute Position
*****************************************************************************************************************/
static long
ASIUSBMovAbsXY(ASIUSBMovXYParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	// multiply by 10,000,000 to get 10th of a micron steps from input metres 
	MoveXY((float)p->xValue * 10000000, (float)p->yValue * 10000000, lpDeviceHandles [(int)p->theDevice-1]);
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Moves the X,Y, and Z axes of the ASI USB device that is currently open the given amount Relative to Current Position
*****************************************************************************************************************/
static long
ASIUSBMovRelXYZ(ASIUSBMovXYZParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	// multiply by 10,000,000 to get 10th of a micron steps from input metres 
	RelMove((float)p->xValue * 10000000, (float)p->yValue * 10000000, (float)p->zValue * 10000000,lpDeviceHandles [(int)p->theDevice-1]);
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Returns 66 (ASCII code for B for "Busy") if device is busy, else returns 78 (ASCII code for N for "Not busy")
*****************************************************************************************************************/
static long
ASIUSBIsBusy (ASIUSBDeviceOnlyParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	char cpStatus;
	GetStatus(cpStatus,lpDeviceHandles [(int)p->theDevice-1]);
	//char buf [255];
	//sprintf(buf, "ASI Device Status %d"CR_STR, (long)cpStatus);
	//XOPNotice(buf);
	p->result = (long)cpStatus;
	return 0;
}

/*****************************************************************************************************************
Sets the current position of the stage as home position
*****************************************************************************************************************/
static long
ASIUSBSetZero (ASIUSBDeviceOnlyParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	SetZero(lpDeviceHandles [(int)p->theDevice-1]);
	//SetHereXYZ(0,0,0,lpDeviceHandle);
	p->result = 0;
	return 0;
}

/*****************************************************************************************************************
I wrote these PID functions to the header specifications, but they don't do anything
Maybe they are not actually implemented?
Sets the "Proportional" part of the PID constants for all axes X,Y, and Z
*****************************************************************************************************************/
static long
ASIUSBSetKp(ASIUSBMovXYZParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	// Call PID function
	SetKpXYZ((float)p->xValue,(float)p->yValue,(float)p->zValue, lpDeviceHandles [(int)p->theDevice-1]);
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Sets the "Integral" part of the PID constants for all axes X,Y, and Z
*****************************************************************************************************************/
static long
ASIUSBSetKi(ASIUSBMovXYZParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	// Call PID function
	SetKiXYZ((float)p->xValue,(float)p->yValue,(float)p->zValue, lpDeviceHandles [(int)p->theDevice-1]);
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Sets the "Derivative" part of the PID constants for all axes X,Y, and Z
*****************************************************************************************************************/
static long
ASIUSBSetKd(ASIUSBMovXYZParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	// Call PID function
	SetKdXYZ((float)p->xValue,(float)p->yValue,(float)p->zValue, lpDeviceHandles [(int)p->theDevice-1]);
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Gets the "Proportional" part of the current PID constants for all axes X,Y, and Z
*****************************************************************************************************************/
static long
ASIUSBGetKp (ASIUSBGetXYZParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	float xVal, yVal, zVal;
	GetKpXYZ(xVal, yVal, zVal, lpDeviceHandles [(int)p->theDevice-1]);	
	*p->xValue = (DOUBLE)xVal;
	*p->yValue = (DOUBLE)yVal;
	*p->zValue = (DOUBLE)zVal;
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Gets the "Integral" part of the current PID constants for all axes X,Y, and Z
*****************************************************************************************************************/
static long
ASIUSBGetKi (ASIUSBGetXYZParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	float xValue, yValue, zValue;
	GetKpXYZ(xValue, yValue, zValue, lpDeviceHandles [(int)p->theDevice-1]);
	*p->xValue = (DOUBLE)xValue;
	*p->yValue = (DOUBLE)yValue;
	*p->zValue = (DOUBLE)zValue;
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Gets the "Derivative" part of the current PID constants for all axes X,Y, and Z
*****************************************************************************************************************/
static long
ASIUSBGetKd (ASIUSBGetXYZParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	float xValue, yValue, zValue;
	GetKpXYZ(xValue, yValue, zValue, lpDeviceHandles [(int)p->theDevice-1]);
	*p->xValue = (DOUBLE)xValue;
	*p->yValue = (DOUBLE)yValue;
	*p->zValue = (DOUBLE)zValue;
	p->result = 0;
	return (0);
}

/*****************************************************************************************************************
Halts all movement on all axes - Panic Button
*****************************************************************************************************************/
static long
ASIUSBHalt (ASIUSBDeviceOnlyParamsPtr p)
{
	if ((p->theDevice > nDevices)||(p->theDevice < 1)){
		p->result = 1;
		return DEVICE_NUM_OUT_OF_RANGE;
	}
	if (DevOpen [(int)p->theDevice -1] == 0){
		long int error = OpenASIDevice((unsigned char)p->theDevice, lpDeviceHandles [(int)p->theDevice-1]);
		if (error < 0){
			DevOpen [(int)p->theDevice -1] = 0;
			p->result = 1;
			return ASItoIgErr (error);
		}
		DevOpen [(int)p->theDevice -1] = 1;
	}
	Halt(lpDeviceHandles [(int)p->theDevice-1]);
	p->result = 0;
	return 0;
}


/*****************************************************************************************************************
ASItoIgErr translates ASI errors, defined in asiusb.h, into Custom Error Codes for the ASIUSBez XOP, which must be
numbered starting from FIRST_XOP_ERR, and are defined in ASIUSBez.h
*****************************************************************************************************************/
static long
ASItoIgErr (long ASIerrCode)
{
	switch (ASIerrCode){
		case SYNC_WARNING:
			return ((long)CEC_SYNC_WARNING);
			break;
		case BAD_WRITE_ERROR:
			return ((long)CEC_BAD_WRITE_ERROR);
			break;
		case BAD_READ_ERROR:
			return ((long)CEC_BAD_READ_ERROR);
			break;
		case DEVICE_DOES_NOT_EXIST:
			return ((long)CEC_DEVICE_DOES_NOT_EXIST);
			break;
		case BAD_HANDLE:
			return ((long) CEC_BAD_HANDLE);
			break;
		case TIME_OUT:
			return ((long) CEC_TIME_OUT);
			break;
		case DEVICE_IN_USE:
			return ((long) CEC_DEVICE_IN_USE);
			break;
		case BAD_DATA:
			return ((long) CEC_BAD_DATA);
			break;
		case TRANSMISSION_ERROR:
			return ((long) CEC_TRANSMISSION_ERROR);
			break;
		case INTERNAL_DLL_ERROR:
			return ((long)CEC_INTERNAL_DLL_ERROR);
			break;
		case INVALID_COMMAND:
			return ((long) CEC_INVALID_COMMAND);
			break;
		case EMPTY_PACKET:
			return ((long)CEC_EMPTY_PACKET);
			break;
		case INVALID_PACKET_SIZE:
			return ((long)CEC_INVALID_PACKET_SIZE);
			break;
		case OUT_OF_RANGE:
			return ((long) CEC_OUT_OF_RANGE);
			break;
		case AXIS_WAS_IN_MOTION:
			return ((long)CEC_AXIS_WAS_IN_MOTION);
			break;
		default:
			return ((long)CEC_UNKNOWN_ASI_ERR);
			break;
	}
}

/*****************************************************************************************************************
Standard XOP Register function function - only functions, no operations in this XOP 
*****************************************************************************************************************/
static long
RegisterFunction()
{
	int funcIndex;

	funcIndex = GetXOPItem(0);			// Which function invoked ?
	switch (funcIndex) {
		case 0:
			return ((long)ASIUSBInit);	// all functions are called using the direct method.
			break;
		case 1:
			return ((long)ASIUSBListDevices);
			break;
		case 2:							
			return((long)ASIUSBOpen);
			break;
		case 3:
			return((long)ASIUSBClose);
			break;
		case 4:
			return ((long)ASIUSBGetXYZ);
			break;
		case 5:
			return ((long)ASIUSBGetXY);
			break;
		case 6:
			return ((long) ASIUSBMovAbsXYZ);
			break;
		case 7:
			return ((long) ASIUSBMovAbsXY);
			break;
		case 8:
			return ((long)ASIUSBMovRelXYZ);
			break;
		case 9:
			return ((long)ASIUSBIsBusy);
			break;
		case 10:
			return ((long)ASIUSBSetZero);
			break;
		case 11:
			return ((long) ASIUSBHalt);
			break;
		case 12:
			return ((long) ASIUSBSetKp);
			break;
		case 13:
			return ((long) ASIUSBSetKi);
			break;
		case 14:
			return ((long) ASIUSBSetKd);
			break;
		case 15:
			return ((long) ASIUSBGetKp);
			break;
		case 16:
			return ((long) ASIUSBGetKi);
			break;
		case 17:
			return ((long) ASIUSBGetKd);
			break;
	}
	return NIL;
}
/*****************************************************************************************************************
XOPEntry()
	This is the entry point from the host application to the XOP for all
	messages after the INIT message. Not much to do in this XOP but get the right function
*****************************************************************************************************************/
static void
XOPEntry(void)
{	
	long result = 0;

	switch (GetXOPMessage()) {
		case FUNCADDRS:
			result = RegisterFunction();	// This tells Igor the address of our function.
			break;
		case CLEANUP:
			break;
	}
	SetXOPResult(result);
}

/*****************************************************************************************************************
main(ioRecHandle)

	This is the initial entry point at which the host application calls XOP.
	The message sent by the host must be INIT.
	main() does any necessary initialization and then sets the XOPEntry field of the
	ioRecHandle to the address to be called for future messages.
*****************************************************************************************************************/
HOST_IMPORT int
main(IORecHandle ioRecHandle)
{	
	XOPInit(ioRecHandle);						// Do standard XOP initialization.
	SetXOPEntry(XOPEntry);						// Set entry point for future calls.
	SetXOPType((long)(RESIDENT | IDLES));		// Specify XOP to stick around and to Idle.
	//Set result to 0 for success
	SetXOPResult(0L);
	return 0;
}
