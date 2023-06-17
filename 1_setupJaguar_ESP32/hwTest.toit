/*
Toit Test application implements a simple HW test for ESP32.

# Install Jaguar (precondition: is installed)
- read: https://docs.toit.io/getstarted
- (current development platform is PC/Win)

# Flash ESP32
- read: https://docs.toit.io/getstarted/device
- ESP32 connected to COMx (here COM7)
- open cmd shell
- cmd: jag flash --name hwTest
- cmd: jag monitor

# run application code
- cmd: jag run hwTest.toit
- cmd: jag watch hwTest.toit

# install rebootable application code as container
- cmd: jag container install hwTest hwTest.Toit
*/
import gpio


// GPIO-port definitions:
NumGpioLed ::= 2            // LED port  
NumGpioPushButton ::= 4     // Push button port

// HW check
PerformHwCheck ::= true      // true or false

checkLed:
    print "check LED (blinks 3 times)"
    pin := gpio.Pin NumGpioLed --output

    3.repeat:
        pin.set 1
        sleep --ms=200
        pin.set 0
        sleep --ms=800

    pin.close
    print "done"

checkButton:
  print "check Button (press it 3 times)"
  pin := gpio.Pin NumGpioPushButton --input --pull_up
  count := 0

  while true:
    if pin.get == 0: 
      sleep --ms=10 // minimal sleep for every loop step
      continue

    print "Button: $count presses"

    while pin.get == 1:
      sleep --ms=20
    
    pin.wait_for 1
    count += 1
    if count >= 3:
      break

  print "Button seems to be ok\n"
  pin.close
  print "done"


main:
    print "\n\n\n#### simple ESP32 application in Toit/Jaguar ####"

    if PerformHwCheck:
        print "perform HW checks ..."
        checkLed
        checkButton

    print "setup application"
    led := gpio.Pin NumGpioLed --output
    pushButton := gpio.Pin NumGpioPushButton --input --pull_up

    print "run application (press button to turn LED on and measure time)"
    nPressed := 0
    
    while true:
        print "Button $(nPressed) times activated"
        
        //pushButton.wait_for 0
        pulse_duration := Duration.of: pushButton.wait_for 0
        print " - button pressed  after $pulse_duration.in_ms ms"
        led.set 1
        sleep --ms=20 // Debounce.

        //pushButton.wait_for 1
        pulse_duration = Duration.of: pushButton.wait_for 1
        print " - button released after $pulse_duration.in_ms ms\n"
        led.set 0
        sleep --ms=20 // Debounce.

        nPressed += 1