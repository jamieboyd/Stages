//######################################################################
// File: ASIUSB.h          header file for ASIUSB1.dll
//
// Purpose:	This file gives the definitions of the various functions
//			available inside the ASIUSB1.dll.   Also listed are error
//			codes and definitions.
//
// start
//	***********Version 2.0**************
/*  Note the following functions are unactivated in this version
GetName
Set/Get backlashXYZ
Set/Get maxErrorXYZ
Set/GetManVslowXYZ
Set/GetManVMidXYZ
Set/GetPCRossXYZ
Set/GetstartvelXYZ
MotorControl
ManualControl
Set/GetUpperLimitA
Set/GetLowerLimitA
*/


// Error Messages
#define		NO_ERRORS					 1
#define     SYNC_WARNING				 2
#define		BAD_WRITE_ERROR				-1
#define		BAD_READ_ERROR				-2
#define		DEVICE_DOES_NOT_EXIST		-3
#define		BAD_HANDLE					-4
#define     TIME_OUT					-5
#define		DEVICE_IN_USE				-6
#define		BAD_DATA					-7
#define     TRANSMISSION_ERROR			-8
#define		INTERNAL_DLL_ERROR			-9
#define		INVALID_COMMAND				-10
#define     EMPTY_PACKET                -11
#define     INVALID_PACKET_SIZE         -12
#define		OUT_OF_RANGE				-40
#define		AXIS_WAS_IN_MOTION			-210


// Logic Definitions
#define		ENABLE						1
#define		DISABLE						0



//typedef CHAR *LPSTR, *PSTR;

/*#####################################################################################
Note: The set standard proceedure to be in accordance with possible future updates
for use of multiple ASI devices is as follows:

 I  Call EnumASIControllers
		Before doing anything else, this function should be called.   This function 
		allows the dll to generate internal lookup tables for devices currently attached 
		to the PC via USB.

	Arguments: NONE

	Returns:	ucNumberASIControllersOnUSB = # of ASI devices currently attached on USB

  Ex:	ucNumberASIControllersOnUSB = EnumASIControllers();

		The function returns the number of ASI controllers actually attached to the
		PC via the USB (C++ users use unsigned char   VB users use BYTE).   In most
		cases this response will be a 1 for the single MS/MFC2000 attached.   In the 
		future as more ASI devices (shutter controllers, manipulator controllers, ect..)
		are converted to USB devices, this may/will change.


II.	If there is more than one device (EnumASIControllers returns number higher than 1)
	The GetEnumDeviceId(ucPosition, lpstrIDstring) function can be used to determine what
	the device is without having to open a normal communications path with or establishing 
	a handle to	the device.

    Arguments:	
	
	  ucPosition = number from 1 to number of devices returned by EnumASIControllers()
	
	  lpstrIDstring =	pointer to a string (!MIN 25 CHARS LONG!) which the dll will 
						fill in with the identification string of that device.

	Returns:	NONE
			

  Ex:
	char strDeviceDescript[10][26];
	For (ucDevicePosition = 1; 
	     ucDevicePosition <  ucNumberASIControllersOnUSB;
		 ucDevicePosition++)
	   {
  	   GetEnumDeviceId(	ucDevicePosition,
	          			(*strDeviceDescript[ucDevicePosition][0])
					 );
	   };

	In this example a loop is settup using the ucNumberASIControllersOnUSB variable from
	step I.   The loop queries each device - allowing the dll to fill in the IdString
	for each device into the array of strings strDeviceDescript[Device][string length].
	Note that the length of the string is set to 26 -> It is crucial that at least 25 
	characters of space be reserved.   If less than 25 characters are reserved the dll 
	may overwrite some unknown variable as there is no protection against entering the
	pointer to a wrong size string.  Up to 25 characters will be copied into the address
	space provided.



III For devices to be used, use the OpenASIDevice(DevicePosition)
	This function establishes a USB communication stream to the device and returns a handle
	to it.
	Starting with 1 the Open Device function is called going to the number of controllers 
	present.  

	Arguments:  DevicePosition = number from 1 to number of devices returned by EnumASIControllers()
    
	Returns:	DeviceHandle = is to be used to access that device for any further function 
				calls. 	 If the device fails to open, an error code will be returned 
				(NOTE1: errors are always negative values ).
				(NOTE2: C users use a handle,	VB users use a LONG) 
		
	Ex:  
	  hndDeviceHandle = OpenASIDevice(ucDevicePosition);
	  

III	Use any of the functions using the handle given from GetDeviceId

	Ex:	iResult = MoveA( 'X', lngNewXPosition , hndDeviceHandle[current_device]);


IV.	Use CloseASIDevice() to properly allow the dll to properly release any resources used 
	for each device.

	Ex: CloseASIDevice( hndDeviceHandle[current_device] );


NOTE: Although in most cases there will only be one axis controller attached, I 
encourage Application Implementors to check for possible attachement of multiple
ASI axis control devices as ASI intends to release several new axis controllers in the near
future for things such as micro-manipulators, Theta stages, Translation tables & more.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
REFERENCE:  A way to detect which axis's are available on each device is through
the Description String filled in by the function GetDeviceId once the device is 
already open.: if there is a X,Y, Z, T, or D in the string, Then that axis is 
controllable through that Device.

  T = Theta: a rotational stage on top of the XY which rotates the slide around the center
  D = Delta: Extra special function such as lamp light level, or monochromater control



  Sample Descriptor String:   "  MS2000-XYb-ZlAs

  BreakDown:
		
		MS2000  = MS2000 controller
		XYbl	= XY axises attached   b=Course Pitch  l-has linear encoders
		ZAs		= Z axis attached   A= has Autofocus circuitry  S-Silver Z motor
*/



