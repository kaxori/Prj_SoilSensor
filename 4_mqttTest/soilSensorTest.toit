/*
Toit Test application implements a simple ADC test for ESP32.

- Sensor: Capacitive Soil Moisture Sensor v1.2
*/

import .configuration     // Projektdefinitionen
import gpio
import gpio.adc
import device


// jag pkg install github.com/toitware/mqtt
// https://docs.toit.io/tutorials/mqtt
// https://github.com/toitware/mqtt/tree/main/examples
import mqtt
import net
import encoding.json as json

import ntp
import esp32 show adjust_real_time_clock

SoilSensorDryVoltage ::= 2.95   // H = 0 %
SoilSensorWetVoltage ::= 1.5   // H = 100 %
SoilSensorVoltageSpan ::= SoilSensorDryVoltage - SoilSensorWetVoltage


SensorInterval := AdcTimeout


humidity uSensor -> int:
    // converts the sensor voltage into relative humidity
    //print "uSensor: $(%1.3f uSensor) V"
    if uSensor <= SoilSensorWetVoltage: return 100
    if uSensor >= SoilSensorDryVoltage: return 0
    return 100 - ((uSensor - SoilSensorWetVoltage)/SoilSensorVoltageSpan*100).to_int



// MQTT broker parameter
// https://docs.toit.io/tutorials/mqtt

MqttServerAddress ::= "192.168.178.196"
MqttPort ::= 1883


DeviceName ::= "ESP32Prototype"

MqttDomain ::= "lab"
MqttFloor ::= "dg"
MqttRoom ::= "lab"
MqttDeviceClass ::= "SoilSensor"
MqttDevice ::= "aSoilSensorPrototype"
MqttClientName ::= MqttDevice

MqttTopicHumidity ::= "$(MqttDomain)/$(MqttDevice)/humidity"
MqttTopicSoilSensor ::= "$(MqttDomain)/$(MqttDevice)/soil"
MqttTopicState ::= "$(MqttDomain)/$(MqttDevice)/state"
CLIENT_ID ::= "my-client-id-$(random)"

MqttTopicInterval ::= "$(MqttDomain)/$(MqttDevice)/interval"


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
  print HEAD + "IP   : $net.open.address.stringify"
  print HEAD + "C_ID : $CLIENT_ID"
  print HEAD + "\n"


/**
returns a string with current time info
*/
getTime -> string:
    // https://libs.toit.io/core/time/class-TimeInfo
    time := Time.now.local
    return "$(%02d time.h):$(%02d time.m):$(%02d time.s).$(%03d time.ns/1000000): "

main:
    printHeader "TOIT SOIL SENSOR TEST with MQTT"
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


    // initialisation
    led := gpio.Pin NumGpioLed --output
    led.set 0
    pushButton := gpio.Pin NumGpioPushButton --input --pull_up
    adcIO := gpio.Pin NumGpioAdc0 --input
    adcADC := adc.Adc adcIO --max_voltage=3.3


    // init communication
    //network := net.open
    //socket := network.tcp_connect MqttServerAddress MqttPort
    transport := mqtt.TcpTransport net.open --host=MqttServerAddress
    //client := mqtt.Client --transport=transport
    client := mqtt.Client --transport=transport
    client.start --client_id=CLIENT_ID


    client.subscribe MqttTopicInterval:: | topic payload |
        print "Received: $topic: $payload.to_string_non_throwing"
        decoded := json.decode payload
        SensorInterval = decoded.to_int
        print "SensorInterval := $(SensorInterval)"
        client.publish MqttTopicState "{'interval':'$(SensorInterval)}',".to_byte_array


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
    else:
        print "We already know the time is $now"


    client.publish MqttTopicState "{'state':'restart'}".to_byte_array

    client.publish MqttTopicState "{'interval':'$(SensorInterval)'}".to_byte_array

    nSamples := 0
    print getTime + "starting application loop"
    while true:

        /**
        read ADC (100 samples) to get sensor voltage
        calculate humidity
        */ 
        led.set 1
        uSensor := CorrectedAdcVoltage (adcADC.get --samples=100)
        hSensor := humidity uSensor

        voltageStr := "$(%3.3f uSensor) V"
        humidityStr := "$(%3d hSensor) %"


        debugMsg := getTime + "$(%3d nSamples). " 
            + "U: $(voltageStr), " 
            + "H: $(humidityStr)"

        print debugMsg

        jsonMsg := "{'time':'$(getTime)', 'nSamples':'$nSamples', 'voltage':'$(voltageStr)', 'humidity':'$(humidityStr)'}"

        //print jsonMsg + "\n"
        client.publish MqttTopicSoilSensor jsonMsg.to_byte_array

        led.set 0
        

        /**
            wait for push button or timeout
        */
        exception := catch --unwind=(: it != DEADLINE_EXCEEDED_ERROR):
            with_timeout --ms=SensorInterval:
                pulse_duration := Duration.of: pushButton.wait_for 0
                sleep --ms=10 // Debounce.

                pulse_duration = Duration.of: pushButton.wait_for 1
                sleep --ms=10 // Debounce.

        nSamples += 1