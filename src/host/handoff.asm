; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

HOST_REAL
; IF is clear. Complete accepted physical IRQs on the restored real chain.
dpmi_physical_handoff:
    pushfd
    pushad
    push ds
    push es
    push fs
    push gs
    cmp byte [cs:dpmi_nested_depth], 0
    jne .done
    mov byte [cs:dpmi_audio_pm_handler], 1
    mov byte [cs:dpmi_active], 2
    xor ax, ax
    mov es, ax
    mov bx, [cs:dpmi_physical_pending]
    mov word [cs:dpmi_physical_pending], 0
    mov ax, bx
    not ax
    and [cs:dpmi_pending_irqs], ax
.next:
    test bx, bx
    jz .done
    mov ax, bx
    and ax, 7
    jnz .master
    mov al, bh
    xor ah, ah
    test ax, ax
    jz .master_remaining
    bsf cx, ax
    add cx, 8
    mov si, cx
    add si, 70h-8
    jmp .take
.master_remaining:
    mov ax, bx
.master:
    bsf cx, ax
    mov si, cx
    add si, 8
.take:
    btr bx, cx
    shl si, 2
    push bx
    push es
    pushf
    call far [es:si]
    cli
    pop es
    pop bx
    jmp .next
.done:
    pop gs
    pop fs
    pop es
    pop ds
    popad
    popfd
    ret

; End the top-level phase at the DOS termination boundary.
dpmi_physical_complete:
    pushf
    cli
    cmp byte [cs:dpmi_active], 2
    jne .done
    mov byte [cs:dpmi_active], 0
    add sp, 2
    ret
.done:
    popf
    ret
