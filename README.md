# u1dila: Ultimate-1 DIsk LAuncher for C16/116/+4

The 1541-Ultimate cartridges can't be used on the Commodore 264 series
computers because they have a different cartridge slot than the C64, with one
exception: The old version 1 offers a "standalone" mode allowing to operate
the cartridge only connected to the serial bus.

In this mode, controlling the cartridge is only possible by either sending
commands to the command channel of its "controlling device", which also allows
reading directories from the SD card, or by blindly using its three buttons,
or a combination of both. That's very cumbersome to do manually.

This tool offers a simple solution for a common usecase: Select and mount a
d64 image, disable the control device, and autostart the mounted disk. It
also offers directly launching "single-file" `.prg` programs.

To use it, configure your 1541-U1 to offer the emulated 1541 as drive number
`#8` and the control device as drive number `#9`. It will then load the SD
card directory on start and can be controlled with the keyboard:

* `RUN/STOP`: exit the tool
* `CRSR UP/DOWN`: select entries in the directory
* `RETURN`: perform an action on the selected entry, depending on its type:
  - `DIR`: change to the selected directory and reload
  - `D64`: mount the image on drive `#8`, disable drive `#9`, perform a soft
           reset and automatically load and run the first file
  - `PRG`: perform a soft reset and load+run the selected file (directly from
           drive `#9`)
  - *other types*: Ignored

