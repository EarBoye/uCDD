; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%define NEST_BASE 10000000h
%define NEST_STRIDE 40000h
%define NEST_LEVELS 8
%define NEST_TABLE 0ffc40000h
NEST_GATE_BYTES equ host_gateway_end-mon_base
NEST_PM_BYTES equ host_ldt_end-mon_vectors
NEST_BYTES equ 4480+NEST_GATE_BYTES+NEST_PM_BYTES
NEST_PAGES equ (NEST_BYTES+4095)/4096

HOST_REAL
dpmi_nested_save:
    push ax
    push bx
    mov ah, 51h
    int 21h
    cmp bx, [cs:dpmi_psp]
    pop bx
    pop ax
    je .bad
    mov byte [cs:dpmi_nested_action], 0
    jmp dpmi_nested_switch
.bad:
    stc
    ret
dpmi_nested_restore:
    mov byte [cs:dpmi_nested_action], 1
dpmi_nested_switch:
    pushf
    cli
    pushad
    push ds
    push es
    push fs
    push gs
    mov ax, cs
    mov ds, ax
    mov [dpmi_nested_return_frame+12], sp
    mov [dpmi_nested_return_frame+16], ss
    mov [dpmi_nested_return_frame+4], ax
    mov [dpmi_nested_return_frame+20], ax
    mov [dpmi_nested_return_frame+24], ax
    mov [dpmi_nested_return_frame+28], ax
    mov [dpmi_nested_return_frame+32], ax
    mov eax, [mon_switch+16]
    mov [dpmi_nested_switch_ip], eax
    mov edi, [mon_base]
    lea eax, [edi+dpmi_nested_pm]
    mov [mon_switch+16], eax
    and byte [mon_gdt+24+5], 0fdh
    mov esi, [mon_real_base]
    add esi, mon_switch
    mov ax, 0de0ch
    int 67h
dpmi_nested_return:
    pop gs
    pop fs
    pop es
    pop ds
    popad
    popf
    cmp byte [cs:dpmi_nested_error], 0
    jne .bad
    clc
    ret
.bad:
    stc
    ret

dpmi_nested_depth db 0
dpmi_nested_action db 0
dpmi_nested_error db 0
dpmi_nested_switch_ip dd 0
    times 32 db 0
dpmi_nested_return_frame dd dpmi_nested_return,0,23002h,0,0,0,0,0,0
    times 512 db 0
dpmi_nested_real_top:

HOST_PROTECTED
    times 512 db 0
dpmi_nested_pm_top:
dpmi_nested_pm:
    mov ax, 10h
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov ebp, edi
    lea esp, [ebp+dpmi_nested_pm_top]
    cld
    mov eax, [ebp+dpmi_nested_switch_ip]
    mov [ebp+mon_switch+16], eax
    mov byte [ebp+dpmi_nested_error], 0
    cmp byte [ebp+dpmi_nested_action], 0
    jne .restore
    cmp byte [ebp+dpmi_nested_depth], NEST_LEVELS
    jae .bad
    cmp byte [ebp+dpmi_nested_depth], 0
    jne .table_ready
    cmp dword [0fffff100h], 0
    jne .bad
    call dpmi_page_allocate
    jc .bad
    or edx, 3
    mov [0fffff100h], edx
    call dpmi_flush
    mov edi, NEST_TABLE
    xor eax, eax
    mov ecx, 1024
    rep stosd
.table_ready:
    movzx ebx, byte [ebp+dpmi_nested_depth]
    shl ebx, 8
    add ebx, NEST_TABLE
    xor esi, esi
.allocate:
%ifdef NEST_FAIL_PAGE
    cmp esi, NEST_FAIL_PAGE
    je .allocation_failed
