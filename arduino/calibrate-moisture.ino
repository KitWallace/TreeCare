/*
run this script with the sensor placed in Water and record the average value, then in air likewise and enter these values in the constants.  
Water and air should then read 100% and 0% respecively

*/

const int AirValue = 2475;   //you need to replace this value 
const int WaterValue = 380;  //you need to replace this value

int Moisture_Pin = A0;

void setup() {
   
   Serial.begin(115200); // open serial port, 

}
  
void loop() {
long sum=0;
int n = 10;
 for (int i=0;i < n; i++) {
   int reading = analogRead(Moisture_Pin);
   sum += reading;
   Serial.println(reading);
   delay(250);
   }

int soilMoistureValue = sum / n;

Serial.print("Average ");
Serial.println(soilMoistureValue);
Serial.print("Min(Water) ");
Serial.print(WaterValue);
Serial.print(" Max(Air) ");
Serial.println(AirValue);

int soilmoisturepercent = map(soilMoistureValue, AirValue, WaterValue, 0, 100);
Serial.print("Moisture:");
if(soilmoisturepercent >= 100)
{
  Serial.println("100 %");
}
else if(soilmoisturepercent <=0)
{
  Serial.println("0 %");
}
else if(soilmoisturepercent >0 && soilmoisturepercent < 100)
{
  Serial.print(soilmoisturepercent);
  Serial.println("%");
  
}

  delay(1000);
}
