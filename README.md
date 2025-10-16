# benzo
<p align="center">
<img src="./preview.gif"/>
</p>
<p align="center">CS2 one byte wallhack for Linux written in x86-64 assembly</p>

## How it works

benzo works by patching the `IsOtherEnemy` function in the game's memory, making the function return false every time

The enemies appear as teammates, showing their name, health and gun through walls

## About

benzo doesn't link with libc, it only uses Linux x86-64 syscalls, therefore its only runtime dependency is the x86-64 Linux kernel

## VAC

This should be safe to use since it doesn't change any cvar, however `TracerPid` will be visible to VAC during the patching process, but there are ways to hide this

## Build-time dependencies

- GNU assembler*
- GNU linker

On most distros installing the `binutils` package will get you these tools

*If you want to use another assembler you will need to use one that supports `GAS` syntax (e.g., `yasm`)

## How to use

```
git clone https://github.com/tranarchy/benzo
cd benzo
./build.sh
sudo ./benzo
```