%endif
    call dpmi_page_allocate
    jc .allocation_failed
    or edx, 3
    mov [ebx+esi*4], edx
    inc esi
    cmp esi, NEST_PAGES
    jb .allocate
    call dpmi_flush
    movzx edx, byte [ebp+dpmi_nested_depth]
    shl edx, 18
    add edx, NEST_BASE
    mov edi, edx
    mov esi, 0ffc00000h
    mov ecx, 1024
    rep movsd
    mov esi, 0fffff004h
    mov ecx, 63
    rep movsd
    add edi, 4
    mov byte [edi], 0
    test byte [410h], 2
    jz .no_fpu_save
    clts
    fnsave [edi+4]
    mov byte [edi], 1
.no_fpu_save:
    add edi, 128
    ; The mixer is outside these ranges. Keep the suspended kernel frames.
    lea esi, [ebp+mon_base]
    mov ecx, NEST_GATE_BYTES
    rep movsb
    lea esi, [ebp+mon_vectors]
    mov ecx, NEST_PM_BYTES
    rep movsb
    call dpmi_bridge_remove
    inc byte [ebp+dpmi_nested_depth]
    mov edi, 0fffff004h
    xor eax, eax
    mov ecx, 63
    rep stosd
    lea edi, [ebp+dpmi_locked_pages]
    mov ecx, DPMI_LOCK_PAGES
    rep stosd
    mov [ebp+dpmi_blocks_page], eax
    mov [ebp+dpmi_pool_head], eax
    mov [ebp+dpmi_pool_count], eax
    mov [ebp+dpmi_large_stack_segment], ax
    mov [ebp+dpmi_large_stack_busy], al
    mov [ebp+dpmi_bridge_real_segment], ax
    mov [ebp+mon_running], al
    mov [ebp+dpmi_active], al
    mov [ebp+dpmi_traps_suspended], al
    mov dword [ebp+mon_return], monitor_run.returned
    lea eax, [ebp+mon_enter]
    mov [ebp+mon_switch+16], eax
    call dpmi_flush
    jmp .leave
.allocation_failed:
    test esi, esi
    jz .free_table
    dec esi
    mov edx, [ebx+esi*4]
    and edx, 0fffff000h
    mov dword [ebx+esi*4], 0
    call dpmi_page_free
    jmp .allocation_failed
.free_table:
    call .release_table
.bad:
    mov byte [ebp+dpmi_nested_error], 1
    jmp .leave
.restore:
    dec byte [ebp+dpmi_nested_depth]
    movzx ebx, byte [ebp+dpmi_nested_depth]
    shl ebx, 18
    add ebx, NEST_BASE
    mov esi, ebx
    mov edi, 0ffc00000h
    mov ecx, 1024
    rep movsd
    mov edi, 0fffff004h
    mov ecx, 63
    rep movsd
    add esi, 4
    cmp byte [esi], 0
    je .no_fpu_restore
    clts
    frstor [esi+4]
.no_fpu_restore:
    add esi, 128
    lea edi, [ebp+mon_base]
    mov ecx, NEST_GATE_BYTES
    rep movsb
    lea edi, [ebp+mon_vectors]
    mov ecx, NEST_PM_BYTES
    rep movsb
    call dpmi_flush
    call dpmi_bridge_install_vectors
    movzx ebx, byte [ebp+dpmi_nested_depth]
    shl ebx, 8
    add ebx, NEST_TABLE
    mov esi, NEST_PAGES
.release:
    dec esi
    mov edx, [ebx+esi*4]
    and edx, 0fffff000h
    mov dword [ebx+esi*4], 0
    call dpmi_page_free
    test esi, esi
    jnz .release
    call .release_table
.leave:
    lea esp, [ebp+dpmi_nested_return_frame]
    cmp byte [ebp+mon_vcpi_flags_slot], 0
    je .return_ready
    mov word [esp-2], 0
    sub esp, 2
.return_ready:
    sub esp, ebp
    add esp, [ebp+mon_real_base]
    clts
    mov ax, 0de0ch
    call far [ebp+mon_server]
    ud2
.release_table:
    cmp byte [ebp+dpmi_nested_depth], 0
    jne .flush
    mov edx, [0fffff100h]
    and edx, 0fffff000h
    mov dword [0fffff100h], 0
    call dpmi_flush
    call dpmi_page_free
.flush:
    call dpmi_flush
    ret
