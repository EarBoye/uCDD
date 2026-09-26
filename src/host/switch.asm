; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

HOST_PROTECTED
dpmi_state_addresses:
    mov word [ebx+36], 0
    mov eax, [ebp+mon_real_base]
    shr eax, 4
    mov [ebx+24], ax
    mov word [ebx+32], dpmi_state_real
    call dpmi_stub_selector
    mov [ebx+12], ax
    mov eax, dpmi_state_pm
    mov [ebx+8], eax
    jmp mon_dpmi.success
dpmi_raw_addresses:
    mov eax, [ebp+mon_real_base]
    shr eax, 4
    mov [ebx+24], ax
    mov word [ebx+32], dpmi_raw_enter
    call dpmi_stub_selector
    mov [ebx+12], ax
    mov eax, dpmi_raw_exit
    mov [ebx+8], eax
    jmp mon_dpmi.success
dpmi_state_pm:
    retf
dpmi_raw_exit:
    int 0f0h
    ud2
dpmi_raw:
    pushad
    push ds
    push es
    mov ax, 10h
    mov ds, ax
    mov es, ax
    call .base
.base:
    pop ebp
    sub ebp, .base
    cmp byte [ebp+dpmi_active], 1
    jne .bad_gate
    cmp word [esp+44], 3bh
    je .stub
    cmp word [esp+44], DPMI_STUB16
    jne .bad_gate
.stub:
    cmp dword [esp+40], dpmi_raw_exit+2
    jne .bad_gate
    mov ebx, esp
    call dpmi_record_segments
    mov [ebp+dpmi_raw_segs], fs
    mov [ebp+dpmi_raw_segs+2], gs
    call dpmi_locked_capture
    mov eax, [esp+16]
    mov [ebp+dpmi_raw_bp], eax
    mov ax, [esp+8]
    mov [ebp+dpmi_raw_target], ax
    mov ax, [esp+12]
    mov [ebp+dpmi_raw_target+2], ax
    lea edi, [ebp+mon_return]
    mov dword [edi], dpmi_raw_real
    mov eax, [ebp+mon_real_base]
    shr eax, 4
    mov [edi+4], eax
    mov eax, [esp+48]
    and eax, 0cd7h
    or eax, 23002h
    cmp byte [ebp+dpmi_vif], 1
    jne .real_flags
    or eax, 200h
.real_flags:
    mov [edi+8], eax
    movzx eax, word [esp+24]
    mov [edi+12], eax
    movzx eax, word [esp+28]
    mov [edi+16], eax
    movzx eax, word [esp+32]
    mov [edi+20], eax
    movzx eax, word [esp+36]
    mov [edi+24], eax
    mov dword [edi+28], 0
    mov dword [edi+32], 0
    jmp mon_leave
.bad_gate:
    sub dword [esp+40], 2
    pop es
    pop ds
    popad
    push dword 0
    push dword 13
    jmp mon_exception

dpmi_raw_pm:
    mov ax, 10h
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov ebp, edi
    mov esp, [ebp+mon_tss+4]
    mov eax, [ebp+dpmi_raw_switch]
    mov [ebp+mon_switch+16], eax
    lea edx, [ebp+mon_resume]
    cmp eax, edx
    jne .stack_ready
    ; The switch came from a host real-mode call. Keep the frame of the call.
    mov esp, [ebp+mon_resume_sp]
    mov [ebp+mon_tss+4], esp
.stack_ready:
    cmp byte [ebp+dpmi_client16], 0
    je .offsets_ready
    movzx eax, word [ebp+dpmi_raw_regs]
    mov [ebp+dpmi_raw_regs], eax
    movzx eax, word [ebp+dpmi_raw_regs+16]
    mov [ebp+dpmi_raw_regs+16], eax
.offsets_ready:
    cmp byte [ebp+dpmi_active], 1
    jne dpmi_locked_abort
    mov ax, [ebp+dpmi_raw_regs+4]
    mov edx, [ebp+dpmi_raw_regs]
    call dpmi_code_target
    jc dpmi_locked_abort
    mov ax, [ebp+dpmi_raw_regs+20]
    mov edx, [ebp+dpmi_raw_regs+16]
    call dpmi_stack_target
    jc dpmi_locked_abort
    mov ax, [ebp+dpmi_raw_regs+24]
    call dpmi_raw_data
    jc dpmi_locked_abort
    mov ax, [ebp+dpmi_raw_regs+28]
    call dpmi_raw_data
    jc dpmi_locked_abort
    lea esi, [ebp+dpmi_exit_frame]
    lea edi, [ebp+mon_return]
    mov ecx, 9
    cld
    rep movsd
    lea eax, [ebp+mon_resume]
    cmp [ebp+mon_switch+16], eax
    je .caller_stack
    cmp dword [ebp+dpmi_bridge_depth], 0
    jne .caller_stack
    cmp byte [ebp+dpmi_callback_active], 0
    je .return_ready
