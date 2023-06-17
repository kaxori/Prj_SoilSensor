// ESP32 Toit prototype

// GPIO-port definitions:
NumGpioLed ::= 2            // LED port  
NumGpioPushButton ::= 4     // Push button port
NumGpioAdc0 ::= 36          // Adc0 port

// HW check
PerformHwCheck ::= true      // true or false
AdcTimeout ::= 15_000        // default adc read intervall in ms
AdcVoltageOffsetError ::= 0.142