/*
  Combined GSM and Wifi Deepsleep code for 1 moisture sennsor and 2 temperature sensors 
  
  Kit Wallace

  with acknowledgements to Rui Santos https://RandomNerdTutorials.com/esp32-sim800l-publish-data-to-cloud/
  and Ian Mitchell
  
*/

#define GSM
//#define WIFI

#include <WiFi.h>

// configuration constants

#ifdef WIFI
// WiFi credentials
const char* ssid     = "mitchsoft";
const char* password = "davethecat";
#endif

#ifdef GSM
// GPRS credentials 
const char apn[]      = "TM"; 
const char gprsUser[] = ""; 
const char gprsPass[] = ""; 

// SIM card PIN (leave empty, if not defined)
const char simPIN[]   = ""; 

#endif

// Host details
const char host[] = "kitwallace.co.uk"; 
const char resource[] = "/logger/log-data.xq";        
const int  httpPort = 80;                             

String appid = "1418";    // pin for the appid -  
String deviceid = "Tree4";   

// GPIO sensor power 
#define TEMPPOWER 13
#define MOISTUREPOWER 25

// moisture sensor
#define moisture_A2D A0

const int AirValue = 3250;   
const int WaterValue = 1320;  

// Data wire is is on Pin 14 (I/O pin) with added 4.7K pullup)
#define ONE_WIRE_BUS 14

// battery monitoring
#define battery_ADC 35

// refresh interval
#define uS_TO_S_FACTOR 1000000ULL     /* Conversion factor for micro seconds to seconds - cast as ULL to allow long sleeps  */
#define TIME_TO_SLEEP  (60)        /* Time ESP32 will go to sleep (in seconds)  */

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
  Serial.println(">>> get_moisture_pc");
   for (int i=0;i < nReadings; i++) {
    int reading = analogRead(moisture_A2D);
    readings[i]=reading;
    delay(reading_delay);
   }
   printArray(readings,nReadings);
   int soilMoistureValue = median(readings,nReadings);
   int soilMoisturePC = constrain(map(soilMoistureValue, AirValue, WaterValue, 0, 100), 0, 100);
   
   Serial.print("<<< get_moisture_pc, returning ");
   Serial.println(soilMoisturePC);
   
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

#define IP5306_ADDR          0x75
#define IP5306_REG_SYS_CTL0  0x00

#define I2C_SDA              21
#define I2C_SCL              22

#include <Wire.h>
// I2C for SIM800 (to keep it running when powered from battery)
TwoWire I2CPower = TwoWire(0);

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

