/*
  
  this version uses Wifi
  
*/

#include <WiFi.h>

// Wifi credentials

const char* ssid     = "ssid";
const char* password = "pw";

// Server details
const char host[] = "kitwallace.co.uk"; // domain name: example.com, maker.ifttt.com, etc
const char resource[] = "/logger/log-data.xq";         // resource path, for example: /post-data.php
const int  httpPort = 80;                             // server port number

String appid = "1418";   // change this 
String device = "Tree5";   // change this for a different location - server knows what tree this sensor attached to so no need for changes in the field.

// Moisure sensor
int moisture_A2D = A0;
const int AirValue = 2475;   
const int WaterValue = 380;  

int get_moisture_pc() {
  long sum=0; 
  for (int i=0;i < 5; i++) {
    int reading = analogRead(moisture_A2D);
    Serial.println(reading);
    sum += reading;
    delay(500);
   }

   int soilMoistureValue = sum / 5;
   int soilMoisturePC = map(soilMoistureValue, AirValue, WaterValue, 0, 100);
   if (soilMoisturePC > 100 )  soilMoisturePC = 100; 
   if (soilMoisturePC <0 )  soilMoisturePC = 0;
   
   return soilMoisturePC; 
}

// battery monitoring
int battery_ADC = 35;

// temperature sensor
#include <OneWire.h>
#include <DallasTemperature.h>

// Data wire is is on Pin 25 (I/O pin) with added 4.7K pullup)
#define ONE_WIRE_BUS 25

// Setup a oneWire instance to communicate with any OneWire devices
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature sensor 
DallasTemperature sensors(&oneWire);

// Set serial for debug console (to Serial Monitor, default speed 115200)
#define SerialMon Serial

#include <Wire.h>

#define uS_TO_S_FACTOR 1000000     /* Conversion factor for micro seconds to seconds */
#define TIME_TO_SLEEP  5*60        /* Time ESP32 will go to sleep (in seconds) 3600 seconds = 1 hour */
    // this value for soak testing only


void WiFi_httpRequest(String url) {
   WiFiClient client;
   url.replace(" ", "+");
   while (true) {
    if (client.connect(host, httpPort)) break;
    Serial.print(".");
    delay(100);
  }

  Serial.print("requesting URL: ");
  Serial.println(url);
// This will send the request to the server
  String httprequest = String("GET ") + url + " HTTP/1.1\r\n" +
               "Host: " + host + "\r\n" + 
               "Connection: close\r\n\r\n";
// Serial.println(httprequest);
  client.print(httprequest);
  
// Read all the lines of the reply from server and print them to Serial
  while(client.available()){
    String line = client.readStringUntil('\r');
    Serial.print(line);
  }
  
//  Serial.println();
  Serial.println("closing connection");
}
void setup() {
  // Set serial monitor debugging window baud rate to 115200
  Serial.begin(115200);
  
  //one wire begin
  sensors.begin();
  
   WiFi.begin(ssid, password);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("");
  Serial.print("WiFi connected ");  
  Serial.print("IP address: ");
  Serial.println( WiFi.localIP());

  delay(3000);

  // Configure the wake up source as timer wake up  
     esp_sleep_enable_timer_wakeup(TIME_TO_SLEEP * uS_TO_S_FACTOR);
}

void loop() {
 
   // get sensor data
      int moisture_pc = get_moisture_pc();
   
      Serial.print("Moisture PC ");
      Serial.println(moisture_pc);
   // get battery level
      float battery_voltage = analogRead(battery_ADC) *2.0 / 1135;
      Serial.print("Battery voltage  ");
      Serial.println(battery_voltage);

      sensors.requestTemperatures();

      float temp_C = sensors.getTempCByIndex(0);

      
      // Making an HTTP POST request
      Serial.println("Performing HTTP POST request...");

      String url = String(resource) + "?_appid=" + appid + "&_device="+ device +"&moisture-pc="+ moisture_pc +"&battery-voltage="+battery_voltage+"&temp-C="+temp_C;

      WiFi_httpRequest(url);
      
  // Put ESP32 into deep sleep mode (with timer wake up)
     esp_deep_sleep_start();
   // delay(TIME_TO_SLEEP*1000);
}
