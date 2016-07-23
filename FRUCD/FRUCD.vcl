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
Drive3			equals	PWM3  

// if PWM 3 is used, then we will use curtis's precharge functionality, ENABLE_PRECHARGE()
// if PWM 4 is used, then we will use a ~5s delay for the precharge state

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
;;;;;Can we Use sth like this to change PDO mapping?
;;;can_pdo_miso_1_map_1 = 0x80032D3

VCL_Throttle = 0
VCL_Brake = 10000 // for testing right now, forced the brake to nonzero; change it to read from CAN msg later

N_MASK=0x01 //netural is the first bit
DV_MASK=0x02  // Drive is the second bit
HV_MASK=0x04  // High voltage request is the thrid bit

;enable_CANopen()
;enable_CANopen_pdo()

;Brake
;///////////////use CAN instead. 

;===============================================================

Mainloop:

;===============================================================

// ON STATE; STATE # 1
// D1 D2 D3 are off
// when HV is asserted, go for precharge

PRE_STATE_ON:

	State = 1
	//Set_Interlock();
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

// PRE_CHARGE STATE; STATE # 2
// D2 D3 are on
// After 5 s, it will automatically go to READY STATE


TURN_ON_PRE_CHARGE:

	State=2
	put_pwm(Drive1,0)

	put_pwm(Drive3,32767) //32767

	setup_delay(DLY1,5000) // 5000 = 5s, 15000 for debugging

	while (DLY1_OUTPUT <> 0) {}

	put_pwm(Drive2,32767)
	

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

	// using PWM 3 as precharge, which depends on Curtis precharge functionality
	//ENABLE_PRECHARGE()
	//if (Precharge_State = 2)
	//{
		//goto STATE_READY
	//}

	// check the Capacitor_Voltage to see whether or not it's okay to close the main contactor. 
	//if (Capacitor_Voltage > 100)
	//{
	//	goto STATE_READY
	//}
	//else
	//{
	//	goto STATE_PRE_CHARGE
	//}

	// do not depend on any info, delay a couple seconds and close the main contactor anyway
	goto STATE_READY
;===============================================================

// Ready State; State# 3
// D2 D3 are on
// If HV is off, go back to State 1
// else if HV and DriveRequest are both asserted(0x06) and NEUTRAL is off, go to Drive state
// else if HV and NEUTRAL are both asserted, stay in in this state

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

//Running state: state # 4
// D1 and D2 are on D3 is off
// if HV is off, go back to state 1
// if HV & NEUTRAL are asserted, then go back to state 3

TURN_ON_RUNNING:
	
	State=4
	put_pwm(Drive1,0)  //32767)
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
			put_pwm(Drive1,0)
			put_pwm(Drive2,32767)
			put_pwm(Drive3,32767)
			goto STATE_READY
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

