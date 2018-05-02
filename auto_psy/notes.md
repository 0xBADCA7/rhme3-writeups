
## Auto-Psy
Our previous experiment proves that the DeLorean is indeed a functional time machine; we need to recover the secrets behind this technology. Our technicians successfully isolated the cluster of ECUs containing the time travel technology. We have also found a data SDcard connected to the cluster. The data, however, is encrypted - and that’s where you come in. We need you to obtain access and extract the secret key which must be stored somewhere inside the ECUs. This ECU cluster appears to contain only one microprocessing unit. We believe this unit contains the functionality of several ECUs, together with a gateway, or gateways, managing traffic between the relevant interfaces. The bus containing the cluster also included a legacy external OBD-II port, which we believe may have been used by vehicle mechanics for diagnostic purposes.
Note that the vehicle dashboard is probably no longer of use at this point.

Best of luck.

## References
https://en.wikipedia.org/wiki/OBD-II_PIDs
https://en.wikipedia.org/wiki/Unified_Diagnostic_Services
https://automotive.wiki/index.php/ISO_14229
	- includes UDS error list

http://lup.lub.lu.se/luur/download?func=downloadFile&recordOId=8871228&fileOId=8871229
	- details on UDS communication sequences

## Candump
Note: serial is empty. No traffic.

When split, I only see traffic on can0.
Split Traffic:
(3925.369) can0 7E5#0209000000000000
(3925.874) can0 7E5#02090A0000000000
(3927.388) can0 7E5#0201000000000000
(3927.893) can0 7E5#02010D0000000000
(3928.903) can0 7DF#0201000000000000
(3929.407) can0 7DF#0201200000000000
(3929.912) can0 7DF#0201400000000000
(3930.417) can0 7DF#0201420000000000

That's basically it.

When linked, I see the following:
	* order not preserved
	* unique messages only

can0: (4190.195) 7E5#02:09000000000000
can1: (4190.208) 7ED#06:49004040000000

can0: (4185.653) 7E5#02:090A0000000000
can1: (4185.666) 7ED#1016:490A50777254 I.PwrTrain_Ctrl
can1: (4185.670) 7ED#21:7261696E5F4374 (cont)
can1: (4185.675) 7ED#22:726C0000000000 (cont)
can1: (4185.680) 7ED#23:00000000000000

can0: (4186.662) 7E5#02:01000000000000
can1: (4186.675) 7ED#06:41000008000300

can0: (4187.167) 7E5#02:010D0000000000
can1: (4187.180) 7ED#03:410D8D00000000


can0: (4193.729) 7DF#02:01000000000000
can1: (4193.742) 7ED#06:41000008000300

can0: (4193.729) 7DF#02:01200000000000
can1: (4193.742) 7ED#06:41200000000100

can0: (4194.234) 7DF#02:01400000000000
can1: (4194.247) 7ED#06:41404000001000

can0: (4194.234) 7DF#02:01420000000000
can1: (4194.247) 7ED#04:41422ee0000000

## Ben's Take
	0. understand UDS
	1. set up a security session
	2. memory read

PS: scapy does UDS, I'm seeing fragments of a ISO-TP

## UDS research

### BLG-Notes.pptx

#### Vehicle Diagnostics: ISO 15765-2 Frames

Four Types of Frames:
	Single Frame
	Multi-Frame
	Consecutive Frame
	Flow Control Frame

First Byte of CAN Frame is Byte One of the PCI Data.

Byte One has Two Parts:
	High Nibble
	Low Nibble

If High Nibble is:
	0 = Single Frame
	1 = Multi-Frame
	2 = Consecutive Frame
	3 = Flow Control

Examples:
	7E0 02 01 03 00 0 00 00 00 00
	7E0 10 14 09 02 01 31 31 31 31
	7E0 21 32 33 34 35 36 37 38
	7E0 30 00 0A 00 00 00 00 00

Low nibble is the data length ***of the message itself not of transport-level request/response*** e.g low-nibble==2 for 7e0 02 01 03 00 0 00 00 00 00

Above 01 03  is the request PID. e.g 09 02 for VIN

OBDII mandates +8 arb id for response. But response ID rules vary for OEMs in extended diagnostics.

OBDII mandates that adding 0x40 to the original request ID indicates success
e.g. 
Request 7e0 02 09 02 000…
Response 7e8 10 14 49 02 01 XX XX XX
(0 14 is multi-frame message length)
(01 is VIN-specific format)

[Then the requested sends a flow-control frame within 100ms]
Request 7e0 3Y ZZ WW 00 00 00
	(Y is CTS/DNS: 0 is clear to send, 1 is stop)
	(ZZ is frame separation. How many more response frames to send before expecting another flow control frame)
	(WW is separation time. How many ms to wait between each response frame send)

Response 7e8 2R XX XX XX XX
	(R is a rolling counter, 1 for this response ++ for each after)

#### Vehicle Diagnostics: Diagnostic Response Messages

Response Messages come back on a Different Arbitration ID

This ID is typically +8 of the Request ID, but does not have to be

Three Types of Responses:
	Positive Response
	Negative Response
	No Response

Responses Usually will come within 100ms or less of the request

Response Types – Positive Response Example: 
	Rqst: 0x7E0 02 01 2F
	Rsp:  0x7E8 03 41 2F FF

Response Types – Negative Response Example:
	Rqst: 0x7E0 02 01 2E
	Rsp:  0x7E8 03 7F 01 12

Response Types – No Response Example:
	Rqst: 0x7E0 02 7E 01
	Rsp:  (None)

“No Response” is the worst because you have to wait the mandatory 100ms delay. This can really slow down fuzzing.

Imagine if
request 7e0 02 15 7f
	(15 as a service doesn’t mean anything in diags)
Response 7e8 03 7f 15 XX 
	(15 is echoed in the error)
	(XX is an NRC – negative response code)

#### Vehicle Diagnostics: Hands On – OBDII (J1979)

Using Scripts and Transmit Messages:
	Find what Modes are Supported
	Find what PIDs are Supported for those Modes

HINT: 0x7E0 is to Address and 0x7E8 is the Response Address

ALSO: Don’t Forget Message Format: 0x7E0 02 01 00 

REMBER: Stop at Mode 0x0F

List of OBDII Modes (Services):
	01 – Request Current Powertrain Diagnostic Data
	02 – Request Powertrain Freeze Frame Data
	03 – Request Emission-Related DTCs
	04 – Clear/Reset Emission-Related DTCs
	05 – Request O2 Sensor Monitoring Test Results
	06 – Request On-Board Monitoring Test Results for Specific Monitored Systems
	07 – Request Emission-Related DTCs Detected During Current or Last Completed Driving Cycle
	08 – Request Control of On-Board Systems, Test or Component
	09- Request Vehicle Information
	0A – Request Emission-Related DTCs with Permanent Status

Goal: see which services this controller supports

Create a new Transmit message. In messages editor. Set 7e0 as arb id. Name fuxx for services.

Set B1 01 B2 00. We will use B2 as the service for fuzzing. We will increment B2 by using a script.

Create a new script. Add a new function block. Called fuzz for services