//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^




//*********************************************************************************************
//*********************************************************************************************
//*********************************************************************************************
// ASI USB FUNCTIONs





////////////////////////////////////////////////////////////////////////////////////////
// ENUMERATE AXIS CONTROLLORS
// This function causes the dll to search the USB ports for attached ASI Axis Controllers
// like the MS2000 and internally create an index of where these devices are on the USB 
// which corrisponds to its position on the list.   Without calling this function first
// other functions may produce unpredictable results.
//
// lpControllerCount - pointer to variable to receive controller count
// 
int _stdcall EnumASIControllers(unsigned int& lpControllerCount );

//================================================================================================


////////////////////////////////////////////////////////////////////////////////////////
// Query ASI Device
// This function allows the return of an Identification String from any ASI device attached
// to the PC via USB.   Before this function will properly work the function 
// EnumASIControllers() must be called.  The lpstrDeviceIdString must be a minimum of 25
// chars long.   If a shorter string is attached to the pointer, the function will write
// out past the end of the string possibly causing fatal system errors.
//
//ARGUMENTS:
// ucDevicePosition			- Number from 1 to number returened by EnumASIControllers()
// lpstrDeviceIdString		- long pointer to a string (min 25 chars long)


// REFERENCES:
/*
FROM Module Name:
    winnt.h

#ifdef STRICT
typedef void *HANDLE;
#define DECLARE_HANDLE(name) struct name##__ { int unused; }; typedef struct name##__ *name
#else
typedef PVOID HANDLE;

typedef CHAR *LPSTR, *PSTR;
*/

// NOTES ON DeviceIdString: 
// First 15 chars = Model No.  Future Reserved of Last 10 = Attached Scope
// EX: MS2000-XYAL-ZAL
// MEANS: MS2000 controller 
//		  -XYAL XY axies with fine pitch lead screws with (L) optional linear encoders
//		  -ZAL	has Z focus control with Autofocus Option with Linear Encoder 	
//



int _stdcall GetEnumDeviceId(	unsigned char	ucDevicePosition,
								LPSTR			lpstrDeviceIdString=0
							);

//================================================================================================



