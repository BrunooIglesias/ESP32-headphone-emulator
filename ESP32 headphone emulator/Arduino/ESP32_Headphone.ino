#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Use standard BLE service UUIDs for better compatibility
#define SERVICE_UUID        "0000FFE0-0000-1000-8000-00805F9B34FB"
#define CHARACTERISTIC_UUID "0000FFE1-0000-1000-8000-00805F9B34FB"
#define STATUS_UUID        "0000FFE2-0000-1000-8000-00805F9B34FB"

// Global pointers to BLE characteristics
BLECharacteristic *pCommandCharacteristic;
BLECharacteristic *pStatusCharacteristic;

// Variables to track device state
bool deviceConnected = false;
bool isPlaying = false;
int volumeLevel = 50;  // 0-100
int batteryLevel = 100;  // 0-100
int signalStrength = 100;  // 0-100
unsigned long lastStatusUpdate = 0;
const long statusUpdateInterval = 1000;  // Update status every second

// Forward declarations
String createStatusJSON();
void sendStatusUpdate();

// Callback class for handling client connection and disconnection events
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("Client connected");
    // Send initial status update
    sendStatusUpdate();
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Client disconnected");
    // Restart advertising
    BLEDevice::startAdvertising();
  }
};

// Callback class for handling incoming writes (commands) to the characteristic
class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = pCharacteristic->getValue();
    
    if (rxValue.length() > 0) {
      Serial.print("Received Value: ");
      Serial.println(rxValue);
      
      String response = "";
      
      // Handle commands
      if (rxValue == "PLAY") {
        isPlaying = true;
        response = "Playing music";
      }
      else if (rxValue == "PAUSE") {
        isPlaying = false;
        response = "Music paused";
      }
      else if (rxValue == "VOLUME UP") {
        volumeLevel = min(100, volumeLevel + 5);
        response = "Volume increased to " + String(volumeLevel);
      }
      else if (rxValue == "VOLUME DOWN") {
        volumeLevel = max(0, volumeLevel - 5);
        response = "Volume decreased to " + String(volumeLevel);
      }
      else if (rxValue == "GET_STATUS") {
        response = createStatusJSON();
      }
      else {
        response = "Invalid command";
      }

      // Send the response back via the characteristic
      pCharacteristic->setValue(response);
      pCharacteristic->notify();
    }
  }
};

// Function implementations
String createStatusJSON() {
  return "{\"playing\":" + String(isPlaying ? "true" : "false") +
         ",\"volume\":" + String(volumeLevel) +
         ",\"battery\":" + String(batteryLevel) +
         ",\"signal\":" + String(signalStrength) + "}";
}

void sendStatusUpdate() {
  if (deviceConnected) {
    String status = createStatusJSON();
    pStatusCharacteristic->setValue(status);
    pStatusCharacteristic->notify();
  }
}

void setup() {
  Serial.begin(115200);
  
  // Initialize BLE and set a device name that mimics a headphone
  BLEDevice::init("ESP32_Headphone");
  
  // Create the BLE server and assign the connection callbacks
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create command characteristic
  pCommandCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );
  pCommandCharacteristic->addDescriptor(new BLE2902());
  pCommandCharacteristic->setCallbacks(new MyCallbacks());
  pCommandCharacteristic->setValue("Headphone Ready");

  // Create status characteristic
  pStatusCharacteristic = pService->createCharacteristic(
                      STATUS_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );
  pStatusCharacteristic->addDescriptor(new BLE2902());
  pStatusCharacteristic->setValue(createStatusJSON());

  // Start the BLE service
  pService->start();

  // Configure advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  pAdvertising->setMinInterval(0x20);    // set minimum advertising interval
  pAdvertising->setMaxInterval(0x40);    // set maximum advertising interval
  pAdvertising->setMinInterval(0x20);    // set minimum advertising interval
  pAdvertising->setMaxInterval(0x40);    // set maximum advertising interval
  BLEDevice::startAdvertising();
  
  Serial.println("BLE headphone emulator is up and running. Waiting for client...");
}

void loop() {
  // Simulate battery drain and signal strength changes
  if (millis() - lastStatusUpdate >= statusUpdateInterval) {
    batteryLevel = max(0, batteryLevel - 1);  // Decrease battery by 1% every second
    signalStrength = random(80, 100);  // Simulate signal strength fluctuations
    
    // Send status update
    sendStatusUpdate();
    lastStatusUpdate = millis();
  }
  
  delay(100);
}
