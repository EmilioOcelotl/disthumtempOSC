#include <SPI.h>
#include <WiFiS3.h>
#include <ArduinoOSCWiFi.h>
#include "arduino_secrets.h"  
#include "Adafruit_VL53L0X.h"
#include <DHT.h>

// ---- CONFIG WIFI ----
char ssid[] = SECRET_SSID;
char pass[] = SECRET_PASS;
int status = WL_IDLE_STATUS;

// ---- CONFIG OSC ----
const char* host = "192.168.1.65";   // dirección del receptor (ej. tu laptop)
const int send_port = 57120;         // puerto destino OSC
const int bind_port = 54345;         // puerto local OSC (opcional si recibes)

// ---- Sensores ----
#define DHTPIN 2
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);
Adafruit_VL53L0X lox = Adafruit_VL53L0X();

// ---- Variables ----
const int numLecturas = 2;
int lecturas[numLecturas] = {0};
int indiceLectura = 0;
bool lleno = false;

const int UMBRAL_MM = 200;

float humedad = 0;
float temperatura = 0;

unsigned long ultimaLecturaDHT = 0;
const unsigned long intervaloDHT = 2000;

void setup() {
  Serial.begin(9600);
  delay(1000);

  dht.begin();
  if (!lox.begin()) {
    Serial.println(F("Error al iniciar VL53L0X"));
    while (1);
  }

  connectToWiFi();
}

void loop() {
  if (status != WL_CONNECTED) {
    connectToWiFi();
    return;
  }

  OscWiFi.update();

  // ---- LECTURA DHT ----
  unsigned long tiempoActual = millis();
  if (tiempoActual - ultimaLecturaDHT >= intervaloDHT) {
    ultimaLecturaDHT = tiempoActual;
    float h = dht.readHumidity();
    float t = dht.readTemperature();
    if (!isnan(h) && !isnan(t)) {
      humedad = h;
      temperatura = t;
    }
  }

  // ---- LECTURA VL53L0X ----
  VL53L0X_RangingMeasurementData_t measure;
  lox.rangingTest(&measure, false);

  int promedio = 0;
  int trigger = 0;

  if (measure.RangeStatus != 4) {
    int distancia = measure.RangeMilliMeter;
    lecturas[indiceLectura] = distancia;
    indiceLectura = (indiceLectura + 1) % numLecturas;
    if (indiceLectura == 0) lleno = true;

    int total = 0;
    int n = lleno ? numLecturas : indiceLectura;
    for (int i = 0; i < n; i++) total += lecturas[i];
    promedio = total / n;

    if (promedio <= UMBRAL_MM) trigger = 1;
  }

  // ---- FORMATO MENSAJE ----
  String mensaje = String(promedio) + "|" +
                   String(humedad) + "|" +
                   String(temperatura) + "|" +
                   String(trigger);

  // Imprimir en Serial
  Serial.println(mensaje);

  // Enviar vía OSC
  OscWiFi.send(host, send_port, "/sensores", mensaje);

  delay(20); // estabilidad
}

void connectToWiFi() {
  while (status != WL_CONNECTED) {
    Serial.print("Conectando a ");
    Serial.println(ssid);
    status = WiFi.begin(ssid, pass);
    delay(5000);
  }
  Serial.println("Conectado a WiFi!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
}
