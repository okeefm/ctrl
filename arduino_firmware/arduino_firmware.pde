/***********************************************************
* DMX-512 Reception                                        *
* Developed by Max Pierson                                 *
* Version Rev13 9 July 2009                                *
* Released under the WTFPL license, although I would       *
* appreciate Attribution and Share-Alike                   *
* See blog.wingedvictorydesign.com for the latest version. *
************************************************************/



/******************************* Addressing variable declarations *****************************/

#include <EEPROM.h>
#define NUMBER_OF_CHANNELS 8
//the number of channels we want to receive (8 by default).

#define SWITCH_PIN_0 11 //the pin number of our "0" switch
#define SWITCH_PIN_1 12 //the pin number of our "1" switch
unsigned int dmxaddress = 1;
/* The dmx address we will be listening to.  The value of this will be set in the Addressing()
*  function, if triggered, and read from EEPROM addresses 510 and 511.

/******************************* MAX485 variable declarations *****************************/

#define RECEIVER_OUTPUT_ENABLE 2
/* receiver output enable (pin2) on the max485.  
*  will be left low to set the max485 to receive data. */

#define DRIVER_OUTPUT_ENABLE 3
/* driver output enable (pin3) on the max485.  
*  will left low to disable driver output. */

#define RX_PIN 0   // serial receive pin, which takes the incoming data from the MAX485.
#define TX_PIN 1   // serial transmission pin

/******************************* DMX variable declarations ********************************/

volatile byte i = 0;              //dummy variable for dmxvalue[]
volatile byte dmxreceived = 0;    //the latest received value
volatile unsigned int dmxcurrent = 0;     //counter variable that is incremented every time we receive a value.
volatile byte dmxvalue[NUMBER_OF_CHANNELS];     //stores the DMX values we're interested in using.
volatile boolean dmxnewvalue = 0; //set to 1 when new dmx values are received.

/******************************* Timer2 variable declarations *****************************/

volatile byte zerocounter = 0;          
/* a counter to hold the number of zeros received in sequence on the serial receive pin.  
*  When we've received a minimum of 11 zeros in a row, we must be in a break.  As written,
*  the timer2 ISR actually checks for 22 zeros in a row, for the full 88uS break.       */

/******************************* LED PWM variable declarations *****************************/
byte LED_PINS[] = {9,10,11}; //these are the addresses for the three LED arrays
#define NUM_PINS 3

