;*******************************************************************************
; stop_light.asm
;
; This code implements:
;  A stoplight state machine coordinating two stoplights at an intersection.
;   There is also a pushbutton input that signals an error event to force the
;   state machine into an alternate (blinking red) condition. The state machine
;   receives TimerTicks from the on-chip Timer A which is serviced by an interrupt
;	service routine. The state machine also receives "button press" events
;	initiating an exception condition that times out after a set amount of time.
;
;   10/04/2001 RA Scheidt - Initial logic for 68HC912B32 EVB, E = 8 MHz
;	02/07/2011 EA Bock - port code to MSP430
;   02/09/2011 DJ Herzfeld - Interrupt modifications
;   01/12/2012 RA Scheidt - Comment clarifications; Code streamlining
;

				.cdecls C,LIST,  "msp430f2012.h"

				.def    RESET                   ; Export program entry-point to
												; make it known to linker.

				.global _initialize            ; export initialize as a global symbol

                .text
;*******************************************************************************
; Equates
;*******************************************************************************
maxValidStates	.equ	6				; Max number of light patterns
maxErrStates	.equ	2				; Max number of error light patterns

ErrorDuration	.equ	230				; fifteen seconds of blinky upon error

; Pin Masks
DEBUG			.equ	00000000b		; User must define this (2.6/2.7) - may require modifying code **********************
LeftR			.equ	00100000b		; P1.5
LeftY			.equ	00010000b		; P1.4
LeftG			.equ	00001000b		; P1.3
RightR			.equ	00000100b		; P1.2
RightY			.equ	00000010b		; P1.1
RightG			.equ	00000001b		; P1.0
BTTNMASK		.equ 	10000000b		; P1.7 for button input
AllLEDs			.equ	LeftR+LeftY+LeftG+RightR+RightY+RightG

maxTAcount      .equ    50000			; Max count for the timer to fire a timer tick

;*******************************************************************************
; Assign variables to hardware multipurpose REGISTERs
;*******************************************************************************
State			.equ	R4		; stop light state variable
Tick			.equ	R5		; tick event flag
StateTmr		.equ	R6		; time to spend in a given state
LedStates		.equ	R7		; placeholder for current LED states
ButtnFlag		.equ	R8		; is the button pressed?
ErrTimer		.equ	R9		; are we in an error condition?
ButtnOn			.equ	R10		; was the button pressed already?

; Code entry point
RESET:
				mov.w   #0280h,SP               ; Initialize stackpointer
				call	#_initialize			; Initialize port, timer interrupt, LED states, GIE
				jmp		loop

;*******************************************************************************
; Initialize Subroutine
;*******************************************************************************
_initialize:
				mov.w   #WDTPW+WDTHOLD, &WDTCTL ; Stop WDT
SetupP2:		bic.b	#DEBUG,&P2SEL			; Set P2 as debug pin
				bis.b	#DEBUG,&P2OUT

; Setup State Machine Timer
SetupC0:    	mov.w   #CCIE, &CCTL0           ; CCR0 interrupt enabled
				mov.w   #maxTAcount, &CCR0      ; Load the max value for the timer to count to
SetupTA:    	mov.w   #TASSEL_2+MC_1, &TACTL  ; Use the SMCLK, timer in 'upmode'
; Setup LEDs
SetupLEDS:		clr.b	LedStates				; default LedStates all off
				mov.b   #AllLEDs, &P1DIR      	; P1.0-P1.5 as outputs; P1.7 (Button) as input
				mov.b	LedStates, &P1OUT		; Move the LED states to the digital port
; Clear general registers
SetupCount:		clr.w	State					; clear State counter
				clr.w 	Tick					; clear Tick counter
				clr.w	StateTmr				; clear State timer
				clr.w 	ButtnFlag				; clear Button pressed flag
				clr.w 	ErrTimer				; start off in a non-error condition
				clr.w	ButtnOn					; clear Button flag
; Initialize user state timer and LED output
SetupState:		mov.b	#Timer_Table, StateTmr	; load default state timer value
				mov.b	#Led_Table, LedStates	; load default LED values

SetupGIE:		bis.w   #GIE, SR                ; interrupts enabled
				ret								; Return from the subroutine

;*******************************************************************************
; main loop - the main loop performs the background task. The background task
;             manages the state machine and polls the push button.
;*******************************************************************************
; Main Loop
loop:
				mov.b	LedStates, &P1OUT		; write LED states to port
				cmp.b	#0,Tick					; is Tick 0
				jne		do_fsm					; if Tick not eq. 0, then process tick in state_machine
				nop								; if not, goto loop (nop = no operation)
				bit		#BTTNMASK, &P1IN 		; test for button press
				jnz		do_button				; jump to button handling
				jmp		endmain					; goto the end of the background task loop if no tick.

