/*
Test moisture sensor smoothing - 

using median for robustness
bubble sort ! and could be optimised to only sort half but not worth the confusion 

*/

// Moisture sensor
const int moisture_A2D = A0;
const int AirValue = 2475;   
const int WaterValue = 380; 

const int nReadings=7;  // must be odd
int readings[nReadings];
int reading_delay=10;

int get_moisture_pc() {
   for (int i=0;i < nReadings; i++) {
    int reading = analogRead(moisture_A2D);
    readings[i]=reading;
    Serial.println(reading);
    delay(reading_delay);
   }
   int soilMoistureValue = median(readings,nReadings);
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

void printArray(int *a, int n)
{
 for (int i = 0; i < n; i++)
 {
   Serial.print(a[i]);
   Serial.print(' ');
 }
 Serial.println();
}

int median (int *a,int n) {
// n odd
  int mid = n/2;
  bubbleSort(a,n);
  return a[mid];
}


int refresh_secs = 10; 

void setup() {
 Serial.begin(9600);
 }

void loop()
{
      int moisture_pc = get_moisture_pc();  
      Serial.print("Moisture PC ");
      Serial.println(moisture_pc);
      delay(refresh_secs*1000);
}