.caller_stack:
    ; The host stack can be in use. Host calls use the caller's stack.
    movzx eax, word [ebp+dpmi_raw_rm_stack]
    mov [ebp+mon_return+12], eax
    movzx eax, word [ebp+dpmi_raw_rm_stack+2]
    mov [ebp+mon_return+16], eax
.return_ready:
    movzx eax, word [ebp+dpmi_raw_regs+20]
    push eax
    push dword [ebp+dpmi_raw_regs+16]
    movzx eax, word [ebp+dpmi_raw_flags]
    mov word [ebp+dpmi_vif], 1
    call dpmi_tf_disarm
    test eax, 200h
    jnz .flags_ready
    call dpmi_clear_vif
.flags_ready:
    and eax, 0cd7h
    or eax, 202h
    push eax
    movzx eax, word [ebp+dpmi_raw_regs+4]
    push eax
    push dword [ebp+dpmi_raw_regs]
    ; Some extenders keep FS and GS across a raw switch. Restore them.
    push ecx
    mov ecx, [ebp+dpmi_raw_segs]
    call dpmi_load_fs_gs
    pop ecx
    mov es, [ebp+dpmi_raw_regs+24]
    mov ax, [ebp+dpmi_raw_regs+28]
    mov ebp, [ebp+dpmi_raw_regs+8]
    mov ds, ax
    MON_IRETD

dpmi_raw_data:
    pushad
    mov dx, ax
    and dx, 0fffch
    jz .ok
    mov dx, ax
    and dx, 3
    cmp dx, 3
    jne .bad
    call dpmi_descriptor
    jc .bad
    mov al, [esi+5]
    and al, 0f0h
    cmp al, 0f0h
    jne .bad
    test byte [esi+5], 8
    jz .ok
    test byte [esi+5], 2
    jz .bad
.ok:
    popad
    clc
    ret
.bad:
    popad
    stc
    ret

HOST_REAL
dpmi_state_real:
    retf
dpmi_raw_real:
    mov ebp, [cs:dpmi_raw_bp]
    jmp far [cs:dpmi_raw_target]
dpmi_raw_enter:
    pushf
    cmp byte [cs:dpmi_active], 1
    jne .inactive
    pop word [cs:dpmi_raw_flags]
    cli
    mov [cs:dpmi_raw_rm_stack], sp
    mov [cs:dpmi_raw_rm_stack+2], ss
    mov [cs:dpmi_raw_regs], edi
    mov [cs:dpmi_raw_regs+4], esi
    mov [cs:dpmi_raw_regs+8], ebp
    mov [cs:dpmi_raw_regs+16], ebx
    mov [cs:dpmi_raw_regs+20], edx
    mov [cs:dpmi_raw_regs+24], ecx
    mov [cs:dpmi_raw_regs+28], eax
    push cs
    pop ds
    mov ax, cs
    mov ss, ax
    mov sp, dpmi_raw_stack_top
    and byte [mon_gdt+24+5], 0fdh
    mov edi, [mon_base]
    mov eax, [mon_switch+16]
    mov [dpmi_raw_switch], eax
    lea eax, [edi+dpmi_raw_pm]
    mov [mon_switch+16], eax
    mov esi, [mon_real_base]
    add esi, mon_switch
    mov ax, 0de0ch
    int 67h
    ud2
.inactive:
    popf
    mov ax, 4c01h
    int 21h
    ud2

dpmi_raw_regs times 32 db 0
dpmi_raw_flags dw 0
dpmi_raw_bp dd 0
dpmi_raw_target dd 0
dpmi_raw_switch dd 0
dpmi_raw_rm_stack dd 0
    times 32 db 0
dpmi_raw_stack_top:
dpmi_exit_frame times 36 db 0
HOST_PROTECTED