1 set value B2 to 00 [ select the tx message and select the Message B2 property. Assign to 0 ]
2 start a loop 256 times
3 Transmit  the message
4 wait for 10ms
5 set value B2 + 1 [ select as above. Set expression to the same as value and append “ + 1 “ ]
6 end the last loop
7 stop

Go back to messages view and use 8e? As a filter to see responses.

Lab: make that script work and use the results to answer: what services are supported?

We got one weird response: “03 7f 3d 11 55 55 55 55”. Others were clearly errors with NRCs

Instructor solution: filter “?? 7F *” shows only negative responses. 

Instructor solution: finding only negative responses with NRC 11. Make a message filter. Message editor receive. Add . Name it. Set the bytes of interest. Then go to filter and select the new messaeg we created. The filter can be used by first checking ‘networking’ to select something first and then exclude the filter.

There were services that had non-11 NRCs there was also one positive response. “02 7e 00 55 55 55 55 55” ; therefore service 7e – 40 == 3e is supported.

#### * Vehicle Diagnostics: ISO 14229 a.k.a. Universal Diagnostic Services

List of Services support by UDS
	10 – Diagnostic Session Control - YES
	11 – ECU Reset - YES
	14 – Clear DTCs
	19 – Read DTCs
	22 – Read Data by ID - YES
	23 – Read Memory by Address - YES
	24 – Read Scaling by ID
	27 – Security Access* - YES
	28 – Communication Control - YES
	2A – Read Data by DID
	2C – Dynamically Controlled ID
	2E – Write Data by ID
	2F – Input Output Control* - YES
	31 – Routine Control
	34 – Request Download
	35 – Request Upload
	37 – Request Transfer Exit
	3D – Write Memory by Address
	BA - YES
	3E - YES
	And more…

#### Vehicle Diagnostics: Hands On: ISO 14229

Scan for Supported Services (10-FF)

Scan for Supported PIDs on Service 22

Note the differences between these PIDs and the PIDs found with OBDII Scans

Document the Services that are supported, you’ll need them later

Let’s take a specific service and drill down to see what sub functions are supported.

On the desktop of the lab PC there is a iso 14229 spec. The simulator here in the lab is using it. There is a list of all services. Let’s look at “read data by identifier”

Read Data by id takes a subfuinction “dataIdentifier” which is 6 bytes long. All bytes can take all possible values in 00-ff.

We are going to brute-force all the possible subfunction values.

Make a new trans message in the message editor. Set Arb id 7e0. 8 byte length. Single frame request. B1 03 B2 22 B3 XX B4 XX. We want to group XXXX. We need to add a signal to this message. Add 16bit signal , drag to bytes 3-4. Name it ‘PID’. Thus as we increment ‘PID’ spy will handle high and low bytes.

Make a script.

1 Set Value of the new tx message PID signal to 0
2 loop 65536
3 transmit new message
4 wait for 10ms
5 set value of the new tx message PID to PID + 1
6 end loop
7 stop

Go back to messages view, make it clear. 

Set the start type of the scripts to manual.

Look through for positive reponses.

---

We had to increase the messages buffer to 900000 by clicking the ‘setup…’ button in messages view. Ran the script and set a filter for “?? 62 *” . ?? To accept any response length. 62 because it is 22 + 40. We got three matching frames:

“04 62 00 0d 51 55 55 55”
“06 62 10 01 00 00 00 55”
“06 62 32 50 00 00 01 55”

#### Vehicle Diagnostics: Service $10 – Start Diagnostics

Used to change Diagnostic Mode.
	Typically between three unique modes:
		Standard OBDII
		Programming Mode
		Enhanced Mode

Required for most enhanced diagnostic request

Programming Mode is used for Reflashing the Controller

For nearly all enh diagnostics you *must* set the $10 service request first. 

***NB: If ECU reset is not available as a service. You can reset the controller by commanding the controller into and then out of programming mode.***

#### Vehicle Diagnostics: Service $2E or $3B – Write Data by ID

Used for:
	Programming configuration information like VIN and Simple Calibrations
	Clearing non-volatile memory
	Setting Options

UDS and KWP: Service ID $2E
	7E0 05 2E 12 34 FE DC 00 00

GMLAN: Service ID $3B
	7E0 04 3B 12 FE DC 00 00 00

NB: some writable regions are locked based on the number of ignition key cycles. i.e. new cars can have theirs re-written  up until a point where they cross the threshold.

#### Vehicle Diagnostics: Service $23 – Read Memory by Address

Used to Read the Values stored in RAM or ROM

Service ID $23 for UDS, KWP and GMLAN

UDS 
	1 Byte (Sub) Variabe Address and Length Format (e.g. 0x14 = 1 byte for Size of Memory. 4 bytes for Memory Address Size)
	2-4 Bytes (as specified) for Memory Address
	1-2 Byte (as specified) for byte to be returned by request

	7E0 07 23 14 12 34 56 78 FE

KWP
	3 Bytes for Memory Address (Typically a pseudo address)
	1 Byte for Bytes returned by request

	7E0 04 23 12 34 56 FE 00 00

GMLAN
	3 or 4 Bytes for Memory Address
	2 Bytes for Bytes returned by request

	7E0 06 23 12 34 56 FE DC 00
	7E0 07 23 12 34 56 78 FE DC

e.g. 7e0 DD 23 XY A…A L…L
DD – variable length
X size of memory request – size in bytes of how many bytes you want returned back
Y size of memory address in bytes (this width influences the DD variable length field)
A address (number of bytes as per Y)
L length of read (number of bytes as per X)

NB: If you try an XY that is not supported you will get a response 13 (inv format) or 31 (request out of range)

A good response might be something like 7e8 05 63 00 00 00 00

NB: this does not include the address requested in the response
NB: for some XY the $23 request is a multi-frame message . E.g. X=2 Y=4
---

Lab: 1) figure out to correct value for XY for the given controller.

Create a transmit message. Call it ‘memory read’ . Length 8 B1 01 B2 23 B3 00 B4 00 B5 00 B6 00 B7 00 B8 00 (all init 00 because they are variable). Select ISO15765-2 for multi column. Update the B’s now – 01 above is part of ISO-TP, omit it. B1 23 B2 00 B4 00 …. Now also the message size is the ISO-TP size. 

***NB: b/c vehicle spy doesn’t pad automatically for ISO-TP messages you must click multiframe-setup button and select padding for 00.***

We’ll make a script. Call it ‘find memory read sub function’ (sub function == ‘sizes’). We want to do two tings. 1) set the memory read initially to 0x11 and 2) update the message size . Create two signals: B1 high and low nibbles. Called “Return Size” and “Memory address size”, respectively.

1 set value B2 high to 1
2 set value B2 low to 1
3 start a loop , run 4 times
4 start a loop, run 4 times
5 transmit the memory read message
6 increment “return size”
7 increment “memory address size”
8 wait 10ms
9 End loop
9 end loop
10 stop

You’ve detected the right size parameters when you get a 31 (out of range) error instead of the 13 (invalid request error)

---

Make a script to dump memory using ‘12’ parameters

We found that the region 0x8000 to 0x8100 and there was one non-zero value at 0x8074 of 0xCf24

