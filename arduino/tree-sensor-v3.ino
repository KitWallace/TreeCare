/*
  Combined GSM and Wifi Deepsleep code for 1 moisture sensor and 2 temperature sensors 
  
  Kit Wallace

  with acknowledgements to Rui Santos https://RandomNerdTutorials.com/esp32-sim800l-publish-data-to-cloud/
  and Ian Mitchell
  
  V3
  
*/

#define GSM
// #define WIFI

// configuration constants

#ifdef WIFI
// WiFi credentials
const char* ssid     = "BT-C3A5ZT";
const char* password = "Azores19";
#endif

#ifdef GSM
// GPRS credentials 
const char apn[]      = "everywhere"; 
const char gprsUser[] = "eesecure"; 
const char gprsPass[] = "secure"; 

// SIM card PIN (leave empty, if not defined)
const char simPIN[]   = ""; 

#endif

// Host details
const char host[] = "kitwallace.co.uk"; 
const char resource[] = "/logger/log-data.xq";        
const int  httpPort = 80;                             

String appid = "1418";    // pin for the appid -  
String deviceid = "Tree1";   

// GPIO sensor power 
#define TEMPPOWER 13
#define MOISTUREPOWER 25

// moisture sensor
#define moisture_A2D A0

const int AirValue = 3250;   
const int WaterValue = 1202;  

// Data wire is is on Pin 14 (I/O pin) with added 4.7K pullup)
#define ONE_WIRE_BUS 14

// battery monitoring
#define battery_ADC 35

// refresh interval
#define uS_TO_S_FACTOR 1000000ULL     /* Conversion factor for micro seconds to seconds - cast as ULL to allow long sleeps  */
#define TIME_TO_SLEEP  60        /* Time ESP32 will go to sleep (in seconds)  */

// end configuration

RTC_DATA_ATTR int run_ms = 0;
RTC_DATA_ATTR int boot_no = 0;

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


#ifdef WIFI
#include <WiFi.h>
   
WiFiClient client;

void WiFi_start() {  
     WiFi.begin(ssid, password);
   
     while (WiFi.status() != WL_CONNECTED) {
       delay(500);
       Serial.print(".");
    }
    Serial.println("");
    Serial.print("WiFi connected ");  
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());   
}

void WiFi_end() {
}

#endif

#ifdef GSM

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
  Serial.println(String("IP5306 KeepOn ") + (isOk ? "OK" : "FAIL"));

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
  Serial.println("Initializing modem...");
  modem.restart();
  // use modem.init() if you don't need the complete restart

  // Unlock your SIM card with a PIN if needed
  if (strlen(simPIN) && modem.getSimStatus() != 3 ) {
    modem.simUnlock(simPIN);
  }
    
  Serial.print("Connecting to APN: ");
  Serial.println(apn);
  if (!modem.gprsConnect(apn, gprsUser, gprsPass)) {
       Serial.println(" fail");
  }
  else {
    Serial.println(" OK");
  }
}

void GSM_end() {
   modem.gprsDisconnect();
   Serial.println("GPRS disconnected");
}

#endif

void HTTP_Request(String httpRequestData) { 
    httpRequestData.replace(" ", "+");
    int tries = 0;
    while (tries < 10) {
      if (client.connect(host, httpPort)) break;
      Serial.print(".");
      tries+=1;
      delay(100);
   }
#ifdef GSM
   int signal_quality = modem.getSignalQuality();          
   httpRequestData = httpRequestData + "&signal-quality="+signal_quality;  
#endif
//  construct http request
    String httpRequest = String("GET ") + resource +"?" + httpRequestData + " HTTP/1.1\r\n" +
               "Host: " + host + "\r\n" + 
               "Connection: close\r\n\r\n";
   Serial.println(httpRequest);
   client.print(httpRequest);
  
// Read all the lines of the reply from server and print them to Serial
/*   
  while(client.available()){
    String line = client.readStringUntil('\r');
    Serial.print(line);
  }
*/
  
//  Serial.println();
   Serial.println("closing connection");
   client.stop();
}

void setup() {
  int start = millis();

  // Set serial monitor debugging window baud rate to 115200
  Serial.begin(115200);
  
  pinMode(TEMPPOWER,OUTPUT);
  pinMode(MOISTUREPOWER,OUTPUT);
  
  digitalWrite(TEMPPOWER,HIGH); // power on the temp sensors
  delay(100);
  //one wire begin
  sensors.begin();
      
  // get temperatures - need to test and mark to find which is which
      sensors.requestTemperatures();
      float soil_temp_C = sensors.getTempCByIndex(0);
      float air_temp_C = sensors.getTempCByIndex(1);

   // end temp data
   
    digitalWrite(TEMPPOWER,LOW); // power off the temp sensors
   
    digitalWrite(MOISTUREPOWER,HIGH); // power on the moisture sensors
    delay(500);  
    
   // get moisture data
     int moisture_pc = get_moisture_pc();
   
    digitalWrite(MOISTUREPOWER,LOW); // power off the moisture sensors

    // get battery level
    float battery_voltage = get_battery_voltage();

    String httpRequestData = "_appid=" + appid + "&_device="+ deviceid +"&moisture-pc="+ moisture_pc +"&battery-voltage="+battery_voltage+"&soil-temp-C="+soil_temp_C +"&air-temp-C="+air_temp_C +"&run_ms="+run_ms+"&boot-no="+boot_no;
    Serial.println(httpRequestData);
  // send data
    
#ifdef GSM
    GSM_start();
    HTTP_Request(httpRequestData);
    GSM_end();
#endif
#ifdef WIFI
    WiFi_start();
    HTTP_Request(httpRequestData);
    WiFi_end();
#endif
   
  // Configure the wake up source as timer wake up  
    esp_sleep_enable_timer_wakeup(TIME_TO_SLEEP * uS_TO_S_FACTOR);
    
    run_ms = millis() - start;   
    boot_no += 1;
    
    esp_deep_sleep_start();
}

void loop() {
}
