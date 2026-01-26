// #import "@preview/clean-math-paper:0.2.4": *
#import "setup.typ": format, center, right, title
#show: format

// // Modify some arguments, which can be overwritten in the template call
// #page-args.insert("numbering", "1/1")
// #text-args-title.insert("size", 2em)
// #text-args-title.insert("fill", black)
// #text-args-authors.insert("size", 12pt)

// #show: template.with(
//   title: "Fractional RSA, COMP2633 Week 8 Homework B",
//   authors: (
//     (name: "Dhairya Shah"),
//   ),
//     date: [November 15th, 2025],
//   heading-color: rgb("#101090"),
//   link-color: rgb("#008002"),
//   abstract: [
// _Finding inverses of e modulo (p-1)(q-1) is too complicated.\ We can just use d = 1 / e._
// ],
//   keywords: ("Crypto", "RSA", "Oracle"),
// )

#set document(
    title: [Fire-Drop\ Firebird CTF 2026]
)

#set heading(numbering: "1.")


#line(length: 100%)

// TODO Replace with #title once we get to a newer typst version
#title()

#line(length: 100%)

= Preface

Challenge authored by Weirdman.

4 Solves, 894 pts.

> Ram costs a thousand dollars because of this 😔🙏

= Analysis
We are provided with a `chal.rar`, `based.jpeg`.

The `.rar` is an archive format that I have not seen in ages personally, to extract with `unrar x chal.rar`, it requested me for a password.

Considering this was a Forensics challenge, I thought the password might be steganographied into the based.jpeg image file (which btw was a really funny read, I 100% agree).

So I wasted just about 30 minutes trying to analyze the based.jpeg image. At the time that I uploaded it to aperisolve, the upload count was two, so I was sure I was on the right path.

Most unfortunately, I was not. Giving up on my lackluster steganography skills, I asked my teammates to try and steg it.

Then I tried to brute some common passwords on `chal.rar`, that's when I noticed that the .pcap file was extracted around 29%. I thought this was really weird, so I guessed that the file wasn't actually password protected.

Consulting the wiki for `.rar`, we can figure out that we need to disable the LHD_PASSWORD bit. After setting it to 0, we also need to recalculate the file's CRC.

Then we can finally `unrar` the file and witness the amazing `2.pcapng` file.

`2.pcapng` covers the SMB transfer of, you guessed it, a file drop over network. The SMB surprisingly uses NTLMSSP/ NTLMSv3.

Surprisingly, this is good for us, we extract the server challenge and the client response to build a crackable hash.

```bash
tshark -r 2.pcapng -Y "ntlmssp.messagetype == 0x00000002" -T fields -e ntlmssp.ntlmserverchallenge
tshark -r 2.pcapng -Y "ntlmssp.messagetype == 0x00000003" -T fields -e ntlmssp.auth.username -e ntlmssp.auth.domain -e ntlmssp.ntlmv2_response
```

Splitting the NTLMv2 response into NTProofStr (first 16 bytes / 32 hex chars) and the blob (rest), then format for hashcat/John:

```
username::domain:server_challenge:NTProofStr:blob
```

or

```
rocky::DESKTOP-BS82713:3baa66840bdaa49b:7a21d053aca5c68cf97e842f44e8e838:010100000000000093733de74b8cdc017a6d2de2b449752400000000020014004400450053004b0054004f0050002d0046004c00010014004400450053004b0054004f0050002d0046004c00040014004400450053004b0054004f0050002d0046004c00030014004400450053004b0054004f0050002d0046004c000700080093733de74b8cdc0106000400020000000800500050000000000000000100000000200000608b394871e5a9eb4f03b21da2463076df770f4f6692e3f9154a805de0431ffdffc7b58cc36d69223ef4876c17241f8bc4db6b48e79a8ca4694dbbc65472edbf0a0010000000000000000000000000000000000009001e0063006900660073002f004400450053004b0054004f0050002d0046004c000000000000000000
```

Now we need to crack this hash. I, being a complete idiot, tried every password bruteforce list in existence apart from rockyou.txt.

I don't even know how I managed to miss the fact that this guy's username is rocky.

So using a wordlist attack, specifically rockyou.txt, we recover the password used as xian.nibai!

This allows us to recover the transferred file over SMB, specifically we can find the transferred flag.zip file.
```
tshark -r 2.pcapng -o ntlmssp.nt_password:xian.nibai -Y "smb2" -T fields -e frame.number -e _ws.col.Info | rg "flag.zip"

# returned 179 and 237

tshark -r 2.pcapng -o ntlmssp.nt_password:xian.nibai -Y "frame.number==179" -V -O smb2

tshark -r 2.pcapng -o ntlmssp.nt_password:xian.nibai -Y "frame.number==237" -V -O smb2i

# concatenate them into a single flag.zip

cat frame179.hex frame237.hex | xxd -r -p > smb_export/flag.zip
```

Now again, this zip file is password protected, so as you may guess, I tried every single wordlist in existence and couldn't unzip it...

Only once my teammates started to yell at me to solve the chall, did I realize that the zip file had based.jpeg and we had a based.jpeg file... Could it be? that they are the same???

Yes, yes they are. But soon you will see why I thought the image file was a red herring.

We can use this #link("https://github.com/kimci86/bkcrack")[great tool] to crack old zip files using ZipCrypto.

With this we recover the zip file without a password and by unzipping it, we can verify that indeed both based.jpegs are the same.

But wait, what is going on with flag.txt... that is not a flag?

```bash

$ > hexdump flag.txt
0000000 feff 0666 0972 0656 0269 0726 047b 0666
0000010 0f72 0336 0e6d 0313 0563 05f6 0d30 04d3
0000020 036e 0377                              
0000024
```

At this stage I was not very happy, and I recognized the UTF 16 LE headers.

So I thought maybe I had made a mistake, and the JPEGs were different. My thought process: the PNG headers are the same, but the contents differ, which is causing my flag.txt decryption to break, I must go fix the based.jpeg

Obviously, I had no hope fixing the based.jpeg, So I did what any rational person would do and tried to brute force the last byte.

My assumption was, the flag.txt should start with `firebird{`, which is 10 bytes, and we need 12 bytes of known plain text for zipcrypto to work. This would allow me to brute force two bytes and get a proper decryption working.

Can you tell how I have no idea how encryption works?

Anyways, I was also inducing hallucination on my dear teammate Sayako, by trying to make him find some pattern.

We imagined, suppose for the start

```
6606
7209
5606
6902
```
could be transformed into
```
66
69 # this 69 came from the previous 6606's last hex digit and the 9 from the next 7209's last hex digit.
72
65 # assume the 56 had to swap for some reason.
62 # same as above
69
```
This results in `firebi`.

In fact we thought it was so promising, continuing using this terrible method, we managed to get all the way up to `firebird{for3nm156_m0M3nsp`, i really don't even know how...

At this point, it was already 1AM and I had induced a lot of hallucination into Sayako-GPT, so I decided to go to sleep.

Sayako-kun stayed up until 3 AM trying to figure out what this flag.txt is...

Let's take a look at his analysis...

#image("sayako-fire-drop.png")

uhmm... I really don't know either.

After slaving away at this challenge, somehow Sayako managed to find the flag. I really don't know how.

This is why we have 30 submissions.

`firebird{for3nm1Sc_m0M3n7}`

Please never write a challenge like this again.

At least give us the right flag in flag.txt or through some actual steganography...

This is like super-encryption all over again. (P.S. I never managed to solve it and I was depressed for so long).

