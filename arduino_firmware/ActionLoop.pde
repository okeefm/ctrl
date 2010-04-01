void action() {

for (int i = 0; i < NUM_PINS; i++)
  {
    if ((dmxvalue[i] >= 0) && (dmxvalue[i] <= 255))
    {
      analogWrite(LED_PINS[i], dmxvalue[i]);
    }
  }

} //end action() loop
