
## Challenge
Catting cars is a major issue these days. It's impossible to sell your stolen car as a whole, so you sell it in parts. Dashboard computers are popular since they break quite often ;-).

Unfortunately, the dashboard computer is paired with the main computer. So, simply exchanging it will not do the trick. In fact, without the handshake to the main computer it will not operate the climate control buttons.

Of course just pairing the dashboard computer isn't cool enough, try to smash the stack instead! We suspect the device isn't using the serial interface for its pairing algorithm.

In addition to the attached challenge and reversing binaries, you're provided a special "challenge" which you can flash to wipe the EEPROM of your dashboard computer.

## Initial Analysis
X <- Z // data
	Z = 0x12612
	X = 0x2000 .. 0x25bc
X <- 0 // bss
	0x25bc .. 0x3081

avr_loader_emu(0x12612, 0x2000, 0x25bc)
avr_bss_emu(0x25bc, 0x3081)

## Serial Chatter
```
Initializing...
Initialization complete
```

Scoping out the leads, we see traffic on:
	- D7
	- D9, D10, D11, D13

TODO: Oscilloscope, check for analogue signals.

## Reversing: Looking for I/O:
	* DACB_CTRLA -- lots of code, but at the end, uncalled
	* ADCA_CTRLA -- also referenced, but uncalled

