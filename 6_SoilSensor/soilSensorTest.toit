/**
Soil moisture sensor application for ESP32 µC

# HW Prototype breadboard setup:
    - ESP32 (AZ-Delivery, USB connected)
    - LED (red, 100 Ohm)
    - Push button (low active)
    - OLED display 0.91\" (128x64, SSD1306, I2C)
    - Capacitive Soil Moisture Sensor v1.2 (analog)

# SW env:
    - Language: Toit
    - SDK: Jaguar V 2.0
    - IDE: VSC

# Modules:
    - soilSensorTest.toit
    - configuration.toit
    - lcdDisplay.toit

# Features
    - Wifi communication
    - NTP time service
    - MQTT broker interface
    - internal ADC with offset correction
    - soil sensor calibration
    - persistent data store
*/



// --------------------------------------------------------
// global imports
import net
import ntp
import esp32 show adjust_real_time_clock
import gpio
import gpio.adc as ADC
import device
import system.storage


// jag pkg install github.com/toitware/mqtt
// https://docs.toit.io/tutorials/mqtt
// https://github.com/toitware/mqtt/tree/main/examples
import mqtt
import encoding.json as json

// jag pkg install ringbuffer
import ringbuffer show *

// jag pkg install actionrepeater
import action_repeater show *
import button_handler show *




/*

[package.lock]
prefixes:
  buttonHandler: Button-Handler
  actionRepeater: Action-Repeater

*/
import pixel_display show *



// --------------------------------------------------------
// local imports
import .configuration
import .LcdDisplay


// --------------------------------------------------------
// Sensor calibration data
SoilSensorDryVoltage ::= 3.2   // H = 0 %
SoilSensorWetVoltage ::= 1.5   // H = 100 %
SoilSensorVoltageSpan ::= SoilSensorDryVoltage - SoilSensorWetVoltage


// --------------------------------------------------------
// global data
adc := ?
mqttClient := ?
lcd := ?
PollInterval := 60_000 // default adc read intervall in ms
nSamples := 0
nRestarts := 0
idSensor := ?



calibrateSoilSensor:
  print "Soil sensor calibration ..."
  /*
  - put sensor in dry condition 
  - wait for stable data
  - save u_dry

  - put sensor in wet condition
  - wait for stable data
  - save u_wet
  */

  print ""
  sleep --ms=5000
  print "done"


incRestarts:
  bucket := storage.Bucket.open --flash BUCKET_NAME
  try:
    exception := catch:
      nRestarts = bucket[BUCKET_KEY_RESTARTS]
    if exception:
      bucket[BUCKET_KEY_RESTARTS] = nRestarts
    else:
      bucket[BUCKET_KEY_RESTARTS] = ++nRestarts

  finally:
    bucket.close
    print "nRestarts: $(nRestarts)"

    
readSensorID -> int?:
  bucket := storage.Bucket.open --flash BUCKET_NAME
  data /int? := null
  try:
    exception := catch:
      data = bucket[BUCKET_KEY_IDSENSOR]

    if exception:
      return data

  finally:
    bucket.close
    //print "$(BUCKET_KEY_IDSENSOR): $(data)"
    return data


writeData --bucket_key/string --value:
  bucket := storage.Bucket.open --flash BUCKET_NAME
  try:
    bucket[bucket_key] = value
  finally:
    bucket.close


/*
readData --bucket_key/string --var:
  print "open data store ..."
  bucket := storage.Bucket.open --flash BUCKET_NAME
  try:
    exc := catch:
    // key not found
      var = bucket[bucket_key]
      print "nRestarts = $nRestarts"
      if var is int: var += 1
      else: nRestarts = 0
      
      bucket[bucket_key] = var
      print "nRestarts: $(nRestarts)=>saved"


    if exc:
      print "exception"
      bucket[bucket_key] = var
      print "nRestarts: $(nRestarts)=>created"

  finally:
    bucket.close
    print "bucket closed."

*/



