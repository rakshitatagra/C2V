#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <BLEDevice.h>
#include <BLEAdvertising.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// ============================================
// YOUR SETTINGS
// ============================================
#define WIFI_SSID     "Purva's S22"
#define WIFI_PASSWORD "***REMOVED***"
#define API_KEY       "AIzaSyDyaNqqF0XRG8_VdsmvjsTY6yBnRLSUL4w"
#define USER_EMAIL    "bus_device@transit.com"
#define USER_PASSWORD "***REMOVED***"
#define DATABASE_URL  "https://transit-e86c6-default-rtdb.asia-southeast1.firebasedatabase.app/"
#define BUS_ROUTE     "BUS_402"

// ============================================
// PINS
// ============================================
#define LED_PIN    25
#define BUTTON_PIN 26

// ============================================
// FIREBASE
// ============================================
FirebaseData streamData;
FirebaseData writeData;
FirebaseAuth auth;
FirebaseConfig config;

// ============================================
// BLE
// ============================================
BLEAdvertising* pAdvertising;
bool bleRunning = false;

// ============================================
// STATE
// ============================================
bool passengerWaiting = false;
bool busArrived       = false;
bool acknowledged     = false;

unsigned long lastBlinkTime  = 0;
bool          ledState        = false;
unsigned long lastButtonPress = 0;

// ============================================
// STREAM CALLBACK
// ============================================
void onDataChange(FirebaseStream data) {
  String path = data.dataPath();
  Serial.println("Firebase changed: " + path);

  if (path == "/passenger_waiting") {
    passengerWaiting = data.boolData();
    if (passengerWaiting) {
      Serial.println("Passenger waiting — slow blink");
    } else {
      Serial.println("passenger_waiting cleared");
    }
  }

  if (path == "/bus_arrived") {
    busArrived = data.boolData();
    if (busArrived) {
      Serial.println("Bus arrived — fast blink + BLE on");
      if (!bleRunning) {
        pAdvertising->start();
        bleRunning = true;
        Serial.println("BLE broadcasting: " + String(BUS_ROUTE));
      }
    } else {
      if (bleRunning) {
        pAdvertising->stop();
        bleRunning = false;
        Serial.println("BLE stopped");
      }
    }
  }

  if (path == "/acknowledged") {
    acknowledged = data.boolData();
    if (acknowledged) {
      Serial.println("Acknowledged — LED solid");
    }
  }
}

void onStreamTimeout(bool timeout) {
  if (timeout) Serial.println("Stream timeout — reconnecting...");
}

// ============================================
// SETUP
// ============================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(LED_PIN,    OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  // Startup blinks
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(200);
    digitalWrite(LED_PIN, LOW);
    delay(200);
  }

  // WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nWiFi FAILED");
    for (int i = 0; i < 15; i++) {
      digitalWrite(LED_PIN, HIGH);
      delay(80);
      digitalWrite(LED_PIN, LOW);
      delay(80);
    }
    return;
  }

  // Firebase with authentication
  config.database_url = DATABASE_URL;
  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  // This callback prints token refresh info to Serial Monitor
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Wait for authentication to complete before proceeding
  Serial.println("Authenticating with Firebase...");
  int authAttempts = 0;
  while (!Firebase.ready() && authAttempts < 20) {
    Serial.print(".");
    delay(500);
    authAttempts++;
  }
  if (Firebase.ready()) {
    Serial.println("\nAuthenticated successfully!");
  } else {
    Serial.println("\nAuthentication FAILED — check API key and credentials");
  }

  // Start stream
  Firebase.RTDB.beginStream(&streamData, "/bus_402");
  Firebase.RTDB.setStreamCallback(&streamData, onDataChange, onStreamTimeout);
  Serial.println("Stream active");

  // BLE setup
  BLEDevice::init(BUS_ROUTE);
  pAdvertising = BLEDevice::getAdvertising();
  Serial.println("BLE ready");

  // Ready indicator — three slow blinks
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(400);
    digitalWrite(LED_PIN, LOW);
    delay(400);
  }
  Serial.println("System fully ready");
}

// ============================================
// LOOP
// ============================================
void loop() {
  Firebase.ready();

  unsigned long now = millis();

  // LED logic
  if (acknowledged) {
    digitalWrite(LED_PIN, HIGH);

  } else if (busArrived) {
    if (now - lastBlinkTime > 150) {
      ledState = !ledState;
      digitalWrite(LED_PIN, ledState);
      lastBlinkTime = now;
    }

  } else if (passengerWaiting) {
    if (now - lastBlinkTime > 900) {
      ledState = !ledState;
      digitalWrite(LED_PIN, ledState);
      lastBlinkTime = now;
    }

  } else {
    digitalWrite(LED_PIN, LOW);
    ledState = false;
  }

  // Button
  if (digitalRead(BUTTON_PIN) == LOW && now - lastButtonPress > 500) {
    lastButtonPress = now;
    Serial.println("Driver acknowledged");

    acknowledged     = true;
    passengerWaiting = false;
    busArrived       = false;

    Firebase.RTDB.setBool(&writeData, "/bus_402/acknowledged", true);

    if (bleRunning) {
      pAdvertising->stop();
      bleRunning = false;
    }

    Serial.println("Acknowledgement sent");
  }
}