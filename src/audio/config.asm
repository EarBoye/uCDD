; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; UCDD.CFG contents. At installation, UCDDSET checks the file and copies the
; complete record into the driver.
CONFIG_VERSION equ 2
CONFIG_SIZE equ 36
HOTKEY_COUNT equ 5
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
; Next, previous, eject, volume up, volume down. Bit 7 marks an E0 key.
config_keys db 51h,49h,12h,4eh,4ah
config_cd_volume db 100
config_game_volume db 100
config_master_volume db 100
config_volume_step db 10
; UCDDSET sets the physical mixer value for the selected card.
master_register db 0f8h
; 0 SB16, 1 SB Pro, 3 SB 1.5/2.0, as sound_card.
virtual_model db 0
virtual_wss_base dw 530h
virtual_wss_irq db 11
; UCDDSET sets the DSP version reply: minor in the high byte.
virtual_dsp_version dw 0504h
    db 0
