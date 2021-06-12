/*
  Calibrate sensor osn Tree device
  
  Kit Wallace
  

*/

// GPIO sensor power 
#define TEMPPOWER 13
#define MOISTUREPOWER 25

// moisture sensor
#define moisture_A2D A3 //wired to this pin 

const int AirValue = 3160;   
const int WaterValue = 1160;  

// Data wire is is on Pin 14 (I/O pin) with added 4.7K pullup)
#define ONE_WIRE_BUS 14

// battery monitoring
#define battery_ADC 35

// refresh interval
#define TIME_TO_SLEEP  10        /* Time ESP32 will go to sleep (in seconds)  */

// end configuration

// voltage
float get_battery_voltage() {
   return analogRead(battery_ADC) *2.0 / 1135;
}

// Moisture sensor

const int nReadings=7;  // must be odd
int readings[nReadings];
int reading_delay=10;

int get_moisture_pc() {
   for (int i=0;i < nReadings; i++) {
    int reading = analogRead(moisture_A2D);
    readings[i]=reading;
    delay(reading_delay);
   }
   printArray(readings,nReadings);
   int soilMoistureValue = median(readings,nReadings);
   Serial.print("Water : ");Serial.print(WaterValue);
   Serial.print(" Air : ");Serial.println(AirValue);
   Serial.print("Moisture Reading ");
   Serial.println(soilMoistureValue);
   int soilMoisturePC = map(soilMoistureValue, AirValue, WaterValue, 0, 100);
   if (soilMoisturePC > 100 )  soilMoisturePC = 100; 
   if (soilMoisturePC <0 )  soilMoisturePC = 0;   
   return soilMoisturePC; 
}

//Bubble sort 
void bubbleSort(int *a, int n)
{
 for (int i = 1; i < n; ++i)
 {
   int j = a[i];
   int k;
   for (k = i - 1; (k >= 0) && (j < a[k]); k--)
   {
     a[k + 1] = a[k];
   }
   a[k + 1] = j;
 }
}

int median (int *a,int n) {
// n odd
  int mid = n/2;
  bubbleSort(a,n);
  return a[mid];
}

void printArray(int *a, int n)
{
 for (int i = 0; i < n; i++)
 {
   Serial.print(a[i]);
   Serial.print(' ');
 }
 Serial.println();
}

// temperature sensor
#include <OneWire.h>
#include <DallasTemperature.h>

// Setup a oneWire instance to communicate with any OneWire devices
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature sensor 
DallasTemperature sensors(&oneWire);

void setup() {
  int start = millis();

  // Set serial monitor debugging window baud rate to 115200
  Serial.begin(115200);
  
  pinMode(TEMPPOWER,OUTPUT);
  pinMode(MOISTUREPOWER,OUTPUT);
  digitalWrite(TEMPPOWER,HIGH); // power on the temp sensors
  digitalWrite(MOISTUREPOWER,HIGH); // power on the moisture sensors

  delay(100);

  //one wire begin
  sensors.begin();

}

void loop() {
 
  Serial.println();  
  // get temperatures - need to test and mark to find which is which
      sensors.requestTemperatures();
      float soil_temp_C = sensors.getTempCByIndex(0);

      Serial.print("Soil Temp "); Serial.println(soil_temp_C);
      float air_temp_C = sensors.getTempCByIndex(1);
      Serial.print("Air Temp "); Serial.println(air_temp_C);
 
   // end temp data
   
    
     
   // get moisture data
     int moisture_pc = get_moisture_pc();
     Serial.print("Moisture % ");Serial.println(moisture_pc);
     delay(TIME_TO_SLEEP*1000);
}
