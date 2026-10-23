; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

HOST_PROTECTED
dpmi_vendor_query:
    mov ax, [ebx+4]
    mov edx, [ebx+12]
    cmp byte [ebp+dpmi_client16], 0
    je .offset
    movzx edx, dx
.offset:
    mov ecx, 7
    xor edi, edi
    call dpmi_read_buffer
    jc .unknown
    cmp dword [eax], 'MS-D'
    jne .unknown
    cmp word [eax+4], 'OS'
    jne .unknown
    cmp byte [eax+6], 0
    jne .unknown
    call dpmi_stub_selector
    mov [ebx], ax
    mov dword [ebx+8], dpmi_vendor_pm
    cmp byte [ebp+dpmi_client16], 0
    je .entry_ready
    mov dword [ebx+8], dpmi_vendor_pm16
.entry_ready:
    mov byte [ebx+36], 0
.unknown:
    jmp mon_dpmi.done

dpmi_vendor_pm:
    cmp ax, 0100h
    jne .bad
    mov ax, 0ff00h
    int 31h
.returned:
    retf
.bad:
    stc
    retf

bits 16
dpmi_vendor_pm16:
    cmp ax, 0100h
    jne .bad
    mov ax, 0ff00h
    int 31h
.returned:
    retf
.bad:
    stc
    retf
bits 32

dpmi_vendor_ldt:
    cmp word [ebx+44], 3bh
    jne .client16
    cmp dword [ebx+40], dpmi_vendor_pm.returned
    je .allocate
    jmp mon_dpmi.unsupported
.client16:
    cmp word [ebx+44], DPMI_STUB16
    jne mon_dpmi.unsupported
    cmp dword [ebx+40], dpmi_vendor_pm16.returned
    jne mon_dpmi.unsupported
.allocate:
    mov ecx, 1
    call dpmi_descriptor_allocate
    jc mon_dpmi.unsupported
    mov [ebx+36], ax
    lea eax, [ebp+dpmi_ldt]
    mov word [esi], DPMI_LDT_COUNT*8-1
    mov [esi+2], ax
    shr eax, 16
    mov [esi+4], al
    mov byte [esi+5], 0f0h
    mov byte [esi+6], 0
    mov [esi+7], ah
    jmp mon_dpmi.success

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

; The "MS-DOS" vendor entry point (RBIL table 02720), for 16-bit clients
; through DPMI_STUB16 (INT 2Fh AX=168Ah in dos.asm). It runs at ring 3 and
; uses DPMI calls only. AX=0100h returns in AX an alias of the LDT: a
; 16-bit data descriptor, DPL 3, over the whole table, allocated by 0000h,
; so the client owns it and may free it. Other functions return carry set.
    bits 16
dpmi_msdos_entry:
    cmp ax, 0100h
    jne .refuse
    push bx
    push cx
    push dx
    xor ax, ax
    mov cx, 1
    int 31h
    jc .done
    mov bx, ax
    mov dx, [cs:mon_base]
    mov cx, [cs:mon_base+2]
    add dx, dpmi_ldt
    adc cx, 0
    mov ax, 0007h
    int 31h
    jc .free
    xor cx, cx
    mov dx, DPMI_LDT_COUNT*8-1
    mov ax, 0008h
    int 31h
    jc .free
    mov ax, bx
.done:
    pop dx
    pop cx
    pop bx
    retf
.free:
    push ax
    mov ax, 0001h
    int 31h
    pop ax
    stc
    jmp .done
.refuse:
    stc
    retf
    bits 32

; EBX=client frame whose DS:(E)SI names a vendor (INT 2Fh AX=168Ah and
; INT 31h AX=0A00h, the same lookup in DPMI 1.0). The one extension this
; host has is "MS-DOS" for a 16-bit client (the note at dos.asm .vendor):
; then CF clear and ES:DI = dpmi_msdos_entry. CF set for any other name.
dpmi_vendor_entry:
    cmp byte [ebp+dpmi_client16], 0
    je .none
    mov ax, [ebx+4]
    movzx edx, word [ebx+12]
    mov ecx, 7
    xor edi, edi
    call dpmi_buffer
    jc .none
    cmp dword [eax], 'MS-D'
    jne .none
    cmp dword [eax+3], 'DOS'
    jne .none
    mov word [ebx], DPMI_STUB16
    mov word [ebx+8], dpmi_msdos_entry
    clc
    ret
.none:
    stc
    ret

; INT 31h AX=0A00h (DPMI 0.9 and 1.0): 8001h when the name is not known.
dpmi_vendor_api:
    call dpmi_vendor_entry
    jc mon_dpmi.unsupported
    jmp mon_dpmi.success
dpmi_raw_exit:
    int 0f0h
    ud2
dpmi_raw:
    DPMI_DEBUG_STOP
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
    call dpmi_quiet_entry
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
%ifdef RESIDENT_HOST
    shr byte [ebp+dpmi_raw_flip], 1
    jnc .size_ready
    call dpmi_nested_toggle
.size_ready:
%endif
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
    ; Save after the stack is final: a call at the TSS stack top overwrites the frame.
    call dpmi_debug_host_save
%ifdef RESIDENT_HOST
    ; The parent's real-mode code can switch to its own code while its child
    ; is current (DOS/4GW INT 2Ah hook).
    mov ax, [ebp+dpmi_raw_regs+4]
    call dpmi_nested_enter
    setc [ebp+dpmi_raw_flip]
%endif
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
