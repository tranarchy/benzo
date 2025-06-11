# benzo

![image](https://github.com/user-attachments/assets/13263ee9-6443-4b26-9e9f-a2276f161ac7)
<p align="center">CS2 wallhack for Linux written in C</p>

## About

This hack works by patching the `IsOtherEnemy` function in the game making enemies appear as teammates, showing their name, health and gun through walls

## VAC

This should be safe to use since it doesn't change any cvar, however `TracerPid` will be visible to VAC during the patching process, but there are ways to hide this

## Build-time dependencies

- C99 compliant compiler
- make

## How to use

```
git clone https://github.com/tranarchy/benzo
cd benzo
make
./benzo
```

