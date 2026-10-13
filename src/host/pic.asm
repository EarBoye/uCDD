; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

HOST_PROTECTED
dpmi_pic_reset:
    mov word [ebp+dpmi_pic_service], 0
    mov word [ebp+dpmi_pic_read_mode], 0a0ah
    in al, 21h
    mov [ebp+dpmi_pic_mask], al
    in al, 0a1h
    mov [ebp+dpmi_pic_mask+1], al
    ret
; EBX=physical IRQ. Keep the physical controller available to the mixer.
dpmi_pic_queue:
    push eax
    push edx
    bts [ebp+dpmi_pending_irqs], ebx
    mov eax, ebx
    mov dx, 20h
    cmp al, 8
    jb .master
    and al, 7
    or al, 60h
    out 0a0h, al
    mov al, 2
.master:
    or al, 60h
    out dx, al
    pop edx
    pop eax
    ret

; EAX=next IRQ, carry set if no eligible request. Other registers stay intact.
dpmi_pic_next:
    ; Nothing pending is the common case. Leave before the controller reads.
    cmp word [ebp+dpmi_pending_irqs], 0
    je .idle
    pushad
    call dpmi_hardware_room
    jc .none
    mov dx, 20h
    call dpmi_pic_read_isr
    movzx ebx, al
    or bl, [ebp+dpmi_pic_service]
    movzx ecx, word [ebp+dpmi_pic_mask]
    not ecx
    and ecx, [ebp+dpmi_pending_irqs]
    and ecx, 0fffbh
    mov esi, ecx
    shr esi, 8
    jz .master
    test byte [ebp+dpmi_pic_mask], 4
    jnz .master
    mov dx, 0a0h
    call dpmi_pic_read_isr
    or al, [ebp+dpmi_pic_service+1]
    movzx eax, al
    bsf edi, esi
    bsf eax, eax
    jz .slave
    cmp edi, eax
    jae .master
.slave:
    or cl, 4
.master:
    movzx eax, cl
    bsf eax, eax
    jz .none
    bsf edx, ebx
    jz .selected
    cmp eax, edx
    jae .none
.selected:
    bts [ebp+dpmi_pic_service], eax
    cmp eax, 2
    jne .request
    lea eax, [edi+8]
    bts [ebp+dpmi_pic_service], eax
.request:
    btr [ebp+dpmi_pending_irqs], eax
    mov [esp+28], eax
    popad
    clc
    ret
.none:
    popad
.idle:
    stc
    ret

; The real-mode handler will own its EOI after a default-vector chain.
dpmi_pic_reflect:
    pushad
    movzx eax, byte [ebp+dpmi_reflect_vector]
    sub al, [ebp+mon_master]
    cmp al, 8
    jb .clear
    mov al, [ebp+dpmi_reflect_vector]
    sub al, [ebp+mon_slave]
    cmp al, 8
    jae .done
    add eax, 8
    and byte [ebp+dpmi_pic_service], 0fbh
.clear:
    btr [ebp+dpmi_pic_service], eax
.done:
    popad
    ret

; EAX=real interrupt number of a 0300h call. A hardware vector whose IRQ the
; host holds in service: end the host's service and mark the handler's EOI
; stray, as the chain from a protected-mode handler does (dpmi_pic_reflect).
dpmi_pic_real_int:
    pushad
    mov edx, eax
    sub al, [ebp+mon_master]
    cmp al, 8
    jb .irq
    mov eax, edx
    sub al, [ebp+mon_slave]
    cmp al, 8
    jae .done
    add eax, 8
.irq:
    movzx eax, al
    btr [ebp+dpmi_pic_service], eax
    jnc .done
    cmp eax, 8
    jb .mark
    and byte [ebp+dpmi_pic_service], 0fbh
.mark:
    mov al, 1
    call resident_stray_eoi_mark
.done:
    popad
    ret

