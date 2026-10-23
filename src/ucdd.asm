; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

bits 16
cpu 386
org 0
%define MDM_SUPPORT 1

%ifdef RESIDENT_AUDIO
%ifndef NO_EMS_QUEUE
%define EMS_QUEUE 1
%endif
%endif

%include "version.inc"
%include "disc.inc"
%include "driver.asm"

; The command helper is transient. It runs in its own segment after the main
; segment and its stack, so that the main segment has room for resident code.
helper_enter:
    mov ax, cs
    mov fs, ax
    add ax, (helper_start-$$)/16
    push ax
    push word command_entry
    retf
    align 16
program_end:
    times 1024 db 0
helper_start:

section helper align=16 vstart=0 follows=.text
%include "helper.asm"
