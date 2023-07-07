// ESP32 Toit prototype

// --------------------------------------------------------
// GPIO-port definitions:
NumGpioLed ::= 2            // LED port  
NumGpioPushButton ::= 4     // Push button port
NumGpioAdc0 ::= 36          // Adc0 port

DeviceName ::= "SoilSensorPrototype"


BUCKET_NAME ::= "soil-sensor"
BUCKET_KEY_RESTARTS ::= "nRestarts"
BUCKET_KEY_IDSENSOR ::= "idSensor"


// --------------------------------------------------------
// MQTT
MqttServerAddress ::= "192.168.178.196"
MqttPort ::= 1883
MqttDomain ::= "lab"
MqttDevice ::= "aSoilSensorPrototype"

// topics
MqttTopicRawAdc ::= "$(MqttDomain)/$(MqttDevice)/rawadc"
MqttTopicVoltage ::= "$(MqttDomain)/$(MqttDevice)/voltage"
MqttTopicHumidity ::= "$(MqttDomain)/$(MqttDevice)/humidity"
MqttTopicSoilSensor ::= "$(MqttDomain)/$(MqttDevice)/soil"
MqttTopicInterval ::= "$(MqttDomain)/$(MqttDevice)/interval"
MqttTopicState ::= "$(MqttDomain)/$(MqttDevice)/state"



// --------------------------------------------------------
// for current prototype setup !
// real voltages (external measured with calibrated voltmeter)
VoltageMax ::= 3.275            // U_3V3
VoltageMin ::= 0.0              // U_GND

// Range of ADC voltages without correction
AdcVoltageMeasMax ::= 3.441     // U_3V3
AdcVoltageMeasMin ::= 0.142     // U_GND

/**
returns corrected ADC voltage
*/
CorrectedAdcVoltage uAdc:
    AdcVoltageGainError ::= (VoltageMax - VoltageMin)/(AdcVoltageMeasMax - AdcVoltageMeasMin)
    //print "uAdcRaw: $(%3.3f uAdc) V"
    return (uAdc - AdcVoltageMeasMin)*AdcVoltageGainError