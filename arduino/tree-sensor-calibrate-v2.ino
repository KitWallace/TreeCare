/*
  Calibrate sensors on Tree moisture device

  Kit Wallace

 

*/

#include <WiFi.h>  // to get MAC address

const char version[] = "tree-sensor-calibrate-v2"; 
// GPIO sensor power
#define TEMPPOWER 13
#define MOISTUREPOWER 25

// moisture sensor
#define moisture_A2D A0 //wired to this pin 


// Data wire is is on Pin 14 (I/O pin) with added 4.7K pullup)
#define ONE_WIRE_BUS 14

// battery monitoring
#define battery_ADC 35

// refresh interval
#define TIME_TO_SLEEP  5       /* Time ESP32 will go to sleep (in seconds)  */

// end configuration

// voltage
float get_battery_voltage() {
  return analogRead(battery_ADC) * 2.0 / 1135;
}

// Moisture sensor

const int nReadings = 7; // must be odd
int readings[nReadings];
int reading_delay = 10;

int get_moisture_value() {
  for (int i = 0; i < nReadings; i++) {
    int reading = analogRead(moisture_A2D);
    readings[i] = reading;
    delay(reading_delay);
  }
  printArray(readings, nReadings);
  int soilMoistureValue = median(readings, nReadings);


  return soilMoistureValue;
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

int median (int *a, int n) {
  // n odd
  int mid = n / 2;
  bubbleSort(a, n);
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

  pinMode(TEMPPOWER, OUTPUT);
  pinMode(MOISTUREPOWER, OUTPUT);
  digitalWrite(TEMPPOWER, HIGH); // power on the temp sensors
  digitalWrite(MOISTUREPOWER, HIGH); // power on the moisture sensors

  delay(100);

  //one wire begin
  sensors.begin();
  Serial.print(version);
}

void loop() {

  Serial.println();
  // get MAC address
  String macAddr = WiFi.macAddress();
  Serial.print("MAC address "); Serial.println(macAddr);

  // get temperatures - need to test and mark to find which is which
  sensors.requestTemperatures();
  float temp_0_C = sensors.getTempCByIndex(0);
  Serial.print("Temp 0 "); Serial.println(temp_0_C);
  float temp_1_C = sensors.getTempCByIndex(1);
  Serial.print("Temp 1 "); Serial.println(temp_1_C);

  // end temp data
  // battery
  float battery = get_battery_voltage();
  Serial.print("Battery voltage "); Serial.println(battery);

  // get moisture data
  int moisture_value = get_moisture_value();
  Serial.print("Moisture value "); Serial.println(moisture_value);
  delay(TIME_TO_SLEEP * 1000);
}
