/*
  Rui Santos
  Complete project details at https://RandomNerdTutorials.com/esp32-sim800l-publish-data-to-cloud/
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files.
  
  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.
  
  adapted by  kit wallace for use in remote moisture sensing
  
*/

// Your GPRS credentials (leave empty, if not needed)
const char apn[]      = "TM"; // APN for ThingsMobile
const char gprsUser[] = ""; // GPRS User
const char gprsPass[] = ""; // GPRS Password

// SIM card PIN (leave empty, if not defined)
const char simPIN[]   = ""; 

// Server details
const char server[] = "kitwallace.co.uk"; // domain name: example.com, maker.ifttt.com, etc
const char resource[] = "/logger/log-data.xq";         // resource path, for example: /post-data.php
const int  port = 80;                             // server port number


String appid = "1418";   // change this 
String device = "Tree4";   // change this for a different location - server knows what tree this sensor attached to so no need for changes in the field.

// TTGO T-Call pins
#define MODEM_RST            5
#define MODEM_PWKEY          4
#define MODEM_POWER_ON       23
#define MODEM_TX             27
#define MODEM_RX             26
#define I2C_SDA              21
#define I2C_SCL              22

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
// Set serial for AT commands (to SIM800 module)
#define SerialAT Serial1

// Configure TinyGSM library
#define TINY_GSM_MODEM_SIM800      // Modem is SIM800
#define TINY_GSM_RX_BUFFER   1024  // Set RX buffer to 1Kb

// Define the serial console for debug prints, if needed
//#define DUMP_AT_COMMANDS

#include <Wire.h>
#include <TinyGsmClient.h>

#ifdef DUMP_AT_COMMANDS
  #include <StreamDebugger.h>
  StreamDebugger debugger(SerialAT, SerialMon);
  TinyGsm modem(debugger);
#else
  TinyGsm modem(SerialAT);
#endif

// I2C for SIM800 (to keep it running when powered from battery)
TwoWire I2CPower = TwoWire(0);


// TinyGSM Client for Internet connection
TinyGsmClient client(modem);

#define uS_TO_S_FACTOR 1000000     /* Conversion factor for micro seconds to seconds */
#define TIME_TO_SLEEP  5*60        /* Time ESP32 will go to sleep (in seconds) 3600 seconds = 1 hour */
    // this value for soak testing only

#define IP5306_ADDR          0x75
#define IP5306_REG_SYS_CTL0  0x00

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
  // Set serial monitor debugging window baud rate to 115200
  SerialMon.begin(115200);
  
  //one wire begin
  sensors.begin();
  
  // Start I2C communication
  I2CPower.begin(I2C_SDA, I2C_SCL, 400000);

  // Keep power when running from battery
  bool isOk = setPowerBoostKeepOn(1);
  SerialMon.println(String("IP5306 KeepOn ") + (isOk ? "OK" : "FAIL"));

  // Set modem reset, enable, power pins
  pinMode(MODEM_PWKEY, OUTPUT);
  pinMode(MODEM_RST, OUTPUT);
  pinMode(MODEM_POWER_ON, OUTPUT);
  digitalWrite(MODEM_PWKEY, LOW);
  digitalWrite(MODEM_RST, HIGH);
  digitalWrite(MODEM_POWER_ON, HIGH);

  // Set GSM module baud rate and UART pins
  SerialAT.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);
  delay(3000);

  // Restart SIM800 module, it takes quite some time
  // To skip it, call init() instead of restart()
  SerialMon.println("Initializing modem...");
  modem.restart();
  // use modem.init() if you don't need the complete restart

  // Unlock your SIM card with a PIN if needed
  if (strlen(simPIN) && modem.getSimStatus() != 3 ) {
    modem.simUnlock(simPIN);
  }

  // Configure the wake up source as timer wake up  
  esp_sleep_enable_timer_wakeup(TIME_TO_SLEEP * uS_TO_S_FACTOR);
}

void loop() {
  SerialMon.print("Connecting to APN: ");
  SerialMon.print(apn);
  if (!modem.gprsConnect(apn, gprsUser, gprsPass)) {
    SerialMon.println(" fail");
  }
  else {
    SerialMon.println(" OK");
    
    SerialMon.print("Connecting to ");
    SerialMon.print(server);
    if (!client.connect(server, port)) {
      SerialMon.println(" fail");
    }
    else {
      SerialMon.println(" OK");

      // get sensor data
      int moisture_pc = get_moisture_pc();
   
      SerialMon.print("Moisture PC ");
      SerialMon.println(moisture_pc);
   // get battery level
      float battery_voltage = analogRead(battery_ADC) *2.0 / 1135;
      SerialMon.print("Battery voltage  ");
      SerialMon.println(battery_voltage);

    // get temperature

      sensors.requestTemperatures();

      float temp_C = sensors.getTempCByIndex(0);
      
      // Making an HTTP POST request
      SerialMon.println("Performing HTTP POST request...");

      String httpRequestData = "_appid=" + appid + "&_device="+ device +"&moisture-pc="+ moisture_pc +"&battery-voltage="+battery_voltage+"&temp-C="+temp_C;

      SerialMon.println(httpRequestData);
      
      client.print(String("POST ") + resource + " HTTP/1.1\r\n");
      client.print(String("Host: ") + server + "\r\n");
      client.println("Connection: close");
      client.println("Content-Type: application/x-www-form-urlencoded");
      client.print("Content-Length: ");
      client.println(httpRequestData.length());
      client.println();
      client.println(httpRequestData);

      unsigned long timeout = millis();
      while (client.connected() && millis() - timeout < 10000L) {
        // Print available data (HTTP response from server)
        while (client.available()) {
          char c = client.read();
          SerialMon.print(c);
          timeout = millis();
        }
      }
      SerialMon.println();
    
      // Close client and disconnect
      client.stop();
      SerialMon.println(F("Server disconnected"));
      modem.gprsDisconnect();
      SerialMon.println(F("GPRS disconnected"));
    }
  }
  // Put ESP32 into deep sleep mode (with timer wake up)
    esp_deep_sleep_start();
//    delay(TIME_TO_SLEEP*1000);
}