/**
Application entry point
*/
main:
  printHeader "TOIT SOIL SENSOR TEST"
  incRestarts

  net.open

  // Welcome identification
  print """
  - press button to read single ADC value
  - or wait for specified timeout
  - 100 samples average value
  - offset error correction
  - analog soil moisture sensor connected
  - led indicates sensor data preocessing
  - interval can be change via mqtt
  - ntp time
  - actionRepeater
  - buttonHandler
  - mqtt 
  - persistent data handling
  """


  /// set local time
  set_timezone "CET-1CEST-2,M3.5.0/02:00:00,M10.5.0/03:00:00" 
  
  now := Time.now
  if now < (Time.from_string "2022-01-10T00:00:00Z"):
      result ::= ntp.synchronize
      if result:
          adjust_real_time_clock result.adjustment
          print "Set time to $Time.now by adjusting $result.adjustment"
      else:
          print "ntp: synchronization request failed"
  //else: print "time is: $now"

  print "current time is: $Time.now.local"





  idSensor = readSensorID
  print "idSensor: $(idSensor)"


  // IO initialisation
  led := gpio.Pin NumGpioLed --output
  led.set 1
  pushButton := gpio.Pin NumGpioPushButton --input --pull_up
  adcIO := gpio.Pin NumGpioAdc0 --input
  adc = ADC.Adc adcIO --max_voltage=3.3
  lcd = LcdDisplay


  // init button handler
  didButtonTest := false
  buttonHandler := ButtonHandler pushButton
    --singleClickAction= :: 
      print "test CLICK"
      
    --doubleClickAction= :: 
      print "test CLICK-CLICK"

    --trippleClickAction= :: 
      print "test CLICK-CLICK-CLICK"
      didButtonTest = true
      
    --longPressAction= :: 
      print "test LONG"

  while not didButtonTest:
    sleep --ms=1000

  led.set 0

  if idSensor == null:
    print "calibrate sensor"
    writeData --bucket_key=BUCKET_KEY_IDSENSOR --value=idSensor
    idSensor = readSensorID



  // init MQTT communication
  transport := mqtt.TcpTransport net.open --host=MqttServerAddress
  mqttClient = mqtt.Client --transport=transport
  mqttClient.start --client_id=MqttDevice

  mqttClient.publish MqttTopicState "{'state':'restarted'}".to_byte_array
  mqttClient.publish MqttTopicState "{'interval':'$(PollInterval)'}".to_byte_array


  // define repeated action for sensor data handling
  sensorAction := ActionRepeater --timeout_ms=PollInterval --action=::
      print "sensorAction"
      led.set 1   // indicate active sensor processing
      pollSensor
      nSamples += 1
      led.set 0   // clear indicator


  // init button handler
  buttonHandler.assignAction --clearAll
    --singleClickAction= :: task :: 
      print "CLICK"
      sensorAction.trigger

    --trippleClickAction= :: task ::
      print "Click-3 => calibrate ..."
      calibrateSoilSensor


  mqttClient.subscribe MqttTopicInterval:: | topic payload |
      print "Received: $topic: $payload.to_string_non_throwing"
      decoded := json.decode payload
      PollInterval = decoded.to_int
      sensorAction.repeat --timeout_ms=PollInterval
      print "PollInterval := $(PollInterval)"
      mqttClient.publish MqttTopicState "{'interval':'$(PollInterval)}',".to_byte_array


  sensorAction.start //10_000
  print "action repetition started - interval: \t$PollInterval ms"
  
  print "\n" + getTime + "starting application loop ..."

  // Idle !
  while true:
    sleep --ms=1000





/**
prints an application header
*/
printHeader appName -> none:
  HEAD ::= "o    "
  print "\n\n\n\n"+HEAD
  print HEAD + "ESP32"
  print HEAD + appName
  print HEAD
  print HEAD + "DevID: $device.hardware_id"
  print HEAD + "ID   : $DeviceName"
  print HEAD + "IP   : $net.open.address.stringify"
  print HEAD + "\n"


/**
converts the sensor voltage into relative humidity [%]
*/
humidity uSensor -> float:
    //print "uSensor: $(%1.3f uSensor) V"
    if uSensor <= 1.0 : return -1.0 // no sensor connected
    if uSensor <= SoilSensorWetVoltage: return 99.4
    if uSensor >= SoilSensorDryVoltage: return 0.1
    return 100 - ((uSensor - SoilSensorWetVoltage)/SoilSensorVoltageSpan*100)//.to_int


/**
returns a string with current time info
*/
getTime -> string:
    // https://libs.toit.io/core/time/class-TimeInfo
    time := Time.now.local
    return "$(%02d time.h):$(%02d time.m):$(%02d time.s).$(%03d time.ns/1000000): "


buffer := RingBuffer 32 //initialize the RingBuffer with a size of 32

getSmoothedAdcSample ->float:
    null
    samples := 0.0
    10.repeat:
        samples = adc.get --samples=1
        buffer.append samples
    
    //print "getSmoothedAdcSample $(%1.3f samples), avg: $(%1.3f buffer.average) std: $(%1.3f buffer.std_deviation)"

    return buffer.average
 

pollSensor -> none:
    null
    /**
    read ADC (100 samples) to get sensor voltage
    calculate humidity
    */ 
    rawAdc := adc.get --raw 
    //uSensor := CorrectedAdcVoltage (adc.get --samples=100)
    uSensor := CorrectedAdcVoltage getSmoothedAdcSample
    
    hSensor := humidity uSensor

    lcd.humidity hSensor.round

    voltageStr := "$(%1.3f uSensor)"
    humidityStr := "$(%2.1f hSensor)"

    debugMsg := getTime + "$(%3d nSamples). " 
        + "U: $(voltageStr) V, " 
        + "H: $(humidityStr) %"
    print debugMsg


    // publish collected data
    mqttClient.publish MqttTopicRawAdc "$(%04d rawAdc)".to_byte_array
    mqttClient.publish MqttTopicVoltage voltageStr.to_byte_array
    mqttClient.publish MqttTopicHumidity humidityStr.to_byte_array

    jsonMsg := "{'time':'$(getTime)', 'nSamples':$nSamples, 'voltage':$(voltageStr), 'humidity':$(humidityStr)}"
    mqttClient.publish MqttTopicSoilSensor jsonMsg.to_byte_array