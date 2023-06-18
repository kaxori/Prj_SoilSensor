// ESP32 Toit prototype

// GPIO-port definitions:
NumGpioLed ::= 2            // LED port  
NumGpioPushButton ::= 4     // Push button port
NumGpioAdc0 ::= 36          // Adc0 port

// HW check
PerformHwCheck ::= true      // true or false
AdcTimeout ::= 15_000        // default adc read intervall in ms



// real voltages (external measured with calibrated voltmeter)
VoltageMax ::= 3.275
VoltageMin ::= 0.0

// Range of ADC voltages without correction
AdcVoltageMeasMax ::= 3.441
AdcVoltageMeasMin ::= 0.142

/**
span HW-voltage (REAL) 3,27 V
span ADC 3,299 V
factor = (3,27-0)/(3,431-0,132) = 0,991

correctedVoltage ::= (uAdc - AdcVoltageMeasMin)*factor
*/
CorrectedAdcVoltage uAdc:
    AdcVoltageGainError ::= (VoltageMax - VoltageMin)/(AdcVoltageMeasMax - AdcVoltageMeasMin)
    //print "uAdcRaw: $(%3.3f uAdc) V"
    return (uAdc - AdcVoltageMeasMin)*AdcVoltageGainError