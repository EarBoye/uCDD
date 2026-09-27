; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

HOST_PROTECTED
dpmi_debug_reset:
    pushad
    lea edi, [ebp+dpmi_debug_regs]
    xor eax, eax
    mov ecx, 8
    rep stosd
    mov dword [ebp+dpmi_debug_regs+24], 0ffff0ff0h
    mov dword [ebp+dpmi_debug_regs+28], 400h
    popad
    ret

dpmi_debug_host_save:
    push eax
    mov eax, dr7
    mov [ebp+dpmi_debug_host+20], eax
    mov eax, 400h
    mov dr7, eax
    mov eax, dr0
    mov [ebp+dpmi_debug_host], eax
    mov eax, dr1
    mov [ebp+dpmi_debug_host+4], eax
    mov eax, dr2
    mov [ebp+dpmi_debug_host+8], eax
    mov eax, dr3
    mov [ebp+dpmi_debug_host+12], eax
    mov eax, dr6
    mov [ebp+dpmi_debug_host+16], eax
    pop eax
    ret

dpmi_debug_host_restore:
    push eax
    mov eax, 400h
    mov dr7, eax
    mov eax, [ebp+dpmi_debug_host]
    mov dr0, eax
    mov eax, [ebp+dpmi_debug_host+4]
    mov dr1, eax
    mov eax, [ebp+dpmi_debug_host+8]
    mov dr2, eax
    mov eax, [ebp+dpmi_debug_host+12]
    mov dr3, eax
    mov eax, [ebp+dpmi_debug_host+16]
    mov dr6, eax
    mov eax, [ebp+dpmi_debug_host+20]
    mov dr7, eax
    pop eax
    ret

; AX is the return CS. Arm only for a client return.
dpmi_debug_arm:
    test al, 3
    jz .done
    mov eax, 0ffff0ff0h
    mov dr6, eax
    test byte [ebp+dpmi_debug_regs+28], 0ffh
    jz .done
    mov eax, [ebp+dpmi_debug_regs]
    mov dr0, eax
    mov eax, [ebp+dpmi_debug_regs+4]
    mov dr1, eax
    mov eax, [ebp+dpmi_debug_regs+8]
    mov dr2, eax
    mov eax, [ebp+dpmi_debug_regs+12]
    mov dr3, eax
    mov eax, [ebp+dpmi_debug_regs+28]
    and eax, ~2000h
    mov dr7, eax
.done:
    ret

; CF identifies an enabled client breakpoint, independently of host TF.
dpmi_debug_breakpoint:
    pushad
    mov eax, dr6
    mov edx, [ebp+dpmi_debug_regs+28]
    mov ecx, 4
.slot:
    test al, 1
    jz .next
    test dl, 3
    jnz .matched
.next:
    shr eax, 1
    shr edx, 2
    loop .slot
    popad
    clc
    ret
.matched:
    mov eax, dr6
    and eax, 0fh
    or [ebp+dpmi_debug_regs+24], eax
    popad
    stc
    ret

; EBX is an exception frame; EDI points after 0F. CF means unsupported.
dpmi_debug_move:
    pushad
    mov byte [ebp+dpmi_debug_pending], 0
    call mon_gp_fetch
    jc .bad
    cmp al, 21h
    je .opcode
    cmp al, 23h
    jne .bad
.opcode:
    mov edx, eax
    inc edi
    call mon_gp_fetch
    jc .bad
    cmp al, 0c0h
    jb .bad
    inc edi
    mov ecx, eax
    and eax, 7
    movzx esi, byte [ebp+dpmi_full_registers+eax]
    add esi, ebx
    shr ecx, 3
    and ecx, 7
    cmp ecx, 4
    jb .register
    or ecx, 2
.register:
    test dword [ebp+dpmi_debug_regs+28], 2000h
    jnz .detect
    cmp dl, 21h
    jne .write
    mov eax, [ebp+dpmi_debug_regs+ecx*4]
    mov [esi], eax
    jmp .done
.write:
    mov eax, [esi]
    cmp ecx, 6
    je .status
    cmp ecx, 7
    je .control
    cmp eax, 0e0000000h
    jb .store
    mov edx, 3
    push ecx
    shl ecx, 1
    shl edx, cl
    pop ecx
    test [ebp+dpmi_debug_regs+28], edx
    jnz .bad
    jmp .store
.status:
    and eax, 0e00fh
    or eax, 0ffff0ff0h
    jmp .store
.control:
    and eax, 0ffff23ffh
    or eax, 400h
    mov edx, eax
    mov esi, eax
    shr esi, 16
    push edi
    xor edi, edi
.validate:
    test dl, 3
    jz .next_slot
    cmp dword [ebp+dpmi_debug_regs+edi*4], 0e0000000h
    jae .bad_control
    mov ebx, esi
    and ebx, 3
    cmp ebx, 2
    je .bad_control
    test ebx, ebx
    jnz .length
    test esi, 0ch
    jnz .bad_control
.length:
    mov ebx, esi
    and ebx, 0ch
    cmp ebx, 8
    je .bad_control
.next_slot:
    shr edx, 2
    shr esi, 4
    inc edi
    cmp edi, 4
    jb .validate
    pop edi
    jmp .store
.bad_control:
    pop edi
    jmp .bad
.store:
    mov [ebp+dpmi_debug_regs+ecx*4], eax
.done:
    mov [esp], edi
    popad
    clc
    ret
.detect:
    and dword [ebp+dpmi_debug_regs+28], ~2000h
    or dword [ebp+dpmi_debug_regs+24], 2000h
    mov byte [ebp+dpmi_debug_pending], 1
    popad
    clc
    ret
.bad:
    popad
    stc
    ret

dpmi_debug_regs times 8 dd 0
dpmi_debug_host times 6 dd 0
dpmi_debug_pending db 0
