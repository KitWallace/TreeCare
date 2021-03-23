/*
  Rui Santos
  Complete project details at https://RandomNerdTutorials.com/esp32-sim800l-publish-data-to-cloud/
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files.
  
  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.
  
  adapted by  kit wallace for use in remote moisture sensing

  optimised by Ian Mitchell

  The frontend for this can be found at http://kitwallace.co.uk/logger/view-log-data.xq?deviceid=Tree4&mode=full
  
*/
// configuration stuff
#define USE_WIFI
//#define USE_GSM
#define WIFI_CONNECTION_RETRY_DELAY 50
//this is the ammount of time in microseconds that the device sleeps for before it does all this again.
#define uS_TO_S_FACTOR 1000000     /* Conversion factor for micro seconds to seconds */
#define TIME_TO_SLEEP  60        /* Time ESP32 will go to sleep (in seconds) 3600 seconds = 1 hour */
//define this to print debug out the serial port
#define DEBUG_PRINTS
//define this to print time stamps - this requires DEBUG_PRINTS to be defined
#define PROFILE_TIME
//the timeout for the http post to wait for data from the server
//OPTIMISATION - do we need to wait for data from the server?
#define HTTP_POST_TIMEOUT (10000L)
#define SERIAL_BAUD_RATE 115200
// Define this to see debug prints of the AT commands sent, if needed
//#define DUMP_AT_COMMANDS
#define TIMES_TO_AVG_MOISTURE 5
#define DELAY_INBETWEEN_MOISTURE_READS 500
// Configure TinyGSM library
#define TINY_GSM_MODEM_SIM800      // Modem is SIM800
#define TINY_GSM_RX_BUFFER   1024  // Set RX buffer to 1Kb
#define TEMPERATURE_RESOLUTION 9 // this can be 12 as it is by default but it saves ~0.5seconds going to 9

// temperature sensor
#include <OneWire.h>
#include <DallasTemperature.h>

#include <DHT12.h>

// gsm modem
#include <Wire.h>
#include <TinyGsmClient.h>

// for wifi
#include <WiFi.h>
#include "wifi_credentials.h"

#ifdef USE_GSM
 bool first_time = true;
 // SIM card PIN (leave empty, if not defined)
 const char apn[]      = "TM"; // APN for ThingsMobile
 const char gprsUser[] = ""; // GPRS User
 const char gprsPass[] = ""; // GPRS Password
 const char simPIN[]   = "";

// Set serial for AT commands (to SIM800 module)
#define SerialAT Serial1

#ifdef DUMP_AT_COMMANDS
  #include <StreamDebugger.h>
  StreamDebugger debugger(SerialAT, Serial);
  TinyGsm modem(debugger);
#else
  TinyGsm modem(SerialAT);
#endif

// TinyGSM Client for Internet connection
TinyGsmClient client(modem);

// TTGO T-Call pins
#define MODEM_RST            5
#define MODEM_PWKEY          4
#define MODEM_POWER_ON       23
#define MODEM_TX             27
#define MODEM_RX             26

#endif

#define I2C_SDA              21
#define I2C_SCL              22

#ifdef DEBUG_PRINTS 
 #define SERIAL_PRINTLN Serial.println
 #define SERIAL_PRINT Serial.print
#else
 #define SERIAL_PRINTLN 
 #define SERIAL_PRINT 
#endif

// Server details
const char server[] = "kitwallace.co.uk"; // domain name: example.com, maker.ifttt.com, etc
const char resource[] = "/logger/log-data.xq";         // resource path, for example: /post-data.php
const int  port = 80;                             // server port number

String appid = "1418";   // change this 
String device = "Tree4";   // change this for a different location - server knows what tree this sensor attached to so no need for changes in the field.

// Moisure sensor
int moisture_A2D = A0;
const int AirValue = 2475;   
const int WaterValue = 380;  

#ifdef PROFILE_TIME
  //a variable to record the time that the script started
  unsigned long StartTime;
#endif

// battery monitoring
const int battery_ADC_pin = 35;

// for the temperature sensor
#define IP5306_ADDR          0x75
#define IP5306_REG_SYS_CTL0  0x00

 // Data wire is is on Pin 25 (I/O pin) with added 4.7K pullup)