#### Vehicle Diagnostics: Service $11 – ECU Reset

Service ID $11

Often a source of initialization Errors

Needed for Reflashing

UDS:
	1 Byte Subfunction:
		0x01 – Hard Reset
		0x02 – KeyOnOffReset
		0x03 – Soft Reset

KWP
	1 Byte Subfunction
	0x01 – Power ON Reset
	0x82 – NVR Reset

GMLAN
	No Such Function
	Reset occurs after Reflash

#### Hands On: Input Output Control

Device Control Service on UDS is 2F

Make a new tx msg. 7e0 8 length “04 2F 00 00 03”

03 is temporary turn-on

NB: positive resp on “?? 6f*” b/c service is 2f

A 7f is ‘service not supported in active session’ . We need to send a ‘start diagnostics’ command. We need to send for an extended diagnostics session

Make a new tx msg. “start enh diag” “7e0” length 8  “02 10 03”

Make a script that send the start enh diag and also fuzzes the IO control

We found that IO code 0x2150 gave a positive result. As well as 0x3250

#### Hands On: Security Access

Use Service 27 to Send a Seed Request to the Module

Did you get the Seed?

Was the Seed Static or Dynamic?

How Many Bytes was the Seed?

Did you get a Negative Response?

There can be multiple levels of security

First thing we need to do is get the seed. There will be seed requests for the different levels.

7E0 02 27 01

02 is ‘get seed’
01 is the level

Response 
7e8 04 67 01 YYYYYYY

01 is an echo of the level request

Then apply some secret alg of YYYYYY to get the right unlock response ZZZZZ

Then send the next even number with the key
e.g. 7e0 04 27 02 ZZZZZ

Then either correct “7e8 02 67 02” or incorrect “7e8 03 7f 27”

What happens when you send a bad key? The NRC is definitely the first. There is tracking of the number of attempts and if you exceed this number then you get a 37 code exceedNummberOfAttempts. You may need to reset the ECU at this point.

Remember that if you get a 7f error , you need to start diagnostics
--- Lab 

Send a seed request. Make a new tx message “7e0 “ len 8 “ 04 27 02 00 00”

I got a response “7e8 04 67 01 3d 1b 55 55 55” so got seed 0x3d1b

I did a memory dump and found 3d 1b cf 24 in memory at 0x8074

So the seed is there. Could cf 24 be the key?

### day2 labs.vs3 

A vehicle spy save file; I used it during the class to win the class challenge. This was 1) dump memory without a security session 2) idenfity interesting values in the memory space , one ended up being a key 2) initiate a security session ; xor the key with the seed and use that as a response 3) win

