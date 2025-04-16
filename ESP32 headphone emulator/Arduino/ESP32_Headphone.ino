#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID        "0000FFE0-0000-1000-8000-00805F9B34FB"
#define CHARACTERISTIC_UUID "0000FFE1-0000-1000-8000-00805F9B34FB"
#define STATUS_UUID        "0000FFE2-0000-1000-8000-00805F9B34FB"
#define DOCUMENT_UUID      "0000FFE3-0000-1000-8000-00805F9B34FB"

// GAIA service and characteristics
#define GAIA_SERVICE_UUID        "00001100-D102-11E1-9B23-00025B00A5A5"
#define GAIA_COMMAND_UUID        "00001101-D102-11E1-9B23-00025B00A5A5"
#define GAIA_RESPONSE_UUID       "00001102-D102-11E1-9B23-00025B00A5A5"
#define GAIA_DATA_UUID          "00001103-D102-11E1-9B23-00025B00A5A5"

BLECharacteristic *pCommandCharacteristic;
BLECharacteristic *pStatusCharacteristic;
BLECharacteristic *pDocumentCharacteristic;
BLECharacteristic *pGaiaCommandCharacteristic;
BLECharacteristic *pGaiaResponseCharacteristic;
BLECharacteristic *pGaiaDataCharacteristic;

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

// Image transfer variables
bool imageTransferInProgress = false;
uint32_t expectedImageSize = 0;
uint32_t receivedImageSize = 0;
const uint32_t CHUNK_SIZE = 512; // Process in 512-byte chunks
uint8_t* chunkBuffer = NULL;

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

class GaiaCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue();
        
        if (value.length() > 0) {
            const uint8_t* data = (const uint8_t*)value.c_str();
            size_t length = value.length();
            
            Serial.print("Received GAIA command: ");
            Serial.print(data[1], HEX);
            Serial.print(" with length: ");
            Serial.println(length);
            
            if (length >= 4) {
                uint8_t version = data[0];
                uint8_t command = data[1];
                uint16_t payloadLength = (data[3] << 8) | data[2];
                
                Serial.print("Command: 0x");
                Serial.print(command, HEX);
                Serial.print(", Payload length: ");
                Serial.println(payloadLength);
                
                if (command == 0x46 && length >= 8) { // Start image transfer
                    handleImageTransferStart(data + 4, payloadLength);
                }
                else if (command == 0x47 && length > 4) { // Image chunk
                    if (!imageTransferInProgress) {
                        Serial.println("Error: Received image chunk but no active transfer");
                        sendGaiaResponse(0x47, 0x01); // Error
                        return;
                    }
                    handleImageChunk(data + 4, payloadLength);
                }
            }
        }
    }
    
    void handleImageTransferStart(const uint8_t* payload, uint16_t length) {
        if (length != 4) {
            Serial.println("Error: Invalid payload length for image transfer start");
            sendGaiaResponse(0x46, 0x01); // Error
            return;
        }
        
        expectedImageSize = (payload[3] << 24) | (payload[2] << 16) | (payload[1] << 8) | payload[0];
        Serial.print("Starting image transfer, expected size: ");
        Serial.println(expectedImageSize);
        
        if (chunkBuffer != NULL) {
            free(chunkBuffer);
            chunkBuffer = NULL;
        }
        
        // Allocate buffer for processing chunks
        chunkBuffer = (uint8_t*)malloc(CHUNK_SIZE);
        if (chunkBuffer == NULL) {
            Serial.println("Failed to allocate memory for chunk buffer");
            sendGaiaResponse(0x46, 0x02); // Memory allocation error
            return;
        }
        
        imageTransferInProgress = true;
        receivedImageSize = 0;
        sendGaiaResponse(0x46, 0x00); // Success
        Serial.println("Image transfer started successfully");
    }
    
    void handleImageChunk(const uint8_t* payload, uint16_t length) {
        if (!imageTransferInProgress) {
            Serial.println("Error: No active image transfer");
            sendGaiaResponse(0x47, 0x01); // Error
            return;
        }
        
        if (chunkBuffer == NULL) {
            Serial.println("Error: Chunk buffer is NULL");
            sendGaiaResponse(0x47, 0x01); // Error
            return;
        }
        
        if (receivedImageSize + length > expectedImageSize) {
            Serial.println("Error: Received more data than expected");
            sendGaiaResponse(0x47, 0x02); // Size error
            return;
        }
        
        // Process the chunk
        memcpy(chunkBuffer, payload, length);
        receivedImageSize += length;
        
        Serial.print("Received chunk of size: ");
        Serial.print(length);
        Serial.print(" bytes. Total received: ");
        Serial.print(receivedImageSize);
        Serial.print(" of ");
        Serial.println(expectedImageSize);
        
        // Here you would process the chunk (e.g., write to SPIFFS, display, etc.)
        // For now, we'll just acknowledge receipt
        
        if (receivedImageSize == expectedImageSize) {
            // Image transfer complete
            imageTransferInProgress = false;
            Serial.println("Image transfer complete!");
            Serial.print("Final image size: ");
            Serial.println(receivedImageSize);
            
            // Free the buffer
            free(chunkBuffer);
            chunkBuffer = NULL;
        }
        
        sendGaiaResponse(0x47, 0x00); // Success
    }
    
    void sendGaiaResponse(uint8_t command, uint8_t status) {
        uint8_t response[5] = {0x10, command, 0x01, 0x00, status};
        pGaiaResponseCharacteristic->setValue(response, 5);
        pGaiaResponseCharacteristic->notify();
        
        Serial.print("Sent GAIA response: command=0x");
        Serial.print(command, HEX);
        Serial.print(", status=0x");
        Serial.println(status, HEX);
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

  // Create GAIA service
  BLEService *pGaiaService = pServer->createService(GAIA_SERVICE_UUID);

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

  // Create GAIA characteristics
  pGaiaCommandCharacteristic = pGaiaService->createCharacteristic(
      GAIA_COMMAND_UUID,
      BLECharacteristic::PROPERTY_WRITE
  );
  pGaiaCommandCharacteristic->addDescriptor(new BLE2902());
  pGaiaCommandCharacteristic->setCallbacks(new GaiaCallbacks());
  
  pGaiaResponseCharacteristic = pGaiaService->createCharacteristic(
      GAIA_RESPONSE_UUID,
      BLECharacteristic::PROPERTY_READ |
      BLECharacteristic::PROPERTY_NOTIFY
  );
  pGaiaResponseCharacteristic->addDescriptor(new BLE2902());
  
  pGaiaDataCharacteristic = pGaiaService->createCharacteristic(
      GAIA_DATA_UUID,
      BLECharacteristic::PROPERTY_WRITE |
      BLECharacteristic::PROPERTY_READ |
      BLECharacteristic::PROPERTY_NOTIFY
  );
  pGaiaDataCharacteristic->addDescriptor(new BLE2902());
  pGaiaDataCharacteristic->setCallbacks(new GaiaCallbacks());

  // Start the BLE service
  pService->start();
  pGaiaService->start();

  // Configure advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->addServiceUUID(GAIA_SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  pAdvertising->setMinInterval(0x20);    // set minimum advertising interval
  pAdvertising->setMaxInterval(0x40);    // set maximum advertising interval
  pAdvertising->setMinInterval(0x20);    // set minimum advertising interval
  pAdvertising->setMaxInterval(0x40);    // set maximum advertising interval
  BLEDevice::startAdvertising();
  
  Serial.println("BLE headphone emulator is up and running with GAIA support. Waiting for client...");
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