////////////////////////////////////////////////////////////////////////////////////////
// OPEN ASI DEVICE and CLOSE ASI DEVICE
// These two functions are used to establish and disconnect a communcications line to a device
// OpenAxisContDevice establishes a communication pipe between the PC and controller via the
// ezusb driver.  The function returns a handle to access that device..
//
// RECIEVES:
//		DevicePosition : number ranging from 0 to 9 representing the plug in order on the USB
//		lpDeviceHandle		reference to variable to receive device handle

int _stdcall OpenASIDevice( unsigned int DevicePosition, HANDLE& lpDeviceHandle );



// The CloseAxisContDevice function should be used to close that communication pipe 
// and allow the dll to release any resources.
int _stdcall CloseASIDevice (HANDLE hndDeviceHandle=0);



// This function writes the given 'writeBuf' then tries to read a response

int _stdcall WriteThenReadBulkData(
							LPSTR writeBuf, 
							DWORD writeBufBytes,
							DWORD writeRetryCount,
							LPSTR readBuf,
							DWORD &readBufBytes,
							HANDLE hndDeviceHandle
						  );


/////////////////////////////////////////////////////////////////////////////////////
//  These two functions allow writing a High Level command directly to the controller
//  and checking for a response
//  If you plan on using these functions, please contact me to get the format of the
//  command and return string.

int _stdcall ReadBulkData(	LPSTR		OutBuffer,
							DWORD&		dBytes, 
							HANDLE		hndDeviceHandle=0);


int _stdcall WriteBulkData(	LPSTR		InBuffer, 
							DWORD		NumberOfBytes, 
							HANDLE		hndDeviceHandle=0);




////////////////////////////////////////////////////////////////////////////////////
//   Allows access to the USB Device Descriptor of the unit attached
//   Requires USB Descriptor struct
int _stdcall GetDeviceDescriptor( PUSB_DEVICE_DESCRIPTOR pvBuffer,
								  HANDLE hndDeviceHandle=0);

/*
From Module: USB100.H

typedef struct _USB_DEVICE_DESCRIPTOR {
    UCHAR bLength;
    UCHAR bDescriptorType;
    USHORT bcdUSB;
    UCHAR bDeviceClass;
    UCHAR bDeviceSubClass;
    UCHAR bDeviceProtocol;
    UCHAR bMaxPacketSize0;
    USHORT idVendor;
    USHORT idProduct;
    USHORT bcdDevice;
    UCHAR iManufacturer;
    UCHAR iProduct;
    UCHAR iSerialNumber;
    UCHAR bNumConfigurations;
} USB_DEVICE_DESCRIPTOR, *PUSB_DEVICE_DESCRIPTOR;

From Module: windef.h
typedef unsigned char UCHAR;
typedef unsigned short USHORT;
*/



////////////////////////////////////////////////////////////////////////////////////////
// Get Position and Status Update Routine
// NOTE: THIS FUNCTION IS STILL IN TESTING PHASE AND IS NOT IMPLEMENTED
// DO NOT USE!!!!!!!!!!!!!!!!!!!!
// This function allows the dll to automatically update the variables holding
// position and status for each axis by setting an interval in milliseconds
// delay inbetween times to query the controller.

// ------------------Status Byte Breakdown----------------------------
//
// Bit 0:  0 = No Motor Signal  1 = Motor Signal  (axis is moving)
// Bit 1:  Always 1 as servos cannot be turned off
// Bit 2:  0 = Pulses Off   1 = Pulses On
// Bit 3:  0 = Joystick/Knob disabled  1 = Joystick/Knob enabled
// Bit 4:  0 = motor not ramping   1 = motor ramping
// Bit 5:  0 = ramping up	1= ramping down
// Bit 6:  Upper limit switch 0 = open  1 = closed
// Bit 7:  Lower limit switch 0 = open  1 = closed
// Note: the Status byte mimics the ludl low level status byte


int _stdcall GetPosStatUpdate(  float lpAxisPositionX=0,
								float lpAxisPositionY=0,
								float lpAxisPositionZ=0,
								float lpAxisPositionT=0,
								char cpAxisStatusX=0,
								char cpAxisStatusY=0,
								char cpAxisStatusZ=0,
								char cpAxisStatusT=0, 
								HANDLE hndDeviceHandle=0);



