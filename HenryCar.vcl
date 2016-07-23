; PARAMETER_ENTRY "Program"
;		TYPE		PROGRAM
;		Level		0
;	END
; PARAMETER_ENTRY "BMS Data"
;		TYPE		Monitor
;		Level		1
;	END
; parameter_entry "State^of^Charge"
; 	type Monitor
; 	width 16bit
; 	address user7
; 	units %
; end
; parameter_entry "Cell^balance^delta"
; 	type Monitor
; 	width 16bit
; 	address user8
; 	units mV
; end
; parameter_entry "Battery^Pack^Temperature"
; 	type Monitor
; 	width 16bit
; 	address user9
;	units oC
; end
; parameter_entry "Battery^Current"
; 	type Monitor
; 	width 16bit
; 	address user10
;	signed YES
;	units amp
; end

;---------------- INPUTS -----------------------------
	;Free							alias Sw_1		;Pin J1-24
	;Interlock_sw					alias Sw_3		;Pin J1-09
	StartSwitch						alias Sw_4		;Pin J1-10
	;Free							alias Sw_5		;Pin J1-11
	NeutralSwitch					alias Sw_6		;Pin J1-12
	;free							alias Sw_7		;Pin J1-22 
	;Free							alias Sw_8		;Pin J1-33
	;Free							alias Sw_14		;Pin J1-19
	;Free							alias Sw_15		;Pin J1-20
	;Free							alias Sw_16		;Pin J1-14
	
;---------------- CAN Variables -----------------------------	
pdoSend equals can1
packStatus equals can2
packActiveData equals can3
BMSNode equals user1
BMSControlLow equals user_bit1
    BMSCloseFet 			bit BMSControlLow.1
    BMSOpenFet 				bit BMSControlLow.2
    BMSCloseContactor 		bit BMSControlLow.4
    BMSOpenContactor 		bit BMSControlLow.8
    BMSDisconnectModule 	bit BMSControlLow.16
    BMSConnectModule 		bit BMSControlLow.32
    BMSKeyOn 				bit BMSControlLow.64
    BMSChargerConnected 	bit BMSControlLow.128
BMSControlHigh equals user_bit2 
    BMSChargingEnabled 		bit BMSControlHigh.1
    BMSInhibitIsolationTest bit BMSControlHigh.2
    BMSNoSafetyOverride 	bit BMSControlHigh.64
    BMSSafetyOverride 		bit BMSControlHigh.128
BMSNumberNodes equals user3
BMSModelYear equals user4
SOCpercent equals user7
BalanceDelta equals user8
HighestPackTemp equals user9
DischargeAmps equals user10

;----------- State Machine Variables etc ----------------------------
DriveState equals user5
NeutralState equals user6
DisplayState equals user11
temp equals user12
LastDriveState equals user13
;xxx equals user14
TachDataState equals user15
StartupPulse equals user16
LastStartswitchStates equals user_bit3
    LastStartswitchState bit LastStartswitchStates.1

;----------- Initialize BMS state variables -------------------
BMSNoSafetyOverride = ON
BMSConnectModule = OFF
BMSDisconnectModule = ON
BMSOpenContactor = ON
BMSOpenFet = ON
BMSCloseFet = OFF
BMSCloseContactor = OFF
BMSKeyOn = ON
BMSNode = 8
BMSNumberNodes = 1
BMSModelYear = 14
DisplayState = 1

;----------- Initialize other variables ------------------------
VCL_App_Ver = 100
DriveState = 1
NeutralState = 1
TachDataState = 2
StartupPulse = 3000 ; How many RPM should tach show during startup pulse


;----------- Tach output variables, automates ----------------
;
; Abs_motor_RPM -> 0| DATA |
;                   | SEL1 | -> 0| DATA |
; Current_RMS ---> 1|SWITCH|     | SEL2 | -> Automate_frequency_output
; CONSTANT 3000RPM -----------> 1|SWITCH| 
setup_select(SEL1, @Abs_motor_RPM, @Current_RMS)
setup_select(SEL2, @SEL1_output, @StartupPulse)
set_select(SEL1, 0)
set_select(SEL2, 0)

Frequency_output_duty_cycle = 16384
Automate_frequency_output(@SEL2_output, 0, 7000, 0, 175)

;------------ Setup mailboxes ----------------------------
disable_mailbox(pdoSend)
Shutdown_CAN_Cyclic()

Setup_Mailbox(pdoSend, 0, 0, 0x506, C_CYCLIC, C_XMT, 0, 0)
Setup_Mailbox_Data(pdoSend,8,
					@BMSNode,	  		
                    @BMSControlLow,
					@BMSControlHigh,			 
					@BMSNumberNodes,	 
					@BMSModelYear,		  
					0,	 
					0,	   
					0)	

