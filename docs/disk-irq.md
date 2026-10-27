# DISKIRQ: disk controller IRQs go straight to DOS

Stops DOS/4GW games freezing at their banner on PCs whose disk controller
is a PCI card, by sending the disk IRQs straight to their real-mode
handlers. Developed on the EarBoye/uCDD fork, where it has been the driver
on our test PC since 19 Oct 2026, and ported here onto Beta 0.9.4-a6. On
this base it is built and not yet run.

## The fault

On a PC whose disk controller is a PCI card, DOS/4GW games froze at their
banner under the resident audio driver. The machine: an ECS P5HX-A
(430HX) with a Promise Ultra133 TX2 as its only IDE controller (the onboard
IDE off). The Promise card's IRQ moves with the BIOS settings: IRQ 9, 14 and
3 were all seen.

The cause: a PCI disk controller holds its level-triggered request until
its real-mode handler runs. When a protected-mode program waits in a
real-mode call for the disk (a DOS read through the extender), the DPMI host
queues that IRQ for the client, the client cannot take it while it waits,
and the disk call never ends.

## The change

The disk controller IRQs go to their real-mode handlers directly, never to
the protected-mode client: IRQ 14 and 15 always, the IRQs of the PCI disk
controllers the driver finds at installation, and one IRQ set by hand for a
controller the scan cannot find (an ISA or VLB card). The sound card's own
IRQ is never one of them.

- `src/disk_scan.asm` (new): walks the PCI BIOS (INT 1Ah, B1xxh) for mass
  storage controllers (class 01h) and the IRQs the BIOS gave them, on a
  stack of its own (a PCI BIOS may use 1 KB of the caller's). `SET
  UCDDPCI=OFF` skips the scan, for a PCI BIOS that fails under the memory
  manager. A controller with no interrupt pin, such as a chipset IDE port in
  compatibility mode, uses IRQ 14 and 15.
- `src/driver.asm`: `UCDD -install` runs the scan, builds the mask
  (`config_disk_mask`) and prints the IRQs beyond 14 and 15, with a warning
  when a disk IRQ is also a sound card setting.
- `src/audio/sb_patch.asm`, `src/host/resident.asm`, `src/host/v86.asm`:
  the driver's block for the host becomes CDF5: CDF4 as it was, then a
  pointer to the mask at +24. The host takes the mask without the timer,
  keyboard, cascade, RTC, coprocessor and the sound card's IRQ.
- `src/host/bridge.asm`: the real-mode IRQ stubs chain a disk IRQ to the
  real-mode handler at once. `src/host/monitor.asm`: a disk IRQ taken in
  protected mode goes to the real-mode handler, as the audio IRQ does.
- UCDDSET (`src/setup.asm`, `src/setup/disk.asm`): a Disk row shows the PCI
  disk IRQs the scan finds and takes an IRQ by hand ("Other disk card
  IRQ"), with a warning when a disk IRQ is a sound card's.
- `UCDD.CFG` version 5 (45 bytes): version 4's record, then the IRQ set by
  hand at offset 42; offsets 43 and 44 are reserved for the fork's
  step-aside and fast DMA branches, which use the same layout. UCDDSET
  reads version 2 and version 4 files as before; the new bytes read 0.

## What was tested

On the fork's own line (0.9.3b and the fork's changes):
- The first form passed IRQ 14 and 15 only. The freeze came back when BIOS
  changes moved the Promise card to IRQ 9, and the scan was added.
- QEMU with an AHCI controller on IRQ 11: the install prints "Disk
  controller IRQs go to DOS directly: 11 14 15" and the driver's and the
  host's masks read 11 14 15; with `UCDDPCI=OFF`, 14 15. DOSBox-X with and
  without a PCI bus finds nothing, and an IRQ set by hand (9) gives 9 14 15.
- The fork's driver, with the scan, has been the driver on the real PC
  since 19 Oct 2026; the IRQ 9 case was not run again as a test.

On this branch (the change ported onto 0.9.4-a6): built at 128 and 32
frames and without resident audio. Not run yet.