Extracting some CAN frame bytes from the vehicle spy XML:
* seed request message: `7E0 02 27 01`
* send key: `7E0 04 27 02 00 00`
* enhanced diagnostics enable: `7E0 02 10 03`
* IO control fuzzer: `7E0 04 2F 00 00 03`
* mem read fuzzer: `7E0 05 23 12 00 00 04`
* memory read: `7E0 23 00 00 00 00`
* svcs subfunction fuzzer: `7E0 03 22 00 00`
* svcs enum: `7E0 01 00`
* seed: `7E8 XX 67 01 XX XX'
* mem read error: `7E8 03 7F 23 13 XX XX XX XX`
* neg response: `7E8 03 7F XX 11`

### BLG-Notes.pptx, page 63-6

Format:
	byte length, bytes data
	or
	byte 10 = multi-frame
	byte length, bytes data
	byte 2x = fragment, bytes data

Examples:
	7e0#01:28 -> service $28 - communications control
	7e0#02:2701 - get seed for Security Access (possibly 2702?)
	-> 7e8#04: 67 01 YYYY - the seed?
	7e0#04:27 02XXXX - send secret code
	-> 7e8:02 6702 - correct
	-> 7e8:03 7f27 - wrong
	- possibly it tracks number of attempts and you'd need to reset if exceeded

What we have might be a custom variant
### Online References
https://hackaday.com/2013/10/29/can-hacking-protocols/
	- service ids
	- CAN frame format
https://automotiveembeddedsite.wordpress.com/uds/
	- more details
https://en.wikipedia.org/wiki/ISO_15765-2
	- correct framing rules

## Can Setup
ip link show dev can0
sudo ip link set can0 type can bitrate 49500 listen-only off
sudo ip link set can0 up
candump -cae can0,0:0,#FFFFFFFF

## Message Breakdown
can0: (4185.653) 7E5#02:090A0000000000
can1: (4185.666) 7ED#1016:490A50777254 I.PwrTrain_Ctrl
can1: (4185.670) 7ED#21:7261696E5F4374 (cont)
can1: (4185.675) 7ED#22:726C0000000000 (cont)
can1: (4185.680) 7ED#23:00000000000000

7e5# 0 -- single-frame
     2 -- 2 data bytes
	09 -- service id: 9
	0a -- sub-function id: 10  (note: high bit is "response required")
7ed# 1 -- multi-frame response
   016 -- expect 0x16 = 22 bytes of payload
	 4 -- I am responding...
	 9 -- to requested service id 9
	0a -- sub-function id
	... -- data

Note: for negative responses use Service ID 0x7F / requested service id / response code

## What we see
Queries from 7e5 and 7df
Responses from 7ed

System 0x01
	subs: 00, 0d, 20, 40, 42
System 0x09
	subs: 00, 0a

## UDS SIDs of interest
	SID 10 - Diagnostic Session Control!
	SID 11 - ECU reset
	SID 27 - Security Access
	SID 35 - Request Upload
	SID 36 - Transfer Data
	SID 37 - Request Transfer Exit
	SID 3e - Tester Present (I'm still here...)

## UDS Errors
	11 - serviceNotSupported, (whole SID is bad)
	12 - subFunctionNotSupported
	13 - incorrectMessageLengthOrInvalidFormat
	22 - conditionsNotCorrect (server isn't happy)
	24 - requestSequenceError (do something else first)
	31 - requestOutOfRange
	33 - securityAccessDenied
	35 - invalidKey
	36 - exceedNumberOfAttempts
	37 - requiredTimeDelayNotExpired
	71 - transferDataSuspended
	73 - wrongBlockSequenceCounter

## Fuzzing
7df#02090a0000000000
	- is a valid system/sub pair, but gets triple responses
  can0  7E8   [8]  10 16 49 0A 46 6C 78 43   '..I.FlxC'
  can0  7E8   [8]  21 61 70 5F 47 61 74 65   '!ap_Gate'
  can0  7E8   [8]  22 77 61 79 00 00 00 00   '"way....'

  can0  7ED   [8]  10 16 49 0A 50 77 72 54   '..I.PwrT'
  can0  7ED   [8]  21 72 61 69 6E 5F 43 74   '!rain_Ct'

  can0  7DB   [8]  10 16 49 0A 46 6C 78 43   '..I.FlxC'
  can0  7DB   [8]  21 61 70 5F 43 74 72 6C   '!ap_Ctrl'

### Pattern 1: 7e5#02:xx:yy
xx==0
can0  7ED   [8]  03 7F 00 11 00 00 00 00   '........'

xx==9
7ed:[09:00] < 404000  @@
7ed:[09:02] < 4c4a435043424c4358313130303032333700  LJCPCBLCX11000237
7ed:[09:0a] < 507772547261696e5f4374726c000000000000000000  PwrTrain_Ctrl


### Sources
7DB: sending with this AID seems to generate no responses
	aka FlxCap_Ctrl
7E8: sending with this AID seems to generate no responses
	aka FlxCap_Gateway
	- expect main engine here... nope
7ED: sending with this AID seems to generate no responses
	aka PwrTrain_Ctrl

7D3: only 7DB is listening here
7E0: only 7E8 is listening here
7E5: only 7ED is listening here
	- note: in all cases, listener is sender +8

7DF: it seems like all three listeners are listening here
	- 7DF is the standard diagnostic reader CAN ID
	- OBD-II listen on [7E0:7E7] and send on [7E8:7EF]
	- invalid sysIds generate errors
	- all of 7E8, 7DB, 7ED reply to all messages
	- for valid sysIds, some subId are ignored, no error
	- generates returns for (01:00), (01:1f), (09:00), (09:02), (09:0a)
		- note that the (09:) messages above are what 7E5 sends
	- error code 12 for messages in (01:)

NOTE:
OBD-II has a "vehicle specific" mode, of the form
	7DF#03xxyyyy00000000, untested

### Results of sending as 7DF
sysId = 0x01
	[01:01]: code 12 error
	[01:1f]: 100E
	[01:5c]: 8700
	[09:00]: 40400000
	[09:02]: LJCPCBLCX11000237 (from 7E8 7DB 7ED)
	[09:0a]: system names  (from 7E8 7DB 7ED)
	default: code 11 error

Raw responses:
can0  7DF   [8]  02 01 00 00 00 00 00 00   '........'
can0  7E8   [8]  06 41 00 00 00 00 02 00   '.A......'
can0  7DB   [8]  06 41 00 00 00 00 02 00   '.A......'
can0  7ED   [8]  06 41 00 00 08 00 03 00   '.A......'

can0  7DF   [8]  02 01 1F 00 00 00 00 00   '........'
can0  7E8   [8]  04 41 1F 10 0E 00 00 00   '.A......'
can0  7DB   [8]  04 41 1F 10 0E 00 00 00   '.A......'
can0  7ED   [8]  04 41 1F 10 0E 00 00 00   '.A......'

can0  7DF   [8]  02 01 5C 00 00 00 00 00   '........'
can0  7ED   [8]  04 41 5C 87 00 00 00 00   '.A\.....'

can0  7DF   [8]  02 09 00 00 00 00 00 00   '........'
can0  7E8   [8]  06 49 00 40 40 00 00 00   '.I.@@...'
can0  7DB   [8]  06 49 00 40 40 00 00 00   '.I.@@...'
can0  7ED   [8]  06 49 00 40 40 00 00 00   '.I.@@...'

can0  7DF   [8]  02 09 02 00 00 00 00 00   '........'
can0  7E8   [8]  10 13 49 02 4C 4A 43 50   '..I.LJCP'
can0  7DB   [8]  10 13 49 02 4C 4A 43 50   '..I.LJCP'
can0  7ED   [8]  10 13 49 02 4C 4A 43 50   '..I.LJCP'
can0  7E8   [8]  21 43 42 4C 43 58 31 31   '!CBLCX11'
can0  7DB   [8]  21 43 42 4C 43 58 31 31   '!CBLCX11'
can0  7ED   [8]  21 43 42 4C 43 58 31 31   '!CBLCX11'
can0  7E8   [8]  22 30 30 30 32 33 37 00   '"000237.'
can0  7DB   [8]  22 30 30 30 32 33 37 00   '"000237.'
can0  7ED   [8]  22 30 30 30 32 33 37 00   '"000237.'

can0  7DF   [8]  02 09 0A 00 00 00 00 00   '........'
can0  7E8   [8]  10 16 49 0A 46 6C 78 43   '..I.FlxC'
can0  7DB   [8]  10 16 49 0A 46 6C 78 43   '..I.FlxC'
can0  7ED   [8]  10 16 49 0A 50 77 72 54   '..I.PwrT'
can0  7E8   [8]  21 61 70 5F 47 61 74 65   '!ap_Gate'
can0  7DB   [8]  21 61 70 5F 43 74 72 6C   '!ap_Ctrl'
can0  7ED   [8]  21 72 61 69 6E 5F 43 74   '!rain_Ct'
can0  7E8   [8]  22 77 61 79 00 00 00 00   '"way....'
can0  7DB   [8]  22 00 00 00 00 00 00 00   '".......'
can0  7ED   [8]  22 72 6C 00 00 00 00 00   '"rl.....'
can0  7E8   [8]  23 00 00 00 00 00 00 00   '#.......'
can0  7DB   [8]  23 00 00 00 00 00 00 00   '#.......'
can0  7ED   [8]  23 00 00 00 00 00 00 00   '#.......'

### Sending as 7D3 -> 7DB -- FlxCap_Ctrl
7db:[01:00] < 00000002
7db:[01:1f] < 2c0d  ,
	SID 10 - error 12
		- SUB 0x01: empty response
		- SUB 0x02: empty response
	SID 11 - error 12
		- needs to be length 2,
		- subfunction & 0x7f
		- 0x01 should be "hard reset"
		- 
	SID 27 - error 22 in mode 1, but in mode 2, works.
	SID 35 - error 33, expects two bytes?
		- SUB 0x00-0xFF: dataFormatIdentifier, use 00 for clear
		- SUB 0x00-0xFF: addressAndLengthFormatIdentifier, two nibbles
			- first nibble is memory size length
			- second niddle is address length
		- more bytes, for memory size and address
		- response might give info about transfers
			- first byte back is 0x10, not sure
			- second byte is block size.
	SID 36 - error 24
		- SUB 0x00-0xFF: blockSequenceCounter
		- might be optional, I think I just hit this over and over until out of data
		- start at 1 and count up. Roll over and keep going.
		- might send many bytes at once
	SID 37 - error 13
		- no subs.
		- indicates end of transfer.
		- use size 1: [01.37]
	SID 3e - response -- likely just for 00

#### Security Access
Request Seed
can0  7D3   [8]  02 27 01 00 00 00 00 00   '.'......'
can0  7DB   [8]  04 67 01 B1 0F 00 00 00   '.g......'

Response
can0  7D3   [8]  04 27 02 00 00 00 00 00   '.'......'
can0  7DB   [8]  03 7F 27 35 00 00 00 00   '..'5....'

Can't try two keys for a single seed.

### Sending to 7E0 -> 7E8 -- FlxCap_Gateway
	SID 10 - error 12
		- SUB 0x01: empty response
		- SUB 0x02: empty response
		- nominally this is used to switch mode, could affect what UDS exists
	SID 11 - error 12
		- all subs error out
	SID 27 - error 22
	SID 35 - error 33
	SID 36 - error 24
	SID 37 - error 13
	SID 3e - response

### Sending to 7E5 -> 7ED -- PwrTrain_Ctrl
	SID 10 - error 12
		- SUB 0x01: empty response
		- SUB 0x02: empty response
	SID 11 - error 12
	SID 27 - error 22
	SID 3e - response

### Security Access
7d3:
	98e5 -> 989f
	f1bc -> f287
7e5:
	850b -> 840a
7e0:
	e859 -> e963

### Request Upload
If I specify a length < 3, I get code 13.
With length = 3, I get code 31 for all, ALFIDs except 22
ALFID 22 implies a length of 7. Giving the following template:
	7d3#07.35.00.22.aa.bb.cc.dd
Hit:
We got a hit with:
	7d3#07.35.00.22.80.00.00.04
Ok, it's go time.
	7d3#07.35.00.22.80.00.10.00
	7db#03.75.10.fd


#### Spec
Actual Spec
    1. 0x35 -- RequestUpload
    2. 0x00 -- dataFormatIdentifier
        high: "compressionMethod"  = 0x0, others are manufacturer specific
        low: "encryptionMethod" = 0x0, others are manufacturer specific
    3. 0x?? -- addressAndLengthFormatIdentifier
        high: byte length of memorySize parameter
        low: byte length of memoryAddress parameter
    M-bytes -- memoryAddress[] = ... (MSB first)
        obvious understanding
    N-bytes -- memorySize[] = ... (MSB first)
        obvious understanding (uncompressed size)

### Analysis of 7DF
This is standard OBD-II
Mode ~= SID ~= first byte after length
PID ~= second byte after length

#### Mode 01
	PID 00 returns four data bytes, "bit encoded"
		- 7DB: 00.00.00.02 -> PID 1f is supported
		- 7E8: 00.00.00.02 -> as above
		- 7ED: 00.08.00.03 -> PID 0d, 1f, 20 are supported
	PID 0d -- is vehicle speed
		- 7ED says: 8D -> 141 km/h -> 88 mph
	PID 1f -- Run time since engine start
		- 4110 seconds -- seems to be changing
	PID 20 -- high PIDs supported
		- 7ED: 00000001 -> supports 40
	PID 40 -- higher PIDs supported
		- 7ED: 40000010 -> pids 42, 5c
	PID 42 -- Control module voltage
		- 7ED: 2EE0 -> 12.000 Volts (exactly)
	PID 5c -- Engine oil temperature
		- 7ED: 8700 -> 95 °C (should return 87, inappropriate null padding)

#### Mode 09
	PID 00 returns four data bytes, "bit encoded"
		- (7E8,7DB,7ED) 40.40.00.00 -> PID 02, 0a are supported.
	PID 02 is VIN, as above
	PID 0a is 20 bytes of ECU name as above

## RE of image dump from 7E0
I have successfully performed a file "upload", and gotten the image. It appears to be a standard AVR binary file. Reversing...

## Initial Analysis
loader:
	Z = 3fd3
	X = 2000
	end = 2146
bss:
	X = 2146
	end = 2243

avr_loader_emu(0x3fd3, 0x2000-1, 0x2146)
avr_bss_emu(0x2146, 0x2243)

doesn't seem right. Likely, needed to add -1 correction above...

Strings are in .rodata, harder to dref
	1fb0
	1fb3
	1fc1
	1fcb
	1fd5
	1fe1

Victory function is accessible, and at 0xe85
	- called from f12
path:
	- any of 7d3
	- PID A0
	- must_be_2_1021f5 must be 2
	- msg length must be 2
	- msg body must be 0 (but get no response if it's 0x80)

First try:
```sh
cansend can0 7d3#02.a0.00.22.30.00.00.04
can0  7DB   [8]  10 29 E0 00 46 4C 41 47   '.)..FLAG'
can0  7DB   [8]  21 3A 00 06 00 00 00 00   '!:......'
can0  7DB   [8]  22 00 18 39 06 00 00 00   '"..9....'
can0  7DB   [8]  23 00 00 00 00 00 00 00   '#.......'
can0  7DB   [8]  24 00 00 00 00 00 00 00   '$.......'
can0  7DB   [8]  25 00 00 00 00 00 00 00   '%.......'
```

Clearly flag mask is wrong?
00060000000000183906000000000000

I tried reset and send: error 33, security access denied.

## Simple RE
Maybe what I need is just lying around?
	00fe
	0119
	1fb3
	1fb0 FLAG
	1fdf
What is at:
	0x232

## Disassembly
### Pids
```c
void victory_function_e85(buffer *msg, void b, short aid, char pid) {
	rx16 = b;
	rx22 = aid;
	r20 = pid;
	if (aid != 0x7d3) return error_7f_8e1(0x11);
	if (session_7d3_102000 != 2) return error_7f_8e1(0x33);
	if (access_7d3_102156 != 2) return error_7f_8e1(0x33);
	if (msg[0x202] != 2) return error_7f_8e1(0x13);
	if (msg[1]&0x7f != 0) return error_7f_8e1(0x12);
	if (msg[1]&0x80 != 0) return 0; // no error
	set_flag_mask_3e1(0xff);
	write_flag_to_buffer_3ee(0x232); // binary at ROM:0x119
	{ // inlined function
		...
		memcpy_P($sp+?, 0x3f60, 6); // "FLAG:\0"
		for (int i=0;i<32;i++) {
			($sp+?+8)[i] = 0x232[i]; // the "flag" buffer, but wrong
		}
		sub_6ca(b, 0x7db, 0x29, $sp+?);
	}
	return 0;
}