bool WiFi_start() {
  int isConnetedCnt = CONNECTION_TRIES;

  Serial.print("Connecting to wifi network ");
    Serial.print(ssid);
     WiFi.begin(ssid, password);
   
     while ((WiFi.status() != WL_CONNECTED) && (isConnetedCnt >= 0)) {       
       isConnetedCnt--;
       Serial.print(".");
       delay(CONNECTION_TRY_DELAY_MS);
    }

  Serial.println("");

    if( isConnetedCnt >= 0 ) {
    
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
#define MODEM_PWKEY          4
#define MODEM_POWER_ON       23
#define MODEM_TX             27
#define MODEM_RX             26



// Set serial for AT commands (to SIM800 module)
#define SerialAT Serial1

// Configure TinyGSM library
#define TINY_GSM_MODEM_SIM800      // Modem is SIM800
#define TINY_GSM_RX_BUFFER  1024  // Set RX buffer to 1Kb

// Define the serial console for debug prints, if needed
//#define DUMP_AT_COMMANDS

#include <TinyGsmClient.h>

#ifdef DUMP_AT_COMMANDS
  #include <StreamDebugger.h>
  StreamDebugger debugger(SerialAT, SerialMon);
  TinyGsm modem(debugger);
#else
  TinyGsm modem(SerialAT);
#endif

// TinyGSM Client for Internet connection
TinyGsmClient client(modem);

bool GSM_start() {
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
       return false;
  }
  else {
    Serial.println(" connected");
    return true;
  }
}

void GSM_end() {
   modem.gprsDisconnect();
   Serial.println("GPRS disconnected");
}

#endif
#define HTTP_CLIENT_CONNECT_TRIES 20
#define HTTP_CLIENT_DELAY 10
void HTTP_Request(String httpRequestData) { 
    httpRequestData.replace(" ", "+");
    int tries = 0;
    Serial.println("Connecting to host...");
    while (tries < HTTP_CLIENT_CONNECT_TRIES) {
      if (client.connect(host, httpPort)) break;
      Serial.print(".");
      tries++;
      delay(HTTP_CLIENT_DELAY);
   }

  //exit if we cant connect to the host
  if ( tries >= HTTP_CLIENT_CONNECT_TRIES ) {
    Serial.println(" not connected");
  }
  else
  {
    Serial.println(" Connected");
  
//get the signal strength
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

  //add the mac address too
  String macAddr = WiFi.macAddress();
  //Serial.println(macAddr);
  httpRequestData = httpRequestData + "&mac="+macAddr;
  
//  construct http request
    String httpRequest = String("GET ") + resource +"?" + httpRequestData + " HTTP/1.1\r\n" +
               "Host: " + host + "\r\n" + 
               "Connection: close\r\n\r\n";
   Serial.println(httpRequest);
   client.print(httpRequest);
  
// Read all the lines of the reply from server and print them to Serial
   
  /*while(client.available()){
    String line = client.readStringUntil('\r');
    Serial.print(line);
  }*/

  }
//  Serial.println();
   //Serial.println("closing connection");
   client.stop();
}

void setup() {
  int start = millis();
  bool connected = false;

  // Start I2C communication
  I2CPower.begin(I2C_SDA, I2C_SCL, 400000);

  // Set serial monitor debugging window baud rate to 115200
  Serial.begin(115200);
  
  pinMode(TEMPPOWER,OUTPUT);
  pinMode(MOISTUREPOWER,OUTPUT);
  
  digitalWrite(TEMPPOWER,HIGH); // power on the temp sensors
  delay(100);
  //one wire begin
  sensors.begin();

  Serial.print("Keep power when running from battery ");
  int power_boost_retries = 15;
  bool isOk;
  for( isOk = setPowerBoostKeepOn(1); (isOk != true) && (power_boost_retries != 0); power_boost_retries--, isOk = setPowerBoostKeepOn(1))
  {
    Serial.print(".");
  }
    
  Serial.println(String("IP5306 KeepOn ") + (isOk ? "OK" : "FAIL"));
      
  // get temperatures - need to test and mark to find which is which
  Serial.println("Reading temperatures...");
      sensors.requestTemperatures();
      float soil_temp_C = sensors.getTempCByIndex(0);
      Serial.print("soil_temp_C=");
      Serial.println(soil_temp_C);
      float air_temp_C = sensors.getTempCByIndex(1);
      Serial.print("air_temp_C=");
      Serial.println(air_temp_C);

      Serial.println("After clipping");
      soil_temp_C = constrain(soil_temp_C, 0, 100);
      Serial.print("soil_temp_C=");
      Serial.println(soil_temp_C);
      air_temp_C = constrain(air_temp_C, 0, 100);
      Serial.print("air_temp_C=");
      Serial.println(air_temp_C);

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
    //Serial.println(httpRequestData);
  // send data
    
#ifdef GSM
    connected = GSM_start();
    if( connected == true ) {
      HTTP_Request(httpRequestData);
      GSM_end();      
    }
#endif
#ifdef WIFI
    connected = WiFi_start();
    if( connected == true ) {
      HTTP_Request(httpRequestData);
      WiFi_end();
    }    
#endif
   
  // Configure the wake up source as timer wake up  
    esp_sleep_enable_timer_wakeup(TIME_TO_SLEEP * uS_TO_S_FACTOR);
    
    run_ms = millis() - start;   
    boot_no += 1;
    
    esp_deep_sleep_start();
}

void loop() {
}
