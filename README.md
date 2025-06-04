# asmlogin

Autologin script for NationStates but written in pure x86_64 Assembly

## Why?

Because I could, and I found it funny.

## Is it written completely from scratch?

Well, no, unfortunately, it does link to libc and libcurl, because re-implementing HTTPS, with SSL and all its associated cryptography, in Assembly, is a _bit_ too insane.

## Does it work?

Yes, it's fully functional. (Works on my machine, at least =P)

## Where does it work?

Any x86_64 system with a POSIX libc and libcurl, I suppose.

## Prerequisites

`nasm` and the GNU C compiler (`gcc`) suite (for the linker).

## How does it work?

Create a file (name it `nations.txt` for example), and populate it with pairs of `nation,password` separated by newlines.

Example:
```
testlandia,1234
example,password
nation,correctHorseBatteryStaple
```

Run `make` to build asmlogin.

Run asmlogin: `asmlogin [MAIN_NATION] [NATION_FILE]` - for me it would be `asmlogin Merethin nations.txt`.

Enjoy.

## Is it NS API legal?

It is, if you're not running any other NS API tools at the same time - asmlogin only sends out one ping request per second.