short check_key_12f8(short arg0, short arg1) {
	// returns 0x0000 to indicate success
	rx14 = bswap(arg0);
	rx16 = arg1;
	Y = [0x45, 0x71, 0x3D, 0x8B, 0x4F];
	rx24 = 0;
	for (int i=0; i<5; i++) {
		rx24 = sub_460(rx24, Y[i]);
	}
	rx24 = sub_460(rx24, arg0/256);
	rx24 = sub_460(rx24, arg0%256);

	// check arg1 against output
	if (r25 != r17) return 0x0001; // fail

	if (rx24 == 0x0000) r19 = 1; // probably 1
	else r19 = 0;

	if (rx16 != 0x0000) r18 = 1; // probably 0
	else r18 = 0;

	if (r18 == r19) return 0x0001; // fail
	else return 0x0000; // success
}

char sub_460(char r24, char r22) {
	r24 ^= r22
	r22 = r24
	r22 = nswap(r22)
	r22 ^= r24
	r0 = r22
	r22 >>= 2
	r22 ^= r0
	r0 = r22
	r22 >>= 1
	r22 ^= r0
	r22 &= 7

	r0 = r24
	r24 = r25
	r22 >>= 1
	r0 >>= 1 (carry?)
	r22 >>= 1 (carry?)
	r25 = r0
	r24 ^= r22
	r0 >>= 1
	r22 >>= 1 (carry?)
	r25 ^= r0
	r24 ^= r22
}

void write_flag_to_buffer_3ee(char *buffer[32]) {
	char y1 = 0;
	// inefficiency is at Y+2..3
	// char = Y+4
	// char = Y+5
	// buffer is at Y+6..7
	for (char y1=0; y1<32; y1++) {
		y5 = 0x119[y1] ^ flag_xor_array_102159[y1];
		buffer[y1] = y5 | flag_mask_102147;
	}
}

