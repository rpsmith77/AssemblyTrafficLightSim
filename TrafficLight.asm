;
; TrafficLight.asm
;
; Author : Ryan Smith
; Purpose: Final Project for CDA 3104. This project will simulate a traffic
;          light. 4 led: red, yellow, green, and white. Red, yellow and green
;          represent their repspective colors at traffic lights, white
;          represents cross walk light. When the button is pressed it will
;          start the process for the crosswalk light

; define bitmasks for lights
.equ RED = (1<<PB3)
.equ YELLOW = (1<<PB2)
.equ GREEN = (1<<PB1)
.equ CROSSWALK = (1<<PB0)|(1<<PB3)

; constants for z pointer light cycle
.equ REG_CYCLE = 3
.equ CROSSWALK_CYCLE = 4

; define registers for array pointers
.def current_light = r18
.def stack_end = r19

; configure interrupt vector table
.org 0x0000                             ; reset
          rjmp      main

.org INT0addr                           ; External Interrupt Request 0
          rjmp      ext0_isr

.org OC1Aaddr                           ; timer1 ctc mode interrupt A
          rjmp      oc1a_isrt

.org INT_VECTORS_SIZE                   ; end of vector table

main:
          ; initialize stack pointers
          ldi       r16,HIGH(RAMEND)
          out       SPH,r16
          ldi       r16,LOW(RAMEND)
          out       SPL,r16

          ; set array pointers
          ldi       ZH,HIGH(lights << 1)
          ldi       ZL,LOW(lights << 1)

          ldi       current_light,0     ; track which light is on
          ldi       stack_end,REG_CYCLE ; use regular light cycle

          ; set PORTB pin's 3-0 to output
          sbi       DDRB,DDB3           ; red led
          sbi       DDRB,DDB2           ; yellow led
          sbi       DDRB,DDB1           ; green led
          sbi       DDRB,DDB0           ; white led
          
          ; set push-button to pull-up
          cbi       DDRD,DDD2           ; set PORTD PIN2 to input
          sbi       PORTD,PD2           ; set PORTD PIN2 to pull up


          ; configure interrupt for push button
          ldi       r20,(1<<INT0)       ; enable interrupt 0
          out       EIMSK,r20

          ; configure interrupt sense control bits
          ldi       r20,(1<<ISC01)      ; set falling ednge
          sts       EICRA,r20           ; interrupt sense control bits

          ; configure timer1 for 3s
          ; 1) set counter to 0
          clr       r20
          sts       TCNT1H,r20          ; clear ->temp
          sts       TCNT1L,r20          ; clear 1L and temp->1H

          ; 1.1) set 3s delay in output compare regiser
          ldi       r20,HIGH(46874)     ; 3s / (1/(16MHZ/1024)) = 46875 - 1
          sts       OCR1AH,r20          ; load high byte
          ldi       r20,LOW(46874)
          sts       OCR1AL,r20          ; and low byte

          ; 2) set mode in timer counter control register A
          clr       r20
          sts       TCCR1A,r20          ; ctc mode (0<<WGM11)|(0<<WGM10)
          
          ; 3) set mode and clock select in timer control counter control register B
          ldi       r20,(1<<WGM12)|(1<<CS12)|(1<<CS10)
          sts       TCCR1B,r20          ; ctc mode & 1024 prescaler

          ; 4) set ctc A interrupt in timer interrupt mask register
          ldi       r20,(1<<OCIE1A)
          sts       TIMSK1,r20

          ; start off with red light on
          ldi       r16,RED
          out       PORTB,r16
          
          ; Enable global interrupts
          sei

; infinite loop
cycle_lights: rjmp cycle_lights

;---------------------------------------
ext0_isr:
; interrupt service routine for external
; interrupt 0 (PD2)
;
; Change stack_end to include crosswalk
;---------------------------------------
          ldi       stack_end,CROSSWALK_CYCLE
          reti                          ; end ext0_isr

;---------------------------------------
oc1a_isrt:
; interrupt service routine for timer 1
; using ctc mode for compare match A
;
; Cycle through lights from z pointer
;---------------------------------------
          lpm       r0,Z+               ; get current light and inc pointer
          out       PORTB,r0            ; toggle light

          inc       current_light       

                                        ; if (current_light != stack_end){
          cp        current_light,stack_end
          brne      exit_oc1a_isrt      ; return;
                                        ; } else {
          ldi       ZH,HIGH(lights << 1); reset Z pointer array
          ldi       ZL,LOW(lights << 1)
          ldi       current_light,0     ; current_light = 0;
          ldi       stack_end,REG_CYCLE ; stack_end = 3; // default value
                                        ; }

exit_oc1a_isrt:
          reti                          ; end oc1a_isrt

          ; PB3  , PB2  ,PB2,  PB0
lights: .db GREEN,YELLOW,RED,CROSSWALK