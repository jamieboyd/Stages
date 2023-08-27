/*
	ASIUSBez.h -- equates for ASIUSBez XOP
*/

/* Custom error codes for ASIUSBez*/
#define REQUIRES_IGOR_500			1 + FIRST_XOP_ERR
#define CEC_SYNC_WARNING			2 + FIRST_XOP_ERR
#define CEC_BAD_WRITE_ERROR			3 + FIRST_XOP_ERR
#define CEC_BAD_READ_ERROR			4 + FIRST_XOP_ERR
#define CEC_DEVICE_DOES_NOT_EXIST	5 + FIRST_XOP_ERR
#define CEC_BAD_HANDLE				6 + FIRST_XOP_ERR
#define CEC_TIME_OUT				7 + FIRST_XOP_ERR
#define CEC_DEVICE_IN_USE			8 + FIRST_XOP_ERR
#define CEC_BAD_DATA				9 + FIRST_XOP_ERR
#define CEC_TRANSMISSION_ERROR		10 + FIRST_XOP_ERR
#define CEC_INTERNAL_DLL_ERROR		11 + FIRST_XOP_ERR
#define CEC_INVALID_COMMAND			12 + FIRST_XOP_ERR
#define CEC_EMPTY_PACKET			13 + FIRST_XOP_ERR
#define CEC_INVALID_PACKET_SIZE		14 + FIRST_XOP_ERR
#define CEC_OUT_OF_RANGE			15 + FIRST_XOP_ERR
#define CEC_AXIS_WAS_IN_MOTION		16 + FIRST_XOP_ERR
#define	CEC_UNKNOWN_ASI_ERR			17 + FIRST_XOP_ERR
#define DEVICE_NUM_OUT_OF_RANGE		18 + FIRST_XOP_ERR
#define DEVICE_NOT_OPEN				19 + FIRST_XOP_ERR

/*typedefs*/
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

#include "XOPStructureAlignmentTwoByte.h"
// For returning a string of a list of devices
typedef struct ASIUSBListDevParams {
	Handle result;
}ASIUSBListDevParams, *ASIUSBListDevParamsPtr;
// For functions that only need to know the number of the device
typedef struct ASIUSBDeviceOnlyParams {
	DOUBLE theDevice;	//Number of the device to open
	DOUBLE result;
}ASIUSBDeviceOnlyParams, *ASIUSBDeviceOnlyParamsPtr;
// Get X,Y, and Z values, note pointers to doubles to hold returned values
typedef struct ASIUSBGetXYZParams {
	DOUBLE* zValue;
	DOUBLE* yValue;
	DOUBLE* xValue;
	DOUBLE theDevice;	//Number of the device
	DOUBLE result;
} ASIUSBGetXYZParams, *ASIUSBGetXYZParamsPtr;
// Get only X and Y values
typedef struct ASIUSBGetXYParams {
	DOUBLE* yValue;
	DOUBLE* xValue;
	DOUBLE theDevice;	//Number of the device
	DOUBLE result;
} ASIUSBGetXYParams, *ASIUSBGetXYParamsPtr;
// Move to a Position (XYZ), note doubles (not pointers) to pass position
typedef struct ASIUSBMovXYZParams {
	DOUBLE zValue;
	DOUBLE yValue;
	DOUBLE xValue;
	DOUBLE theDevice;	//Number of the device
	DOUBLE result;
}ASIUSBMovXYZParams, *ASIUSBMovXYZParamsPtr;
//Move to a Position (XY)
typedef struct ASIUSBMovXYParams {
	DOUBLE yValue;
	DOUBLE xValue;
	DOUBLE theDevice;	//Number of the device
	DOUBLE result;
}ASIUSBMovXYParams, *ASIUSBMovXYParamsPtr;
// For functions with only a return value
typedef struct EmptyParams {
	DOUBLE result;
}EmptyParams, *EmptyParamsPtr;
#include "XOPStructureAlignmentReset.h"

/* Prototypes */
HOST_IMPORT int main(IORecHandle ioRecHandle);
static long RegisterFunction();
static void XOPEntry(void);
static long ASItoIgErr (long ASIerrCode);
static long ASIUSBInit (EmptyParamsPtr p);
static long ASIUSBListDevices (ASIUSBListDevParamsPtr p);
static long ASIUSBOpen (ASIUSBDeviceOnlyParamsPtr p);
static long ASIUSBClose (ASIUSBDeviceOnlyParamsPtr p);
static long ASIUSBGetXYZ (ASIUSBGetXYZParamsPtr p);
static long ASIUSBGetXY (ASIUSBGetXYParamsPtr p);
static long ASIUSBMovAbsXYZ (ASIUSBMovXYZParamsPtr p);
static long ASIUSBMovAbsXY(ASIUSBMovXYParamsPtr p);
static long ASIUSBMovRelXYZ (ASIUSBMovXYZParamsPtr p);
static long ASIUSBIsBusy(ASIUSBDeviceOnlyParamsPtr p);
static long ASIUSBSetZero(ASIUSBDeviceOnlyParamsPtr p);
static long ASIUSBHalt(ASIUSBDeviceOnlyParamsPtr p);
static long ASIUSBSetKp(ASIUSBMovXYZParamsPtr p);
static long ASIUSBSetKi(ASIUSBMovXYZParamsPtr p);
static long ASIUSBSetKd(ASIUSBMovXYZParamsPtr p);
static long ASIUSBGetKp (ASIUSBGetXYZParamsPtr p);
static long ASIUSBGetKi (ASIUSBGetXYZParamsPtr p);
static long ASIUSBGetKd (ASIUSBGetXYZParamsPtr p);