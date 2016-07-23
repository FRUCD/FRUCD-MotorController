;===============================================================
; Hello - Print Hello World on the Spy Glass
;===========================================
;
; Copyright © 2001, all rights reserved
; XYZ Corporation
; Anytown, USA
;
; Version 1.1
;
;
; Description
;------------
;  This program demonstrates how to display text on the Curtis
;  SpyGlass display.  It also demonstrates the use of the time
;  delay function to display multiple lines of text.
;
;
; I/O Requirements
;-----------------
;  This program only uses the serial port.
;
;
;---------------------------------------------------------------
; Declaration Section
;--------------------
; none
;
;
;===============================================================
; Parameter Declarations
;=======================
;
;
;
; PARAMETER_ENTRY "Program"
;		TYPE		PROGRAM
;		Level		0
;	END
;
;
;	PARAMETER_ENTRY "Delay Time"
;		TYPE		PROGRAM
;		ADDRESS		user1
;		WIDTH		16bit,
;	END
;
;
;===============================================================
; One time Initialization
;========================
;
user1 = 500


;-------------------------------------------------------------------------
; Main :: Main Line of the Hello World Program
;---------------------------------------------
;
while (1 = 1) {
	Put_Spy_Message("Hello",0,"",PSM_TEXT_ONLY)
    call Delay 

	Put_Spy_Message("World",0,"",PSM_TEXT_ONLY)
    call Delay 
}

;-------------------------------------------------------------------------
; Delay :: Run the Fixed Delay
;-----------------------------
;
Delay:

    Setup_Delay(DLY1, 500)
    while (DLY1_Output <> 0) {}

    return