enable_mailbox(pdoSend)

Setup_Mailbox(packStatus, 0, 0, 0x188, C_EVENT, C_RCV, 0, 0)
Setup_Mailbox_Data(packStatus,8,
					@SOCpercent,
					0,
					0,
					0,
					0,
					0,
					@BalanceDelta,
					0)
					
Setup_Mailbox(packActiveData, 0, 0, 0x408, C_EVENT, C_RCV, 0, 0)
Setup_Mailbox_Data(packActiveData, 8,
					0,
					@HighestPackTemp,
					0,
					@DischargeAmps,
					@DischargeAmps+USEHB,
					0,
					0,
					0)

Startup_CAN()
CAN_Set_Cyclic_Rate( 30 );actually 120ms 		
Setup_NMT_State(ENTER_OPERATIONAL)			;Set NMT state so we can detect global NMT commands
Startup_CAN_Cyclic()

setup_delay(dly1,200)
while (dly1_output <> 0)
{
}
BMSNoSafetyOverride = ON
BMSConnectModule = ON
BMSDisconnectModule = OFF
BMSOpenContactor = OFF
BMSOpenFet = OFF
BMSCloseFet = ON
BMSCloseContactor = ON
BMSKeyOn = ON



main:
;---------------- Spyglass state machine -------------------------
	if(DLY3_Output = 0)
	{
		if(DisplayState = 1){
			Put_Spy_Message("SOC", SOCpercent, "%", PSM_Decimal)
		}
		if(DisplayState = 2){
			temp = Motor_Temperature/10
			Put_Spy_Message("Tm", temp, "C", PSM_Decimal)
		}
		if(DisplayState = 3){
			temp = Controller_Temperature/10
			Put_Spy_Message("Tc", temp, "C", PSM_Decimal)
		}
		if(DisplayState = 4){
			Put_Spy_Message("Tb", HighestPackTemp, "C", PSM_Decimal)
		}
		
		if(SOCpercent>=90){
			Put_Spy_LED(8223)
		}
		else if((SOCpercent>=70) & (SOCpercent<90)){
			Put_Spy_LED(8207)
		}
		else if((SOCpercent>=50) & (SOCpercent<70)){
			Put_Spy_LED(8199)
		}
		else if((SOCpercent>=30) & (SOCpercent<50)){
			Put_Spy_LED(8195)
		}
		else if((SOCpercent>=10) & (SOCpercent<30)){
			Put_Spy_LED(8193)
		}
		else{
		Put_Spy_LED(8192)
		}
		DisplayState = DisplayState + 1
		if(DisplayState > 4)
		{
			DisplayState = 1
		}
		Setup_Delay(DLY3, 1500)
	}

;-------------- Interlock latching state machine -----------
	if(DriveState = 1){
		Clear_interlock()
		if(StartSwitch = ON)
		{
			DriveState = 2
		}
	}
	else if(DriveState = 2){
		Set_interlock()
	}
	else{
		Clear_interlock()
	}
;------------------Tach Data Select --------------------------
	if(TachDataState = 1){ ;Display RPM
		set_select(SEL1, 0)
		if((StartSwitch = ON) & (LastStartswitchState = OFF)){
			TachDataState = 2
		}
	}
	else if(TachDataState = 2){ ;Display Amps*10
		set_select(SEL1, 1)
		if((StartSwitch = ON) & (LastStartswitchState = OFF)){
			TachDataState = 1
		}
	}
	LastStartswitchState = StartSwitch
	
;--------------- Tach pulse on startup for EPS ------------------
	if((LastDriveState = 1)&(DriveState = 2)){
		setup_delay(DLY2, 1000)
	}
	if(DLY2_Output <> 0){
		set_select(SEL2,1)
	}
	else{
		set_select(SEL2, 0)
	}
	LastDriveState = DriveState

;-------------- Neutral braking disable state machine -----------
	if(NeutralState = 1)
	{
		;turn neutral braking on
		Neutral_Braking_TrqM = 6550 ;20 percent
		if(NeutralSwitch = ON)
		{
			NeutralState = 2
		}
	}
	else if(NeutralState = 2)
	{
		;turn neutral braking off
		Neutral_Braking_TrqM = 0
		if((NeutralSwitch = OFF) and (Mapped_Throttle > 3277)) ; out of neutral and >10% throttle
		{
			NeutralState = 1
		}
	}
	else
	{
		Neutral_Braking_TrqM = 0
	}


goto main