void ecuReset_542(void* arg0, short arg1, short aid, short r18=0x11) {
	r16 = arg1
	r14 = aid
	r20 = 0x11
	Z = arg0

	if (Z[0x102] != 2) error_7f_8E1(..., 0x13); // packet length
	if (Z[1]&0x7f - 1 >= 2) error_7f_8E1(..., 0x12); // sub-function 1 or 2, doesn't matter
	if (Z[1] & 0x80 == 0) {
		sendUdsReply_1672(arg1, aid+8, 2, Y+1==[0x51, subf]);
		if (rx14 = 0x7E5) rx14 = can1_102095;
		else rx14 = can2_10200b;
		rx12 = rx16 + 0x206;
		for (word_102154 = 0x64; word_102154 != 0 && arg1[0x106] !=0; /**/) {
			sub_15a3(r14, r16, 3); // delay reset long enough to reply?
		}
	}
	sub_1176(can1_102095[0x84], can1_102095[0x86]); // possible disable CAN?
	sub_1176(can2_10200b[0x84], can2_10200b[0x86]);
	software_reset();
}

void requestUpload_5db(void* arg0, short arg1, short aid, short r18=0x35) {
	rx8 = arg0;
	rx12 = arg1;
	rx16 = aid;
	r5 = 0x35;
	if (aid == 0x7e0) {
		r14 = session_7e0_102001
		r15 = access_7e0_102159
		memcpy_P(Y+0x1d, ROM:0x301b , 0x20); // "FlxCap_Gateway"
		rx10 = 0x2165;
		rx24 = 0x8000; // max
		rx20 = 0;      // min
	} else if (aid == 0x7d3) {
		r14 = session_7d3_102000
		r15 = access_7d3_102156
		memcpy_P(Y+0x1d, ROM:0x3011 , 0x20); // "FlxCap_Ctrl"
		rx10 = 0x215f;
		rx24 = 0xC000; // max
		rx20 = 0x8000; // min
	} else {
		error_7f_8e1(..., 0x11);
	}

	if (r14 != 2) error_7f_8e1(..., 0x33); // session
	if (r15 != 2) error_7f_8e1(..., 0x33); // access
	if (r10[4] != 0) error_7f_8e1(..., 0x22); // state bundle -> conditions...
	if (arg0[0x102] < 3) error_7f_8e1(..., 0x13); // length
	if (arg0[0x1] != 0) error_7f_8e1(..., 0x31); // subf -> out of range? XXX verify
	if (arg0[0x2] != 0x22) error_7f_8e1(..., 0x31); // len:len
	if (arg0[0x102] != 7) error_7f_8e1(..., 0x31); // length (again)

	rx14 = arg0[3:4] // request offset
	rx6 = arg0[5:6] // request length
	if (rx14 < rx20) error_7f_8e1(..., 0x31); // below range
	if (rx14 >= rx24) error_7f_8e1(..., 0x31); // above range
	if (rx24 < rx14 + rx6) error_7f_8e1(..., 0x31); // end if above range
	// what about negative lengths? nope. Ordering is correct

	memcpy(Y+1, ROM:0x3003, 0x1c); // "Accessing %s Mem Space..."
	serial_printf(USARTC0, Y+1, Y+1d); // obvious

	rx10[0:1] = rx14; // request start
	rx10[2:3] = rx14+rx6; // request end
	rx10[4] = 2;
	rx10[5] = 0;
	sendUdsReply_1672(arg1, aid+8, 3, Y+31=[0x75,0x10, 0xFD]);
	return 0;
}

struct transferSession { 
	short requestStart; // [0:1]
	short requestEnd;   // [2:3]
	char state;         // [4]   1 or 2
	char blockCounter;  // [5]   starts at 0, goes up to 0xFD
}

void transferData_71a(void* arg0, short arg1, short aid, short r18=0x36) {
	X = arg0;
	rx24 = arg1;
	rx22 = aid;
	r20 = 0x36;
	if (aid == 0x7e0) {
		r19 = session_7e0_102001;
		r18 = access_7e0_102159;
		Z = 0x2165;
	} else if (aid == 0x7d3) {
		r19 = session_7d3_102000
		r18 = access_7d3_102156
		Z = 0x215f;
	} else {
		error_7f_8e1(..., 0x11);
	}

	if (r19 != 2) error_7f_8e1(..., 0x24); // session
	if (r18 != 2) error_7f_8e1(..., 0x24); // access
	if (Z.state != [1:2]) error_7f_8e1(..., 0x24); // state bundle -> conditions...
	if (arg0[0x102] != 2) error_7f_8e1(..., 0x13); // length

	// slightly re-ordered
	r21 = Z.state
    r19 = Z.blockCounter 
	r17 = Z.state-1

	rx14 = X = r19 = Z.blockCounter
	r16 = -1
	rx14 = Z.blockCounter + 1

	r18 = arg0[1]; // block requested
	if (arg0[1] != Z.blockCounter + 1 && r17 == 2) {
		// re-request
		if (arg0[1] != Z.blockCounter) error_7f_8e1(..., 0x73); // wrong block sequence...
		if (arg0[1] == 0) error_7f_8e1(..., 0x73); // wrong block sequence...
		if (Z.state&0xfd != 1) error_7f_8e1(..., 0x73); // wrong block sequence...
		X -= 1
		rx16 = Z.blockCounter * 0xfd + Z[1:0]; // block to read
	} else {
		rx16 = r19 * 0xfd + Z[0:1]; // block to read
		Z.blockCounter = r19 + 1;
		if (Z.state == 2) {
			Z.state = 1;
		}
	}

	if (Z.requestEnd < rx16) error_7f_8e1(..., 0x71); // transfer suspended
	if (rx16 >= Z.requestEnd) error_7f_8e1(..., 0x71); // transfer suspended 
	X = rx14 - rx16
	if (X >= 0xfe) {
		r19 = 0xfd;
		r14 = 0xfd;
	} else {
		r19 = 3
		Z.state = 3;
		r14 -= r16;
	}
	sub_6d2();
	return 0;
}