## Decompilation
```c

Note: ROM:0x3bf is left on stack
void init_flag_array_89bb(void) {
	// stack frame: 11
	char i;              // Y+1
	void* off=ROM:0x3bf; // Y+2..3
	uint32_t y4;         // Y+4..7
	uint32_t y8;         // Y+8..11

	y4 = *(uint32_t*)off; // zero in my build
	y8 = r4;
	sub_8922(0x2ef1, y8);
	y8 = 0;
	for (i=0; i<8; i++) {
		flag_array_102f01[i] = sub_885c(0x2ef1);
	}
}

IN: r24 = 0xF0
OUT: rt24 == 0x0F || die()
char test_eeprom_4f91(char arg0) {
	// stack frame: 17
	char x = arg0; // Y+1
	char buf1[8];  // Y+2
	char buf2[8];  // Y+10

	memset(buf1, 0, 8);
	eeprom_read_block(buf1, 1, 8); // EEPROM address 1
	memcpy(buf2, abba_10237A, 8);

	if (0==strncmp(buf1, buf2, 8)) {
		x = cert_4eea();
	}

	eeprom_read_block(buf1, 1, 8); // EEPROM address 1
	if (0==strncmp(buf1, buf2, 8)) {
		x = 0xf;
	} else {
		x = cert_4eea();
		// gonna die()
	}

	eeprom_read_block(buf1, 1, 8); // EEPROM address 1
	if (0 != strncmp(buf1, buf2, 8)) brick_and_die();
	if (0 != strncmp(buf1, buf2, 8)) brick_and_die();

	return x;
}

OUT: r24 = 0x0F
char init_load_eeprom_4eea(void) {
	// stack frame: 0xab
	char x = 1;        // Y+1
	char var_2 = 0;    // Y+2
	char var_3 = 0xf0; // Y+3
	char buf2[8];      // Y+4..12

	memcpy(buf2, abba_10237A, 8);
	// XXX
}

void main_loop_2C8B(void) {
	// stack frame: 0x22 -> 34
	uint32_t y1;    // Y+1..4
	short y5;       // Y+5..6
	short unused7;  // Y+7..8
	short y9;       // Y+9..10
	short yB;       // Y+11..12
	char yD[11];    // Y+13..23
	                // Y.....34
	y1 = 0;
	while (true) {
		if (byte_1021b9 != byte_1021ba) { // note 0x2137+0x82
			byte_1021ba = (byte_1021ba+1)%8
				rx24 = byte_1021ba * 14 + 0x12
				sub_25a0(&yD, &0x2137[rx24]);
			sub_2612(yD);
		}
		if (sub_26e3()) {
			// this block is doing dynamic stack allocation
			rx16 = $sp;
			y5 = sub_2654();
			unused7 = y5-1;
			$sp -= y5;
			y9 = $sp + 1;
			memset(y9, 0x0, y5);

			yB = sub_2720(y9);
			if (yB == 0x665) {
				sub_1094(y9, y5);
			} else if (yB == 0x776) {
				msg_dispatch_66c8(y9, r5);
			} else {
				// nil
			}
			$sp = rx16; // stack back
		}
		y1 = (y1 + 1) & 1
			if (y1 != 0x100 && byte_102e5d) try_readMessageBuffer_2575();
	}
	// forever
}

sub_25a0() {
	// XXX
}

sub_2612() {
	// XXX
}

bool sub_26e3() {
	short y1 = sub_2654();
	char topNibble = byte_102a11 >> 4;
	if (topNibble == 1) {
		rx24 = 4*((2 * y1 / 7) + y1) +1
		if (byte_102e5e >= rx24) return true;
		else return false;
	} else {
		if (byte_102e5e) return true;
		else return false;
	}
}

short sub_2654(void) {
	short y1 = 0;
	char topNibble = byte_102a11 >> 4;
	if (topNibble == 0) {
		y1 = (byte_102a1b & 0xf) - 1;
		if (y1<9)  return y1;
		else return 0;
	} else if (topNibble == 1) {
		return ((byte_102a11 & 0xf) << 8) | byte_102a12;
	} else {
		return 0;
	}
}

sub_2720() {
	// XXX -- this one is important
}

sub_1094(sh) {
	char y1;
	// arg0
	// XXX
}

void msg_dispatch_66c8(void *arg0, void *arg1) {
	// arg0 at Y+1..2
	// arg1 at Y+3..4
	if (byte_102e61 == 11) {
		parse_cert_6481(arg0, arg1);
	} else if (byte_102e61 != 0) {
		printf("Message received, sharing climate control settings."):
		sub_666d(0x210c, 5);
	}
	return;
}

try_readMessageBuffer_2575() {
	// XXX
}


void parse_cert_6481(void *arg0, void *arg1) {
	// stack frame 9
	char y1; // Y+1
	char y2; // Y+2
	char y3; // Y+3
	char y4; // Y+4
	char y5; // Y+5
	// arg0 at  Y+6..7
	// arg1 at  Y+8..9
	if (byte_102e61 != 11) {
		remember_and_die();
	} else if (*arg0 != 0x30) {
		printf("Certificate format not supported");
		die();
	} else if (arg1 < 64 || arg0[1]+2 != arg1) {
		printf("Key length not supported");
		die();
	}
	y1 = arg0[1]+2:
	/****/ if ( 0 == (y2=arg0[3]) || y2+5 < y1) {
		printf("Invalid length parameters");
		return 0xa4;
	} else if ( 0 == (y3=arg0[y2+5]) || y2+y3+7 < y1) {
		printf("Invalid length parameters");
		return 0xa4;
	} else if ( 0 == (y4=arg0[y2+y3+7]) || y2+y3+y4+9 < y1) {
		printf("Invalid length parameters");
		return 0xa4;
	} else if ( 0 == (y5=arg[y2+y3+y4+9]) || y2+y3+y4+y5+9 < y1) {
		printf("Invalid length parameters");
		return 0xa4;
	} else if (y5 != 0x31) {
		printf("Key length not supported");
		return 0xa4;
	} else {
		generate_session_key_2b8a(arg0+y2+y3+y4+10);
		byte_102e61 = 0;
		printf("Session key initialized"):
		return 0x4a;
	}
}

void sub_666d(void *arg0, short five) {
	// stack frame 8
	short unused;    //  Y+1..2
	char buffer[36]; //  Y+3..4
	// arg0 is stored at Y+5..6
	// five is stored at Y+7..8
	rx14 = rx16 = $sp;
	{
		unused = 0x20+five-1;
		$sp -= (0x20+five); // stack alloc 37 bytes
		buffer = $sp+1;
		sub_2af8(arg0, five, buffer+five);
		memcpy(buffer, arg0, five);
		sub_61c1(buffer, 0x20+five, 0x01ff, 0x40);
	}
	$sp = r14;
	$sp = r16;
	return;
}

void sub_2af8(char *src, short offset, char* dest) {
	// stack frame 22 / 0x16
	char swap[16]; // Y+1
	// src      is at Y+0x11..12
	// offset   is at Y+0x13..13
	// dest     is at Y+0x15..16
	for (i=0; i<16; i++) {
		swap[i] = 0;
	}
	eeprom_read_block(&swap, 0x1028, 16);
	possible_hmac_4b03(dest, swap, 0x0080, src, offset << 3);
	return;
}

void possible_hmac_4b03(char *dest, char *temp, short eighty, char *src, uint32_t off8) {
	// possibly HMAC_SHA_256?
	// XXX
}

void generate_session_key_2b8a(void* arg0) {
	// stack frame 185
	void* y1;        // Y+1..2
	void* y3;        // Y+3..4
	char buffer[24]; // Y+5..28
	short y29;       // Y+29..30
	short y34;       // Y+34..35
	short y37;       // Y+37..48
	short y39;       // Y+39..40
	short y42;       // Y+42..43
	sessionKey sk44; // Y+44
	sessionKey sk69; // Y+69
	char bufTwo[24]; // Y+94..117
	char bufThr[24]; // Y+118..141
	// arg0 at          Y+184..185

	for (int i=0; i<24; i++) {
		buffer[i] = 0;
	}
	eeprom_read_block(buffer, 0x100a, 24);
	y29 = 24
	y33 = &buffer
	sub_2d61(y29);
	if (arg0[0]!=4) {
		printf("Error during session key generation");
		die();
	}
	y1 = arg0+1;
	y3 = arg0+25;
	y34 = 24;
	y39 = 24;
	y37 = y1;
	y42 = y3;

	sub_2d61(&y34);
	sub_2d61(&y39);
	if (j_init_struct_50a6(&sk44, 0xc0)) {
		printf("Insufficient memory");
		die();
	}
	sub_51a4(&sk44, &y34);

	if (j_init_struct_50a6(&sk69, 0xc0)) {
		printf("Insufficient memory");
		die();
	}
	sub_59d8(&sk69, &y29, &sk44, 0x20e8);

	for (int i=0; i<24; i++) {
		bufTwo[i] = 0;
		bufThr[i] = 0;
	}

	y142[0:1] = 24;
	y142[3:4] = &y94;
	y142[5:6] = 24;
	y142[8:9] = &y118;
	sub_521d(&y142, &sk69, 0x20e8);
	sub_6130(&y152, y142[3:4], 0, 24);
	eeprom_write_block(&y152, 0x1028, 16);
	return;
}

sub_2d64(char arg0[]) {
	char i;  // Y+1
	char j;  // Y+2
	// arg0 at  Y+3..4
	if (arg[0:1]!=0 && arg0[arg0[0:1]-1]) {
		arg0[0:1] -= 1; // move arg0[0:1] to last non-NULL
	}
	if (arg[0:1]==0) {
		arg0[2] = '\0';
		return;
	}
	j = 7;
	i = arg0[3:4] + arg0[0:1] - 1;
	while (i>=0 && j!=0) {
		i <<= 1;
		j--;
	}
	//
	arg0[2] &= 0xf8;
	arg0[2] |= j;
}

struct sessionKey {
	short s1;
	char  c1;
	char  buf1[192];
	short s2;
	char  c2;
	char  buf2[192];
	short s3;
	char  c3;
	char  buf3[192];
	short s4;
	char  c4;
	char  buf4[192];
	short s5;
	char  c5;
	char  buf5[192];
};

char init_struct_50a9(sessionKey key, short size) {
	// arg0 at Y+1..2
	// size at Y+3..4
	arg0[3:4] = malloc(size);
	arg0[8:9] = malloc(size);
	arg0[13:14] = malloc(size);
	arg0[18:19] = malloc(size);
	arg0[23:24] = malloc(size);
	if (any of the above calls failed) {
		free(the ones that worked);
		return 1;
	} else {
		zero_arg0_35f2(arg0+0);
		zero_arg0_35f2(arg0+5);
		zero_arg0_35f2(arg0+10);
		zero_arg0_35f2(arg0+15);
		zero_arg0_35f2(arg0+20);
		return 0;
	}
}

void print_flag_8bb8( void(*usartC0_send_byte)(unsigned char) ) {
	// usartC0_send_byte is Y+6..7
	char i;   // Y+1
	void *y2; // Y+2..3
	char unused;  // Y+4
	char y5;  // Y+5
	for (i=0; i<32; i++) {
		y2 = flag_0x39e+i;
		y5 = unused = ROM:flag_0x39e[i];
		y5 ^= flag_array_102f01[i];
		usartC0_send_byte( y5 | ~byte_102ef0 );
	}
}

```