; Do State Machine Branch
do_fsm:											; a tick has occurred
				bis		#DEBUG, &P1OUT			; Set DEBUG pin high to see how much time we are
												; spending in Tick handler
				dec		Tick					; remove the event from the flag byte
				cmp.b	#001h, ButtnFlag		; has the button been pressed recently?
				jeq		error_operation			; if so, branch to error condition handler
				jmp		normal_operation		; if not, branch to normal _operation handler

; Do Button Branch
do_button:
				cmp.b   #001h, ButtFlag			; check if button was set
				jeq		endtick     			; jump to reset
				mov.b	#0x01, ButtnFlag		; signal a button press
				mov.b	#ErrorDuration, ErrTimer ; reset error timer
				mov.b	#001h, StateTmr			; truncate current state on button press
				jmp		endtick					; exit the Tick handler

; Error Operation Branch
error_operation:
				dec		ErrTimer				; has the error condition timered out?
				jz		exit_err_state			; if so, restore default conditions to state machine
				dec		StateTmr				; if not, stay in error state
				jz		next_err_state			; if current StateTmr expired, goto next state
				jmp		endtick					; or else exit Tick handler
next_err_state:
				inc		State					; go on to next state but limit it to the max number of valid stated
				cmp.b	#maxErrStates, State	; has the max number of states been reached?				;
				jl		skip_err_state_reset	;
				clr.w	State
skip_err_state_reset:
				mov.b	Err_Timer_Table(State), StateTmr	; load new timer value into StateTmr
				mov.b	Err_Led_Table(State), LedStates		; load new Led value into LedStates
end_next_err_state:
				jmp		endtick					; or else exit Tick handler
exit_err_state:
				bic.b	#0x01, ButtnFlag		; clear button press signal
				mov.b	Timer_Table, StateTmr	; load default state timer value into StateTmr
				mov.b	Led_Table, LedStates	; load default LED values
				clr.w	State					; clear State counter; set default state to stateRG
				jmp		endtick					; exit the Tick handler

; Normal Operation Branch
normal_operation:
				dec		StateTmr				;
				jz		next_state				; if StateTmr expired, goto next state
				jmp		endtick					; or else exit the Tick handler

next_state:
				inc		State					; Go on to next state but limit it to the max number of valid stated
				cmp		#maxValidStates, State	; Has the max number of states been reached?
				jl		skip_state_reset		; if not, skip ahead
				clr.w	State					; go back to the initial state (state 0).

skip_state_reset:
				mov.b	Timer_Table(State), StateTmr	; load new timer value into StateTmr
				mov.b	Led_Table(State), LedStates		; load new Led value into LedStates

end_next_state:
				jmp		endtick					; exit the Tick handler

; Exit branch code, resume main loop
endtick:
				bic		#DEBUG, &P1OUT			; Set DEBUG pin low
endmain:
				jmp		loop					; go back to the top of the background task


;*******************************************************************************
TA0_ISR: ;    increment tick value (R5)
;*******************************************************************************
				inc		Tick			; check things, ADC (PERIODIC CODE)
				reti					; Return from interrupt

;*******************************************************************************
; Constants - Tables of values used by state machine.
;*******************************************************************************
; Timer Table - number of ticks for each light pattern
Timer_Table:
sRGtime			.byte	 31				; about 2 seconds
sRYtime			.byte	 31				; about 2 seconds
sRR1time		.byte	 31				; about 2 seconds
sGRtime			.byte	 31
sYRtime			.byte	 31
sRR2time		.byte	 31
; Error Table - number of ticks for each error pattern
Err_Timer_Table:
 				.byte	7				; about 1/2 second
 				.byte	7				; about 1/2 second
; LED Table - each LED pattern
Led_Table:
 				.byte	LeftR+RightG	; 00100001b		; Left R & Right G
 				.byte	LeftR+RightY	; 00100010b		; Left R & Right Y
 				.byte	LeftR+RightR	; 00100100b		; Left R & Right R
 				.byte	LeftG+RightR	; 00001100b		; Left G & Right R
 				.byte	LeftY+RightR	; 00010100b		; Left Y & Right R
 				.byte	LeftR+RightR	; 00100100b		; Left R & Right R
; Error LED Table - each error LED pattern
Err_Led_Table:
				.byte	LeftR+RightR	; Left R & Right R
 				.byte	00000000b		; Left Off & Right Off

;*******************************************************************************
; Interrupt Vectors
;*******************************************************************************
				.sect   ".reset"                ; MSP430 RESET Vector
				.short  RESET                   ;

				.sect   ".int09"				; MSP430 TimerA0 Vector
				.short  TA0_ISR
				.end