#define ONE_WIRE_BUS 25

// Setup a oneWire instance to communicate with any OneWire devices
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature sensor 
DallasTemperature sensors(&oneWire);

// I2C for SIM800 (to keep it running when powered from battery)
TwoWire I2CPower = TwoWire(0);

int get_moisture_pc() {
  long sum=0; 
  for (int i=0;i < TIMES_TO_AVG_MOISTURE; i++) {
    int reading = analogRead(moisture_A2D);
    //SERIAL_PRINTLN(reading);
    sum += reading;
    delay(DELAY_INBETWEEN_MOISTURE_READS);
   }

   int soilMoistureValue = sum / TIMES_TO_AVG_MOISTURE;
   
   int soilMoisturePC = map(soilMoistureValue, AirValue, WaterValue, 0, 100);

   //clip it
   if (soilMoisturePC > 100 )  soilMoisturePC = 100; 
   if (soilMoisturePC <0 )  soilMoisturePC = 0;
   
   return soilMoisturePC; 
}

bool setPowerBoostKeepOn(int en){
  I2CPower.beginTransmission(IP5306_ADDR);
  I2CPower.write(IP5306_REG_SYS_CTL0);
  if (en) {
    I2CPower.write(0x37); // Set bit1: 1 enable 0 disable boost keep on
  } else {
    I2CPower.write(0x35); // 0x37 is default reg value
  }
  return I2CPower.endTransmission() == 0;
}

void setup() {

  #ifdef PROFILE_TIME
    //record the start time
    StartTime = millis();
  #endif

  #ifdef DEBUG_PRINTS
    // Set serial monitor debugging window baud rate to 115200
    Serial.begin(SERIAL_BAUD_RATE);
  #endif
  
  //one wire begin
  sensors.begin();
  
  // Start I2C communication
  I2CPower.begin(I2C_SDA, I2C_SCL, 400000);

  // Keep power when running from battery
  bool isOk = setPowerBoostKeepOn(1);
  SERIAL_PRINTLN(String("IP5306 KeepOn ") + (isOk ? "OK" : "FAIL"));

  #ifdef USE_GSM
    // Set modem reset, enable, power pins
    pinMode(MODEM_PWKEY, OUTPUT);
    pinMode(MODEM_RST, OUTPUT);
    pinMode(MODEM_POWER_ON, OUTPUT);
    digitalWrite(MODEM_PWKEY, LOW);
    digitalWrite(MODEM_RST, HIGH);
    digitalWrite(MODEM_POWER_ON, HIGH);
  
    // Set GSM module baud rate and UART pins
    SerialAT.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);
    delay(3000);//why the delay?
  
    // Restart SIM800 module, it takes quite some time
    // To skip it, call init() instead of restart()
    SERIAL_PRINT("Initializing modem ");
    if( first_time )
    {
      SERIAL_PRINTLN("restart.");
      modem.restart();
      first_time = false; //does not remember - store in rtc ram -does that add much to the power consumption compaired to what it saves?
    }
    else
    {
      SERIAL_PRINTLN("init.");
      modem.init();
    }

    /*String modemInfo = modem.getModemInfo();
    SERIAL_PRINT("Modem Info: ");
    SERIAL_PRINTLN(modemInfo);*/
  
    // Unlock your SIM card with a PIN if needed
    if (strlen(simPIN) && modem.getSimStatus() != 3 ) {
      modem.simUnlock(simPIN);
    }
  #endif
  
}

