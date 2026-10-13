; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%ifndef HOST_PROFILE_MACROS
%define HOST_PROFILE_MACROS 1

; The second argument is zero only where incoming flags are dead.
%macro HOST_COUNT 1-2 1
%ifdef HOST_PROFILE
%if %2
    pushfd
%endif
    inc dword [ebp+host_profile_%1]
%if %2
    popfd
%endif
%endif
%endmacro

; Cycle counts (RDTSC, Pentium and later) for the profile build. A slot
; holds cycles (8 bytes) and passes (4 bytes). The begin and end macros keep
; every register and the flags; EBP is the host base.
%macro HOST_TSC_BEGIN 1
%ifdef HOST_PROFILE
    pushfd
    push eax
    push edx
    cpu pentium
    rdtsc
    cpu 386
    mov [ebp+host_profile_t0_%1], eax
    mov [ebp+host_profile_t0_%1+4], edx
    pop edx
    pop eax
    popfd
%endif
%endmacro

; %1 start slot, %2 the slot index in ECX terms: a constant, or `class` for
; the exception class byte set along the way.
%macro HOST_TSC_END 2
%ifdef HOST_PROFILE
    pushfd
    push eax
    push ecx
    push edx
    cpu pentium
    rdtsc
    cpu 386
    sub eax, [ebp+host_profile_t0_%1]
    sbb edx, [ebp+host_profile_t0_%1+4]
%ifidn %2, class
    movzx ecx, byte [ebp+host_profile_class]
%else
    mov ecx, %2
%endif
    lea ecx, [ecx+ecx*2]
    add [ebp+host_profile_cycles+ecx*4], eax
    adc [ebp+host_profile_cycles+ecx*4+4], edx
    inc dword [ebp+host_profile_cycles+ecx*4+8]
    pop edx
    pop ecx
    pop eax
    popfd
%endif
%endmacro

; The bridge can nest (a callback runs client code that bridges again): only
; the outermost pass is timed.
%macro HOST_TSC_BEGIN_NESTED 1
%ifdef HOST_PROFILE
    inc byte [ebp+host_profile_depth_%1]
    cmp byte [ebp+host_profile_depth_%1], 1
    jne %%done
    HOST_TSC_BEGIN %1
%%done:
%endif
%endmacro

%macro HOST_TSC_END_NESTED 2
%ifdef HOST_PROFILE
    dec byte [ebp+host_profile_depth_%1]
    jnz %%done
    HOST_TSC_END %1, %2
%%done:
%endif
%endmacro

; The exception class from the opcode byte: 1 CLI, 2 STI, 3 IN, 4 OUT, else 0.
%macro HOST_TSC_CLASS 1
%ifdef HOST_PROFILE
    push eax
    mov al, %1
    cmp al, 0fah
    jne %%not_cli
    mov byte [ebp+host_profile_class], 1
    jmp %%done
%%not_cli:
    cmp al, 0fbh
    jne %%not_sti
    mov byte [ebp+host_profile_class], 2
    jmp %%done
%%not_sti:
    ; E4h to E7h and ECh to EFh: bit 1 says OUT.
    and al, 2
    shr al, 1
    add al, 3
    mov [ebp+host_profile_class], al
%%done:
    pop eax
%endif
%endmacro

; The step decoder replaces incoming arithmetic flags.
%macro HOST_SAMPLE_STEP 0
%ifdef HOST_PROFILE
    inc dword [ebp+host_profile_step]
    test word [ebp+host_profile_step], 4095
    jnz %%done
    push eax
    push edx
    mov eax, [ebp+host_profile_step]
    shr eax, 12
    and eax, 3
    mov edx, [ebx+48]
    mov [ebp+host_profile_samples+eax*8], edx
    mov edx, [ebx+52]
    mov [ebp+host_profile_samples+eax*8+4], edx
    pop edx
    pop eax
%%done:
%endif
%endmacro

%endif
