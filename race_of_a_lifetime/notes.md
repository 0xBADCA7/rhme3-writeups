
## Overview
Connect with board over serial, send it your coordinates, go somewhere. If you move too fast, you'll be disqualified, if you go to slow, you won't get there in time.

Format:
    37.430000   24.980000
    37.430000   24.980000

Destination 1:
    Delftechpark 49, 2628 XJ Delft, The Netherlands
    51.9979258  4.3834606

Binary search speed allowed:
    1 degree lat too big
    0.9 degrees lat is fine
    0.8 degrees lat is fine
    0.7 degrees lat is fine
    0.4 degrees lat is fine
    Looks like I'm allowed 100km/h

Positions are sent in degrees, but:
	* It sounds like every message is an "hour".
	* A degree of latitude is about 111km.
	* A degree of longitude is between 111, and 0, depending on latitude
	* The math to determine longitude give latitude is annoying, but easy to find and transcribe...

I got it. Given a mission to South China Sea. Time to go real
Grep for:
```
Location: 30.83 122.81
```
Know that, can take flights from:
    CDG, PVG, SFO

CDG: 49.0096906 2.5457305
SFO: 37.6213129,-122.3811494
PVG: 31.1443439,121.806079

So, need to:
    - write a semi-interactive tool, takes a destination from me, and goes there
    - relays output to me

Rest of the work is done in ``race.rb``

