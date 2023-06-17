/*
Toit Test application implements a simple ADC test for ESP32.

- Sensor: Capacitive Soil Moisture Sensor v1.2
- has analog output
- dry: Uout:3.29 V, Humidity H = 0%
- wet: Uout:1.53 V, Humidity H = 100%
*/

import .configuration     // Projektdefinitionen
import gpio
import gpio.adc
import net
import device



SoilSensorDryVoltage ::= 3.299   // H = 0 %
SoilSensorWetVoltage ::= 1.53   // H = 100 %
SoilSensorVoltageSpan ::= SoilSensorDryVoltage - SoilSensorWetVoltage


humidity uSensor -> int:
    return 100 - ((uSensor - SoilSensorWetVoltage)/SoilSensorVoltageSpan*100).to_int


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
  print HEAD + "\n"


/**
returns a string with time info
*/
getTime -> string:
    // https://libs.toit.io/core/time/class-TimeInfo
    time := Time.now.local
    return "$(%02d time.h):$(%02d time.m):$(%02d time.s).$(%03d time.ns/1000000): "

main:
    printHeader "TOIT SOIL SENSOR TEST"
    print """
    - press button to read single ADC value
    - or wait for specified timeout
    - 100 samples average value
    """


    // initialisation
    led := gpio.Pin NumGpioLed --output
    led.set 0
    pushButton := gpio.Pin NumGpioPushButton --input --pull_up
    adcIO := gpio.Pin NumGpioAdc0 --input
    adcADC := adc.Adc adcIO --max_voltage=3.3



    nSamples := 0
    print getTime + "starting application loop"
    while true:

        // read Adc
        led.set 1
        adcU := (adcADC.get --samples=1) - AdcVoltageOffsetError
        adcU100 := (adcADC.get --samples=100) - AdcVoltageOffsetError
        diff := adcU - adcU100
        sign := diff > 0 ? "+" : ""
        print getTime + "$(%3d nSamples). $(%3d humidity adcU) %,  Uadc: $(%3.3f adcU) V, (avg: $(%3.3f adcU100) V, $(sign)$(%3.3f diff))"
        led.set 0
        

        /**
            wait for push button or timeout
        */
        exception := catch --unwind=(: it != DEADLINE_EXCEEDED_ERROR):
            with_timeout --ms=AdcTimeout:
                pulse_duration := Duration.of: pushButton.wait_for 0
                sleep --ms=10 // Debounce.

                pulse_duration = Duration.of: pushButton.wait_for 1
                sleep --ms=10 // Debounce.

        nSamples += 1