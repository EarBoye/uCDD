; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

HOST_REAL
dpmi_large_stack_segment dw 0
dpmi_large_stack_busy db 0
dpmi_large_stack_allocate:
    mov bx, 512
    call dpmi_real_allocate
    jc .done
    mov [dpmi_large_stack_segment], ax
.done:
    retf

HOST_PROTECTED
; Keep the normal resident stack small. Large parameter lists use a client block.
dpmi_large_stack_prepare:
    xor eax, eax
    cmp ecx, 30
    jbe .done
    cmp word [edi+48], 0
    jne .done
    cmp byte [ebp+dpmi_large_stack_busy], 0
    jne .unavailable
    cmp word [ebp+dpmi_large_stack_segment], 0
    jne .ready
    cmp dword [ebp+dpmi_bridge_depth], 0
    jne .unavailable
    cmp byte [ebp+dpmi_callback_active], 0
    jne .unavailable
    cmp byte [ebp+dpmi_exception_active], 0
    jne .unavailable
    cmp dword [ebp+dpmi_locked_depth], 0
    jne .unavailable
    pushad
    lea edi, [ebp+mon_rm_regs]
    push edi
    xor eax, eax
    mov ecx, 50
    rep stosb
    pop edi
    mov eax, [ebp+mon_real_base]
    shr eax, 4
    mov [edi+36], ax
    shl eax, 16
    mov ax, dpmi_large_stack_allocate
    mov [edi+42], eax
    mov word [edi+32], 202h
    mov al, 1
    call mon_real_far
    popad
    cmp word [ebp+dpmi_large_stack_segment], 0
    je .unavailable
.ready:
    mov ax, [ebp+dpmi_large_stack_segment]
    mov [edi+48], ax
    mov word [edi+46], 8192
    mov byte [ebp+dpmi_large_stack_busy], 1
    mov eax, 1
.done:
    clc
    ret
.unavailable:
    mov eax, 8012h
    stc
    ret

dpmi_large_stack_restore:
    cmp dword [esp+4], 0
    je .done
    mov edx, [esp+8]
    mov [edi+46], edx
    mov byte [ebp+dpmi_large_stack_busy], 0
.done:
    ret 8