/////////////////////////////////////////////////////////////////////////////////////
// same as Status command........replies 
// status = B : controller is finishing a commanded move
// status = N : controller is idle
int _stdcall GetStatus(char& status, 
			        HANDLE hndDeviceHandle=0);



/////////////////////////////////////////////////////////////////////////////////////
// Used to move a single Axis to an absolute position
// Axis can be X, Y, Z, or in the future T for stages with a rotating platform
int _stdcall MoveA  (char Axis, float Position, HANDLE hndDeviceHandle=0);
// Moves X and Y coordinates to an absolute position
int _stdcall MoveXY (float X,float  Y, HANDLE hndDeviceHandle=0);
// Moves X, Y, &Z to absolute positions
int _stdcall MoveXYZ(float X, float Y, float Z, HANDLE hndDeviceHandle=0);

int _stdcall MoveN(long axisCount, long axisNumberArray[], float axisPositionArray[], HANDLE hndDeviceHandle);


// Moves any axis a relative distance from the current position
int _stdcall RelMove(float X, float Y, float Z, HANDLE hndDeviceHandle=0);

int _stdcall MoveRelN(long axisCount, long axisNumberArray[], float axisPositionArray[], HANDLE hndDeviceHandle);


////////////////////////////////////////////////////////////////////////////////////
// Used to retrieve the current position of all three axis's
int _stdcall WhereA  (char cAxis, float& fPosition, HANDLE hndDeviceHandle=0);

int _stdcall Where  (float& X, float& Y, float& Z, HANDLE hndDeviceHandle=0);

int _stdcall WhereN(long axisCount, long axisNumberArray[], float axisPositionArray[], HANDLE hndDeviceHandle=0);


////////////////////////////////////////////////////////////////////////////////////
// Used to retrieve the ASI status byte for one axis which gives information
// on whether a motor is enabled, moving, ramping, or on a limit switch
// See ASI manual for HL command RDSBYTE for more info, or contact me
// 
int _stdcall GetStatusByte(char& cpStatusByte, 
						   unsigned char Axis='Z',
         				   HANDLE hndDeviceHandle=0);


int _stdcall GetAxisStatusN(long axisCount, long *axisNumberArray, unsigned char *axisStatusArray, unsigned long hndDeviceHandle);



//////////////////////////////////////////////////////////////////////////////////
// Sets current position of stage to a stage position for all three axis'
int _stdcall SetHereXYZ(float lX, 
						float lY, 
						float lZ, 
						HANDLE hndDeviceHandle=0);
//////////////////////////////////////////////////////////////////////////////////
// Sets current position of axis to a numerical position for one axis
// cAxis Values: X,Y,Z,T
int _stdcall SetHereA  (char cAxis, 
						float lPosition, 
						HANDLE hndDeviceHandle=0);

int _stdcall HereN(long axisCount, long axisNumberArray[], float axisPositionArray[], HANDLE hndDeviceHandle=0);


//////////////////////////////////////////////////////////////////////////////////
// Halts all movements on any axis
// *does not affect AutoFocus, GetLimits, or Alignment Modes
int _stdcall Halt(HANDLE hndDeviceHandle=0);

//////////////////////////////////////////////////////////////////////////////////
//  Causes Stage to move to limit switch position corner of stage
int _stdcall HomeXYZ(HANDLE hndDeviceHandle=0);

//////////////////////////////////////////////////////////////////////////////////
//  Causes One axis to move to a limit position
// Axis: X,Y,Z,T
int _stdcall HomeA(char cAxis, 
				   HANDLE hndDeviceHandle=0);


//////////////////////////////////////////////////////////////////////////////////
// Causes controller to do a soft reset
// NOT IMPLEMENTED - RESERVED FOR FUTURE USE
int _stdcall ResetDevice(HANDLE hndDeviceHandle=0);


