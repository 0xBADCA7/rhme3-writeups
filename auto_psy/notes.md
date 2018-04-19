
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
	- details on UDS communicatino sequences

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
BLG-Notes.pptx, page 63-6

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

### UDS SIDs of interest
	SID 10 - Diagnostic Session Control!
	SID 11 - ECU reset
	SID 27 - Security Access
	SID 35 - Request Upload
	SID 36 - Transfer Data
	SID 37 - Request Transfer Exit
	SID 3e - Tester Present (I'm still here...)

### UDS Errors
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

### Sending as 7D3 -> 7DB -- FlxCap_Ctrl
7db:[01:00] < 00000002
7db:[01:1f] < 2c0d  ,
	SID 10 - error 12
		- SUB 0x01: empty response
		- SUB 0x02: empty response
	SID 11 - error 12
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
```c                                                                              Z = 1)
void victory_function_e85(buffer *msg, void b, short aid, char pid) {
	rx16 = b;
	rx22 = aid;
	r20 = pid;
	if (aid != 0x7d3) return error_7f_8e1(0x11);
	if (must_be_2_1021f5 != 2) return error_7f_8e1(0x33);
	if (access_7d3_102019 != 2) return error_7f_8e1(0x33);
	if (msg[0x202] != 2) return error_7f_8e1(0x13);
	if (msg[1]&0x7f != 0) return error_7f_8e1(0x12);
	if (msg[1]&0x80 != 0) return 0; // no error
	set_flag_mask_3e1(0xff);
	print_flag_3ee(0x232); // binary at ROM:0x119
}

short check_key_12f8(short arg0, short arg1) {
	// returns 0x0000 to indicate success
	rx14 = bswap(arg0);
	rx16 = arg1;
	Y = [0x45, 0x71, 0x3D, 0x8B, 0x4F];
	rx24 = 0;
	for (int i=0; i<5; i++) {
		rx24 = sub_1293(rx24, Y[i]);
	}
	rx24 = sub_1293(rx24, arg0/256);
	rx24 = sub_1293(rx24, arg0%256);

	// check arg1 against output
	if (r25 != r17) return 0x0001; // fail

	if (rx24 == 0x0000) r19 = 1; // probably 1
	else r19 = 0;

	if (rx16 != 0x0000) r18 = 1; // probably 0
	else r18 = 0;

	if (r18 == r19) return 0x0001; // fail
	else return 0x0000; // success
}

char sub_1293(char r24, char r22) {
	r24 ^= r22
	r22 = r24
	r22 = nswap(r22)
	r22 ^= r24
	r0 = r22
	r22 >>= 2
	r22 ^= r0
	r09 = r22
	r22 >>= 1
	r22 ^= r0
	r22 &= 7

	r0 = r24
	r24 = r25
	r22 >>= 1
	r0 <<= 1 (carry?)
	r22 <<= 1 (carry?)
	r25 = r0
	r24 ^= r22
	r0 >>= 1
	r22 <<= 1 (carry?)
	r25 ^= r0
	r24 ^= r22
}

void print_flag_3ee(char *buffer[32]) {
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

