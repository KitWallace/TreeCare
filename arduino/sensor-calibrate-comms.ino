/*
  Calibrate sensors - comms
  
  Kit Wallace
  
  see https://kitwallace.tumblr.com/tagged/moisture
  
*/

int n;
int elapsed=0;

#include <WiFi.h>
#define SerialMon Serial

#define ThingsMobile 

// GPIO sensor power 
#define TEMPPOWER 13
#define MOISTUREPOWER 25

// moisture sensor
#define moisture_A2D A0  

// Data wire is is on Pin 14 (I/O pin) with added 4.7K pullup)
#define ONE_WIRE_BUS 14

// battery monitoring
#define battery_ADC 35

// refresh interval
#define TIME_TO_SLEEP  30        /* Time ESP32 will go to sleep (in seconds)  */

// GPRS credentials 
#ifdef ThingsMobile
const char apn[]      = "TM"; 
const char gprsUser[] = ""; 
const char gprsPass[] = ""; 
#endif

#ifdef GiffGaff
const char apn[]      = "giffgaff.com"; 
const char gprsUser[] = "giffgaff"; 
const char gprsPass[] = ""; 

#endif

// SIM card PIN (leave empty, if not defined)
const char simPIN[]   = ""; 
// end configuration


// Server details
const char host[] = "kitwallace.co.uk"; 
const char resource[] = "/logger/log-data.xq";         
const int  httpPort = 80;                           

String appid = "1418";   
String device = "config";  

// voltage
float get_battery_voltage() {
   return analogRead(battery_ADC) *2.0 / 1135;
}

// Moisture sensor

int min_moisture = 10000;
int max_moisture =  0;

const int nReadings=7;  // must be odd
int readings[nReadings];
int reading_delay=10;

int get_moisture_reading() {
   for (int i=0;i < nReadings; i++) {
    int reading = analogRead(moisture_A2D);
    readings[i]=reading;
    delay(reading_delay);
   }
   printArray(readings,nReadings);
   int moisture_reading = median(readings,nReadings);
   return moisture_reading; 
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
   SerialMon.print(a[i]);
   SerialMon.print(' ');
 }
 SerialMon.println();
}

// temperature sensor
#include <OneWire.h>
#include <DallasTemperature.h>

// Setup a oneWire instance to communicate with any OneWire devices
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature sensor 
DallasTemperature sensors(&oneWire);



// TTGO T-Call pins
#define MODEM_RST            5
#define MODEM_PWKEY          4
#define MODEM_POWER_ON       23
#define MODEM_TX             27
#define MODEM_RX             26
#define I2C_SDA              21
#define I2C_SCL              22


// Set serial for AT commands (to SIM800 module)
#define SerialAT Serial1

// Configure TinyGSM library
#define TINY_GSM_MODEM_SIM800      // Modem is SIM800
#define TINY_GSM_RX_BUFFER  1024  // Set RX buffer to 1Kb

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
void GSM_start() {
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
  delay(1000);

  // Restart SIM800 module, it takes quite some time
  // To skip it, call init() instead of restart()
  SerialMon.println("Initializing modem...");
  // use modem.init() if you don't need the complete restart
  if (!modem.restart()) {
      SerialMon.println("Failed to restart");
  }

  // Unlock your SIM card with a PIN if needed
  if (strlen(simPIN) && modem.getSimStatus() != 3 ) {
    modem.simUnlock(simPIN);
  }
    
  SerialMon.print("Connecting to APN: ");
  SerialMon.println(apn);
  if (!modem.gprsConnect(apn, gprsUser, gprsPass)) {
       SerialMon.println(" fail");
  }
  else {
    SerialMon.println(" OK");
  }
}

void GSM_end() {
   modem.gprsDisconnect();
   SerialMon.println("GPRS disconnected");
}

void HTTP_Request(String httpRequestData) { 
    httpRequestData.replace(" ", "+");
    int tries = 0;
    while (tries < 10) {
      if (client.connect(host, httpPort)) break;
      SerialMon.print(".");
      tries+=1;
      delay(100);
   }

   int signal_quality = modem.getSignalQuality();          
   httpRequestData = httpRequestData + "&signal-quality="+signal_quality;  
   
//  construct http request
    String httpRequest = String("POST ") + resource + " HTTP/1.1\r\n" +
               "Host: " + host + "\r\n" + 
               "Connection: close\r\n" +
               "Content-Type: application/x-www-form-urlencoded\r\n" +
               "Content-Length: " + httpRequestData.length() + "\r\n\r\n" +
               httpRequestData;
   SerialMon.println(httpRequest);
   client.print(httpRequest);
  
// Read all the lines of the reply from server and print them to Serial
  uint32_t timeout = millis();
  while (client.connected() && millis() - timeout < 10000L) {
    // Print available data
    while (client.available()) {
      char c = client.read();
      SerialMon.print(c);
      timeout = millis();
    }
  }
  SerialMon.println();

 
//  SerialMon.println();
   SerialMon.println("closing connection");
   client.stop();
}

void setup() {
  n=0;
  // Set serial monitor debugging window baud rate to 115200
  SerialMon.begin(115200);
  
  pinMode(TEMPPOWER,OUTPUT);
  pinMode(MOISTUREPOWER,OUTPUT);
  digitalWrite(TEMPPOWER,HIGH); // power on the temp sensors
  digitalWrite(MOISTUREPOWER,HIGH); // power on the moisture sensors

  delay(100);

  //one wire begin
  sensors.begin();
  
}

void loop() {
  int start = millis();
  SerialMon.println();  
   // get MAC id 
  
   String macAddr = WiFi.macAddress();
   SerialMon.print("MAC address "); SerialMon.println(macAddr);

  // get temperatures - need to test and mark to find which is which
      sensors.requestTemperatures();
      float soil_temp_C = sensors.getTempCByIndex(0);

      SerialMon.print("Soil Temp "); SerialMon.println(soil_temp_C);
      float air_temp_C = sensors.getTempCByIndex(1);
      SerialMon.print("Air Temp "); SerialMon.println(air_temp_C);     
     
   // get moisture data
     int moisture_reading = get_moisture_reading();
     SerialMon.print("Moisture Reading ");SerialMon.println(moisture_reading);
     if (moisture_reading < min_moisture && moisture_reading > 100)
           min_moisture = moisture_reading;
    if (moisture_reading > max_moisture )
           max_moisture = moisture_reading;
           
   // get battery level
     float battery_voltage = get_battery_voltage();
     SerialMon.print("Battery voltage "); SerialMon.println(battery_voltage);

     String httpRequestData = "_appid=" + appid + "&_device="+device +"&macAddr="+ macAddr + "&CCID="+modem.getSimCCID()+"&n="+n+"&elapsed="+elapsed+"&moisture_reading=" + moisture_reading +
          "&min_moisture="+min_moisture+"&max_moisture="+max_moisture+"&air_temp="+air_temp_C+"&soil_temp="+soil_temp_C+"&battery="+battery_voltage;
     ;
     SerialMon.println(httpRequestData);
  // send data


    GSM_start();
    HTTP_Request(httpRequestData);
    GSM_end();

    n++;
    elapsed= millis() - start;
    delay(TIME_TO_SLEEP*1000);
}
