# PIC16C6XX Power Glitch Attack (WIP)

### Overview

This project will *hopefully* result in obtaining a dump of the protected code on the original Xbox SMC (System Management Controller) to be used for research and/or emulation purposes.

![PIC Research Image](images/pic-research.jpg?raw=true "PIC Research")

### Requirements

##### Hardware (more detailed instructions will follow later)

- Desoldered PIC16LC63A
- Pynq-Z2 FPGA (although others can be used with project modifications)
- An external 6.6V-12.75V DC power source (a 9V battery works great)
- Breadboard
- SOIC-28 breakout board
- Single row pin headers
- Jumper Wires
- 2 NPN Transistors (2N2222A for example)
- 4 1K Resistors
- Hot air gun and other soldering equipment
- Logic analyzer for troubleshooting

##### Software

[Vivado Design Suite - HLx Editions](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools.html)

### Support

Contact xbox7887 in [XboxDev on Discord](https://discord.gg/WxJPPyz).

### Reference

[XboxDevWiki](http://xboxdevwiki.net/System_Management_Controller)  
[PIC16C6X](https://web.archive.org/web/20190801020141/http://ww1.microchip.com/downloads/en/DeviceDoc/30234E.pdf)  
[PIC16C6XX Programming Specifications](https://web.archive.org/web/20190801020358/http://ww1.microchip.com/downloads/en/DeviceDoc/30228k.pdf)  
[PIC16C63A](https://web.archive.org/web/20190728230058/http://ww1.microchip.com/downloads/en/DeviceDoc/30605D.pdf)  
[PIC16C63A Errata](https://web.archive.org/web/20190801015506/http://ww1.microchip.com/downloads/en/DeviceDoc/80015b.pdf)  
[Copy Protection in Modern Microcontrollers](https://web.archive.org/web/20190801014726/https://www.cl.cam.ac.uk/~sps32/mcu_lock.html)  
[Crack Pic](https://web.archive.org/web/20190801015320/http://www.piclist.com/techref/microchip/crackpic.htm)  
[Tamper Resistance - a Cautionary Note](https://web.archive.org/web/20190801015019/https://www.cl.cam.ac.uk/~rja14/tamper.html)  
[Cracking / Guarding PICs](https://web.archive.org/web/20190801015119/http://www.piclist.com/techref/microchip/crack.htm)
