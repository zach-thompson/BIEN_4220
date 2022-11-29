
				.cdecls C,LIST,  "msp430f2013.h"

				.def    RESET                   ; Export program entry-point to
												; make it known to linker.

				.global _initialize            ; export initialize as a global symbol

                .text

;*******************************************************************************
; Equates
;*******************************************************************************

maxValidStates	.equ	7				; Max number of phase states

; Pin Masks
DEBUG			.equ	10000000b		; P2.7
A_PIN			.equ	00001000b		; P1.3
B_PIN			.equ	00000100b		; P1.2
C_PIN			.equ	00000010b		; P1.1
D_PIN			.equ	00000001b		; P1.0
BTTNMASK1		.equ 	01000000b		; P2.6 for button input

maxTAcount      .equ    50000			; Max count

;*******************************************************************************
; Assign variables to hardware multipurpose REGISTERs
;*******************************************************************************

State			.equ	R4				; stop light state variable
PINStates		.equ	R7				; placeholder for current PIN states
ButtnFlag		.equ	R8				; button flag


; Code entry point
RESET:
				mov.w   #0280h,SP       ; Initialize stackpointer
				call	#_initialize	; Initialize port, timer interrupt, PIN states, GIE
				jmp		loop

;*******************************************************************************
; Initialize Subroutine
;*******************************************************************************

_initialize:
				mov.w   #WDTPW+WDTHOLD, &WDTCTL 		 ; Stop WDT

; Setup State Machine Timer
SetupC0:    	mov.w   #CCIE, &CCTL0           		 ; CCR0 interrupt enabled
				mov.w   #maxTAcount, &CCR0      		 ; Load the max value for the timer to count to
SetupTA:    	mov.w   #TASSEL_2+MC_1, &TACTL  		 ; Use the SMCLK, timer in 'upmode'
; Setup LEDs
SetupPINS:		clr.b	PINStates						 ; default PINStates all off
				mov.b   #A_PIN+B_PIN+C_PIN+D_PIN, &P1DIR ; P1.0-P1.3 as outputs;
				mov.b	PINStates, &P1OUT				 ; Move the PIN states to the digital port

; Setup Port 2
SetupBTTN:
				bic.b #BTTNMASK1, &P2DIR 				; Set P2.6 (Button) as input
				bis.b #BTTNMASK1, &P2OUT 				; set pin to pull up
				bis.b #BTTNMASK1, &P2REN 				; enable resistor system
				bic.b #BTTNMASK1, &P2SEL 				; normal GPIO mode for multiplexor pin

				bis.b #BTTNMASK1, &P2IES 				; set high to low transition
				bis.b #BTTNMASK1, &P2IE  				; enable interrupt on pin
				bic.b #BTTNMASK1, &P2IFG 				; clear if any flags raised by writing to P1OUT or P2DI

; Clear general registers
SetupCount:		clr.w	State							; clear State counter
				clr.w 	ButtnFlag						; clear Button pressed flag
; Initialize user state timer and LED output
SetupState:
				mov.b	#Phase_Table, PINStates			; load default PIN values

SetupGIE:		bis.w   #GIE, SR                		; interrupts enabled
				ret										; Return from the subroutine

;*******************************************************************************
; main loop				; runs until interrupt
;*******************************************************************************
loop:
				nop
				jmp		loop							; waiting for input

;*******************************************************************************
BTTN_ISR: ;    increment tick value (R5)
;*******************************************************************************
				xor.b	#BIT0, ButtnFlag
				bic.b	#BTTNMASK1, &P2IFG
				reti									; Return from interrupt

;*******************************************************************************
TA0_ISR: ;    increment tick value (R5)
;*******************************************************************************

; Do State Machine Branch
do_fsm:
				cmp.b	#001h, ButtnFlag				; check button press
				jeq		error_operation					; if so, branch to error condition handler
				jmp		normal_operation				; if not, branch to normal _operation handler

;-------------------------------------------------------------------------------
; Error Operation Branch
error_operation:
				dec		State							; go to next state down
				cmp.w	#0FFFFh, State					; check for overflow value
				jne		skip_err_state_reset			; jump if no overflow, else
				mov.b	#maxValidStates, State			; reset the state to top state

skip_err_state_reset:
				mov.b	Phase_Table(State), PINStates	; load new PIN value into PINStates
				mov.b	PINStates, &P1OUT				; write PIN states to digital port
				reti

;-------------------------------------------------------------------------------
; Normal Operation Branch
normal_operation:
				inc		State							; go to next state down
				cmp		#maxValidStates, State			; compare to max state value
				jl		skip_state_reset				; jump if less than max, else
				clr.w	State							; reset to initial state

skip_state_reset:
				mov.b	Phase_Table(State), PINStates	; load new PIN value
				mov.b	PINStates, &P1OUT				; write PIN states to port
				reti									; Return from interrupt

;*******************************************************************************
; Constants - Tables of values used by state machine.
;*******************************************************************************

; Phase Table - half step drive
Phase_Table:
 				.byte	00001001b				; state 0
 				.byte	00001000b				; state 1
 				.byte	00001100b				; state 2
 				.byte	00000100b				; state 3
 				.byte	00000110b				; state 4
 				.byte	00000010b				; state 5
 				.byte	00000011b				; state 6
 				.byte	00000001b				; state 7

;*******************************************************************************
; Interrupt Vectors
;*******************************************************************************

				.sect   ".reset"                ; MSP430 RESET Vector
				.short  RESET                   ;

				.sect	".int03"				; P2 interrupt
				.short  BTTN_ISR

				.sect   ".int09"				; MSP430 TimerA0 Vector
				.short  TA0_ISR
				.end