; An IRET call to a real IRQ vector transfers ownership of its EOI.
dpmi_pic_real_chain:
    cmp al, 2
    jne .done
    pushad
    mov ecx, [edi+42]
    xor ebx, ebx
.irq:
    bt [ebp+dpmi_pic_service], ebx
    jnc .next
    call dpmi_bridge_vector
    mov al, dl
    call dpmi_bridge_real_vector
    cmp [esi], ecx
    je .chain
    cmp [ebp+dpmi_bridge_vectors+ebx*4], ecx
    jne .next
.chain:
    btr [ebp+dpmi_pic_service], ebx
    ; The host sent the EOI when it queued the IRQ. The handler's is stray.
    mov al, 1
    call resident_stray_eoi_mark
    cmp ebx, 8
    jb .restored
    and byte [ebp+dpmi_pic_service], 0fbh
    jmp .restored
.next:
    inc ebx
    cmp ebx, 16
    jb .irq
.restored:
    popad
.done:
    ret

dpmi_pic_audio_allowed:
    push ecx
    mov cl, [ebp+dpmi_guest_irq]
    mov ch, 1
    shl ch, cl
    mov cl, ch
    dec ch
    or cl, ch
    test [ebp+dpmi_pic_service], cl
    jnz .blocked
    push eax
    movzx eax, word [ebp+dpmi_pic_mask]
    not eax
    and eax, [ebp+dpmi_pending_irqs]
    test byte [ebp+dpmi_pic_mask], 4
    jz .cascade
    and eax, 0ffh
.cascade:
    test eax, 0ff00h
    jnz .pending
    test al, ch
.pending:
    pop eax
    jnz .blocked
    pop ecx
    clc
    ret
.blocked:
    pop ecx
    stc
    ret

; Same byte-I/O ABI as mon_callback. Non-PIC ports use that callback.
dpmi_pic_io:
    cmp dx, 20h
    je .pic
    cmp dx, 21h
    je .pic
    cmp dx, 0a0h
    je .pic
    cmp dx, 0a1h
    jne .other
.pic:
    cmp cl, 1
    jne .bad
    pushad
    xor ebx, ebx
    test dl, 80h
    jz .index
    inc ebx
.index:
    test ch, ch
    jz .read
    test dl, 1
    jnz .mask
    ; ICW1 starts an initialisation, which the host does not emulate.
    test al, 10h
    jnz .failure
    cmp al, 0ch
    jne .command
    ; Poll: the next read answers like the request register.
    mov al, 0ah
.command:
    cmp al, 0ah
    je .mode
    cmp al, 0bh
    je .mode
    mov ah, al
    and ah, 0f8h
    ; Set priority, and special mask mode: the host keeps its own priorities,
    ; and the physical controller serves the mixer as well.
    cmp ah, 0c0h
    je .success
    cmp al, 40h
    je .success
    cmp al, 48h
    je .success
    cmp al, 68h
    je .success
    ; The rotate forms end the service like their plain forms, and the
    ; controller gets the plain form.
    and ah, 7fh
    and al, 7fh
    mov [esp+28], al
    cmp ah, 60h
    je .specific
    cmp al, 20h
    jne .failure
    call dpmi_pic_read_isr
    or al, [ebp+dpmi_pic_service+ebx]
    movzx eax, al
    bsf eax, eax
    jz .plain_forward
    jmp .eoi
.specific:
    and eax, 7
.eoi:
    lea ecx, [ebx*8]
    add ecx, eax
    bt [ebp+dpmi_pic_service], ecx
    jnc .plain_forward
    btr [ebp+dpmi_pic_service], ecx
    jmp .success
