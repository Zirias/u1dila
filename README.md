# u1dila: Ultimate-1 DIsk LAuncher for 8bit Commodore home computers

This is a browser and launcher for a 1541-Ultimate operated in "standalone
mode". It currently only supports the original revision (**not** the UII or
UII+).

<a href="https://github.com/Zirias/u1dila/blob/res/u1dila-vic20.png?raw=true"><img src="https://github.com/Zirias/u1dila/blob/res/u1dila-vic20.png?raw=true" alt="u1dila vic20" width="196px"></a>
<a href="https://github.com/Zirias/u1dila/blob/res/u1dila-c64.png?raw=true"><img src="https://github.com/Zirias/u1dila/blob/res/u1dila-c64.png?raw=true" alt="u1dila c64" width="196px"></a>
<a href="https://github.com/Zirias/u1dila/blob/res/u1dila-c16.png?raw=true"><img src="https://github.com/Zirias/u1dila/blob/res/u1dila-c16.png?raw=true" alt="u1dila c16, c116, plus/4" width="196px"></a>
<a href="https://github.com/Zirias/u1dila/blob/res/u1dila-c128.png?raw=true"><img src="https://github.com/Zirias/u1dila/blob/res/u1dila-c128.png?raw=true" alt="u1dila c128" width="196px"></a>

## Terms and definitions

* **1541 Ultimate**: A piece of (modern) hardware exactly emulating a 1541
  disk drive, communicating on the standard CBM serial bus. It is normally
  plugged into the cartridge slot of a C64 or C128 and can be cotrolled with
  its builtin software.
* **Standalone mode**: At least the original revision supports operation
  without being plugged into the cartridge slot.
* **Control device**: The 1541-U always offers a device emulating the drive,
  which uses "mounted" D64 images as virtual floppy disks. But it can offer an
  additional device (on a distinct drive number) allowing direct access to its
  storage (SD card or USB drive). Some older 1541-U docs called that the "SD 2
  IEC", newer 1541-UII+ docs call it the "SoftIEC". To avoid confusion, the
  term **control device** is used here, as it also allows to send specific
  commands to the 1541-U, which is required for `u1dila`.

## Motivation

The 1541-Ultimate cartridges can't be used on the Commodore 264 (C16, C116,
Plus/4) series computers because they have a different cartridge slot than the
C64, with one exception: The old version 1 offers a "standalone mode" allowing
to operate the cartridge only connected to the serial bus. This standalone
mode is also sometimes useful in more unusual situations, even if you have a
compatible cartridge slot.

In this mode, controlling the cartridge is only possible by either sending
commands to the command channel of its "controlling device", which also allows
reading directories from the SD card, or by blindly using its three buttons,
or a combination of both. That's very cumbersome to do manually.

## What this tool does

`u1dila` offers a simple solution for a common usecase: Select and mount a
d64 image, disable the control device, and (optionally) autostart the mounted
disk. It also offers directly launching "single-file" `.prg` programs.

Currently, the emulated 1541 device **must** be drive `#8` for `u1dila`, but
the control device can be chosen freely (`#9`, `#10` or `#11`).

There's a limit for the number of entries that can be shown in a directory.
`u1dila` always adds two "pseudo directory" entries on top, `/` for the root
directory and `..` for the parent directory. Not counting these, the limit is
fixed at **254 entries**. But note `u1dila` only ever displays supported
types, which are `DIR`, `D64` and `PRG`. This limit should be enough for most
practical purposes, still if you have a directory with more entries of these
supported types, the exceeding entries will be silently ignored and
inaccessible.

## Drive number of the control device

**`u1dila` assumes that it's initially loaded from the control device**, IOW,
from the SD card of the 1541-U. It will use that same device number to load
and browse directories.

You can override this before running `u1dila` using a simple `POKE` command,
for example run one of these to make the tool use drive `#10`:

    POKE 174,10        :REM for C16, C116, PLUS/4
    POKE 186,10        :REM for all other supported machines

For the technically interested: These commands directly modify the location
used by the KERNAL to store the device number of the last serial bus device
used. `u1dila` just looks there for all its communications.

## Usage

Once started, the tool will load the current directory and display it for
browsing, only showing entries of types `DIR`, `D64` and `PRG`. It can be
controlled with the keyboard as follows:

* `RUN/STOP`: exit the tool
* `CRSR UP/DOWN`: select entries in the directory
* `RETURN`: perform an action on the selected entry, depending on its type:
  - `DIR`: change to the selected directory and reload
  - `D64`: mount the image on drive `#8`, disable the control device, perform
           a soft reset and automatically load and run the first file
  - `PRG`: perform a soft reset and load+run the selected file (directly from
           the control device)
* `F1`: perform action on the selected entry, same as `RETURN` with one
  exception: When used on a `D64` image, automatically loading + running is
  skipped, so you can manually load whatever file you wanted from the image.

## Supported platforms

The following build targets (add `PLATFORM=xxx` to your `make` command,
default is `c16`) are offered, and you can download prebuilt `prg` files for
these from a release page as well:

* `vic20`: The unexpanded (5 kiB) VIC-20. RAM is so limited on this machine,
  this build restricts the number of directory entries to just 104.
* `vic20x`: VIC-20 with the low 3kiB memory extension (at `$400`).
* `vic20e`: VIC-20 with one (or more) 8kiB memory extensions (starting at
  `$2000`).
* `c64`: Commodore 64
* `c16`: Commodore 264 series (C16, C116, Plus/4)
* `c128`: Commodore 128 (will be forced into 40 column mode for simplicity)

## Building yourself

To build `u1dila` yourself, you need

* The `cc65` package (providing `ca65` and `ld65`)
* GNU make
* A POSIX shell environment providing `sh`, `echo`, `mv`, `rm` and `touch`

On Windows, the required shell environment may be provided for example by the
`WSL` (Windows Subsystem for Linux) or by `MSYS2`.

To build the `prg`, just type

    make -j PLATFORM=xxx

where `xxx` is one of the supported platforms described above, defaulting to
`c16` if not given at all. The `-j` flag is optional and tells `make` to run
multiple jobs in parallel, which typically speeds up the build. On platforms
normally not using GNU make, like e.g. the BSDs, you'll have to type `gmake`
instead of `make`. You may also add `V=1` (for verbose) to see all the
commands invoked literally, by default only the targets built are shown.

To clean all files created by the build, type

    make clean

