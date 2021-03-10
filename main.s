 ;****************** main.s ***************
; Program written by: Valvano, solution
; Date Created: 2/4/2017
; Last Modified: 1/17/2021
; Brief description of the program
;   The LED toggles at 2 Hz and a varying duty-cycle
; Hardware connections (External: One button and one LED)
;  PE1 is Button input  (1 means pressed, 0 means not pressed)
;  PE2 is LED output (1 activates external LED on protoboard)
;  PF4 is builtin button SW1 on Launchpad (Internal) 
;        Negative Logic (0 means pressed, 1 means not pressed)
; Overall functionality of this system is to operate like this
;   1) Make PE2 an output and make PE1 and PF4 inputs.
;   2) The system starts with the the LED toggling at 2Hz,
;      which is 2 times per second with a duty-cycle of 30%.
;      Therefore, the LED is ON for 150ms and off for 350 ms.
;   3) When the button (PE1) is pressed-and-released increase
;      the duty cycle by 20% (modulo 100%). Therefore for each
;      press-and-release the duty cycle changes from 30% to 70% to 70%
;      to 90% to 10% to 30% so on
;   4) Implement a "breathing LED" when SW1 (PF4) on the Launchpad is pressed:
;      a) Be creative and play around with what "breathing" means.
;         An example of "breathing" is most computers power LED in sleep mode
;         (e.g., https://www.youtube.com/watch?v=ZT6siXyIjvQ).
;      b) When (PF4) is released while in breathing mode, resume blinking at 2Hz.
;         The duty cycle can either match the most recent duty-
;         cycle or reset to 30%.
;      TIP: debugging the breathing LED algorithm using the real board.
; PortE device registers
GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C
; PortF device registers
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_PUR_R   EQU 0x40025510
GPIO_PORTF_DEN_R   EQU 0x4002551C
GPIO_PORTF_LOCK_R  EQU 0x40025520
GPIO_PORTF_CR_R    EQU 0x40025524
GPIO_LOCK_KEY      EQU 0x4C4F434B  ; Unlocks the GPIO_CR register
SYSCTL_RCGCGPIO_R  EQU 0x400FE608

       IMPORT  TExaS_Init
       THUMB
       AREA    DATA, ALIGN=2
;global variables go here


       AREA    |.text|, CODE, READONLY, ALIGN=2
       THUMB

       EXPORT  Start

;PE1   			   EQU 0x40024010 ; positive-logic button input 
;PE2           	   EQU 0x40024020 ; positive-logic LED output
PF4		   		   EQU 0x40025040 ; negative-logic button input (on launchboard)


Start
 ; TExaS_Init sets bus clock at 80 MHz
     BL  TExaS_Init
; voltmeter, scope on PD3
 ; Initialization goes here
     LDR R0, =SYSCTL_RCGCGPIO_R ; activate the clock for port D
	 LDRB R1, [R0]
	 ORR R1, #0x30 ; set bit 7 to turn on the clock
	 STRB R1, [R0]
	 NOP
	 NOP
	 
	 LDR R0, =GPIO_PORTF_LOCK_R ;unlock the lock register
	 LDR R1, =GPIO_LOCK_KEY
	 STR R1, [R0]
	 LDR R0, =GPIO_PORTF_CR_R ;
	 LDR R1, [R0]
	 ORR R1, #0xFF 
	 STR R1, [R0]
	 
	 LDR R0, =GPIO_PORTF_DIR_R ; set direction register
	 LDR R1, [R0]
	 AND R1, #0xFF ; PF0-PF7 outputs
	 STR R1, [R0]
	 
	 LDR R0, =GPIO_PORTF_DEN_R ; enable port F digital port
	 LDR R1, [R0]
	 ORR R1, #0x10 ; digital enable PF1,PF3
	 STR R1, [R0]
	 
	 LDR R0, =GPIO_PORTF_PUR_R ; pull-up resistors for PE4
	 LDR R1, [R0]
	 ORR R1, #0x10 ;
	 STR R1, [R0]
	 
	 LDR R0, =GPIO_PORTE_DIR_R ; ret direction of registers
	 LDR R1, [R0]
	 AND R1, #0xFD
	 ORR R1, #0x04
	 STR R1, [R0]
	 
	 LDR R0, =GPIO_PORTE_DEN_R ; enable port E digital port
	 LDR R1, [R0]
	 ORR R1, #0x06
	 STR R1, [R0]   

     CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
	  ; load address for PE2 into R2(OUTPUT) PF2
	  LDR R2,=GPIO_PORTE_DATA_R
	  ; load address for PE3 into R3(INPUT) FOR PF1
	  LDR R3,=GPIO_PORTE_DATA_R
	  ; load address for PF4 into R4
	  LDR R4,=PF4
	  ; move 0 into R8 to start program with button unpressed
	  MOV R8,#0
	  ; move 30 into R10 to store duty cycle percentage, initialy 2hz 30%
	  MOV R10,#300
	  MOV R11,#1100

