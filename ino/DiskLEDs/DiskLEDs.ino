// LED Flashing Software That Slurps Serial Input slurrrrppppp

// (c) Michael Gregorowicz MMXVII 

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Designed For The Lovely STM32F103C8T6 Blue Pill
//
// Compiler Output:
// Sketch uses 18,380 bytes (14%) of program storage space. Maximum is 131,072 bytes.
// Global variables use 3,952 bytes of dynamic memory

// send debug info back across serial, you gotta watch for it...
#define DEBUG false

// are we gonna test or what?
#define LIGHTTEST false

// the color pins are defined here
#define RED PA0
#define BLUE PA1
#define GREEN PA2

// the LED pins are defined here
#define DISK0 PB9
#define DISK1 PB8
#define DISK2 PB7
#define DISK3 PB6
#define DISK4 PB15
#define DISK5 PB14
#define DISK6 PB13
#define DISK7 PB12

// flags for a light event
#define P_DISK0 1       // disk 0, led 1 (sdb) should be lit
#define P_DISK1 2       // disk 1, led 2 (sdc) should be lit
#define P_DISK2 4       // disk 2, led 3 (sdd) should be lit
#define P_DISK3 8       // disk 3, led 4 (sde) should be lit
#define P_DISK4 16      // disk 4, led 5 (sdf) should be lit
#define P_DISK5 32      // disk 5, led 6 (sdg) should be lit
#define P_DISK6 64      // disk 6, led 7 (sdh) should be lit
#define P_DISK7 128     // disk 7, led 8 (sdi) should be lit
#define P_RED 256       // all the disks in the mask should be on and red
#define P_BLUE 512      // all the disks in the mask should be on and blue
#define P_GREEN 1024    // tall the disks in the mask should be on green
#define P_OFF 2048      // turn off all the lights
#define P_D75MS 4096    // stays in this state for 100ms (75 + 25)
#define P_D125MS 8192   // stays in this state for 150ms (125 + 25)
#define P_D475MS 16384  // stays in this state for 500ms (475 + 25)
#define P_SYNCED 32768  // check if we're in sync

// 8 disks, Read and Write LEDs, for easy access
int disks[8] = {
    DISK0, // sdb
    DISK1, // sdc
    DISK2, // sdd
    DISK3, // sde
    DISK4, // sdf
    DISK5, // sdg
    DISK6, // sdh
    DISK7  // sdi
};

int disk_flags[8] = {
    P_DISK0, // sdb
    P_DISK1, // sdc
    P_DISK2, // sdd
    P_DISK3, // sde
    P_DISK4, // sdf
    P_DISK5, // sdg
    P_DISK6, // sdh
    P_DISK7  // sdi
};

/*
 * Arduino Basics
 */

void setup() {

    // * setup serial for listening for lightup commands from the host
    Serial.begin(115200);
    Serial.setTimeout(500);

    // * set all pinMode()s, and turn all lights off
    init_leds();      

    if (LIGHTTEST) {
        pinMode(PA5, INPUT);
        randomSeed(analogRead(PA5));
        for (byte ti = 0; ti < 255; ti++) {
            int flags = 0;
            byte flip = random(10);
            if (flip <= 3) {
                flags |= P_RED;
            } else if (flip > 3 && flip <= 7) {
                flags |= P_BLUE;
            } else {
                byte fl2 = random(10);
                if (fl2 > 5) {
                    flags |= P_GREEN;
                } else if (fl2 < 3) {
                    flags |= P_BLUE | P_RED;
                } else if (fl2 == 5) {
                    flags |= P_RED | P_BLUE | P_GREEN;
                } else {
                    flags |= P_GREEN | P_RED;
                }
                
            }
            for (int i = 0; i < 8; i++) {
                byte df = random(10);
                if (df > 5) {
                    flags |= disk_flags[i];
                }
            }
            
            flags |= P_D75MS;
            
            on(flags);
        }
        all_off(NULL);
    }
}

void loop() {
    uint8_t buf[2];
    Serial.readBytes(buf, (size_t) 2);
    int flags = buf[0] | buf[1] << 8;
    
    if (flags & P_SYNCED) {
        Serial.print(0xFD, BYTE);
        on(flags);
    } else {
        // we can only be one byte off, try and get in sync by reading one more...
        uint8_t offbuf[1];
        Serial.readBytes(offbuf, (size_t) 1);
        flags = buf[1] | offbuf[0] << 8;
        if (flags & P_SYNCED) {
            // out of sync but synced.
            Serial.print(0xFE, BYTE);
            on(flags);
        } else {
            // out of sync
            Serial.print(0xFF, BYTE);
        }
    }
}

/*
 * End Arduino Basics
 */

// turn on these disks
void on (int flags) {
    int ms = 25;
    if (flags & P_D75MS) {
        ms += 75;
    }
    if (flags & P_D125MS) {
        ms += 125;
    }
    if (flags & P_D475MS) {
        ms += 475;
    }

    if (flags == P_OFF) {
        all_off(ms);
    } else {
        // activate the colors we'll be using
        set_color(flags);
        
        // now turn on the lights we're supposed to
        turn_lights_on(flags);
        
        delay(ms);
        all_off(NULL);
    }
}

void turn_lights_on (int flags) {
    if (flags & P_DISK0) {
        pinMode(DISK0, OUTPUT);
        digitalWrite(DISK0, LOW);
    }
    if (flags & P_DISK1) {
        pinMode(DISK1, OUTPUT);
        digitalWrite(DISK1, LOW);
    }
    if (flags & P_DISK2) {
        pinMode(DISK2, OUTPUT);
        digitalWrite(DISK2, LOW);
    }
    if (flags & P_DISK3) {
        pinMode(DISK3, OUTPUT);
        digitalWrite(DISK3, LOW);
    }
    if (flags & P_DISK4) {
        pinMode(DISK4, OUTPUT);
        digitalWrite(DISK4, LOW);
    }
    if (flags & P_DISK5) {
        pinMode(DISK5, OUTPUT);
        digitalWrite(DISK5, LOW);
    }
    if (flags & P_DISK6) {
        pinMode(DISK6, OUTPUT);
        digitalWrite(DISK6, LOW);
    }
    if (flags & P_DISK7) {
        pinMode(DISK7, OUTPUT);
        digitalWrite(DISK7, LOW);
    }
}

// set light color.. low == on, high == off.. i think
void set_color(int flags) {
    analogWrite(RED, 255);
    analogWrite(GREEN, 255);
    analogWrite(BLUE, 255);
    if (flags & P_RED) {
        analogWrite(RED, 0);
    }
    
    if (flags & P_BLUE) {
        analogWrite(BLUE, 0);
    }
    
    if (flags & P_GREEN) {
        analogWrite(GREEN, 0);
    }
}

// returns the number of lights it turned off
void all_off (int duration) {
    analogWrite(RED, 255);
    analogWrite(BLUE, 255);
    analogWrite(GREEN, 255);
    for (int i = 0; i < 8; i++) {
        digitalWrite(disks[i], LOW);
        pinMode(disks[i], INPUT);
    }
    delay(duration);
}

void init_leds() {
    pinMode(RED, OUTPUT);
    pinMode(BLUE, OUTPUT);
    pinMode(GREEN, OUTPUT);
    for (int i = 0; i < 8; i++) {
        pinMode(disks[i], INPUT);
    }
}

