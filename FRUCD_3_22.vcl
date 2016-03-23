; Formula Racing UCD
; Curtis 1239E Motor Controller Code
; Zhening (Sirius) Zhang

VCL_App_Ver = 104 	;Set VCL software revision

;--------------------
; I/O Requirements
;--------------------
;	For functions to work properly:
;		//HV switch connected to SW_4
;		//DriveRequest switch connected to SW_5
;		//Lower swtich connected to SW_6
;       Used CAN message to controll instead. 
;
;		Drive1 connected to PWM1
;		Drive2 connected to PWM2
;		Drive3 connected to PWM3
;
;		for WINVCL debugging use PWM 2 3 4
;;;Place holder, subject to change 

Drive1			equals	PWM1             
Drive2			equals	PWM2
Drive3			equals	PWM4  

HV				equals	User_bit1
DriveRequest	equals	User_bit2         
NEUTRAL			equals	User_bit3

PDO1			equals	User1
PDO2			equals	User2
PDO3			equals	User3
State			equals	User4
N_MASK			equals	User5
DV_MASK			equals	User6
HV_MASK			equals	User7

State=0
;;;;;Use this to change PDO mmapping.
;can_pdo_miso_1_map_1 = 0x80032D3

VCL_Throttle = 0
VCL_Brake = 10000

N_MASK=0x01
DV_MASK=0x02
HV_MASK=0x04

;enable_CANopen()
;enable_CANopen_pdo()

;Brake
;///////////////use CAN instead. 

;===============================================================

Mainloop:

;===============================================================

PRE_STATE_ON:

	State = 1
	Set_Interlock();
	put_pwm(Drive1,0)
	put_pwm(Drive2,0)
	put_pwm(Drive3,0)

STATE_ON:

	enter Service_Request_Handle

	if (HV = 1)
	{
		goto TURN_ON_PRE_CHARGE
	}
	else
	{
		goto STATE_ON
	}


;===============================================================

TURN_ON_PRE_CHARGE:

	State=2
	put_pwm(Drive1,0)
	put_pwm(Drive2,32767)
	put_pwm(Drive3,32767)

STATE_PRE_CHARGE:
	
	enter Service_Request_Handle

	;pre charge delay 5s

	setup_delay(DLY1,5000) // 5000 = 5s, 15000 for debugging

	while (DLY1_OUTPUT <> 0) 
	{
		if (HV = 0)
		{
			goto PRE_STATE_ON
		}
	}

	goto STATE_READY

;===============================================================

STATE_READY:

	enter Service_Request_Handle

	State=3

	if (HV = 0)
	{
		goto PRE_STATE_ON
	}
	else if (DriveRequest = 1)
	{
		if (NEUTRAL = 0)
		{
			if (VCL_Brake <> 0)  ; brake has to be pressed to turn on the car
			{
				goto TURN_ON_RUNNING
			}
		}
	}

	goto STATE_READY

;===============================================================

TURN_ON_RUNNING:
	
	State=4
	put_pwm(Drive1,32767)
	put_pwm(Drive2,32767)
	put_pwm(Drive3,0)

STATE_RUNNING:

	enter Service_Request_Handle

	if (HV = 0)
	{
		goto PRE_STATE_ON
	}
	else if (NEUTRAL = 1)
	{
		if  (DriveRequest = 0)
		{	
			put_pwm(Drive1,0)
			put_pwm(Drive2,32767)
			put_pwm(Drive3,32767)
			goto STATE_READY
		}
	}

	goto STATE_RUNNING

;===============================================================


begin_module Service_Request_Handle
	
	;read CAN message here and modify HV, NEUTRAL, and Drive Request
	HV= (PDO1 & HV_MASK) >> 2
	DriveRequest= (PDO1 & DV_MASK) >> 1
	NEUTRAL= PDO1 & N_MASK
	exit

end_module

begin_module Throttle_Input

	;read CAN here, get brake and throttle input 

end_module 

