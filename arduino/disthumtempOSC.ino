#include <WiFiS3.h>
#include <ArduinoOSCWiFi.h>
#include "arduino_secrets.h"  
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

// ---- Variables ----
float humedad = 0;
float temperatura = 0;

unsigned long ultimaLecturaDHT = 0;
const unsigned long intervaloDHT = 2000;

void setup() {
  Serial.begin(9600);
  delay(1000);

  dht.begin();
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

    // ---- FORMATO MENSAJE ----
    String mensaje = String(humedad) + "|" + String(temperatura);

    // Imprimir en Serial
    Serial.println(mensaje);

    // Enviar vía OSC
    OscWiFi.send(host, send_port, "/sensores", mensaje);
  }

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
