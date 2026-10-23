; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; UCDD.CFG contents. At installation, UCDDSET checks the file and copies the
; complete record into the driver.
CONFIG_VERSION equ 5
CONFIG_SIZE equ 45
HOTKEY_COUNT equ 11
config_data db 'uCDD',CONFIG_VERSION
sound_card db 0
sb_base dw 220h
sb_irq db 5
sb_dma8 db 1
sb_dma16 db 5
config_ready db 0
virtual_base dw 220h
virtual_irq db 5
virtual_dma8 db 1
virtual_dma16 db 5
; Bits 0 to 3: Ctrl, Alt, Shift, Win.
config_modifiers db 3
; 0 off, 1 keys 1 to 0, 2 keys F1 to F10.
config_disc_keys db 1
; Next, previous, eject, then up and down keys for the CD, master, FM, and
; PCM levels. Bit 7 marks an E0 key.
config_keys db 51h,49h,12h,13h,21h,4eh,4ah,14h,22h,15h,23h
config_cd_volume db 100
config_game_volume db 100
config_master_volume db 100
config_volume_step db 10
; UCDDSET sets the physical mixer value for the selected card.
master_register db 0f8h
; 0 SB16, 1 SB Pro, 3 SB 1.5/2.0, as sound_card; 4 the ESS AudioDrive, the
; only one the ESS build (--virtual-ess) presents.
%ifdef VIRTUAL_ESS
virtual_model db 4
%else
virtual_model db 0
%endif
virtual_wss_base dw 530h
virtual_wss_irq db 11
; UCDDSET sets the DSP version reply: minor in the high byte.
%ifdef VIRTUAL_ESS
virtual_dsp_version dw 0103h
%else
virtual_dsp_version dw 0d04h
%endif
config_fm_volume db 100
; Version 5 (24 Oct 2026, the merge of the author's 0.9.4-a6): the author's
; version 4 record above, then the fork's three bytes. UCDDSET brings every
; older file to this layout (setup/config_file.asm), the fork's bytes reading
; 0 where a file has none.
; IRQ of a disk controller that the PCI scan does not find, or 0.
config_disk_irq db 0
; 1 keeps the physical output and the traps on at all times. 0 lets the
; driver step aside while no disc is bound for CD audio and the physical card
; can stand in for the virtual one (audio/standby.asm).
config_audio_always db 0
; 1 asks for the platform's fast DMA timing on the output channel while the
; driver is engaged (docs/platform-dma.md, audio/standby.asm), on a chipset
; the install's scan finds in its table (platform.asm); nothing happens on
; another.
config_fast_dma db 0
config_size_check equ 1 / (($-config_data) = CONFIG_SIZE)
; Not in UCDD.CFG. UCDD -install scans the PCI BIOS (disk_scan.asm) and sets
; the mask: IRQ 14 and 15, the IRQs of PCI disk controllers, and
; config_disk_irq. Those IRQs go straight to the real-mode handler (see
; host/bridge.asm).
config_disk_mask dw 0c000h
