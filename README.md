# YAS-109 HDMI-ARC disconnect fix

A fix for the Yamaha **YAS-109** soundbar's long-standing bug where it **drops
HDMI-ARC and goes silent after the TV is powered off and back on**, often needing
a power-cycle or the phone app to recover.

It fixes the bug **without reflashing firmware** and **without the Yamaha app**. It
adds three small files to the bar's Linux side that reset the soundbar's MCU when
the TV wakes, which forces the MCU to re-run its (otherwise once-only) HDMI-ARC
handshake. It is fully reversible.

> **Status:** working on real hardware — firmware **Ver 5.31**, driving a **TCL
> 55" LCD TV**. The bar survived every TV power-cycle, stayed connected, and the TV
> remote controlled it. See [docs/ROOT-CAUSE.md](docs/ROOT-CAUSE.md) for the analysis.

---

## ⚠️ Read this before you do anything

- **This is not an official Yamaha update. Use it at your own risk.** You can brick
  your soundbar. There is no warranty (see `LICENSE`).
- **Only tested on firmware Ver 5.31 with a TCL TV.** Other firmware versions, other
  hardware revisions, and other TVs may behave differently. The MCU reset command and
  the serial port are specific to this model/firmware.
- **It installs by running a script as root through Yamaha's own USB update path.**
  That is powerful and that is why it can brick the unit if the payload is wrong.
  Read `scripts/install-fix.sh` yourself before building the update file.
- **It is reversible** (`scripts/uninstall-fix.sh`) and **does not modify firmware**,
  but a bad flash can still leave the bar in a bad state. Keep your stock firmware
  image as a restore path (you supply your own — see below).

This repository contains **only original fix code and documentation**. It contains
**no Yamaha firmware and no decryption keys** — you provide those yourself from your
own device / the public sources linked below.

---

## What it does

1. `yas109-arc-watch.sh` runs on the bar, polling the kernel suspend counter.
2. When the TV powers back on (the bar resumes), it sends the MCU reset command
   `AXX+DEV+RST` over the UART (`/dev/ttyS1`, 115200 8N1).
3. The MCU reboots and re-runs its one-time HDMI-ARC init → ARC audio returns.

It is run by a **new** systemd service (`yas109-arc.service`); **no stock file is
edited**, which is what makes it clean to remove.

## Files

| File | Where it ends up | Role |
|---|---|---|
| `scripts/install-fix.sh` | runs once as root (the USB payload) | installs the three files below |
| `scripts/yas109-arc-watch.sh` | `/data/yas109-arc-watch.sh` on the bar | the resume watcher |
| `scripts/yas109-arc.service` | `/etc/systemd/system/` on the bar | starts the watcher at boot |
| `scripts/uninstall-fix.sh` | runs once as root (the USB payload) | removes everything, restores prior state |

## How to install (high level)

The bar accepts a USB firmware update that is an **OpenSSL-encrypted shell script**
named `yamaha_usb_upgrade.enc`. The stock updater decrypts it and runs it as root.
This project uses that same path to drop in the fix instead of flashing anything.

1. **Get your model's update encryption key** and the ability to encrypt a payload.
   This project does not ship it. The firmware's encryption was publicly documented by
   **lab313ru**; see [docs/DECRYPT.md](docs/DECRYPT.md) for pointers. Do this with your
   own firmware.
2. **Encrypt `scripts/install-fix.sh`** into a `yamaha_usb_upgrade.enc` using the same
   OpenSSL parameters the stock updater expects (see `docs/DECRYPT.md`). Do **not**
   include `update.zip` / `uImage_ota_mcu` — their absence is what makes the updater
   drop the files without flashing firmware.
3. Put `yamaha_usb_upgrade.enc` (plus the matching `yamaha_ver.txt`) in the **root** of
   a FAT32 USB stick.
4. Flash it on the bar using the model's USB update procedure (UPDATE-only jack; hold
   **Vol−** + **Power**). Wait for the completion chime.
5. **Power-cycle the bar once** so the new systemd service starts, then set it up with
   the TV and test by turning the TV off and on a few times.

The watcher logs to `/data/yas109-arc.log` on the bar, so you can confirm it fires on
each resume.

## How to uninstall

Encrypt `scripts/uninstall-fix.sh` the same way, flash it, and it removes all three
files. Firmware was never modified, so the bar returns to exactly its prior state.
Logs are kept.

## Keep a restore image

Before you start, keep a copy of your bar's **stock firmware update** (the official
`.enc` set for your version). If anything ever goes wrong, that is your clean restore
path. This repo intentionally does **not** distribute it.

## Credits & prior work

- Firmware encryption / decryption method: **lab313ru** (public gists, linked in
  `docs/DECRYPT.md`).
- Root-cause analysis and the fix in this repo are original work, done by reverse
  engineering the decrypted firmware.

## License

MIT — see `LICENSE`. No warranty. You are responsible for what you flash to your own
hardware.