; Joined from the non-specific EOI when the host has nothing in service on the
; controller (BSF found no bit) and from .eoi when the bit named is not the
; host's. EBX=0 for the master, 1 for the slave; [ESP+28] holds the command
; byte, with the rotate bit taken off, for the forward.
.plain_forward:
%ifdef RESIDENT_HOST
    ; A non-specific EOI on the master that is not the host's goes to the
    ; driver's virtual PIC, through a real-mode call. The cases that end
    ; there without a virtual interrupt to end are decided here instead: the
    ; stray EOI of a handler whose IRQ the host ended at the queue, and an
    ; EOI with no virtual interrupt in service or none delivered yet, which
    ; is the controller's (virtual_pic_write).
    test ebx, ebx
    jnz .forward
    cmp byte [esp+28], 20h
    jne .forward
    mov esi, [ebp+resident_audio_request]
    test esi, esi
    jz .forward
    mov ecx, [ebp+resident_stray_eoi]
    jecxz .delivered_check
    cmp byte [ecx], 0
    je .delivered_check
    mov byte [ecx], 0
    jmp .success
.delivered_check:
    cmp byte [esi+1], 0
    je .controller
    mov ecx, [ebp+resident_delivered]
    jecxz .forward
    cmp byte [ecx], 0
    jne .forward
.controller:
    mov al, 20h
    out dx, al
    jmp .success
%endif
.mode:
    mov [ebp+dpmi_pic_read_mode+ebx], al
    mov [esp+28], al
    jmp .forward
.mask:
    mov [ebp+dpmi_pic_mask+ebx], al
.forward:
    popad
    jmp dpmi_pic_backend
.read:
    call dpmi_pic_backend
    jc .failure
    test dl, 1
    jnz .value
    cmp byte [ebp+dpmi_pic_read_mode+ebx], 0bh
    je .service
    mov ecx, [ebp+dpmi_pending_irqs]
    cmp ebx, 0
    jne .slave_request
    test ecx, 0ff00h
    jz .request
    or cl, 4
    jmp .request
.slave_request:
    shr ecx, 8
.request:
    or al, cl
    jmp .value
.service:
    or al, [ebp+dpmi_pic_service+ebx]
.value:
    mov [esp+28], eax
.success:
    popad
    clc
    ret
.failure:
    popad
.bad:
    stc
    ret
.other:
    jmp [ebp+mon_callback]

; DX=command port, AL=backend ISR. Preserve controller read selection.
dpmi_pic_read_isr:
    pushad
    mov al, 0bh
    mov ecx, 0101h
    call dpmi_pic_backend
    mov ecx, 1
    call dpmi_pic_backend
    mov [esp+28], al
    mov al, [ebp+dpmi_pic_read_mode]
    cmp dx, 20h
    je .restore
    mov al, [ebp+dpmi_pic_read_mode+1]
.restore:
    mov ecx, 0101h
    call dpmi_pic_backend
    popad
    ret

dpmi_pic_backend:
%ifdef RESIDENT_HOST
    cmp dx, 20h
    jne .resident_regular
    mov esi, [ebp+resident_audio_request]
    test esi, esi
    jz .resident_regular
    test ch, ch
    jnz .resident_select
    mov al, [esi+9]
    out dx, al
    in al, dx
    and al, [esi+8]
    cmp byte [esi+9], 0bh
    je .resident_service
    or al, [esi]
    clc
    ret
.resident_service:
    or al, [esi+1]
    clc
    ret
.resident_select:
    cmp al, 0ah
    je .resident_mode
    cmp al, 0bh
    jne .resident_regular
.resident_mode:
    mov [esi+9], al
    out dx, al
    clc
    ret
.resident_regular:
%endif
    cmp dx, 0a0h
    jae .physical
    cmp [ebp+mon_callback], ebp
    jne .callback
.physical:
    test ch, ch
    jnz .out
    in al, dx
    clc
    ret
.out:
    out dx, al
    clc
    ret
.callback:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    call [ebp+mon_callback]
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

dpmi_pic_service dd 0
dpmi_pic_mask dw 0ffffh
HOST_REAL
; The real-mode IRQ stubs put the selected register back after a read.
dpmi_pic_read_mode dw 0a0ah
HOST_PROTECTED
