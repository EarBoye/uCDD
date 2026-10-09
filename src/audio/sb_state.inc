; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only
%ifndef SB_STATE
%define SB_STATE 1
%define SB_TAIL_CACHE 1
guest_base dw 220h
guest_irq dw 5
guest_dma8 dw 1
guest_dma16 dw 5
guest_vector db 0dh
guest_irq_bit db 20h
guest_irq_priority db 3fh
guest_irq_higher db 1fh
guest_eoi db 65h
guest_dma_ports dw 2,3,83h,0c4h,0c6h,8bh
audio_irq_busy db 0
audio_irq_mask_bit db 0
sb_single db 0
sb_input db 0
sb_finished db 0
sb_paused db 0
sb_speaker db 1
sb_pcm_gain dd 32768,32768
sb_filter_legacy db 0
sb_filter_bypass db 0
sb_filter_state times 4 dd 0
sb_tail_mode db 0
sb_tail_valid db 0
sb_tail_segment dw 0
sb_tail_offset dw 0
sb_tail_consumed dd 0
sb_tail_read_offset dw 0
sb_pause_clock dd 0
sb_pause_mix_frame dd 0
sb_test_register db 0
sb_dac_enabled db 0
sb_dac_value db 128
sb_dac_head dw 0
sb_dac_tail dw 0
sb_dac_frame dd 0
game_origin dd 0
; XORed into every sample by the general mix loop: 80h for signed 8-bit data,
; 8000h for unsigned 16-bit single-cycle data, otherwise zero.
sb_sign8 dd 0
sb_sign16 dw 0
%ifdef VIRTUAL_IRQ
; Command 80h: set while a silence plays, until the output clock reaches
; sb_silence_end. Then the 8-bit interrupt is signalled.
sb_silence db 0
sb_silence_end dd 0
%endif
%ifdef RESIDENT_AUDIO
game_physical dd 0
sb_patch_active db 0
sb_patch_available db 0
sb_patch_clock dd 0
sb_patch_limit dd 0
sb_patch_base dw 0
; Set when a single-cycle block starts a stream: the block does not signal
; until the game has run. 1: the output interrupt that follows the start does
; not signal. 2: no signal until SB_HOLD_FRAMES of output have played since
; sb_hold_clock, the output position when the start write returned.
sb_single_hold db 0
sb_hold_clock dd 0
SB_HOLD_FRAMES equ 128
%endif
%endif
