
The following files needed for the creation and/or use of the ASIUSBex XOP were downloaded from the Applied Scientific Instrumentation Inc. website as part of the freely available ASI USB package, version 3.1. This package is no longer available from ASI, as their new WK model models do not support “native” USB, so I have included them here.

ASIUSB1.DLL
EZUSB.SYS
EZUSBW2K.INF
EZUSBWXP.INF
ASIUSB.H
ASIUSB1.LIB
USB_WXP.TXT

The following discussion is edited from the original ASI README.TXT.

* ASIUSB1.DLL, EZUSB.SYS, EZUSBWXP.INF, which are Windows system files 
needed by all ASI software using USB to control the MS-2000. Windows XP machines need
EZUSBWXP.INF; Windows 2000 machines need EZUSBW2K.INF.

* ASIUSB.H, a text file associated with ASIUSB1.DLL, needed for C language programming, not
  needed to run any application; ASIUSB1.LIB is a C library file, needed to link software 
  that uses objects declared in ASIUSB.h.


* USB_WXP.TXT contains instructions on connecting the MS-2000 to a Windows XP machine via USB.

More details about these files follow.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
NOTICE!!!

At this point the ASIUSB1.dll is not fully thread safe.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

**************************************************************************
EZUSB.SYS

General Purpose USB Driver System file Should be placed in the windows system directory

**************************************************************************
EZUSBW2K.INF

Information file which the windows registry will lock on to in order to know which driver to use when the MS2000 is plugged into the USB port

There is usually a Windows system directory, such as C:\WINNT\INF, where many .INF files
are stored. This is where EZUSBW2K.INF belongs.

**************************************************************************
ASIUSB1.dll

Dynamic Link Library with functions for all major ASI MS2000 commands.
Only one copy of this file should reside in the system.
ASI recommends placing this file into one of these folders:
* the Windows system folder (e.g., C:\WINDOWS\SYSTEM, or C:\WINNT\SYSTEM),
* the Windows folder (e.g., C:\WINDOWS, or C:\WINNT),
* a directory listed in the PATH environment variable.
These are the folders where a Windows program will by default look for the .DLLs
it needs. For this reason, if ASIUSB1.DLL is in a suitable folder, there will
usually be many other .DLL files in the same folder.
**************************************************************************
ASIUSB.H

Header file for the .dll, contains function declarations, and programming information on 
how the functions are intended to be used as well as return and error code information.