//////////////////////////////////////////////////////////////////////////////////
// Sets the maximum travel speed for any or all axis'
int _stdcall SetMaxSpeedXYZ(float lX=0.0, 
							float lY=0.0, 
							float lZ=0.0, 
							HANDLE hndDeviceHandle=0);
//////////////////////////////////////////////////////////////////////////////////
// Gets the maximum travel speed for any or all axis'
int _stdcall GetMaxSpeedXYZ(float& fX, 
							float& fY, 
							float& fZ, 
							HANDLE hndDeviceHandle=0);

//////////////////////////////////////////////////////////////////////////////////
// Same as ASI HL Version command
// lpIdBuffer string must be minimum of 20 chars
int _stdcall GetFirmVersion( LPSTR idBuffer, HANDLE hndDeviceHandle=0);



//////////////////////////////////////////////////////////////////////////////////
// Same as ASI HL WHO command - Future use will return who + scope
// lpIdBuffer must be minimum of 25 chars 
// First 15 = Model #    Last 10 = Attached Scope

int _stdcall GetDeviceId( LPSTR idBuffer, HANDLE hndDeviceHandle=0);


//////////////////////////////////////////////////////////////////////////////////
// Same as ASI HL WHO command
// lpIdBuffer must be minimum of 20 chars 
int _stdcall GetName(LPSTR lpIdBuffer, 
					 HANDLE hndDeviceHandle=0);

//////////////////////////////////////////////////////////////////////////////////
// Sets current position to Zero on all axises
int _stdcall SetZero(HANDLE hndDeviceHandle=0);


//////////////////////////////////////////////////////////////////////////////////
// Used to set offset distance from target for anti-backlash algorithm
int _stdcall SetBacklashXYZ(float lX=0.0, 
							float lY=0.0, 
							float lZ=0.0, 
							HANDLE hndDeviceHandle=0);
//////////////////////////////////////////////////////////////////////////////////
// Used to read current offset distance for anti-backlash algorithm
// (units in tenths of microns)
int _stdcall GetBacklashXYZ(float& lX, 
							float& lY, 
							float& lZ, 
							HANDLE hndDeviceHandle=0);



//////////////////////////////////////////////////////////////////////////////////////
// Sets value for slow range of joystick control
// NOT IMPLEMENTED - Reserved for future use
// (units in tenths of millimeters)
int _stdcall SetManVslowXYZ(float lX=0.0, 
							float lY=0.0, 
							float lZ=0.0, 
							HANDLE hndDeviceHandle=0);

// Gets current value
// NOT IMPLEMENTED - Reserved for future use
// (units in millimeters)
int _stdcall GetManVslowXYZ(float& lX, 
							float& lY, 
							float& lZ, 
							HANDLE hndDeviceHandle=0);

//////////////////////////////////////////////////////////////////////////////////////
// Sets value for mid range speed of joystick control
// NOT IMPLEMENTED - Reserved for future use
int _stdcall SetManVMidXYZ(float lX=0.0, 
						   float lY=0.0, 
						   float lZ=0.0, 
						   HANDLE hndDeviceHandle=0);
// Gets current value
// NOT IMPLEMENTED - Reserved for future use
int _stdcall GetManVMidXYZ(float& lX, 
						   float& lY, 
						   float& lZ, 
						   HANDLE hndDeviceHandle=0);


//////////////////////////////////////////////////////////////////////////////////////
//This is the position error which determines at what point the controller
//will attempt to correct a drifting position

// NOTE: this value should never be less than PCross setting

// (units in millimeters)
int _stdcall SetMaxErrorXYZ(float lX=0.0, 
							float lY=0.0, 
							float lZ=0.0, 
							HANDLE hndDeviceHandle=0);

// Used to read current value setting of SetMaxError 
// (units in millimeters)
int _stdcall GetMaxErrorXYZ(float& lX, 
							float& lY, 
							float& lZ, 
							HANDLE hndDeviceHandle=0);


