//******************************************************************************
//  MSP430F20xx Demo - Software Toggle P1.0
//
//  Description: Toggle P1.0 by xor'ing P1.0 inside of a software loop.
//  ACLK = n/a, MCLK = SMCLK = default DCO
//
//                MSP430F20xx
//             -----------------
//         /|\|              XIN|-
//          | |                 |
//          --|RST          XOUT|-
//            |                 |
//            |             P1.0|-->LED
//
//  M.Buccini / L. Westlund
//  Texas Instruments, Inc
//  October 2005
//  Built with CCE Version: 3.2.0 and IAR Embedded Workbench Version: 3.40A
//
// Modified:
// 2015.01.12: R. Scheidt PhD; Added more comments
// 2014.01.16: R. Scheidt PhD; Added comments
// 2019.01.29: D. Lantange BS; Modified comments and changed do-while loop
//
//******************************************************************************

#include  <msp430f2013.h>

void main(void)
{
  volatile unsigned int i;					// i is the loop counter. We declare
											// it is volatile to trick the compiler
											// into not optimizing the empty loop
											// away. A volatile variable is one that
											// can change due to hardware action, so
											// compiler optimizations should leave
											// it alone. If you every debug your code
											// and you are missing a variable, the
											// optimizer probably removed it.

  WDTCTL = WDTPW + WDTHOLD;                 // Stop hardware watchdog timer.
  											// Watchdog timers exist to restart
											// your program if their counter
											// overflows. Your program would
											// have to constantly reset the
											// watchdog to prevent this. This is
											// useful if your program gets stuck
											// in a loop and can't reset the
											// watchdog.
  P1DIR |= 0x01;                            // Set GPIO P1.0 to "output" direction

// Enter an infinite loop. Generally speaking, all microcontroller projects
// should have a "main" method that takes the form of an infinite loop
  for (;;)
  {

    P1OUT ^= 0x01;		// Toggle P1.0 using exclusive-OR.
						// To "toggle" means to change the state from "on" to
						// "off" or vice versa.
						// Note that "0x01" is hexadecimal for decimal "1" or
						// binary "00000001". P1.0 is short for "Port 1, Pin 0".
						// 0x01 indicates that we are toggling the state of Pin 0.

    i = 50000;        	// Load the Loop Counter's value
	while(i != 0){		// While the counter is not equal to zero
		i--;			// Decrement the counter
	}
						// We have decremented the counter to zero.
						// Loop back to the start of the FOR loop.
  }
}