## High Level Overview:
main_500e()
	* basic init, as always
	* 6f9a() -- loads Userid from NVM, possibly more?
	* 4f91() -- possibly load certs from NVM?
	* printf("Initializing...\n");
	* 671e() -- more init?
	* printf("Initialization complete\n");
	* main_loop_2c8b()
	* printf("==END==\n");

I've labelled a function "brick_and_die", but it might just wipe out progress
	* It sets a flag that causes detect_fi() to take the slow path
	* renamed remember_and_die()

We enable interrupts...
	* 0x56 -> INT0__
		- PORTE_INT_base?
	* 0x58 -> INT1__0

Get the right manual, go to page ~426, find the base address, follow link.

ROM:0x24e -- 0..F0..F (32 bytes) is at
ROM:0x27e -- sha256 h0..h7 values
ROM:0x29e -- sha256 h[0..63] values
ROM:0x39e -- The (obscured) flag
ROM:0x3bf -- a uint32_t that has something to do with the flag

Win condition is to:
	1. set `must_be_1337_10210A = 0x1337`
	2. call `print_flag_or_die_4E8F()`
Neither of those are referenced...

Possible inroads:
	- look at all EEPROM sites, might be able to learn something
		- script based on 0x101??? comments?
	- we have a some printf()s related to message recipt -> backtrace
	- look for overflows: memcpy, memmove, printf
		- also general search for X+, Y+, Z+
		- nope, too many to just check them all out

