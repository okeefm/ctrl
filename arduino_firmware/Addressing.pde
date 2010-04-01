void Addressing(byte switch0, byte switch1)
{
byte bitnumber = 0; //the number of bits recorded so far
boolean blink = 0; //used to blink the pin 13 LED once the address is recorded.

if (switch0 == 0 && switch1 == 0)
  {
  EEPROM.write(510, lowByte(dmxaddress));
  EEPROM.write(511, highByte(dmxaddress));
  //if BOTH addressing switches are held down, the starting address is reset to 1.
  }
    
else if (switch0 == 0 ^ switch1 == 0)
  {
  /* if EITHER switch0 or switch1 is held down (but not both), the addressing subroutine is
  *  run.  Since it writes the new address into EEPROM, there's no need to pass anything
  *  back to the main function. */
  while (bitnumber < 9) //runs 9 times, recording a bit in dmxaddress each time.
    {
    digitalWrite(13, HIGH); //turn on pin 13 to indicate addressing mode.
    
    if (switch0 != digitalRead(SWITCH_PIN_0) || switch1 != digitalRead(SWITCH_PIN_1))
      //execute loop if either switch state has changed
      {
          if (digitalRead(SWITCH_PIN_0) == HIGH && digitalRead(SWITCH_PIN_1) == LOW)
              //execute if 1 pin is pressed
              {
              switch0 = digitalRead(SWITCH_PIN_0);
              switch1 = digitalRead(SWITCH_PIN_1);  //update switch state variables with the new state
              bitSet(dmxaddress, bitnumber);  //write a 0 to the appropriate bit of dmxaddress
              bitnumber++;
              digitalWrite(13, LOW); //flash off pin 13 to indicate bit accepted
              delay(500);
              }

          if (digitalRead(SWITCH_PIN_0) == LOW && digitalRead(SWITCH_PIN_1) == HIGH)
              //execute if 0 pin is pressed
              {
              switch0 = digitalRead(SWITCH_PIN_0);
              switch1 = digitalRead(SWITCH_PIN_1);  //update switch state variables with the new state
              bitClear(dmxaddress, bitnumber);  //write a 0 to the appropriate bit of dmxaddress
              bitnumber++;
              digitalWrite(13, LOW); //turn off pin 13 to indicate bit accepted
              delay(500);
              }
      } //end switch state change if statement
    } //end while loop
  }//end else if addressing subroutine

for (byte i = 0; i < 15; i++) //blink LED 4 times when new address is received.
  {
  digitalWrite(13, blink);
  delay(100);
  blink = ~blink;
  }
  
EEPROM.write(510, lowByte(dmxaddress));//writes the first byte of dmxaddress to EEPROM address 510
EEPROM.write(511, highByte(dmxaddress));//writes the second byte of dmxaddress to EEPROM address 511

return;

}  //end Addressing()
