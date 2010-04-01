 #define LED_RED 11
  #define LED_BLUE 10
  #define LED_GREEN 9
  #include <Firmata.h>
  void analogWriteFirmata(byte pin, int value)
  { 
    analogWrite(pin, value);
  }
  
void setup() {
 pinMode(LED_RED, OUTPUT);
 pinMode(LED_BLUE, OUTPUT);
 pinMode(LED_GREEN, OUTPUT);
 
 Firmata.setFirmwareVersion(2, 1);
 Firmata.attach(ANALOG_MESSAGE, analogWriteFirmata);
 Firmata.begin();
}
  
void loop() {
  while(Firmata.available()) {
    Firmata.processInput();
  }
}