loop_1 
; main engine
; check for PF4 button press
     LDR R12,[R4]
	 CMP R12,#0x10
	 BNE PF4_press
; check for PE1 button press
     LDR R12,[R3]
	 BIC R12,R12,#0x02
	 CMP R12,#0
	 BEQ loop_11
	 B   loop_12
loop_11
	 CMP R8,#4
	 BEQ PE1_release
loop_12
     ; save button state into R8
	 MOV R8, R12
	 ; set PE3 high
	 MOV R0,#8
	 STR R0,[R3] ;ADRESS OF INPUT     
	 ; delay for 150ms
	 MOV R5,R10
	 BL delay
loop_2
	 ; clear PE3 low
	 MOV R0,#0
	 STR R0,[R1]
	 ; delay for 350ms
	 MOV R0,#1000
	 SUB R5,R0,R10
	 BL delay
	 B  loop_1

delay
; delay for 0.5ms
     MOV R6,#9999
delay_loop
     SUBS R6,R6,#1
     BNE delay_loop
	 SUBS R5,R5,#1
	 BNE delay
	 BX LR

PE1_release
; increase the duty cycle by 20% 
; (if duty cycle = 110, set back to 10)
	 ADD R10,R10,#200
	 CMP R10,R11
	 BEQ reset_duty_cycle
	 B   loop_12
	 
reset_duty_cycle
; reset duty cycle back to 10%
	 MOV R10,#100
	 B   loop_12
	 
PF4_press
; initiate LED breathing
    ; store value in R10 in R9
	MOV R9,R10
	
LED_breathing
    ; recheck if PF4 is pressed
	LDR R12,[R4]
	CMP R12,#0x10
	BEQ PF4_release
	; store 2 in R5
	MOV R10,#0
	B   increase_brightness_loop
	
increase_brightness_loop
    ; set PE3 high
	MOV R0,#8
	STR R0,[R3]
	; increment duty cycle
	ADD R10,R10,#1
	CMP R10,#20
	BEQ decrease_brightness_loop
	MOV R5,R10
    ; delay
	BL  delay
	; set PE3 low
	MOV R0,#0
	STR R0,[R3]
	; dealy
	MOV R0,#20
	SUB R5,R0,R10
	BL  delay
	B   increase_brightness_loop
	
decrease_brightness_loop
	; set PE1 high
	MOV R0,#8
	STR R0,[R3]
	; decrement duty cycle
	SUB R10,R10,#1
	CMP R10,#0
	BEQ LED_breathing
	MOV R5,R10
    ; delay
	BL  delay
	; set PE1 low
	MOV R0,#0
	STR R0,[R3]
	; delay
	MOV R0,#20
	SUB R5,R0,R10
	BL  delay
	B   decrease_brightness_loop

PF4_release
; return to normal function
	; return value from R7 into R5
    MOV R10,R9
	B   loop_1

    ALIGN      ; make sure the end of this section is aligned
    
	END        ; end of file