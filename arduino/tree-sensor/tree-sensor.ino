/*
  Combined GSM and Wifi Deepsleep code for 1 moisture sennsor, 2 temperature sensors and a humidity sensor.
  
  Kit Wallace

  with acknowledgements to Rui Santos https://RandomNerdTutorials.com/esp32-sim800l-publish-data-to-cloud/
  and Ian Mitchell

  Board ESP32 Ardunio->TTGO T1
  
*/

//include files
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Wire.h>
#include <WiFi.h>
#include <ArduinoHttpClient.h>

//configuration
//the way to connect to the network
#define GSM
//#define WIFI

#include <Wire.h>

#define REPORT_HUMIDITY_READINGS

#ifdef REPORT_HUMIDITY_READINGS
#include "DFRobot_SHT20.h"

DFRobot_SHT20 sht20;
#endif

#ifdef WIFI

// WiFi credentials
const char* ssid     = "mitchsoft";
const char* password = "davethecat";
#endif

#ifdef GSM
// Configure TinyGSM library
#define TINY_GSM_MODEM_SIM800      // Modem is SIM800
#define TINY_GSM_RX_BUFFER  1024  // Set RX buffer to 1Kb
#include <TinyGsmClient.h>

// GPRS credentials 
const char apn[]      = "TM"; 
const char gprsUser[] = ""; 
const char gprsPass[] = ""; 

// SIM card PIN (leave empty, if not defined)
const char simPIN[]   = ""; 

#endif

// GPIO sensor power 
#define TEMPPOWER 13
#define MOISTUREPOWER 25
#define HUMIDITYPOWER 32

// moisture sensor
#define moisture_A2D A0

//configuration data for the sensor
const int AirValue = 3250;   
const int WaterValue = 1320;  

// temperature sensor data wire is is on Pin 14 (I/O pin) with added 4.7K pullup)
#define ONE_WIRE_BUS 14

// refresh interval
#define TIME_TO_SLEEP  (60)        /* Time ESP32 will go to sleep (in seconds)  */

// Host details
const char host[] = "kitwallace.co.uk"; 
const char resource[] = "/logger/log-data.xq";        
const int  httpPort = 80;                             

const String appid = "1418";    // pin for the appid -  
const String deviceid = "Tree4";   

// battery monitoring
#define battery_ADC 35

#define uS_TO_S_FACTOR 1000000ULL     /* Conversion factor for micro seconds to seconds - cast as ULL to allow long sleeps  */

//these variables are stored in the rtc ram wich is kept powered when the board is sleeping
RTC_DATA_ATTR int run_ms = 0;
RTC_DATA_ATTR int boot_no = 0;
enum error_code{NO_ERROR = 0, CANT_CONNECT_TO_HOST = 1, CANT_CONNECT_TO_GSM_NETWORK = 2, CANT_CONNECT_TO_APN = 3, CANT_CONNECT_TO_GPRS = 4, CANT_POST_DATA = 5, POST_DATA_NOT_SUCCESS = 6, POST_DATA_BAD_STATUS = 7};
RTC_DATA_ATTR error_code last_error = NO_ERROR;

// voltage
float get_battery_voltage() {
   return analogRead(battery_ADC) *2.0 / 1135;
}

// Moisture sensor
const int nReadings=7;  // must be odd
int readings[nReadings];
const int reading_delay=10;

int get_moisture() {
  //Serial.println(">>> get_moisture");
   for (int i=0;i < nReadings; i++) {
    int reading = analogRead(moisture_A2D);
    readings[i]=reading;
    delay(reading_delay);
   }

   int soilMoistureValue = median(readings,nReadings);
      
   //Serial.print("<<< get_moisture, returning ");
   //Serial.println(soilMoistureValue);
   
   return soilMoistureValue; 
}

