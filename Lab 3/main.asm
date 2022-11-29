;-------------------------------------------------------------------------------
;	Lab 3 Part 2
;	@author Caleb Celano
;	program to drive motor with PWM and button to change speed
;	BIEN 4220 Embedded Biomedical Instruments
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; include device header file

;-------------------------------------------------------------------------------
            .def    RESET                   ; export program entry-point to
                                            ; make it known to linker.

            .global _initialize             ; export initialize as global symbol
;-------------------------------------------------------------------------------
            .text                           ; assemble into program memory.
			.retain                         ; override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; and retain any sections that have
                                            ; references to current section.

;*******************************************************************************
; Equates
;*******************************************************************************
maxMotorStates 	.equ 4 						; number of motor states

BTTNMASK1 		.equ 01000000b 				; P2.6 for button input
Motor 			.equ 00000100b 				; P1.2 for control output

motor_Not	.equ	0028Fh					; 1% power
motor_Low	.equ	03FFFh					; 25% power
motor_Med	.equ	07FFFh					; 50% power
motor_High	.equ	0BFFFh					; 75% power

;*******************************************************************************
; Assign variables to hardware multipurpose REGISTERs
;*******************************************************************************
state 			.equ R4 					; motor state variable
motorStates 	.equ R7 					; current motor state

;*******************************************************************************
; Initialization
;*******************************************************************************
RESET   	 mov.w   #__STACK_END,SP        ; initialize stackpointer
StopWDT:     mov.w   #WDTPW|WDTHOLD,&WDTCTL ; stop watchdog timer
SetupP1:     bis.b   #Motor,&P1DIR          ; P1.1 output
			 bis.b   #Motor,&P1SEL 	    	; P1.2 output timer A1


SetBttn:
	bic.b #BTTNMASK1, &P2DIR   				; P2.6 input
	bis.b #BTTNMASK1, &P2OUT 				; pull_up
	bis.b #BTTNMASK1, &P2REN 				; enabled
	bic.b #BTTNMASK1, &P2SEL 				; normal GPIO mode

	bis.b #BTTNMASK1, &P2IES 				; high_to_low
	bis.b #BTTNMASK1, &P2IE 				; interupt enabled
	bic.b #BTTNMASK1, &P2IFG 				; clear flags

SetupTA2:
	mov.w #OUTMOD_7, &CCTL1 				; CCR1 toggle, interrupt not enabled
	mov.w #TASSEL_2+MC_1, &TACTL 			; set clock: SMCLK, up_mode, interrupt

SetupPWM:
	mov.w #0FFFFh, &TACCR0 					; PWM period
	mov.w #0028Fh, &TACCR1 					; set initial motor_Not value

SetupMotor:
	clr.w MotorStates 						; MotorStates all off
	mov.w MotorStates, &P1OUT 				;

SetupCount:
	clr.w State 							; clear State
	clr.w MotorStates 						; clear motor table

SetupState:
	mov.w #Motor_Table, MotorStates 		; load default Motor values

SetupGIE:
	bis.w #GIE, SR 							; interrupts enabled

;*******************************************************************************
; Main loop here
;*******************************************************************************
loop:										; run until interrupted
	nop
	jmp loop

port2ISR:									; interrupt

next_state:
	inc State 								; go to next state
	cmp #maxMotorStates, State 				; compare to max state value
	jl skip_state_reset                     ; else
	clr.w State 							; reset states

skip_state_reset:
	mov.w Motor_Table(State), MotorStates 	; load next state
	mov.w MotorStates, &TACCR1 				; adjust PWM
	bic.b #BTTNMASK1, &P2IFG 				; clear flag
	reti 									; return to loop

;*******************************************************************************
; Stack Pointer definition
;*******************************************************************************
            .global __STACK_END
            .sect   .stack

;*******************************************************************************
; Constants - Tables of values used by state machine.
;*******************************************************************************

; Motor speed table
Motor_Table:
	.word motor_Not				; 1% power
	.word motor_Low				; 25% power
	.word motor_Med				; 50% power
	.word motor_High			; 75% power

;*******************************************************************************
; Interrupt Vectors
;*******************************************************************************
    .sect   ".reset"                		; MSP430 RESET Vector
    .short  RESET

    .sect ".int03" 							; 2.6 header file vector
	.short port2ISR 						; ISR name
