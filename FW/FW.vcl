; PARAMETER_ENTRY "Program"
;		TYPE		PROGRAM
;		Level		0
;	END
; PARAMETER_ENTRY "UCDFRStateData"
;		TYPE		Monitor
;		Level		1
;	END
; parameter_entry "State"
; 	type Monitor
; 	width 16bit
; 	address user4
; 	units @
; end
; parameter_entry "SetInterlock"
; 	type Monitor
; 	width 16bit
; 	address User_bit4
; 	units @
; end

; Formula Racing UCD
; Curtis 1239E Motor Controller Code
; Zhening (Sirius) Zhang
; Edited by Basheer Ammar

VCL_App_Ver = 100 	;Set VCL software revision

;--------------------
; I/O Requirements
;--------------------
;	For functions to work properly:
;       Used CAN message for controll
;
;		Drive1 connected to PWM1
;		Drive2 connected to PWM2
;		Drive3 connected to PWM3

Drive1			equals	PWM1
Drive2			equals	PWM2
Drive3			equals	PWM3
Drive4          equals  PWM4

HVRequest		equals	User_bit1
DriveRequest	equals	User_bit2
NEUTRAL			equals	User_bit3

PDO1			equals	User1
PDO2			equals	User2
PDO3			equals	User3
State			equals	User4
N_MASK			equals	User5
DV_MASK			equals	User6
HV_MASK			equals	User7

DisplayState 	equals  User8
temp            equals	User9

throttle_high	equals	User10
throttle_low	equals	User11

Count_Low		equals	User12
Count_High		equals  User13

BMS_temp		equals	User14
SOC 			equals  User15
flashing_H		equals	User16
flashing_L		equals	User17
SetInterlock	equals	User_bit4

;---------------- Initialization ----------------------------

SetInterlock = 0
VCL_Throttle = 0
VCL_Brake = 0
state = 0
DisplayState = 1
Count_Low = 0
Count_High = 0
flashing_L = 0
flashing_H = 0

N_MASK=0x01 //netural is the first bit
DV_MASK=0x02  // Drive is the second bit
HV_MASK=0x04  // High voltage request is the thrid bit

;---------------- CAN Variables -----------------------------
pdoSend           equals can1
pdoRecvInterlock  equals can2
debug             equals can3
pdoAck	          equals can4
pdoRecvThrottle   equals can5


;FE_Main_State	equals Main_State
;FE_Cap_Vol		equals Capacitor_Voltage
;FE_Mapped_Throttle	equals ABS_Mapped_Throttle
;FE_Motor_RPM	equals ABS_Motor_RPM
;FE_Motor_Temp	equals Motor_Temperature
;FE_Key_Vol		equals Keyswitch_Voltage
;FE_Bat_A		equals Battery_Current
;FE_Bat_A_D		equals Battery_Current_Display
;FE_Controller_Temp	equals Controller_Temperature
;FE_Controller_Temp_Cutback equals ControllerTempCutback
;FE_Current_RMS	equals Current_RMS
;FE_Current_Request	equals Current_Request

;FE_VCL_Throttle	equals VCL_Throttle
;FE_VCL_Brake	equals VCL_Brake

;------------ Setup mailboxes ----------------------------
disable_mailbox(pdoSend)
Shutdown_CAN_Cyclic()

Setup_Mailbox(pdoSend, 0, 0, 0x566, C_CYCLIC, C_XMT, 0, 0)
Setup_Mailbox_Data(pdoSend,8,
                    @Capacitor_Voltage + USEHB,
					@Capacitor_Voltage,
					@ABS_Motor_RPM + USEHB,
					@ABS_Motor_RPM,
					@Motor_Temperature + USEHB,
					@Motor_Temperature,
					@ABS_Mapped_Throttle + USEHB,
					@ABS_Mapped_Throttle)

enable_mailbox(pdoSend)

disable_mailbox(debug)

Setup_Mailbox(debug, 0, 0, 0x466, C_CYCLIC, C_XMT, 0, 0)
Setup_Mailbox_Data(debug,8,
					@SetInterlock,
                    @HVRequest,
					@state,
					@PWM1_Output,
					@PWM2_Output,
					@PWM3_Output,
					@VCL_Throttle,
					@VCL_Brake)

enable_mailbox(debug)

disable_mailbox(pdoAck)
Setup_Mailbox(pdoAck, 0, 0, 0x666, C_EVENT, C_XMT, 0, 0)
Setup_Mailbox_Data(pdoAck,8,
					0xFF,
                    @Keyswitch_Voltage + USEHB,
                    @Keyswitch_Voltage,
					@Battery_Current + USEHB,
					@Battery_Current,
					@Battery_Current_Display,
					@Controller_Temperature + USEHB,
					@Controller_Temperature
)
enable_mailbox(pdoAck)

