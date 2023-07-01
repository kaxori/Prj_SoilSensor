/**
    !!!! a quick and dirty !!!! implementation of Display 
*/
import gpio                 // io
import i2c                  // protocol
import ssd1306 show *       // display controller

import pixel_display show * // pixel display
import pixel_display.texture show *
import pixel_display.two_color show *
import pixel_display.histogram show *

// fonts
import font show *
import font_x11_adobe.sans_24_bold
import roboto.regular_12 as font1     // big font are with top part !!!!



LCD1306 /PixelDisplay := get_display



get_display -> PixelDisplay:
    scl := gpio.Pin 22
    sda := gpio.Pin 21
    bus := i2c.Bus
        --sda=sda
        --scl=scl
        --frequency=100_000

    devices := bus.scan
    if not devices.contains Ssd1306.I2C_ADDRESS: throw "No SSD1306 display found"

    driver := Ssd1306.i2c (bus.device Ssd1306.I2C_ADDRESS)
    //LCD1306 := TwoColorPixelDisplay driver
    return TwoColorPixelDisplay driver

/*
hello oled:
    print "hello"
    font1 := Font [font1.ASCII] 
    font1_context := oled.context --landscape --font=font1 --color=WHITE

    oled.add (oled.text font1_context 0 24 "SOIL HUMIDITY")
    oled.draw
    sleep --ms=2000
*/    


class LcdDisplay:
    //oled_ /PixelDisplay := ?
    oled_ := 0
    isInit /bool := false
    histo_ := 0
    humid_text := 0

      
    constructor:// oled_: // -> PixelDisplay:
        //print "LcdDisplay"
        oled_ = get_display
        oled_.background = BLACK
        hello oled_


    clear -> none:
        oled_.remove_all


    hello oled -> none:
        txt ::= "SOIL SENSOR"
        //print txt
        font1_context := oled.context --landscape --font=(Font [font1.ASCII] ) --color=WHITE
        oled.add (oled.text font1_context 0 24 txt)
        oled.draw
        sleep --ms=2000
        oled.remove_all

        // 
        SCALE ::= 0.64
        histo_ = TwoColorHistogram 0 0 88 64 oled.landscape SCALE WHITE
        oled.add histo_

       // font1 := Font [r12.ASCII]   //Font.get "sans16"
        text_context := oled.context --landscape --font=(Font [font1.ASCII])  --color=WHITE --alignment=TEXT_TEXTURE_ALIGN_RIGHT

        label_text := oled.text text_context 128 12 "FEUCHTE"

        sans24b := Font [sans_24_bold.ASCII]
        sans24b_context := font1_context.with --font=sans24b --alignment=TEXT_TEXTURE_ALIGN_RIGHT

        // text object
        humid_text = oled.text sans24b_context 129 64 "__"
        oled.draw
        sleep --ms=1000


    
    humidity hum/int:
        null
        //print "LcdDisplay.humidity $(%2d hum)"
        humid_text.text = "$(%2d hum)"

        // check if valid humidity
        //if 0 < hum < 100: 
        hum+=2  // draw zero line
        histo_.add hum
        //else:
        //    histo_.add 0

        oled_.draw
