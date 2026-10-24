; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

HOST_PROTECTED
dpmi_pic_reset:
    mov byte [ebp+dpmi_pic_open], 0
    mov word [ebp+dpmi_pic_service], 0
    mov byte [ebp+dpmi_real_eoi], 0
    mov byte [ebp+dpmi_real_priority], 0ffh
    mov word [ebp+dpmi_pic_special], 0
    mov word [ebp+dpmi_pic_read_mode], 0a0ah
    mov word [ebp+dpmi_pic_highest], 0
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
%ifdef RESIDENT_HOST
    bts [ebp+dpmi_physical_pending], ebx
%endif
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
    pushad
    call dpmi_hardware_room
    jc .none
    cmp word [ebp+dpmi_pending_irqs], 0
    je .none
    mov dx, 20h
    call dpmi_pic_read_isr
    movzx ebx, al
    or bl, [ebp+dpmi_pic_service]
    or bl, [ebp+dpmi_real_eoi]
    and bl, [ebp+dpmi_real_priority]
    movzx ecx, word [ebp+dpmi_pic_mask]
    not ecx
%ifdef RESIDENT_HOST
    ; While an INT 13h call runs through the driver's hook (cd_bios_busy), the
    ; disk IRQs and the cascade pass the mask (Zyclunt masks them for its IRQ
    ; probe).
    call dpmi_pic_disk_busy
    jz .open
    or ecx, 0c044h
.open:
%endif
    mov edi, ecx
    and ecx, [ebp+dpmi_pending_irqs]
    and ecx, 0fffbh
    mov esi, ecx
    shr esi, 8
    jz .master
    test edi, 4
    jz .master
    mov dx, 0a0h
    call dpmi_pic_read_isr
    or al, [ebp+dpmi_pic_service+1]
    cmp byte [ebp+dpmi_pic_special+1], 0
    je .slave_priority
    mov ah, [ebp+dpmi_pic_mask+1]
    not ah
    and al, ah
.slave_priority:
    ; The highest priority follows the lowest level (C0h-C7h).
    push ecx
    movzx ecx, byte [ebp+dpmi_pic_highest+1]
    ror al, cl
    movzx eax, al
    mov edx, esi
    ror dl, cl
    movzx edx, dl
    bsf edi, edx
    bsf eax, eax
    jz .slave
    cmp edi, eax
    jae .slave_blocked
.slave:
    add edi, ecx
    and edi, 7
    pop ecx
    or cl, 4
    jmp .master
.slave_blocked:
    pop ecx
.master:
    mov edx, ecx
    mov cl, [ebp+dpmi_pic_highest]
    ror dl, cl
    ror bl, cl
    movzx eax, dl
    bsf eax, eax
    jz .none
    movzx edx, bl
    bsf edx, edx
    jz .rotated
    cmp eax, edx
    jae .none
.rotated:
    add al, cl
    and eax, 7
.selected:
    bts [ebp+dpmi_pic_service], eax
    cmp eax, 2
    jne .request
    lea eax, [edi+8]
    bts [ebp+dpmi_pic_service], eax
.request:
    btr [ebp+dpmi_pending_irqs], eax
%ifdef RESIDENT_HOST
    btr [ebp+dpmi_physical_pending], eax
%endif
    mov [esp+28], eax
    popad
    clc
    ret
.none:
    popad
    stc
    ret

; The real-mode handler will own its EOI after a default-vector chain.
dpmi_pic_reflect:
    push eax
    movzx eax, byte [ebp+dpmi_reflect_vector]
    call dpmi_pic_handoff
    pop eax
    ret

; EAX=vector simulated with 0300h. CF=1: the IRQ went to the real handler. Only the IRQs whose IVT stub always chains
; to the real handler (6, 8-11, 14, 15) hand over the EOI. The stub of the
; others can defer, and a deferred IRQ would never clear the real EOI.
dpmi_pic_simulated:
    pushad
    call dpmi_vector_irq
    jnc .skip
    cmp al, 6
    je .chain
    cmp al, 8
    jb .skip
    cmp al, 12
    je .skip
    cmp al, 13
    je .skip