## String Backtracing
main_500e
	sub_671e -- these two are the calls between "Initializing..."
	sub_65c1 -- and "Initialization complete"
		cert_loadP_4de4 -- P in this case mean '?'
		cert_parse_63E0 -- "Invalid certificate size", "Loaded invalid certificate"
			cert_check_valid_6297
				cert_check_Riscar_CA_6236 -- "Riscar CA"
				cert_check_Nist_P192_627B -- "NIST P-192"
			sub_61c1 -> sub_2873 -> sub 28c9
				cert_something[123] -- "Unexpected length parameter"
	main_loop_2c8b
		msg_dispatch_66C8 -- "Message received, sharing climate control settings."
			parse_cert_6481 -- "Certificate format not supported", "Key length not supported", "Invalid length parameters", "Session key initialized"
				generate_session_key_2b8a --  "Error during session key generation", "Insufficient memory"
			sub_666d
		sub_2720
			try_readMessageBuffer_2575 -- "Failed to read message buffer" && die

## Patching with r2
```sh
[0x00000000]> e asm.cpu =?
...
ATxmega128a4u
[0x00000000]> e asm.cpu = ATxmega128a4u
[0x00000000]> 0xd400
[0x0000d400]> pd 8
       ::   0x0000d400      8f3f           cpi r24, 0xff
       ::   0x0000d402      9105           cpc r25, r1
       `==< 0x0000d404      91f3           breq 0xd3ea
        `=< 0x0000d406      88f3           brcs 0xd3ea
            0x0000d408      0e94316d       call 0xda62
            0x0000d40c      8d83           std y+5, r24
            0x0000d40e      9e83           std y+6, r25
            0x0000d410      2981           ldd r18, y+1
[0x0000d400]> oo+
[0x0000d400]> wx 8130
[0x0000d400]> pd 8
       ::   0x0000d400      8130           cpi r24, 0x01
       ::   0x0000d402      9105           cpc r25, r1
       `==< 0x0000d404      91f3           breq 0xd3ea
        `=< 0x0000d406      88f3           brcs 0xd3ea
            0x0000d408      0e94316d       call 0xda62
            0x0000d40c      8d83           std y+5, r24
            0x0000d40e      9e83           std y+6, r25
            0x0000d410      2981           ldd r18, y+1
[0x0000d400]> wa  cpi r24, 0x10
Written 2 byte(s) ( cpi r24, 0x10) = wx 8031
[0x0000d400]> pd 8
       ::   0x0000d400      8031           cpi r24, 0x10
       ::   0x0000d402      9105           cpc r25, r1
       `==< 0x0000d404      91f3           breq 0xd3ea
        `=< 0x0000d406      88f3           brcs 0xd3ea
            0x0000d408      0e94316d       call 0xda62
            0x0000d40c      8d83           std y+5, r24
            0x0000d40e      9e83           std y+6, r25
            0x0000d410      2981           ldd r18, y+1
```