void setup() {
  
  /*******************************LED Pin configuration ***********************************/
  for (int i = 0; i < NUM_PINS; i++)
  {
    pinMode(i, OUTPUT);
  }  
  /******************************* Max485 configuration ***********************************/
  
  pinMode(RECEIVER_OUTPUT_ENABLE, OUTPUT);
  pinMode(DRIVER_OUTPUT_ENABLE, OUTPUT);
  digitalWrite(RECEIVER_OUTPUT_ENABLE, LOW);
  digitalWrite(DRIVER_OUTPUT_ENABLE, LOW);    //sets pins 3 and 4 to low to enable reciever mode on the MAX485.

  pinMode(RX_PIN, INPUT);  //sets serial pin to receive data

  /******************************* Addressing subroutine *********************************/

  pinMode(SWITCH_PIN_0, INPUT);           //sets pin for '0' switch to input
  digitalWrite(SWITCH_PIN_0, HIGH);       //turns on the internal pull-up resistor for '0' switch pin
  pinMode(SWITCH_PIN_1, INPUT);           //sets pin for '1' switch to input  
  digitalWrite(SWITCH_PIN_1, HIGH);       //turns on the internal pull-up resistor for '1' switch pin
    
  byte switch1 = 0;
  byte switch0 = 0;  //the switch states for the 1 and 0 pin 
  switch0 = digitalRead(SWITCH_PIN_0);
  switch1 = digitalRead(SWITCH_PIN_1);
  
  if (switch0 == 0 || switch1 == 0)
  {
  Addressing(switch0, switch1);
  //call the addressing subroutine if either switch is pressed.
  }

  //read the previously stored value from EEPROM addresses 510 and 511.
  dmxaddress = EEPROM.read(511);   //read the high byte into dmxaddress
  dmxaddress = dmxaddress << 8;  
  //bitshift the high byte left 8 bits to make room for the low byte
  dmxaddress =  dmxaddress | EEPROM.read(510);   //read the low byte into dmxaddress
  dmxaddress = dmxaddress + 3;
  /*  this will allow the USART receive interrupt to fire an additional 3 times for every dmx frame.  
  *   Here's why:
  *   Once to account for the fact that DMX addresses run from 0-511, whereas channel numbers
  *        start numbering at 1.
  *   Once for the Mark After Break (MAB), which will be detected by the USART as a valid character 
  *        (a zero, eight more zeros, followed by a one)
  *   Once for the START code that precedes the 512 DMX values (used for RDM).  */


  /******************************* USART configuration ************************************/
  
  Serial.begin(250000);
  /* Each bit is 4uS long, hence 250Kbps baud rate */
  
  cli(); //disable interrupts while we're setting bits in registers
  
  bitClear(UCSR0B, RXCIE0);  //disable USART reception interrupt
  
  /******************************* Timer2 configuration ***********************************/
  
  //NOTE:  this will disable PWM on pins 3 and 11.
  bitClear(TCCR2A, COM2A1);
  bitClear(TCCR2A, COM2A0); //disable compare match output A mode
  bitClear(TCCR2A, COM2B1);
  bitClear(TCCR2A, COM2B0); //disable compare match output B mode
  bitSet(TCCR2A, WGM21);
  bitClear(TCCR2A, WGM20);  //set mode 2, CTC.  TOP will be set by OCRA.
  
  bitClear(TCCR2B, FOC2A);
  bitClear(TCCR2B, FOC2B);  //disable Force Output Compare A and B.
  bitClear(TCCR2B, WGM22);  //set mode 2, CTC.  TOP will be set by OCRA.
  bitClear(TCCR2B, CS22);
  bitClear(TCCR2B, CS21);
  bitSet(TCCR2B, CS20);   // no prescaler means the clock will increment every 62.5ns (assuming 16Mhz clock speed).
  
  OCR2A = 64;                
  /* Set output compare register to 64, so that the Output Compare Interrupt will fire
  *  every 4uS.  */
  
  bitClear(TIMSK2, OCIE2B);  //Disable Timer/Counter2 Output Compare Match B Interrupt
  bitSet(TIMSK2, OCIE2A);    //Enable Timer/Counter2 Output Compare Match A Interrupt
  bitClear(TIMSK2, TOIE2);   //Disable Timer/Counter2 Overflow Interrupt Enable          
  
  sei();                     //reenable interrupts now that timer2 has been configured. 
  
}  //end setup()


void loop()  {
  // the processor gets parked here while the ISRs are doing their thing. 
  
  if (dmxnewvalue == 1) {    //when a new set of values are received, jump to action loop...
    action();
    dmxnewvalue = 0;
    dmxcurrent = 0;
    zerocounter = 0;      //and then when finished reset variables and enable timer2 interrupt
    i = 0;
    bitSet(TIMSK2, OCIE2A);    //Enable Timer/Counter2 Output Compare Match A Interrupt
  }
} //end loop()


//Timer2 compare match interrupt vector handler
ISR(TIMER2_COMPA_vect) {
  if (bitRead(PIND, PIND0)) {  // if a one is detected, we're not in a break, reset zerocounter.
    zerocounter = 0;
    }
  else {
    zerocounter++;             // increment zerocounter if a zero is received.
    if (zerocounter == 22)     // if 22 0's are received in a row (88uS break)
      {   
      bitClear(TIMSK2, OCIE2A);    //disable this interrupt and enable reception interrupt now that we're in a break.
      bitSet(UCSR0B, RXCIE0);
      }
  }
} //end Timer2 ISR



ISR(USART_RX_vect){
  dmxreceived = UDR0;
  /* The receive buffer (UDR0) must be read during the reception ISR, or the ISR will just 
  *  execute again immediately upon exiting. */
 
  dmxcurrent++;                        //increment address counter
 
  if(dmxcurrent > dmxaddress) {         //check if the current address is the one we want.
    dmxvalue[i] = dmxreceived;
    i++;
    if(i == NUMBER_OF_CHANNELS) {
      bitClear(UCSR0B, RXCIE0); 
      dmxnewvalue = 1;                        //set newvalue, so that the main code can be executed.
    } 
  }
} // end ISR