.chain:
    popad
    jmp dpmi_pic_handoff
.skip:
    popad
    clc
    ret

; EAX=vector of an IRQ whose real-mode handler owns its EOI from here. CF=1.
dpmi_pic_handoff:
    pushad
    call dpmi_vector_irq
    jnc .done
    movzx eax, al
    bt [ebp+dpmi_pic_service], eax
    jnc .done
    btr [ebp+dpmi_pic_service], eax
    mov ecx, eax
    cmp eax, 8
    jb .owner
    and byte [ebp+dpmi_pic_service], 0fbh
    mov ecx, 2
.owner:
%ifdef RESIDENT_HOST
    mov al, 1
    shl al, cl
    or [ebp+dpmi_real_eoi], al
%endif
.done:
    popad
    stc
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
    mov ecx, ebx
    cmp ebx, 8
    jb .owner
    and byte [ebp+dpmi_pic_service], 0fbh
    mov ecx, 2
.owner:
%ifdef RESIDENT_HOST
    mov al, 1
    shl al, cl
    or [ebp+dpmi_real_eoi], al
%endif
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
    ; CL=the guest level and levels above it, CH=levels above it.
    push edx
    mov dl, [ebp+dpmi_pic_highest]
    mov cl, [ebp+dpmi_guest_irq]
    mov dh, 1
    shl dh, cl
    sub cl, dl
    and cl, 7
    mov ch, 2
    shl ch, cl
    dec ch
    mov cl, dl
    rol ch, cl
    mov cl, ch
    xor ch, dh
    pop edx
    push eax
    mov al, [ebp+dpmi_pic_service]
    or al, [ebp+dpmi_real_eoi]
    and al, [ebp+dpmi_real_priority]
    test al, cl
    pop eax
    jnz .in_service
    push eax
    movzx eax, word [ebp+dpmi_pic_mask]
    not eax
    and eax, [ebp+dpmi_pending_irqs]
    test byte [ebp+dpmi_pic_mask], 4
    jz .cascade
    and eax, 0ffh
.cascade:
    test eax, 0ff00h
    jz .master
    or al, 4
.master:
    test al, ch
    pop eax
    jnz .request
    pop ecx
    clc
    ret
.in_service:
    HOST_DIAG 22
    jmp .blocked
.request:
    HOST_DIAG 23
.blocked:
    pop ecx
    stc
    ret

%ifdef RESIDENT_HOST
; ZF=0 while an INT 13h call runs through the driver's hook.
dpmi_pic_disk_busy:
    push eax
    mov eax, [ebp+resident_bios_busy]
    test eax, eax
    jz .done
    cmp byte [eax], 0
.done:
    pop eax
    ret

; EBX=controller. AL=bits of the disk IRQs and the cascade to clear.
dpmi_pic_open_mask:
    mov al, 0bbh
    test ebx, ebx
    jz .done
    mov al, 3fh
.done:
    ret

; Called at every physical IRQ. Open the disk IRQs on the real controller for
; the length of an INT 13h call and restore the game's mask afterwards.
dpmi_pic_sync:
    pushad
    call dpmi_pic_disk_busy
    setnz cl
    cmp cl, [ebp+dpmi_pic_open]
    je .done
    mov [ebp+dpmi_pic_open], cl
    xor ebx, ebx
    mov edx, 21h
.port:
    in al, dx
    mov ah, al
    call dpmi_pic_open_mask
    mov ch, al
    and al, ah
    test cl, cl
    jnz .write
    ; Closing: only the disk bits go back to the game's mask.
    mov ah, [ebp+dpmi_pic_mask+ebx]
    not ch
    and ah, ch
    or al, ah
.write:
    out dx, al
    mov dl, 0a1h
    inc ebx
    cmp ebx, 2
    jb .port
.done:
    popad
    ret

