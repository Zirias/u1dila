# u1dila: Ultimate-1 DIsk LAuncher for 8bit Commodore home computers

The 1541-Ultimate cartridges can't be used on the Commodore 264 (C16, C116,
Plus/4) series computers because they have a different cartridge slot than the
C64, with one exception: The old version 1 offers a "standalone" mode allowing
to operate the cartridge only connected to the serial bus. This standalone
mode is also sometimes useful in more unusual situations, even if you have a
compatible cartridge slot.

In this mode, controlling the cartridge is only possible by either sending
commands to the command channel of its "controlling device", which also allows
reading directories from the SD card, or by blindly using its three buttons,
or a combination of both. That's very cumbersome to do manually.

This tool offers a simple solution for a common usecase: Select and mount a
d64 image, disable the control device, and (optionally) autostart the mounted
disk. It also offers directly launching "single-file" `.prg` programs.

![u1dila screenshot](https://github.com/Zirias/u1dila/blob/res/screenshot.png?raw=true)

There's a limit for the number of files that can be shown in a directory. To
fit the "file number" into one byte, this limit is **254 files** (with two
pseudo-files added for changing directory to parent and root). That's probably
enough for most practical purposes, but if you have any larger directory on
your SD card, additional files will simply be ignored.

The following build targets (add `PLATFORM=xxx` to your `make` command,
default is `c16`) are offered, and you can download prebuilt `prg` files for
these from a release page as well:

* `vic20`: The unexpanded (5 kiB) VIC-20. RAM is so limited on this machine,
  this build restricts the number of directory entries to just 100.
* `vic20x`: VIC-20 with the low 3kiB memory extension (at `$400`).
* `vic20e`: VIC-20 with one (or more) 8kiB memory extensions (starting at
  `$2000`).
* `c64`: Commodore 64
* `c16`: Commodore 264 series (C16, C116, Plus/4)
* `c128`: Commodore 128 (will be forced into 40 column mode for simplicity)

To use `u1dila`, configure your 1541-U1 to offer the emulated 1541 as drive
number `#8` and the control device as drive number `#9`. It will then load the
SD card directory on start and can be controlled with the keyboard:

* `RUN/STOP`: exit the tool
* `CRSR UP/DOWN`: select entries in the directory
* `RETURN`: perform an action on the selected entry, depending on its type:
  - `DIR`: change to the selected directory and reload
  - `D64`: mount the image on drive `#8`, disable drive `#9`, perform a soft
           reset and automatically load and run the first file
  - `PRG`: perform a soft reset and load+run the selected file (directly from
           drive `#9`)
  - *other types*: Ignored
* `F1`: perform action on the selected entry, same as `RETURN` with one
  exception: When used on a `D64` image, automatically loading + running is
  skipped, so you can manually load whatever file you wanted from the image.
