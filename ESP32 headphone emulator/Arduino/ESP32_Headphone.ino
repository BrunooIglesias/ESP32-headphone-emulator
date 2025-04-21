#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID        "0000FFE0-0000-1000-8000-00805F9B34FB"
#define CHARACTERISTIC_UUID "0000FFE1-0000-1000-8000-00805F9B34FB"
#define STATUS_UUID         "0000FFE2-0000-1000-8000-00805F9B34FB"

#define GAIA_SERVICE_UUID   "00001100-D102-11E1-9B23-00025B00A5A5"
#define GAIA_COMMAND_UUID   "00001101-D102-11E1-9B23-00025B00A5A5"
#define GAIA_RESPONSE_UUID  "00001102-D102-11E1-9B23-00025B00A5A5"
#define GAIA_DATA_UUID      "00001103-D102-11E1-9B23-00025B00A5A5"

BLECharacteristic *pCommandCharacteristic;
BLECharacteristic *pStatusCharacteristic;
BLECharacteristic *pGaiaCommandCharacteristic;
BLECharacteristic *pGaiaResponseCharacteristic;
BLECharacteristic *pGaiaDataCharacteristic;

bool deviceConnected = false;
bool isPlaying = false;
int volumeLevel = 50;
int batteryLevel = 100;
int signalStrength = 100;

unsigned long lastStatusUpdate = 0;
const long statusUpdateInterval = 1000;
const long batteryUpdateInterval = 10000;
unsigned long lastBatteryUpdate = 0;

const char* HARDCODED_DOCUMENT = R"(
ESP32 Headphone Device Information
--------------------------------
Device Name: ESP32 Headphone
Firmware Version: 1.0.0
Hardware Version: 1.0
Bluetooth Version: 4.2
Battery Type: Li-ion
Battery Capacity: 1000mAh
Audio Codec: SBC
Supported Profiles: A2DP, AVRCP
Equalizer Presets: 5
Max Volume: 100
Current Status: Connected
Last Update: 2024-04-16
)";

String createStatusJSON() {
  return String("{\"playing\":")
         + (isPlaying ? "true" : "false")
         + String(",\"volume\":") + String(volumeLevel)
         + String(",\"battery\":") + String(batteryLevel)
         + String(",\"signal\":") + String(signalStrength)
         + String("}");
}

void sendStatusUpdate() {
  if (deviceConnected) {
    String js = createStatusJSON();
    pStatusCharacteristic->setValue(js);
    pStatusCharacteristic->notify();
  }
}

class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    sendStatusUpdate();
  }
  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    BLEDevice::startAdvertising();
  }
};

class MyCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) override {
    String rx = pCharacteristic->getValue();
    String resp;
    bool upd = false;
    if      (rx == "PLAY")        { isPlaying = true;  resp = "Playing"; upd = true; }
    else if (rx == "PAUSE")       { isPlaying = false; resp = "Paused";  upd = true; }
    else if (rx == "VOLUME UP")   { volumeLevel = min(100, volumeLevel + 5); resp = "VOL " + String(volumeLevel); upd = true; }
    else if (rx == "VOLUME DOWN") { volumeLevel = max(0, volumeLevel - 5); resp = "VOL " + String(volumeLevel); upd = true; }
    else if (rx == "GET_STATUS")  { resp = createStatusJSON(); upd = true; }
    else                          { resp = "Invalid"; }
    pCharacteristic->setValue(resp);
    pCharacteristic->notify();
    if (upd) sendStatusUpdate();
  }
};

class GaiaCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) override {
    String val = pCharacteristic->getValue();
    const uint8_t* data = (const uint8_t*)val.c_str();
    size_t len = val.length();
    if (len >= 5 && data[0] == 0x10) {
      uint8_t cmd = data[1];
      uint16_t plen = (data[3] << 8) | data[2];
      if (cmd == 0x46 && plen == 1 && data[4] == 0x02) {
        size_t docLen = strlen(HARDCODED_DOCUMENT);
        const size_t CHUNK = 12;
        for (size_t off = 0; off < docLen; off += CHUNK) {
          size_t sz = min(CHUNK, docLen - off);
          uint8_t packet[4 + sz];
          packet[0] = 0x10;
          packet[1] = 0x47;
          packet[2] = sz & 0xFF;
          packet[3] = (sz >> 8) & 0xFF;
          memcpy(packet + 4, HARDCODED_DOCUMENT + off, sz);
          pGaiaDataCharacteristic->setValue(packet, 4 + sz);
          pGaiaDataCharacteristic->notify();
          delay(10);
        }
        uint8_t r[5] = {0x10, 0x46, 0x01, 0x00, 0x00};
        pGaiaResponseCharacteristic->setValue(r, 5);
        pGaiaResponseCharacteristic->notify();
      }
    }
  }
};

void setup() {
  Serial.begin(115200);
  BLEDevice::init("ESP32_Headphone");
  BLEServer *srv = BLEDevice::createServer();
  srv->setCallbacks(new MyServerCallbacks());
  BLEService *svc  = srv->createService(SERVICE_UUID);
  BLEService *gsvc = srv->createService(GAIA_SERVICE_UUID);

  pCommandCharacteristic = svc->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pCommandCharacteristic->addDescriptor(new BLE2902());
  pCommandCharacteristic->setCallbacks(new MyCallbacks());
  pCommandCharacteristic->setValue("Ready");

  pStatusCharacteristic = svc->createCharacteristic(
    STATUS_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pStatusCharacteristic->addDescriptor(new BLE2902());
  pStatusCharacteristic->setValue(createStatusJSON());

  pGaiaCommandCharacteristic = gsvc->createCharacteristic(
    GAIA_COMMAND_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pGaiaCommandCharacteristic->addDescriptor(new BLE2902());
  pGaiaCommandCharacteristic->setCallbacks(new GaiaCallbacks());

  pGaiaResponseCharacteristic = gsvc->createCharacteristic(
    GAIA_RESPONSE_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pGaiaResponseCharacteristic->addDescriptor(new BLE2902());

  pGaiaDataCharacteristic = gsvc->createCharacteristic(
    GAIA_DATA_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pGaiaDataCharacteristic->addDescriptor(new BLE2902());

  svc->start();
  gsvc->start();
  BLEDevice::getAdvertising()->addServiceUUID(SERVICE_UUID);
  BLEDevice::getAdvertising()->addServiceUUID(GAIA_SERVICE_UUID);
  BLEDevice::startAdvertising();
}

void loop() {
  if (deviceConnected && millis() - lastStatusUpdate >= statusUpdateInterval) {
    signalStrength = random(80, 100);
    sendStatusUpdate();
    lastStatusUpdate = millis();
  }
  if (deviceConnected && millis() - lastBatteryUpdate >= batteryUpdateInterval) {
    batteryLevel = max(0, batteryLevel - 1);
    sendStatusUpdate();
    lastBatteryUpdate = millis();
  }
  delay(100);
}