void loop() {
  bool connected = false;
  #ifdef PROFILE_TIME
    SERIAL_PRINT("Start time: ");
    SERIAL_PRINTLN(StartTime);
    SERIAL_PRINT("Took(to get to loop): ");
    SERIAL_PRINTLN(millis() - StartTime);
  #endif

  #ifdef USE_GSM
  SERIAL_PRINT("Connecting to APN: ");
  SERIAL_PRINT(apn);

  connected = modem.gprsConnect(apn, gprsUser, gprsPass);
  #endif

  #ifdef USE_WIFI
    WiFiClient client;
    SERIAL_PRINT("Connecting to wifi network ");
    SERIAL_PRINT(ssid);
    WiFi.begin(ssid, password);
    
    while (WiFi.status() != WL_CONNECTED) {
      delay(WIFI_CONNECTION_RETRY_DELAY);
      Serial.print(".");
    }
  
    Serial.println(" connected!");  
    Serial.print("IP address is ");
    Serial.println( WiFi.localIP() );

    connected = true;
  
    //delay(3000);
  #endif
  
  if (!connected) {
    SERIAL_PRINTLN(" failed");
    //store readings?
  }
  else {
    SERIAL_PRINTLN(" OK");
    
    SERIAL_PRINT("Connecting to server ");
    SERIAL_PRINT(server);
    
    if ( !client.connect(server, port) ) {
      SERIAL_PRINTLN(" failed!");
      //store readings?
    }
    else 
    {
      SERIAL_PRINTLN(" OK");

      SERIAL_PRINT("Took(to get connect): ");
      int time_to_connect = millis() - StartTime;
      SERIAL_PRINTLN(time_to_connect);
      
      // get moisture data
      int moisture_pc = get_moisture_pc();
   
      SERIAL_PRINT("Moisture PC is ");
      SERIAL_PRINTLN(moisture_pc);

      // get battery level
      float battery_voltage = analogRead(battery_ADC_pin) * 2.0 / 1135;
      
      SERIAL_PRINT("Battery voltage is ");
      SERIAL_PRINTLN(battery_voltage);

      // get temperature
      sensors.setResolution(TEMPERATURE_RESOLUTION);
      sensors.requestTemperaturesByIndex(0);
      float temp_C = sensors.getTempCByIndex(0);
      SERIAL_PRINT("Temperature is ");
      SERIAL_PRINTLN(temp_C);
      
      #ifdef USE_GSM
        int csq = modem.getSignalQuality();
        SERIAL_PRINT("Signal quality is ");
        SERIAL_PRINTLN(csq);
      #endif
  
      SERIAL_PRINT("Time to setup and read: ");
      int time_to_read = millis() - StartTime -time_to_connect;
      SERIAL_PRINTLN(time_to_read);
      
      // Making an HTTP POST request
      SERIAL_PRINTLN("Performing HTTP POST request.");

      String httpRequestData = "_appid=" + appid + 
        "&_device=" + device + 
        "&moisture-pc=" + moisture_pc +
        "&battery-voltage=" + battery_voltage +
        "&temp-C=" + temp_C +
        "&time-to-connect=" + time_to_connect + 
        "&time-to-read=" + time_to_read;
        
       #ifdef USE_GSM
        httpRequestData += "&gsm-signal-quality=" + csq;
       #endif

      //SERIAL_PRINTLN(httpRequestData);
      
      client.print(String("POST ") + resource + " HTTP/1.1\r\n");
      client.print(String("Host: ") + server + "\r\n");
      client.println("Connection: close");
      client.println("Content-Type: application/x-www-form-urlencoded");
      client.print("Content-Length: ");
      client.println(httpRequestData.length());
      client.println();
      client.println(httpRequestData);

      /*unsigned long timeout = millis();
      while (client.connected() && millis() - timeout < HTTP_POST_TIMEOUT) {
        // Print available data (HTTP response from server)
        // why wait for response?
        while (client.available()) {
          char c = client.read();
          SERIAL_PRINT(c);
          timeout = millis();
        }
      }*/
    
      // Close client and disconnect
      client.stop();
      SERIAL_PRINTLN(F("Server disconnected"));
      #ifdef USE_GSM
        modem.gprsDisconnect();
        SERIAL_PRINTLN(F("GPRS disconnected"));
      #endif
    }
  }

  #ifdef PROFILE_TIME
    SERIAL_PRINT("The loop took: ");
    SERIAL_PRINTLN(millis() - StartTime);
  #endif
  
  SERIAL_PRINT("Put ESP32 into deep sleep mode with timer wake up(s) in ");
  SERIAL_PRINTLN(TIME_TO_SLEEP);
  esp_sleep_enable_timer_wakeup(TIME_TO_SLEEP * uS_TO_S_FACTOR);

  #ifdef USE_GSM
    digitalWrite(MODEM_PWKEY, HIGH);
    digitalWrite(MODEM_RST, LOW);
    digitalWrite(MODEM_POWER_ON, LOW);
  #endif
  
  esp_deep_sleep_start();
}
