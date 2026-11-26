# Root cause: why the YAS-109 drops ARC after the TV powers off

## Summary
The YAS-109 has two processors:

- an **ABOV A33G526** (ARM Cortex-M3) **MCU** that owns HDMI, CEC and ARC, and
- a **MediaTek MT8516** running embedded Linux (Wiimu / LinkPlay), the "smart" side.

The MCU runs its **HDMI-ARC initialization exactly once, at MCU boot**, and nothing
ever re-runs it. When the TV powers off and back on, the ARC link needs to be
re-established, but the MCU never repeats that init, so **ARC stays dead** until the
whole bar is reset. That is the "disconnects after the TV powers off" symptom.

## Evidence (from the decrypted firmware)
On the MCU image (loaded raw as `ARM:LE:32:Cortex` in a decompiler):

- `FUN_0043f4c4` — the HDMI-ARC init routine.
- It is called **only** by the MCU boot path `FUN_00443b52`, which is
  *initialize-once, then an empty infinite loop*. So ARC init runs a single time.
- The CEC handler (`FUN_0043f1a8`) does **not** call ARC init, so a CEC wake/handshake
  from the TV never re-initializes ARC.

On the Linux side, the process that owns the serial link to the MCU is `mv_ioguard`
(it holds `/dev/ttyS1`). On a TV wake it only sends `AXX+POW+000` (a power/notify
message) — it never asks the MCU to re-init ARC.

## The lever
`mv_ioguard` already knows how to reset the MCU: a `GNOTIFY=REBOOT` request maps
(via `FUN_0040fed0`, "reboot" → `AXX+DEV+RST`) to the MCU reset command.

- **Command:** `AXX+DEV+RST` — 11 ASCII bytes, **no terminator** (verified against the
  raw bytes: the literal is followed by `\x00` in the image, i.e. the string ends there).
- **Port / line settings:** `/dev/ttyS1`, **115200 8N1** (the firmware's config string
  decodes to `115200,8,N,1`).

Resetting the MCU makes it reboot and **re-run `FUN_0043f4c4`**, which re-establishes
HDMI-ARC. That is the entire fix: detect "the TV just came back on" and pulse that reset.

## Detecting "the TV came back on"
The bar suspends when the TV powers off and resumes when it powers on. The kernel
exposes a resume counter at `/sys/power/suspend_stats/success`; it increments on each
resume. The watcher polls it and acts on each increment. (If a given unit does not
actually suspend on TV-off, this trigger won't fire — see Limitations.)

## Why not reflash the MCU / firmware?
The bug is a **re-init timing** problem, not a corrupt image. A userspace watcher plus
an MCU reset fixes the observed behavior with far less risk than rewriting MCU flash.
Nothing in the stock firmware is modified, so the change is cleanly reversible.

## Limitations / where this may not generalize
- Verified on **firmware Ver 5.31** and a **TCL** TV only. Function addresses above are
  from that image; other versions will differ (the *approach* should still hold).
- Assumes the bar **suspends on TV-off / resumes on TV-on**. If a unit stays fully
  awake, the suspend-counter trigger never fires and this specific watcher won't help.
- `AXX+DEV+RST` and `/dev/ttyS1` @ 115200 are model/firmware specific.
