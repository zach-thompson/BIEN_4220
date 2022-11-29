;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430f2012.h"       ; Include device header file
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory.
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.

; Definitions
LED			.equ	BIT0	; P1.0
Input1		.equ	BIT1	; P1.1
Input2		.equ	BIT2	; P1.2


;-------------------------------------------------------------------------------
RESET:      mov.w   #__STACK_END,SP         	; Initialize stackpointer
StopWDT:    mov.w   #WDTPW|WDTHOLD,&WDTCTL  	; Stop watchdog timer

SetupP1:	bis.b	#LED, &P1DIR				; LED as output
			bic.b	#Input1+Input2, &P1DIR		; Inputs pins as inputs
			bic.b	#LED+Input1+Input2, &P1SEL	; Clear the secondary functionality
			bic.b	#LED, &P1OUT				; Turn off the LED

SetupP1Int: bis.b	#Input1+Input2, &P1IE		; Enable the interrupts for these input pins
			bic.b	#Input1+Input2, &P1IES		; Have the interrupt fire when the pin goes from low to high
			bic.b	#Input1+Input2, &P1IFG		; Clear any residual interrupt flags

			bis.b	#GIE,SR						; Enable Global Interrupts
			jmp		Main

;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------
Main:
			nop									; Do nothing - otherwise insert state machine here
			jmp		Main

;-------------------------------------------------------------------------------
; ISRs Here
;-------------------------------------------------------------------------------
P1ISR:		; P1ISR fires if ANY of the interrupt-enabled input pins changed state as described in P1IES
			; First we need to determine which pin triggered the interrupt
			; We can check this by bit testing the P1IFG register.
			bit.b	#Input1, &P1IFG				; Bit test if the first input was the cause of the interrupt
			jeq		In2ISR						; Jump if Input1 bit was NOT set
			; We can only get here if we did not jump (else it must be Input1)
In1ISR:
			bis.b	#LED, &P1OUT				; Turn the LED on
			bic.b	#Input1, &P1IFG				; We are done processing the interrupt, clear the flag
			reti								; Return from the interrupt
In2ISR:
			bic.b	#LED, &P1OUT				; Turn the LED off
			bic.b	#Input2, &P1IFG				; We are done processing the interrupt, clear the flag
			reti								; Return from the interrupt

;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack
            
;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET
            .sect	".int02"				; Port 1 interrupt vector
            .short	P1ISR
            
