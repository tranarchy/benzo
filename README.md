# benzo
![image](https://github.com/user-attachments/assets/1c2a1d1e-9da0-4916-9998-dd61b4841cef)
<p align="center">CS2 wallhack for Linux written in x86-64 assembly</p>

## About

This hack works by patching the `IsOtherEnemy` function in the game's memory, making the function return false every time

The enemies appear as teammates, showing their name, health and gun through walls

## VAC

This should be safe to use since it doesn't change any cvar, however `TracerPid` will be visible to VAC during the patching process, but there are ways to hide this

## Prerequisites

You will need `GNU assembler`, `GNU linker` and `GNU make`

On most distros installing the `binutils` and `make` package will get you these tools

If you want to use another assembler you will need to use one that supports `GAS` syntax (e.g., `yasm`)

## How to use

```
git clone https://github.com/tranarchy/benzo
cd benzo
make
./benzo
```
