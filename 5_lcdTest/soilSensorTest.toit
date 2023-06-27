/*
Soil moisture sensor application for ESP32 µC

# HW Prototype breadboard setup:
    - ESP32 (AZ-Delivery, USB connected)
    - LED (red, 100 Ohm)
    - Push button (low active)
    - OLED display 0.91" (128x64, SSD1306, I2C)
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


*/


// --------------------------------------------------------
// global imports
import net
import ntp
import esp32 show adjust_real_time_clock
import gpio
import gpio.adc as ADC
import device

// jag pkg install github.com/toitware/mqtt
// https://docs.toit.io/tutorials/mqtt
// https://github.com/toitware/mqtt/tree/main/examples
import mqtt
import encoding.json as json


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
PollInterval := 5_000//60_000 // default adc read intervall in ms
nSamples := 0


/**
Application entry point
*/
main:
    net.open

    // Welcome identification
    printHeader "TOIT SOIL SENSOR TEST with MQTT and LCD"
    print """
    - press button to read single ADC value
    - or wait for specified timeout
    - 100 samples average value
    - offset error correction
    - analog soil moisture sensor connected
    - led indicates sensor data preocessing
    - interval can be change via mqtt
    - ntp time
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

  

    // IO initialisation
    led := gpio.Pin NumGpioLed --output
    led.set 1
    pushButton := gpio.Pin NumGpioPushButton --input --pull_up
    adcIO := gpio.Pin NumGpioAdc0 --input
    adc = ADC.Adc adcIO --max_voltage=3.3
    lcd = LcdDisplay


    // init MQTT communication
    transport := mqtt.TcpTransport net.open --host=MqttServerAddress
    mqttClient = mqtt.Client --transport=transport
    mqttClient.start --client_id=MqttDevice

    mqttClient.publish MqttTopicState "{'state':'restarted'}".to_byte_array
    mqttClient.publish MqttTopicState "{'interval':'$(PollInterval)'}".to_byte_array

    mqttClient.subscribe MqttTopicInterval:: | topic payload |
        print "Received: $topic: $payload.to_string_non_throwing"
        decoded := json.decode payload
        PollInterval = decoded.to_int
        print "PollInterval := $(PollInterval)"
        mqttClient.publish MqttTopicState "{'interval':'$(PollInterval)}',".to_byte_array
        


    print "poll interval: \t$PollInterval ms"
    sleep --ms=3_000
    print "\n" + getTime + "starting application loop ..."
    while true:

        led.set 1   // indicate active sensor processing
        pollSensor
        led.set 0   

        nSamples += 1
        
        /**
            wait for push button or timeout
            - ??? how to terminate button wait by message ?
        */
        exception := catch --unwind=(: it != DEADLINE_EXCEEDED_ERROR):
            with_timeout --ms=PollInterval:

                // wait for button press&release
                pushButton.wait_for 0
                sleep --ms=10 // Debounce.
                pushButton.wait_for 1
                sleep --ms=10 // Debounce.




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



pollSensor -> none:
    null
    /**
    read ADC (100 samples) to get sensor voltage
    calculate humidity
    */ 
    rawAdc := adc.get --raw 
    uSensor := CorrectedAdcVoltage (adc.get --samples=100)
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