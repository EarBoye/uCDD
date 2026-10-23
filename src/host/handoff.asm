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

; Far call, AL=physical master ISR. Return AX=accepted IRQs without a
; protected-mode handler. The caller gives them to the real chain.
dpmi_real_pending:
    pushf
    cli
    push bx
    push cx
    mov bl, al
    xor ax, ax
    cmp byte [cs:dpmi_active], 1
    jne .done
    cmp byte [cs:resident_refill_busy], 0
    jne .done
    mov ax, [cs:dpmi_bridge_mask]
    not ax
    and ax, [cs:dpmi_physical_pending]
    and ax, 0fffbh
    jz .done
    or bl, [cs:dpmi_real_eoi]
    xor bh, bh
    bsf cx, bx
    jz .take
    ; Only levels above the highest level in service.
    mov bx, 1
    shl bx, cl
    dec bx
    cmp cl, 2
    jbe .master
    mov bh, 0ffh
.master:
    and ax, bx
.take:
    mov bx, ax
    not bx
    and [cs:dpmi_physical_pending], bx
    and [cs:dpmi_pending_irqs], bx
.done:
    pop cx
    pop bx
    popf
    retf

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
