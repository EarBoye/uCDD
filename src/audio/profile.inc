; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Cycle counts for the test build with DRIVER_PROFILE (build.py
; --profile-driver). RDTSC needs a Pentium. Each slot keeps the cycles spent
; between its BEGIN and END and the number of passes; the block is found in
; memory by its tag. Both macros keep every register and the flags.
%macro DRV_TSC_BEGIN 1
%ifdef DRIVER_PROFILE
    pushf
    push eax
    push edx
    cpu pentium
    rdtsc
    cpu 386
    mov [cs:drv_profile_t0_%1], eax
    mov [cs:drv_profile_t0_%1+4], edx
    pop edx
    pop eax
    popf
%endif
%endmacro

%macro DRV_TSC_END 1
%ifdef DRIVER_PROFILE
    pushf
    push eax
    push edx
    cpu pentium
    rdtsc
    cpu 386
    sub eax, [cs:drv_profile_t0_%1]
    sbb edx, [cs:drv_profile_t0_%1+4]
    add [cs:drv_profile_%1], eax
    adc [cs:drv_profile_%1+4], edx
    inc dword [cs:drv_profile_%1+8]
    pop edx
    pop eax
    popf
%endif
%endmacro

; One slot: cycles (8 bytes), passes (4 bytes).
%macro DRV_PROFILE_SLOT 1
drv_profile_%1: dq 0
    dd 0
%endmacro

%macro DRV_PROFILE_START 1
drv_profile_t0_%1: dq 0
%endmacro

%macro DRV_PROFILE_DATA 0
%ifdef DRIVER_PROFILE
align 4
drv_profile:
    db 'uCDDprof', 1, 0
    dw drv_profile_end-drv_profile
    ; Slots in this order, 12 bytes each, from offset 12:
    ; irq (the physical interrupt handler from the stack switch to its EOI),
    ; mix (mix_half from the handler), load (the disc half load and filter),
    ; refill (cd_foreground from the timer and the deferred refill),
    ; dosread (the INT 21h read of the image), xmsw (the XMS writes into
    ; the queue), trap (port_callback, the active path).
    DRV_PROFILE_SLOT pirq
    DRV_PROFILE_SLOT mix
    DRV_PROFILE_SLOT load
    DRV_PROFILE_SLOT refill
    DRV_PROFILE_SLOT dosread
    DRV_PROFILE_SLOT xmsw
    DRV_PROFILE_SLOT trap
    DRV_PROFILE_START pirq
    DRV_PROFILE_START mix
    DRV_PROFILE_START load
    DRV_PROFILE_START refill
    DRV_PROFILE_START dosread
    DRV_PROFILE_START xmsw
    DRV_PROFILE_START trap
drv_profile_end:
%endif
%endmacro