int get_moisture_pc(int raw_reading) {
  int soilMoistureValue = raw_reading;
   int soilMoisturePC = constrain(map(soilMoistureValue, AirValue, WaterValue, 0, 100), 0, 100);
   
   //Serial.print("<<< get_moisture_pc, returning ");
   //Serial.println(soilMoisturePC);
   
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


// Setup a oneWire instance to communicate with any OneWire devices
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature sensor 
DallasTemperature sensors(&oneWire);

#define IP5306_ADDR          0x75
#define IP5306_REG_SYS_CTL0  0x00

#define I2C_SDA              21
#define I2C_SCL              22

// I2C for SIM800 (to keep it running when powered from battery)
TwoWire I2CPower = TwoWire(0);

// I2C for the humidity sensor
#define I2C_SDA2              (12) //green
#define I2C_SCL2              (33) //yellow
TwoWire I2CHumidity = TwoWire(1);

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

#ifdef WIFI
#define CONNECTION_TRIES 20
#define CONNECTION_TRY_DELAY_MS 50
   
WiFiClient client;

bool WiFi_start(int *internet_connection_retries) {
  int isConnetedCnt = CONNECTION_TRIES;

  Serial.print("Connecting to wifi network ");
    Serial.print(ssid);
     WiFi.begin(ssid, password);
   
     while ((WiFi.status() != WL_CONNECTED) && (isConnetedCnt > 0)) {       
       isConnetedCnt--;
       Serial.print(".");
       delay(CONNECTION_TRY_DELAY_MS);
    }

  Serial.println("");

  *internet_connection_retries = CONNECTION_TRIES - isConnetedCnt;

    if( isConnetedCnt != 0 ) {
    
      Serial.print("WiFi connected ");  
      Serial.print("IP address: ");
      Serial.println(WiFi.localIP());   
      return true;
    }
    else
    {
      Serial.print("WiFi NOT connected ");  
      return false;
    }
    
}

void WiFi_end() {
}

#endif

#ifdef GSM

// TTGO T-Call pins
#define MODEM_RST            5
#define MODEM_PWRKEY         4
#define MODEM_POWER_ON       23
#define MODEM_TX             27
#define MODEM_RX             26

// Set serial for AT commands (to SIM800 module)
#define SerialAT Serial1

// Define the serial console for debug prints, if needed
//#define DUMP_AT_COMMANDS

#ifdef DUMP_AT_COMMANDS
  #include <StreamDebugger.h>
  StreamDebugger debugger(SerialAT, SerialMon);
  TinyGsm modem(debugger);
#else
  TinyGsm modem(SerialAT);
#endif

// TinyGSM Client for Internet connection 
TinyGsmClient client(modem);

bool GSM_start(int *internet_connection_retries) {
  // Set modem reset, enable, power pins - following https://github.com/Xinyuan-LilyGO/LilyGo-T-Call-SIM800/blob/master/examples/Arduino_TinyGSM/Arduino_TinyGSM.ino
  #ifdef MODEM_RST
    // Keep reset high
    pinMode(MODEM_RST, OUTPUT);
    digitalWrite(MODEM_RST, HIGH);
  #endif

  pinMode(MODEM_PWRKEY, OUTPUT);
  pinMode(MODEM_POWER_ON, OUTPUT);

  // Turn on the Modem power first
  digitalWrite(MODEM_POWER_ON, HIGH);

  // Pull down PWRKEY for more than 1 second according to manual requirements
  digitalWrite(MODEM_PWRKEY, HIGH);
  delay(100);
  digitalWrite(MODEM_PWRKEY, LOW);
  delay(1000);
  digitalWrite(MODEM_PWRKEY, HIGH);

  // Set GSM module baud rate and UART pins
  SerialAT.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);
  //delay(1000);
  
  // Restart SIM800 module, it takes quite some time
  // To skip it, call init() instead of restart()
  Serial.println("Initializing modem...");
  if( boot_no == 0) modem.restart();
  else modem.init();
  // use modem.init() if you don't need the complete restart
  //modem.restart();
  
  // Unlock your SIM card with a PIN if needed
  if (strlen(simPIN) && modem.getSimStatus() != 3 ) {
    modem.simUnlock(simPIN);
  }
  Serial.print("Waiting for network...");
  if (!modem.waitForNetwork(240000L)) {
      Serial.println(" fail");
      last_error = CANT_CONNECT_TO_GSM_NETWORK;
  }
  Serial.println(" OK");

  if (modem.isNetworkConnected()) {
        Serial.println("Network connected");
  }
    
  Serial.print("Connecting to APN: ");
  Serial.print(apn);
  if (!modem.gprsConnect(apn, gprsUser, gprsPass)) {
       Serial.println(" gprsConnect failed");
       return false;
       last_error = CANT_CONNECT_TO_APN;
  }

  if (modem.isGprsConnected()) { 
    Serial.println(" GPRS connected");
    *internet_connection_retries = 0;
    return true;
  }
  else
  {
    *internet_connection_retries = -1;
    last_error = CANT_CONNECT_TO_GPRS;
    return false;
  }
}

void GSM_end() {
   modem.gprsDisconnect();
   Serial.println("GPRS disconnected");

   //turn off the modem
   digitalWrite(MODEM_POWER_ON, LOW);
}