//////////////////////////////////////////////////////////////////////////////////////
// Determines the maximum distance allowable between the Target and actual Position
// before a move is considered complete.
// 
// NOTE: this value should never be greater than MaxError setting
// 
int _stdcall SetPCrossXYZ(float lX=0.0, 
						  float lY=0.0, 
						  float lZ=0.0, 
						  HANDLE hndDeviceHandle=0);
// Gets current value
int _stdcall GetPCrossXYZ(float& lX, 
						  float& lY, 
						  float& lZ, 
						  HANDLE hndDeviceHandle=0);


//////////////////////////////////////////////////////////////////////////////////////
// Stets starting velocity for when a controller ramps up speed during a move
// NOT IMPLEMENTED - Reserved for future use
int _stdcall SetStartVelXYZ(float lX=0.0, 
							float lY=0.0, 
							float lZ=0.0, 
							HANDLE hndDeviceHandle=0);
// Gets current value
// NOT IMPLEMENTED - Reserved for future use
int _stdcall GetStartVelXYZ(float& lX, 
							float& lY, 
							float& lZ, 
							HANDLE hndDeviceHandle=0);

//////////////////////////////////////////////////////////////////////////////////////
// Tells controller to output a DAC signal which gives a motor signal turning motor 
// at a set rate
// Acceptable values -100 to 100         a value of 0 turns off the command
// Axis' X Y Z T
int _stdcall SpinMotorA(char cAxis='X', 
						float  fPercentOfSpeed=0, 
						HANDLE hndDeviceHandle=0);



//////////////////////////////////////////////////////////////////////////////////////
// Set/Get PID constants
// PID constants control motor move rotine profile
// These settings affect the landing time and ability of the motor driver
int _stdcall SetKpXYZ(	float fX=0.0, 
						float fY=0.0, 
						float fZ=0.0, 
						HANDLE hndDeviceHandle=0);

int _stdcall SetKiXYZ(	float fX=0.0, 
						float fY=0.0, 
						float fZ=0.0, 
						HANDLE hndDeviceHandle=0);

int _stdcall SetKdXYZ(	float fX=0.0, 
						float fY=0.0, 
						float fZ=0.0, 
						HANDLE hndDeviceHandle=0);
//-------------------------------------------------------------------
int _stdcall GetKpXYZ(	float& X, 
						float& Y, 
						float& Z, 
						HANDLE hndDeviceHandle=0);

int _stdcall GetKiXYZ(	float& X, 
						float& Y, 
						float& Z, 
						HANDLE hndDeviceHandle=0);

int _stdcall GetKdXYZ(	float& X, 
						float& Y, 
						float& Z, 
						HANDLE hndDeviceHandle=0);


//////////////////////////////////////////////////////////////////////////////////////
// These routines are for MS/MFC controllers with I2C non-volitile memory in them.
// The Save Settings allows the user to save the current setup (speed,joystick profile,etc)
// to non-volitile memory.  The settings will automatically be reloaded whenever the controller
// is reset by power (OFF/ON or RESET button).

int	_stdcall SaveSettings(	HANDLE hndDeviceHandle=0);



// The ResetSettings function turns off the saved settings so that the controller will boot
// with normal parameters.  Do not use with controllers released before 15 JAN 03

int _stdcall ResetSettings(	HANDLE hndDeviceHandle=0);





//////////////////////////////////////////////////////////////////////////////////////
// Set/Get SC (Stop Constant) constants
// SC controls motor dampening at the end of a move to reduce feedback oscillation
// These settings affect the landing time and oscillation of the motor driver

int _stdcall SetSCXYZ(	float fX=0.0, 
						float fY=0.0, 
						float fZ=0.0, 
						HANDLE hndDeviceHandle=0);
//-------------------------------------------------------------------
int _stdcall GetSCXYZ(	float& , 
						float& , 
						float& , 
						HANDLE hndDeviceHandle=0);




//////////////////////////////////////////////////////////////////////////////////////
// Enables or disables the motor control for an axis
//  0 disables, 1 enables
// NOT IMPLEMENTED - Reserved for future use
int _stdcall MotorControl(char cXEnable=1, 
						  char cYEnable=1, 
						  char cZEnable=1,  
						  HANDLE hndDeviceHandle=0);

