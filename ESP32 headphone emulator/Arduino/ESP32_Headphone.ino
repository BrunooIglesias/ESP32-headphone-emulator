#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID        "0000FFE0-0000-1000-8000-00805F9B34FB"
#define CHARACTERISTIC_UUID "0000FFE1-0000-1000-8000-00805F9B34FB"
#define STATUS_UUID        "0000FFE2-0000-1000-8000-00805F9B34FB"
#define DOCUMENT_UUID      "0000FFE3-0000-1000-8000-00805F9B34FB"

BLECharacteristic *pCommandCharacteristic;
BLECharacteristic *pStatusCharacteristic;
BLECharacteristic *pDocumentCharacteristic;

bool deviceConnected = false;
bool isPlaying = false;
int volumeLevel = 50;  // 0-100
int batteryLevel = 100;  // 0-100
int signalStrength = 100;  // 0-100
unsigned long lastStatusUpdate = 0;
const long statusUpdateInterval = 1000;  // Update status every second (changed from 60000)
const long batteryUpdateInterval = 10000;  // Update battery every 10 seconds (changed from 300000)
unsigned long lastBatteryUpdate = 0;

// Add document buffer
String documentBuffer = "";
bool isDocumentTransferInProgress = false;

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

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = pCharacteristic->getValue();
    
    if (rxValue.length() > 0) {
      Serial.print("Received Value: ");
      Serial.println(rxValue);
      
      String response = "";
      bool shouldUpdateStatus = false;
      
      // Handle commands
      if (rxValue == "PLAY") {
        isPlaying = true;
        response = "Playing music";
        shouldUpdateStatus = true;
      }
      else if (rxValue == "PAUSE") {
        isPlaying = false;
        response = "Music paused";
        shouldUpdateStatus = true;
      }
      else if (rxValue == "VOLUME UP") {
        volumeLevel = min(100, volumeLevel + 5);
        response = "Volume increased to " + String(volumeLevel);
        shouldUpdateStatus = true;
      }
      else if (rxValue == "VOLUME DOWN") {
        volumeLevel = max(0, volumeLevel - 5);
        response = "Volume decreased to " + String(volumeLevel);
        shouldUpdateStatus = true;
      }
      else if (rxValue == "GET_STATUS") {
        response = createStatusJSON();
        shouldUpdateStatus = true;
      }
      else {
        response = "Invalid command";
      }

      // Send the response back via the characteristic
      pCharacteristic->setValue(response);
      pCharacteristic->notify();
      
      // Send an immediate status update when values change
      if (shouldUpdateStatus) {
        sendStatusUpdate();
      }
    }
  }
};

// Add new callback class for document handling
class DocumentCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = pCharacteristic->getValue();
    
    if (rxValue.length() > 0) {
      Serial.print("Received Document Chunk: ");
      Serial.println(rxValue);
      
      if (rxValue == "START_DOCUMENT") {
        Serial.println("Starting document transfer");
        documentBuffer = "";
        isDocumentTransferInProgress = true;
        pCharacteristic->setValue("Document transfer started");
        pCharacteristic->notify();
        Serial.println("Sent: Document transfer started");
      }
      else if (rxValue == "END_DOCUMENT") {
        Serial.println("Ending document transfer");
        isDocumentTransferInProgress = false;
        pCharacteristic->setValue("Document transfer completed");
        pCharacteristic->notify();
        Serial.println("Sent: Document transfer completed");
        Serial.print("📄 Final document size: ");
        Serial.println(documentBuffer.length());
        Serial.println("📄 Document content:");
        Serial.println(documentBuffer);
        // Here you could save the document to SPIFFS if needed
      }
      else if (isDocumentTransferInProgress) {
        Serial.print("Received chunk of size: ");
        Serial.println(rxValue.length());
        documentBuffer += rxValue;
        Serial.print("Current document size: ");
        Serial.println(documentBuffer.length());
        // Send acknowledgment
        pCharacteristic->setValue("Chunk received");
        pCharacteristic->notify();
        Serial.println("Sent: Chunk received");
        delay(10); // Small delay to ensure notification is sent
      }
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

// Add document sending function with chunking
void sendDocumentChunk(String chunk) {
  if (deviceConnected) {
    Serial.print("Sending document chunk of size: ");
    Serial.println(chunk.length());
    // Split large chunks if needed
    const int maxChunkSize = 20; // Maximum chunk size
    for (int i = 0; i < chunk.length(); i += maxChunkSize) {
      int endIndex = (i + maxChunkSize) > chunk.length() ? chunk.length() : (i + maxChunkSize);
      String subChunk = chunk.substring(i, endIndex);
      Serial.print("Sending sub-chunk of size: ");
      Serial.println(subChunk.length());
      pDocumentCharacteristic->setValue(subChunk);
      pDocumentCharacteristic->notify();
      Serial.println("Sent sub-chunk");
      delay(10); // Small delay to ensure notification is sent
    }
  } else {
    Serial.println("Cannot send document chunk: device not connected");
  }
}

// Add document reading function
String getDocument() {
  return documentBuffer;
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

  // Create document characteristic
  pDocumentCharacteristic = pService->createCharacteristic(
                      DOCUMENT_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );
  pDocumentCharacteristic->addDescriptor(new BLE2902());
  pDocumentCharacteristic->setCallbacks(new DocumentCallbacks());
  pDocumentCharacteristic->setValue("Document Ready");

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
  // Update status more frequently
  if (deviceConnected && (millis() - lastStatusUpdate >= statusUpdateInterval)) {
    signalStrength = random(80, 100);  // Simulate signal strength fluctuations
    sendStatusUpdate();
    lastStatusUpdate = millis();
  }

  // Update battery more frequently with realistic drain
  if (deviceConnected && (millis() - lastBatteryUpdate >= batteryUpdateInterval)) {
    // Simulate more realistic battery drain
    float drainAmount = 0.1;  // Base drain of 0.1% per 10 seconds
    
    if (isPlaying) {
      drainAmount += 0.1;  // Additional drain when playing
    }
    
    batteryLevel = max(0, batteryLevel - (int)drainAmount);
    lastBatteryUpdate = millis();
    sendStatusUpdate();  // Send immediate update when battery changes
  }
  
  delay(100);
}
