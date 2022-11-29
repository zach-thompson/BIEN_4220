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

LED_PIN		.equ	BIT0					; P1.0 LED
TA0_PIN		.equ	BIT1					; P1.1
TA1_PIN		.equ	BIT2					; P1.2

;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer

SetupP1   	bis.b  	#TA0_PIN+TA1_PIN, &P1SEL ; P1.1 and P1.2 option select for TA function
            bis.b  	#LED_PIN+TA0_PIN+TA1_PIN, &P1DIR            ; P1.0-P1.2 are outputs
			bis.b	#LED_PIN, &P1OUT		; LED starts off

SetupTA     mov.w   #OUTMOD_0, &CCTL0 	    ; CCR0 OUTPUT mode, interrupt NOT enabled
	   		mov.w   #OUTMOD_0, &CCTL1 	    ; CCR1 OUTPUT mode, interrupt NOT enabled
          	bis.w  	#OUT, &TACCTL0         	; Manually set the TA0 output pin
         	bis.w  	#OUT, &TACCTL1         	; Manually set the TA1 output pin
          	mov.w   #OUTMOD_5, &CCTL0 	    ; CCR0 RESET mode
           	mov.w   #OUTMOD_5, &CCTL1 	    ; CCR1 RESET mode
           	mov.w   #TASSEL_2+MC_2+ID_3+TAIE, &TACTL   ; SMCLK, continuous mode, clock divider of 8, TAOF software interrupt enabled

SetupPWM  	mov.w	#40000, &CCR0			; set up the TA0 duty cycle
	  		mov.w	#20000, &CCR1			; set up the TA1 duty cycle

			bis.w	#GIE, SR

			jmp		MainLoop

;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------
MainLoop:
			nop
            jmp		MainLoop

;-------------------------------------------------------------------------------
TAX_ISR:;    Common ISR for CCR1-4 and overflow
;-------------------------------------------------------------------------------
            add.w   &TAIV,PC                ; Add Timer_A offset vector
            reti                            ; CCR0 - no source
            reti     		                ; CCR1 - CCR1 (would put a jmp here if you wanted to use CCR1 ISR)
            reti                            ; CCR2 - CCR2 (we don't have one on these models of MSP430s)
            reti                            ; CCR3 - Not used
            reti                            ; CCR4 - Not Used
            jmp		TAoverISR				; Lastly is the TA Overflow which runs below

TAoverISR:									; Vector A: TAIFG (Overflow)
			xor.b	#LED_PIN, &P1OUT		; Toggle LED
			mov.w   #OUTMOD_0, &CCTL0 	    ; CCR0 OUTPUT mode, interrupt NOT enabled
	   		mov.w   #OUTMOD_0, &CCTL1 	    ; CCR1 OUTPUT mode, interrupt NOT enabled
          	bis.w  	#OUT, &TACCTL0          ; Manually set the TA0 output pin
         	bis.w  	#OUT, &TACCTL1          ; Manually set the TA1 output pin
          	mov.w   #OUTMOD_5, &CCTL0 	    ; CCR0 RESET mode
           	mov.w   #OUTMOD_5, &CCTL1 	    ; CCR1 RESET mode

			reti

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
            
            .sect	".int08"
            .short	TAX_ISR