void sub_6d2() {
	X = r14 + 2
	rx10 = r14 + 1
	X = stack_alloc(r14+2);
	r20 |= 0x40; // likely PID
	X[0] = r18;
	rx18 = &X[3];
	{
		rx20 = rx18 - X;
		if (rx10 < rx20) {
			sendUdsReply_1672(rx24, rx22+8, r14+2, X);
		}
		*rx18++ = lpm(rx16++);
	}
}
```

### Mains
```c
void main(void) {
	init {
		we init USART C -- aka serial
		and PORTB -- might be lighting the LED, might be D7/D8
		Note:
			PORTD[1..2] is CAN#_RST
			PORTE[0..3] is CAN#_INT, STBY,CLK
		looks like:
			* 0x7DF is enabled on both interfaces
			* 0x7E5 is enabled on can1_102095
			* 0x7E0 is enabled on can2_10200b
			* if (ROM:0xbfe0 == 0) 0x7D3 is enabled on can2_10200b
		sub_1420();
		sub_1456(can1_102095);
		sub_1456(can2_10200b);
		sub_cfe(can1_102095, 0x7df, 0xfff); {
			for (int i=0;i<=5;i++) sub_c81(r24, i, r22, r20);
		}
		sub_cfe(can2_10200b, 0x7df, 0xfff); {
			for (int i=0;i<=5;i++) sub_c81(r24, i, r22, r20);
		}
		sub_c81(can1_102095, 2, 0x7e5, 0xfff);
		sub_c81(can2_10200b, 2, 0x7e0, 0xfff);
		if (ROM:0xbfe0 != 0) sub_c81(can2_10200b, 3, 0x7d3, 0xfff);

		sub_140b()
		sub_142e()

		rx14 = Y+0x524 // bzero(rx14, 14)
		rx10 = Y+0x41d // bzero(rx10, 263)
		rx12 = Y+0x316 // bzero(rx12, 263)
		rx6  = Y+0x20f // bzero(rx6,  263)
		rx16 = Y+0x108 // bzero(rx16, 263)
		rx4  = 0
		rx2  = Y+0x1   // bzero(rx2,  263)
		// below is sorted for sanity
		Y+0x532 = dword_102138 = [0,1,5,7]; // random state to choose...
		Y+0x536:7 = 9, 0x0a; // these are valid OBD-II
		Y+0x538:9 = 9, 0x00;
		Y+0x53a:b = 1, 0x0d;
		Y+0x53c:d = 1, 0x42;
		Y+0x53e:f = 1, 0x40;
		Y+0x540:1 = 1, 0x20;
		Y+0x542:3 = 1, 0x00;
		// missing Y+0x544..7, whole dword, used in an ISR...
		Y+0x548:9 = &Y+0x536;
		Y+0x54a:b = &Y+0x538;
		Y+0x54c:d = &Y+0x53a
	}

	// r6 is something to do with how to send the reply, PORT?
	// r10 is related to the message buffer, but possibly at a large offset? ~0x102?
	loop {
    	if (byte_10214a != 0 && Y+0x20e == 0 && r5 < 9) {
			// these are the randomish entry points on the right
			// they cause the random OBD2 messages that idle through the system.
			EIJMP *((0xfe + r5) << 1);
			switch (r5) {
				case 0x309:
					Y+0x544 = dword_102146;
					erx22 += r4 * r14[6] + dword_102146;
					r4 = sub_478() & 3;
					r5 = Y+0x532[r4]
			}
		}

		if ( sub_e4c(off_102095, r14) == 0 &&
				(r14[0]&1) == 0 &&
				(r14[2:1] == 0x7e5 || r14[2:1] == 0x7df)) {
			sub_1491(r10, r14);
		}

		if ( sub_e4c(off_10200b, r14) == 0 &&
				(r14[0]&1) == 0 &&
				(r14[2:1] == 0x7d3 || r14[2:1] == 0x7df)) {
			sub_1491(r12, r14);
		}

		starting from 0x3D3;
		if (Y+0x520[3] == 2) {
			if (Y+0x520[1:0] == 0x7df) {
				Y+0x520[1:0] = 0x7e5;
				process_uds_f12(r10, r6, 1);
				Y+0x520[1:0] = 0x7df;
			} else {
				process_uds_f12(r10, r6, 0);
			}
			Y+0x520[3] = 0;
		}
		if (Y+0x419[3] == 2) {
			if (Y+0x419[1:0] == 0x7df) {
				Y+0x419[1:0] == 0x7e0;
				process_uds_f12(r12, r16, 1);
				Y+0x419[1:0] == 0x7d3;
				process_uds_f12(r12, r2, 1);
				Y+0x419[1:0] = 0x7df;
			} else {
				// so the reason that we don't process
				// 7d3 messages properly, must be the lack of r2 below...
				// I think it means it doesn't reply to me, need tap?
				process_uds_f12(r12, r16, 0);
			}
			Y+419[3] = 0;
		}
		if (byte_10214B != 0) {
			byte_10214B = 0;
			sub_15a3(off_10200b, r16, 1);
			sub_15a3(off_10200b, r2, 1);
			sub_15a3(off_10200b, r6, 1);
		}
	}
}

void error_7f_8e1(r24, r22_aid, r20_sid, r18_code);
void sendUdsReply_1672(r24, r22_aid, r20_length, char r18_buffer[r20_length]);
```

### ISRs
```c
void TCC2_LUNF_(void) {
	if (dword_102191 != 0) dword_102191 -= 1; // sub_147c
	TCC_count_102146 += 1; // used for random seeds

	word_102152 += 1;
	if (word_102152&1 == 1) time_to_canreply_10214b = 1;
	if (word_102152 == 500) {
		time_to_cansend_10214a = 1;
		word_102152 = 0;
		per_kilo_102150 += 1;
		if (per_kilo_102150&1 == 1) uptime_secs_10214C += 1;
	}

	if (word_102154 != 0) word_102154 -= 1; // ecuReset
}

```

### Commms
```c
struct can_interface {
	char 1;
	short ports[4];
	short 0x101;
	...
}

void sub_bd4(struct can_inf, char arg1) {
	r20 = arg1;
	Z = can_inf;
	sub_114c(can_inf[0x84:0x85], can_inf[0x86:0x87], 0xf, 0xe0, (swap(arg1)<<1)&0xe0);
	for (Y=0xc350; /**/; Y--) {
		sub_1104(can_inf[0x84:0x85], can_inf[0x86:0x87], 0xe);
		if ( (swap(arg1)<<1)&0x7 ) return;
		if (Y==0) {
			sub_1431();
			Y=0xffff;
		}
	}
}

// This is the reverse path to sub_d30, which might enable 7D3
void sub_c81(struct can_inf, char arg1, short aid, short mask=0xfff) {
	sub_bd4(can_inf, 4);

	if (arg1 < 2) r20 = 4; else r20 = 0;
	r20 += arg1 * 4; // arg1 + (0 or 16).
	sub_121e(can_inf[0x84:0x85], can_inf[0x86:0x87], r20, 0, aid, 0); // not sure about endianess

	if (arg1 > 1) r4 = 1; else r4 = 0;
	r20 = (r4+8)*4; // 32 or 36.
	sub_121e(can_inf[0x84:0x85], can_inf[0x86:0x87], r20, 0, mask, 0); // not sure about endianess

	sub_bd4(can_inf, 0);

	0x2003[ 4*(can_inf[0] - 1) + 2*rx4 ] = mask; // size 8 array
	0x216d[ 12*(can_inf[0] - 1) + 2*arg1 ] = aid; // size 36 array
}

void sub_d30(short arg0) {
	for (Y = 0; Y != 6; Y++) {
		short rx20 = arg0[0] - 1;

        Z = rx20*4
		if (Y < 2) Z += 2
		rx18 = array_102003[Z:Z+1]; // four elements, all 0xFFF

		Z = 12 * rx20 + 2 * Y;
		rx20 = array_10216d[Z:Z+1]

		sub_c81(arg0, Y, rx20, rx18); // can_inf, mode, aid, mask
	}
}

void sub_146b(short arg0) {
	sub_bdf(arg0);
	sub_c42(arg0, 1);
	sub_d30(arg0);
}

