# Prj_SoilSensorTest

Triggered by "Digitale-Dinge" (see: www.digitale-dinge.de/blog/episode58_esp32garten for the video) i repeated the earlier setup of Toit/Jaguar in 2022. 

*If you want to test out Toit/Jaguar on ESP32, you can use these simple examples for your startup.*

## examples 
*stepwise added functionality:*
- 1_setupJaguar_ESP32
- 2_adcTest
- 3_soilSensorTest
- 4_mqttTest
- 5 small OLED added, current humidity and history diagram
- 6 firmware improvments: actionRepeater, buttonHandler


## Sensor data
### Capacitive Soil Moisture Sensor V1.2

#### measuring sensor voltages in dry/wet condition
*voltages measured with multimeter*

sensor#  | U dry [V]| U wet[V]
:---:|:---:|:---:
| | *in air* | *in water* |
| | H ~0% | H ~100% |
#1 | 3.275 | 1.56
#2|3.275|1.56
#3|3.275|1.50


## Toit/Jaguar commands
- `jag flash --name ToitTest --port COM7`
- `jag run <filename>.toit`
- `jag watch <filename>.toit`
- `jag monitor`
- `jag container install <name> <filename>.toit`

## references
- https://github.com/okaki-gardening/toit-firmware
- https://docs.toit.io/
- https://pypi.org/project/mqtt-recorder/