;disable_mailbox(pdoInfo)
;Setup_Mailbox(pdoInfo, 0, 0, 0x866, C_EVENT, C_XMT, 0, 0)
;Setup_Mailbox_Data(pdoInfo,8,
;					@ControllerTempCutback + USEHB,
;					@ControllerTempCutback,
;					@Current_RMS + USEHB,
;					@Current_RMS,
;					@Current_Request + USEHB,
;					@Current_Request,
;					0,
;					0
;)
;enable_mailbox(pdoInfo)

Setup_Mailbox(pdoRecvInterlock, 0, 0, 0x765, C_EVENT, C_RCV, 0, pdoAck)
Setup_Mailbox_Data(pdoRecvInterlock,8,
					@SetInterlock,
                    0,
					0,
					0,
					0,
					0,
					@SOC,
					@BMS_temp)

Setup_Mailbox(pdoRecvThrottle, 0, 0, 0x766, C_EVENT, C_RCV, 0, pdoAck)
Setup_Mailbox_Data(pdoRecvThrottle,8,
					@throttle_high,
                    @throttle_low,
					0,
					0,
					0,
					0,
					0,
					0)

Startup_CAN()
CAN_Set_Cyclic_Rate( 30 );actually 120ms
Setup_NMT_State(ENTER_OPERATIONAL)			;Set NMT state so we can detect global NMT commands
Startup_CAN_Cyclic()


Mainloop:
;--------------- Relays Control -----------------------------
;--------------- Mirror driver 1-> driver 5 -----------------
;--------------- and driver 3 -> driver 4 -------------------

	if(PWM3_Output > 0){
		put_pwm(PWM4, 0x7fff)
	}
	else{
		put_pwm(PWM4, 0x0)
	}

	if(PWM1_Output > 0){
		put_pwm(PWM5, 0x7fff)
	}
	else{
		put_pwm(PWM5, 0)
	}

;---------------- Display State Machine ----------------------

	Count_Low = Count_Low + 1
	if (Count_Low = 255){
		Count_High = Count_High + 1
		Count_Low = 0
	}

	if(DisplayState = 1) ;Motor Temperature display
	{

		temp = Motor_Temperature/10
		Put_Spy_Message("MT:", temp, "C", PSM_Decimal)

		if (Count_High = 20){
			DisplayState = 2
			Count_High = 0
		}
	}
	else if (DisplayState = 2)
	{
		;temp = Controller_Temperature/10
		Put_Spy_Message("BT:", BMS_temp, "C", PSM_Hex)

		if (Count_High = 20){
			DisplayState = 1
			Count_High = 0
		}
	}

	if((SOC >= 40)) ;0 to 60 even intervals from 60 to 100 degrees Celsius
	{
		Put_Spy_LED(8223)
	}
	else if((SOC >= 30) & (SOC < 40))
	{
		Put_Spy_LED(8207)
	}
	else if((SOC >= 20) & (SOC < 30))
	{
		Put_Spy_LED(8199)
	}
	else if((SOC >= 10) & (SOC < 20))
	{
		Put_Spy_LED(8195)
	}
	else if((SOC >= 0) & (SOC < 10))
	{
		Put_Spy_LED(8193)
	}
	;else{
	;	Put_Spy_LED(8192)
	;}

;---------------- Interlock State Machine --------------------

	if(state = 0)		; Interlock OFF
	{
		Clear_interlock()
		put_pwm(PWM2,0)

		if(SetInterlock > 0)	; if interlock request observed, go to interlock state
		{
			state = 1
		}

	}
	else if(state = 1)	; Interlock ON, requested by CAN message
	{
		put_pwm(PWM2,32767)
		Set_interlock()

		if(((throttle_high*255 + throttle_low) < 0) or ((throttle_high*255 + throttle_low) > 32767)) ; if throttle signal out of bounds, reset it to zero
		{
			VCL_Throttle = 0
		}
    	else
		{
			VCL_Throttle = (throttle_high*255 + throttle_low)
	  	}

		if(SetInterlock = 0)	; if interlock request is not observed, go back to pre-interlock state
		{
			state = 0
		}

		if(Status3 > 0)
		{
			state = 2
		}
	}
	else if(state = 2)	; Trap state. No exit conditions. DO NOT TOUCH!!!!!!!
	{
		Clear_interlock()
		put_pwm(PWM2, 0)
	}

goto Mainloop