void sub_f2e() {
}

void sub_15a3(void*can_ptr, short r22, char r20=1|3) {
	// r20 is 3 if called from ecuReset(), is 1 if called from main()
}

```

## Simulation
It looks like print_flag is broken, doesn't use the buffers properly
Try sim: Patches (note, I haven't byteswapped the belows)
	2486:  92cf -> 9508
	118a:  cffd -> 0000 (NOP it out)
	27b0:  93cf -> 9508 (just ret, fuck it)

data 0x2140  c7 a6 e8 24 f6 5a 00 00 00 83 36 44 b1 7e 6e 89  Ç¦è$öZ...ƒ6D±~n.
data 0x2150  a5 9d 82 33 58 a2 ee 44 93 97 8c a3 a0 5f 87 27  ¥..3X¢îD“—Œ£ _.'
data 0x2160  82 37 66 38 80 ab 83 f7 c2 46 86 c9 49 e2 b4 ee  .7f8€«ƒ÷ÂF.ÉIâ´î
data 0x2170  12 7e ca 32 76 a2 ee 44 93 00 00 00 00 00 00 00  .~Ê2v¢îD“.......

c7 a6 e8 24 f6 5a 00 00  00
flag_array_102149:
83 36 44 b1 7e 6e 89 a5  9d 82 33 58 a2 ee 44 93
flag_xor_array_102159:
97 8c a3 a0 5f 87 27 82  37 66 38 80 ab 83 f7 c2
46 86 c9 49 e2 b4 ee 12  7e ca 32 76 a2 ee 44 93

lpm_flag_array_119:
B8F19996BE3CBB1F5401E65DBA98F692BE762AACD681708CFB184F53DD92F573

If I byteswap 0x119, and xor into 2159, I get
	f459c98962ef39e408eccbbbf1a9037f
Note: we get ascii, it decodes to that.
Doesn't check out. Maybe I broke the code with my 3 patches...

Code is broken, like I suspected. It's trying to use 0x119 as a buffer, but when it does so, it correctly reads from program memory, but writes to RAM, and RAM that low is memory mapped I/O... so BS.

```ruby
s1='978ca3a05f87278237663880ab83f7c24686c949e2b4ee127eca3276a2ee4493'
s2='B8F19996BE3CBB1F5401E65DBA98F692BE762AACD681708CFB184F53DD92F573'
b1=s1.scan(/../).map{|x| x.to_i(16)};
b2=s2.scan(/../).map{|x| x.to_i(16)}.each_slice(2).map{|a,b|[b,a]}.flatten;
puts b1.zip(b2).map{|x,y| (x^y).chr}.join;
```

## Finale
I was running against the old version. Grabbed the new one...

7d3/7db doesn't respond to direct messages. Does respond to public ones.
But not UDS...

Gateway is on 7e0/7e8. I probably need to do something there...
	- trying another rom-dump on 7e0, substantially different...
	- most of the bindiff carried over, lots of minor changes
	- victory() isn't broken anymore

Updated offsets:
	avr_loader_emu(0x35b4, 0x2000, 0x2146)
	avr_bss_emu(0x2146, 0x220f)

Holy crap serial is enabled. It's printing helpful messages:
	- Strings are now base 0x3000
	- look for 0x6000, 0x6006, 0x6036, 0x604a, 0x605e
	- "FLAG:" is at 0x6000.
	- actual flag is up at around 0x5ff0, outside our memory dump.

Reversing from Flag:
	- all traffic to 7d3 is filtered. I need to open that filter.
	- need session_7d3_102000 == 2, easy with $10 session control
	- need access_7d3_102156 == 2, easy by brute force, unless that changed.
	- and length == 2, and payload == 0. All easy.
	- need to crack open `main()`.

Access Flags:
	- there are two per ECU. Low, and High.
	- High controls access to $35, $36, $37, (and $A0).

###  Possbiles:
	- need to issue a command to the gateway to open access to FlxCap_Ctrl
		- need to invoke sub_c81(can2_10200b, ?, 0x7d3, 0xfff)
		- is invoked from sub_d30 <- sub_146b <- sub_f2e <- sub_15A3 <- ecuReset
			- ignoring setup calls in main()
			- looks like that path is to reset to defaults...
		- what about things that reference can2_10200B?
			- other than main() and ecuReset()
			- sub_10c7 -- is an ISR -> sub_1697(), sub_fd9()
			- sub_1431
		- what about things that invoke CCP?
			- sub_1431 mucks with the cans then software resets...
		- what about word 214c?

	- need to mess around physically.
		- use SPI to enable the missing pins
		- probe lines, look for signals

	- ECU reset?
		- worth trying...
		- if we can affect ROM:0xBFE0 -> 0x5ff0, and reset, db3 opens up...
			- Harvard, there's no SPM anywhere...
			- but why have the test if it's impossible?
			-
	
	- ISRs?
		- I think they might be doubled... nope
			- we have TCC0_INT_BASE -- timer/counter on port C
				- there's a TC pair for each port, 
			- we have PORTE_INT0, and PORTE_INT1
				-> these interrupts driven by CAN1_INT/CAN2_INT

### PIDs
	3e tester present: requres subf=0; does nothing; doesn't reply if subf&0x80
	10 session control: requires subf=[1..2]; alter control; if (subf&0x80) skip reply;
	11 ecu reset: requires subf=[1..2]; branch on 0x7e5;
		- if (~ subf&0x80) reply; 64.times{ sub_15a3() }; sub_1176(each can)
	27 security access: as well described, references 2146
	35 request upload: 7e0/7d3; bunch of reqs above; serial_printf(); reply.
	36 transfer data: 7e0/7d3; bunch of probably known details
	37 transfer exit: 7e0/7d3; bunch of probably known details

Note:
	session mode for 7e5 is only used in security access
	session mode for 7e0 is used in access, and request/transfer/exit sequence
	session mode for 7d3 is used in the above, and victory function
	security access for 7e5 is implemented but unused.
	security access for 7e0 is used for request/transfer/exit 
	security access for 7d3 is used for request/transfer/exit + victory

About can[12]_1020XX:
	- can1_102095 is used for 7e5/PwrTrain
		- PORTE_INT0_ references
		- called by an external interrupt?
	- can2_10200b is used for both 7e0/FlxCap, and 7d3/FlxCap
		- sub_10c7 references
		- called by an external interrupt?
	- both
		- extensive references in main(), for obvious reasons
		- ecuReset_542 calls sub_15a3() with them, then calls sub_1176() shortly after
		- sub_1431 references

### Probing Lines
A0-A5: nothing
D:
	9. sig -- D9/SS/PC4 -- CAN2
	10. sig -- D10/MOSI/PC5 -- CAN2
	MISO/SCK are not exported are PC6, PC7.

	6. sig -- D6/SS/PD4 -- CAN1
	11. sig -- D11/MOSI/PD5 -- CAN1
	12. sig -- D12/MISO/PD6 -- CAN1
	13. sig -- D13/SCK/PD7 --CAN1



### Diff Analysis
process_uds() -- nothing consequential
victory_function() -- now working properly
ecuReset() -- irrelevants

