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
maxStates	.equ	4
LED_PIN		.equ	BIT0					; P1.0 LED
TA0_PIN		.equ	BIT1					; P1.1
TA1_PIN		.equ	BIT2					; P1.2
BTTN_1		.equ	010000000b				; P2.6, button 1
BTTN_2		.equ	100000000b				; P2.7, button 2

State		.equ 	R4
speedState	.equ	R7

;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer

SetupP1
			bis.b	#TA0_PIN+TA1_PIN,&P1SEL				; P1.1 & P1.2 option, TAxfunction
			bis.b	#LED_PIN+TA0_PIN+TA1_PIN,&P1DIR		; P1.0-P1.2 outputs
			bis.b	#LED_PIN,&P1OUT						; toggle LED

SetupP2
			bic.b	#BTTN_1+BTTN_2,&P2DIR			; input pins
			bis.b	#BTTN_1+BTTN_2,&P2OUT
			bis.b	#BTTN_1+BTTN_2,&P2REN
			bic.b	#BTTN_1+BTTN_2,&P2SEL
			bis.b	#BTTN_1+BTTN_2,&P2IE			; enable interrupts
			bis.b	#BTTN_1+BTTN_2,&P2IES			; set low_to_high
			bic.b	#BTTN_1+BTTN_2,&P2IFG			; clear flags

SetupTA
			mov.w 	#OUTMOD_0,&CCTL0					; set T0 output, interrupt not enabled
			mov.w	#OUTMOD_0,&CCTL1					; set T1 output, interrupt not enabled
			bis.w	#OUT,&TACCTL0						; set T0 output pin
			bis.w	#OUT,&TACCTL1						; set T1 output pin
			mov.w	#OUTMOD_5,&CCTL0					; set T0 reset mode
			mov.w	#OUTMOD_5,&CCTL1					; set T1 reset mode
			mov.w	#TASSEL_2+MC_2+ID_0+TAIE,&TACTL		; set SMLCK to continuous, TAOF interrupt

SetupPWM
			mov.w	#40000,&CCR0							;set TA0 duty cycle
			mov.w	#20000,&CCR1							;set TA1 duty cycle

SetupState
			mov.w	#speedTable,speedState
			bis.w	#GIE,SR
			jmp		MainLoop
;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------
MainLoop:
			nop
			jmp		MainLoop

;-------------------------------------------------------------------------------
; TAX_ISR:	 Common ISR for CR1-4 and overflow
;-------------------------------------------------------------------------------
TAX_ISR:
			add.w	&TAIV,PC						; timer offset
			reti									; CCR0 - no source
			reti									; CCR1
			reti									; CCR2
			reti									; CCR3
			reti									; CCR4
			jmp		TAoverISR

TAoverISR:
			xor.b	#LED_PIN,&P1OUT					; toggle LED
			mov.w	#OUTMOD_0,&CCTL0				; CRR0 output mode (off)
			mov.w	#OUTMOD_0,&CCTL1				; CRR1 output mode (off)
			bis.w	#OUT,&TACCTL0					; set output pin
			bis.w	#OUT,&TACCTL1					; set output pin
			mov.w	#OUTMOD_5,&CCTL0				; set CCR0 reset mode
			mov.w	#OUTMOD_5,&CCTL1				; set CCR1 reset mode
			reti									; return

P2ISR:
			bit.b	#BTTN_2,&P2IFG					; check first flag
			jeq		In2ISR							; jump to In2 if not set

;-------------------------------------------------------------------------------
In1ISR:												; first button interrupt

nextState:
			incd	State							; next state
			cmp		#maxStates,State				; compare to max states
			jl		skipStateReset					; jump if not, else
			clr.w	State							; clear

skipStateReset:
			mov.w	speedTable(State),speedState 	; load next state
			mov.w	speedState,&CCR0				; output state value to p1.1
			bic.b	#BTTN_1,&P2IFG					; clear flag
			reti									; return

;-------------------------------------------------------------------------------
In2ISR:												; second button interrupt

nextState2:
			incd	State							; next state
			cmp		#maxStates,State				; compare to max states
			jl		skipStateReset2					; jump if not, else
			clr.w	State							; clear

skipStateReset2:
			mov.w	speedTable(State),speedState 	; load next state
			mov.w	speedState,&CCR1				; output state value to p1.2
			bic.b	#BTTN_2,&P2IFG					; clear flag
			reti									; return

;-------------------------------------------------------------------------------
; Speed table
;-------------------------------------------------------------------------------
speedTable:
			.word	1000							; low range value
			.word 	1333
			.word	1666
			.word	2000							; high range value
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

            .sect	".int08"				; timer interrupt
            .short	TAX_ISR

            .sect	".int03"				; port 2 interrupt
            .short	P2ISR