%endif

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
    jne dpmi_pic_wide
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
    cmp al, 48h
    je .special_mode
    cmp al, 68h
    je .special_mode
    cmp al, 0ah
    je .mode
    cmp al, 0bh
    je .mode
    mov ah, al
    and ah, 0f8h
    cmp ah, 60h
    je .specific
    cmp ah, 0c0h
    je .rotate
    cmp al, 20h
    jne .failure
    call dpmi_pic_read_isr
    or al, [ebp+dpmi_pic_service+ebx]
    cmp byte [ebp+dpmi_pic_special+ebx], 0
    je .eoi_priority
    mov ah, [ebp+dpmi_pic_mask+ebx]
    not ah
    and al, ah
.eoi_priority:
    ; The highest priority follows the lowest level.
    movzx eax, al
    mov cl, [ebp+dpmi_pic_highest+ebx]
    ror al, cl
    bsf eax, eax
    jz .forward
    add al, cl
    and eax, 7
    jmp .eoi
.specific:
    and eax, 7
.eoi:
    lea ecx, [ebx*8]
    add ecx, eax
    bt [ebp+dpmi_pic_service], ecx
    jnc .forward
    btr [ebp+dpmi_pic_service], ecx
    jmp .success
.mode:
    mov [ebp+dpmi_pic_read_mode+ebx], al
    jmp .forward
.rotate:
    inc eax
    and al, 7
    mov [ebp+dpmi_pic_highest+ebx], al
    jmp .forward
.mask:
    mov [ebp+dpmi_pic_mask+ebx], al
    call dpmi_pic_priority
%ifdef RESIDENT_HOST
    ; The same IRQs stay open on the real controller.
    call dpmi_pic_disk_busy
    jz .forward
    call dpmi_pic_open_mask
    and [esp+28], al
%endif
    jmp .forward
.special_mode:
    mov ah, al
    and ah, 20h
    mov [ebp+dpmi_pic_special+ebx], ah
    call dpmi_pic_priority
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

dpmi_pic_wide:
    test ch, ch
    jz dpmi_pic_io.bad
    test dl, 1
    jnz dpmi_pic_io.bad
    cmp cl, 2
    je .start
    cmp cl, 4
    jne dpmi_pic_io.bad
.start:
    cmp al, 20h
    je .eoi
    push ax
    and al, 0f8h
    cmp al, 60h
    pop ax
    jne dpmi_pic_io.bad
.eoi:
    push ecx
    mov cl, 1
    call dpmi_pic_io
    pop ecx
    ret

dpmi_pic_priority:
    push eax
    mov al, 0ffh
    cmp byte [ebp+dpmi_pic_special], 0
    je .ready
    mov al, [ebp+dpmi_pic_mask]
    not al
.ready:
    mov [ebp+dpmi_real_priority], al
    pop eax
    ret

dpmi_pic_restore:
    pushad
    xor ebx, ebx
.controller:
    cmp byte [ebp+dpmi_pic_highest+ebx], 0
    je .special
    mov dx, 20h
    test ebx, ebx
    jz .default_priority
    mov dx, 0a0h
.default_priority:
    mov al, 0c7h
    mov ecx, 0101h
    call dpmi_pic_backend
    mov byte [ebp+dpmi_pic_highest+ebx], 0
.special:
    cmp byte [ebp+dpmi_pic_special+ebx], 0
    je .next
    mov dx, 20h
    test ebx, ebx
    jz .port_ready
    mov dx, 0a0h
.port_ready:
    mov al, 48h
    mov ecx, 0101h
    call dpmi_pic_backend
    mov byte [ebp+dpmi_pic_special+ebx], 0
.next:
    inc ebx
    cmp ebx, 2
    jb .controller
    call dpmi_pic_priority
    popad
    ret

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
    or al, [ebp+dpmi_real_eoi]
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

dpmi_pic_mask dw 0ffffh
dpmi_pic_open db 0
dpmi_pic_read_mode dw 0a0ah
dpmi_pic_special dw 0
; Level with the highest priority: one above the lowest (C0h-C7h).
dpmi_pic_highest dw 0