//////////////////////////////////////////////////////////////////////////////////////
// Enables or diables the Manual input (Joystick/ Knob) for an axis
// 0 disables, 1 enables
// NOT IMPLEMENTED - Reserved for future use
int _stdcall ManualControl(char XEnable=1, 
						   char YEnable=1, 
						   char ZEnable=1,  
						   HANDLE hndDeviceHandle=0);


//////////////////////////////////////////////////////////////////////////////////////
//  Sets a firmware limit position that the controller will not pass when moving
// in a posative direction
// NOT IMPLEMENTED - Reserved for future use
int _stdcall SetUpperLimitA(char Axis, 
							float Position=0, 
							HANDLE hndDeviceHandle=0);
// Gets current value
// NOT IMPLEMENTED - Reserved for future use
int _stdcall GetUpperLimitA(char Axis, 
							float& Position, 
							HANDLE hndDeviceHandle=0);


// Allows setting of XYZ upper firmware limit switch
int _stdcall SetUpperLimitXYZ(	float fX, 
								float fY, 
								float fZ, 
								HANDLE hndDeviceHandle);

// Gets setting of XYZ uppper firmware limit switch
int _stdcall GetUpperLimitXYZ(	float& fX, 
								float& fY, 
								float& fZ, 
								HANDLE hndDeviceHandle);


//////////////////////////////////////////////////////////////////////////////////////
//  Sets a firmware limit position that the controller will not pass when moving in a 
// negative direction
// NOT IMPLEMENTED - Reserved for future use
int _stdcall SetLowerLimitA(char Axis, 
							float Position=0, 
							HANDLE hndDeviceHandle=0);
// Gets Current Value
// NOT IMPLEMENTED - Reserved for future use
int _stdcall GetLowerLimitA(char Axis, 
							float& Position, 
							HANDLE hndDeviceHandle=0);

// Allows setting of XYZ lower firmware limit switch
int _stdcall SetLowerLimitXYZ(	float fX, 
								float fY, 
								float fZ, 
								HANDLE hndDeviceHandle);

// Gets setting of XYZ lower firmware limit switch
int _stdcall GetLowerLimitXYZ(float& fX, 
							  float& fY, 
							  float& fZ, 
							  HANDLE hndDeviceHandle);



//////////////////////////////////////////////////////////////////////////////////////
// Controls the ability and calls the autofocus routine
int _stdcall AutoFocus( long	Type=0, 
					    long	SpeedPercentage=0,
						float    Depth=0.0, 
						HANDLE hndDeviceHandle=0);


int _stdcall SetAF_Adjust( 	float  fValue=4.7,
							HANDLE hndDeviceHandle=0);

int _stdcall GetAF_Adjust(  float& fValue, 
							HANDLE hndDeviceHandle);

//////////////////////////////////////////////////////////////////////////////////////
// NOT IMPLEMENTED - Reserved for future use
int _stdcall CenterXY(HANDLE hndDeviceHandle=0);
int _stdcall CenterWait(HANDLE hndDeviceHandle=0); 

//////////////////////////////////////////////////////////////////////////////////////
// NOT IMPLEMENTED - Reserved for future use
int _stdcall LHome( float X_Pos=0, float Y_Pos=0, long Type=0);
int _stdcall LHomeWait(HANDLE hndDeviceHandle=0); 


//////////////////////////////////////////////////////////////////////////////////////
// NOT IMPLEMENTED - Reserved for future use
int _stdcall SetInc( float  X_Inc=0.0, 
					 float  Y_Inc=0.0,
					 float  Z_Inc=0.0, 
					 HANDLE hndDeviceHandle=0);

int _stdcall GetInc( float& X_Inc  , 
					 float& Y_Pos  , 
					 float& Z_Pos  , 
					 HANDLE hndDeviceHandle=0);

int _stdcall GO(HANDLE hndDeviceHandle=0); 