Description:
	- e -- muck around with variables, cpu is set wrong, have to fix
	- o -- muck around with files
	- oo+ -- reopen current file, in RW
	- w -- write
	- wx -- write give hex string to current position
	- 0xd400 -- move around
	- pd 8 -- print disassembly, 8 lines

## Simulated Runs:
Breakpoints:
	7226 / 0xe44c usart_print
	2c8b / 0x5916 main_loop_2c8b

### Patches:
	6a00 / 0xd400 -- 8f3f -> 8330
	6d4b / 0xda96 -- 8d83 -> 8f70 90e0 8b83 1c82 8d83 1e82
	92e5 / 0x125ca -- e0ec f1e0 -> 682f 70e1 fb01 2083 0196 0895
```sh
	# patch const RNG test to iterate 3 times instead of 255 times
	0x6a00*2
	wa  cpi r24, 0x03

	# patch test RNG `rx24` times to `and` rx24 with 0x000f to reduce count
	0x6d4b*2
	"wa  andi r24, 0x0f; ldi r25, 0x00; std y+3, r24; std y+4, r1; std y+5, r24; std y+6, r1"

	# patch eeprom block reads to come from RAM:0x3200 instead
	0x92c7*2
	wa  sbci r23, -0x32

	# patch eeprom byte reads to come from RAM:0x3200 instead
	0x92d8*2
	wa  sbci r31, -0x32

	# patch eeprom writes to go to RAM:0x3200
	0x92e5*2
    "wa movw r22, r24; ldi r19, 0x32; add r23, r19; movw r30, r22; st z, r18; adiw r24, 0x01; ret"

	# write a 0xff to 0x3200 so that we don't have to go through FI slow startup
	0x6778*2
	"wa ser r24; sts 0x3200, r24; ldi r24, 0; ldi r25, 0; call 0x12594; std y+3, r24; std y+1, r1; std y+2, r1; nop"

```

### --
Issue: Simulator doesn't do EEPROM writes
Solution: Find another spot and patch it to write there...
	- BSS ends at 0x3081, so I could use 0x3100+