#endif
#define HTTP_CLIENT_CONNECT_TRIES 20
#define HTTP_CLIENT_DELAY 10
void HTTP_Request_dev(String httpRequestData) {

  
  HttpClient    http(client, host, httpPort);

    httpRequestData.replace(" ", "+");

  httpRequestData += "&httpdev=1";

  httpRequestData = "?" + httpRequestData;

    Serial.println(httpRequestData);

  Serial.print(F("Performing HTTP GET request... "));
  int err = http.get(resource + httpRequestData);
  
  if (err != 0) {
    Serial.println(F("failed to connect"));
    last_error = CANT_POST_DATA;
    return;
  }

  /*int status = http.responseStatusCode();
  Serial.print(F("Response status code: "));
  Serial.println(status);
  if (!status) {
    last_error = POST_DATA_BAD_STATUS;
    return;
  }*/

  Serial.println(F("Response Headers:"));
  while (http.headerAvailable()) {
    String headerName  = http.readHeaderName();
    String headerValue = http.readHeaderValue();
    Serial.println("    " + headerName + " : " + headerValue);
  }

  int length = http.contentLength();
  if (length >= 0) {
    Serial.print(F("Content length is: "));
    Serial.println(length);
  }
  if (http.isResponseChunked()) {
    Serial.println(F("The response is chunked"));
  }

  String body = http.responseBody();
  Serial.println(F("Response:"));
  Serial.println(body);
  if( body.indexOf("OK") == -1 )
  {
    Serial.println(F("The response was not OK"));
    last_error = POST_DATA_NOT_SUCCESS;
  }

  Serial.print(F("Body length is: "));
  Serial.println(body.length());

  // Shutdown

  http.stop();
   
}

void HTTP_Request(String httpRequestData) { 
    httpRequestData.replace(" ", "+");
    int tries = 0;
    while (tries < 10) {
      if (client.connect(host, httpPort)) break;
      Serial.print(".");
      tries+=1;
      delay(100);
   }

   httpRequestData += "&httpdev=0";

//  construct http request
    String httpRequest = String("GET ") + resource + "?" + httpRequestData + " HTTP/1.1\r\n" +
               "Host: " + host + "\r\n" + 
               "Connection: close\r\n\r\n";
   Serial.println(httpRequest);
   client.print(httpRequest);
  
// Read all the lines of the reply from server and print them to Serial
  Serial.println("Response:");

  /*while(client.available()){
    String line = client.readStringUntil('\r');
    Serial.print(line);
  }*/

   uint32_t timeout = millis();
  while (client.connected() && millis() - timeout < 10000L) {
    // Print available data
    while (client.available()) {
      char c = client.read();
      Serial.print(c);
      timeout = millis();
    }
  }
  Serial.println();
  
  Serial.println("End of response.");
  
//  Serial.println();
   Serial.println("closing connection");
   client.stop();
}
/*
Method to print the reason by which ESP32
has been awaken from sleep
*/
void print_wakeup_reason(){
  esp_sleep_wakeup_cause_t wakeup_reason;

  wakeup_reason = esp_sleep_get_wakeup_cause();

  switch(wakeup_reason)
  {
    case ESP_SLEEP_WAKEUP_EXT0 : Serial.println("Wakeup caused by external signal using RTC_IO"); break;
    case ESP_SLEEP_WAKEUP_EXT1 : Serial.println("Wakeup caused by external signal using RTC_CNTL"); break;
    case ESP_SLEEP_WAKEUP_TIMER : Serial.println("Wakeup caused by timer"); break;
    case ESP_SLEEP_WAKEUP_TOUCHPAD : Serial.println("Wakeup caused by touchpad"); break;
    case ESP_SLEEP_WAKEUP_ULP : Serial.println("Wakeup caused by ULP program"); break;
    default : Serial.printf("Wakeup was not caused by deep sleep: %d\n",wakeup_reason); break;
  }
}

void setup() {
  int start = millis();
  bool connected = false;
  int internet_connection_retries = 0;  
  
  // Start I2C communication
  I2CPower.begin(I2C_SDA, I2C_SCL, 400000);
  #ifdef REPORT_HUMIDITY_READINGS
    I2CHumidity.begin(I2C_SDA2, I2C_SCL2, 400000);
  #endif

  // Set serial monitor debugging window baud rate to 115200
  Serial.begin(115200);

  //Print the wakeup reason for ESP32
  print_wakeup_reason();
  
  Serial.println(String("===== Boot ") + boot_no + String(" ===== Last run took ") + run_ms + String("ms ====="));

  #define POWER_BOOST_RETRIES (5)
  #define POWER_BOOST_RETRY_DELAY (50)

  Serial.print("Keep power when running from battery");  
  bool isOk = setPowerBoostKeepOn(1);
  int power_boost_retries;
  
  for( power_boost_retries = 0; (isOk != true) && (power_boost_retries < POWER_BOOST_RETRIES); power_boost_retries++)
  {
    Serial.print(".");
    delay(POWER_BOOST_RETRY_DELAY);
    isOk = setPowerBoostKeepOn(1);
  }

  Serial.println("");
  
  Serial.println(String("IP5306 KeepOn ") + (isOk ? "OK" : "FAIL"));
  Serial.println(String("Retries: ") + power_boost_retries);
  
  pinMode(TEMPPOWER,OUTPUT);
  pinMode(MOISTUREPOWER,OUTPUT);
  #ifdef REPORT_HUMIDITY_READINGS
    pinMode(HUMIDITYPOWER,OUTPUT);
  #endif
  
  digitalWrite(TEMPPOWER,HIGH); // power on the temp sensors
  delay(100);
  
  //one wire begin
  sensors.begin();

  // get temperatures - need to test and mark to find which is which
  Serial.println("Reading temperatures...");
  sensors.requestTemperatures();
  int soil_temp_C = constrain(sensors.getTempCByIndex(0), 0, 100);
  //Serial.print("soil_temp_C=");
  //Serial.println(soil_temp_C);
  int air_temp_C = constrain(sensors.getTempCByIndex(1), 0, 100);
  //Serial.print("air_temp_C=");
  //Serial.println(air_temp_C);

  // end temp data
   
  digitalWrite(TEMPPOWER,LOW); // power off the temp sensors
   
  digitalWrite(MOISTUREPOWER, HIGH); // power on the moisture sensors
  delay(500); //why???
    
  // get moisture data
  int moisture = get_moisture();
  
  digitalWrite(MOISTUREPOWER, LOW); // power off the moisture sensors
  
  // get battery level
  float battery_voltage = get_battery_voltage();

  #ifdef REPORT_HUMIDITY_READINGS
    //get humidity
    digitalWrite(HUMIDITYPOWER, HIGH); // power on the sensor
    //delay(500); //why???
    
    sht20.initSHT20(I2CHumidity);                         // Init SHT20 Sensor
    delay(100);
    sht20.checkSHT20();                        // Check SHT20 Sensor
      
    float humidity = sht20.readHumidity();
    //Serial.print("\tHumidity: ");
    //Serial.print(humidity, 1);
    //Serial.println("%");
  
    float humidity_temp = sht20.readTemperature();      // Read Temperature
    //Serial.print("\tTemperature: ");
    //Serial.print(humidity_temp, 1);
    //Serial.println("C");
      
    digitalWrite(HUMIDITYPOWER, LOW); // power off the sensor
  #endif
  
  //connect to the internet
  #ifdef GSM
    connected = GSM_start(&internet_connection_retries);
  #endif
  #ifdef WIFI
    connected = WiFi_start(&internet_connection_retries);
  #endif

  //construct the http request data
  String httpRequestData = "_appid=" + appid
  + "&battery-voltage=" + battery_voltage
  + "&last-run_ms=" + run_ms  
  + "&boot-no=" + boot_no
  + "&power-boost-retries=" + power_boost_retries
  + "&internet-connection-retries=" + internet_connection_retries
  + "&soil-temp-C=" + soil_temp_C
  + "&air-temp-C=" + air_temp_C
  #ifdef REPORT_HUMIDITY_READINGS
    + "&humidity-temp=" + humidity_temp
    + "&humidity=" + humidity
  #endif
  + "&moisture=" + moisture;
  
  //add the mac address too
  String macAddr = WiFi.macAddress();
  //Serial.println(macAddr);
  httpRequestData = httpRequestData + "&_MAC="+macAddr;
  
  //add the last error
  httpRequestData = httpRequestData + "&last-error="+last_error;
  
  #ifdef GSM
    int signal_quality = modem.getSignalQuality();
    // add the signal quality on to the data
    httpRequestData = httpRequestData + "&signal-quality="+signal_quality;
  #endif
  
  #ifdef WIFI
    int rssi = WiFi.RSSI();   
    // add the signal quality on to the data
    httpRequestData = httpRequestData + "&rssi="+rssi;
  #endif

  //Serial.println(httpRequestData);

  // send data
  if( connected == true ) {
      //HTTP_Request_dev(httpRequestData);
      HTTP_Request(httpRequestData);
  }
  
  //disconnect    
  #ifdef GSM
    GSM_end();      
  #endif
  #ifdef WIFI
    WiFi_end();
  #endif
   
  // Configure the wake up source as timer wake up  
  esp_sleep_enable_timer_wakeup(TIME_TO_SLEEP * uS_TO_S_FACTOR);
  
  run_ms = millis() - start;   
  boot_no += 1;

  Serial.println(String("===== This run took ") + run_ms + String("ms ====="));

  //put modem to sleep?
    
  esp_deep_sleep_start();
}

void loop() {
  //this never runs
}
