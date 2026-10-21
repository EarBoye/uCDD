; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

HOST_PROTECTED
dpmi_dos_frame:
    cld
    lea edi, [ebp+dpmi_dos_regs]
    push edi
    xor eax, eax
    mov ecx, 50
    rep stosb
    pop edi
    ret
dpmi_dos_call:
    mov ax, 21h
    call mon_real_int
    test byte [edi+32], 1
    ret
dpmi_dos_allocate:
    call dpmi_dos_begin
    cmp word [ebx+24], 0
    je dpmi_dos_bad_value
    call dpmi_dos_frame
    mov ax, [ebx+24]
    mov [edi+16], ax
    mov word [edi+28], 4800h
    call dpmi_dos_call
    jnz dpmi_dos_error
    mov ax, [edi+28]
    mov [ebx+36], ax
    push edi
    movzx ecx, word [ebx+24]
    call dpmi_dos_tile_count
    call dpmi_descriptor_allocate
    pop edi
    jc .full
    mov edx, eax
    shr edx, 3
    mov byte [ebp+dpmi_used+edx], 3
    mov [ebx+28], ax
    test dword [ebx+20], 10000h
    je .result
    mov [ebx+36], ax
.result:
    movzx eax, word [edi+28]
    movzx ecx, word [ebx+24]
    call dpmi_dos_tiles
    jmp dpmi_dos_success
.full:
    mov ax, [edi+28]
    mov [edi+34], ax
    mov word [edi+28], 4900h
    call dpmi_dos_call
    mov ax, 8011h
    jmp dpmi_dos_finish_error
dpmi_dos_free:
    call dpmi_dos_begin
    mov ax, [ebx+28]
    call dpmi_dos_descriptor
    jc dpmi_dos_bad_selector
    call dpmi_descriptor_base
    shr eax, 4
    push eax
    call dpmi_dos_frame
    pop eax
    mov [edi+34], ax
    mov word [edi+28], 4900h
    call dpmi_dos_call
    jnz dpmi_dos_error
    mov ecx, 1
    call dpmi_dos_untile
    movzx eax, word [ebx+28]
    call dpmi_clear_selector
    shr eax, 3
    mov byte [ebp+dpmi_used+eax], 0
    mov dword [esi], 0
    mov dword [esi+4], 0
    jmp dpmi_dos_success
dpmi_dos_resize:
    call dpmi_dos_begin
    cmp word [ebx+24], 0
    je dpmi_dos_bad_value
    mov ax, [ebx+28]
    call dpmi_dos_descriptor
    jc dpmi_dos_bad_selector
    call dpmi_dos_tile_room
    jc dpmi_dos_full
    call dpmi_descriptor_base
    shr eax, 4
    push eax
    call dpmi_dos_frame
    pop eax
    mov [edi+34], ax
    mov ax, [ebx+24]
    mov [edi+16], ax
    mov word [edi+28], 4a00h
    call dpmi_dos_call
    jnz dpmi_dos_error
    movzx ecx, word [ebx+24]
    call dpmi_dos_tile_count
    call dpmi_dos_untile
    call dpmi_descriptor_base
    shr eax, 4
    movzx ecx, word [ebx+24]
    call dpmi_dos_tiles
    jmp dpmi_dos_success
dpmi_dos_error:
    mov ax, [edi+16]
    mov [ebx+24], ax
    mov ax, [edi+28]
    jmp dpmi_dos_finish_error

dpmi_dos_begin:
    cmp byte [ebp+dpmi_dos_via21], 0
    jne .direct
    mov dword [ebx+20], 0
.direct:
    mov byte [ebp+dpmi_dos_via21], 0
    ret
dpmi_dos_restore_dx:
    test dword [ebx+20], 10000h
    jz .done
    push eax
    mov ax, [ebx+20]
    mov [ebx+28], ax
    pop eax
.done:
    ret
dpmi_dos_success:
    call dpmi_dos_restore_dx
    jmp mon_dpmi.success
dpmi_dos_bad_value:
    mov ax, 8021h
    jmp dpmi_dos_finish_error
dpmi_dos_full:
    mov ax, 8011h
    jmp dpmi_dos_finish_error
dpmi_dos_bad_selector:
    mov ax, 8022h
dpmi_dos_finish_error:
    call dpmi_dos_restore_dx
    jmp dpmi_error

dpmi_dos_regs times 50 db 0
dpmi_dos_via21 db 0

dpmi_dos_descriptor:
    movzx eax, ax
    mov edx, eax
    and edx, 7
    cmp edx, 7
    jne .bad
    shr eax, 3
    cmp eax, DPMI_LDT_COUNT
    jae .bad
    cmp byte [ebp+dpmi_used+eax], 3
    jne .bad
    lea esi, [ebp+dpmi_ldt+eax*8]
    clc
    ret
.bad:
    stc
    ret

; ECX=paragraphs. Return ECX=descriptors for the block. 16-bit clients get
; one descriptor for each 64 KB.
dpmi_dos_tile_count:
    cmp byte [ebp+dpmi_client16], 0
    je .one
    add ecx, 0fffh
    shr ecx, 12
    ret
.one:
    mov ecx, 1
    ret
; ESI=first descriptor, EAX=real segment, ECX=paragraphs.
dpmi_dos_tiles:
    pushad
    shl eax, 4
    mov edx, ecx
.tile:
    mov ecx, edx
    cmp byte [ebp+dpmi_client16], 0
    je .size
    cmp ecx, 1000h
    jbe .size
    mov ecx, 1000h
.size:
    sub edx, ecx
    mov [esi+2], ax
    mov ebx, eax
    shr ebx, 16
    mov [esi+4], bl
    shl ecx, 4
    dec ecx
    mov [esi], cx
    shr ecx, 16
    and byte [esi+6], 70h
    or [esi+6], cl
    test edx, edx
    jz .done
    add eax, 10000h
    add esi, 8
    mov word [esi+5], 00f2h
    lea ebx, [esi-dpmi_ldt]
    sub ebx, ebp
    shr ebx, 3
    mov byte [ebp+dpmi_used+ebx], 5
    jmp .tile
.done:
    popad
    ret
; ESI=first descriptor, ECX=descriptors to keep. Free the tiles after them.
dpmi_dos_untile:
    pushad
    lea edx, [esi-dpmi_ldt]
    sub edx, ebp
    shr edx, 3
    add edx, ecx
.next:
    cmp edx, DPMI_LDT_COUNT
    jae .done
    cmp byte [ebp+dpmi_used+edx], 5
    jne .done
    mov byte [ebp+dpmi_used+edx], 0
    mov dword [ebp+dpmi_ldt+edx*8], 0
    mov dword [ebp+dpmi_ldt+edx*8+4], 0
    lea eax, [edx*8+7]
    call dpmi_clear_selector
    inc edx
    jmp .next
.done:
    popad
    ret
; ESI=first descriptor. CF when the tiles for BX paragraphs do not fit.
dpmi_dos_tile_room:
    pushad
    movzx ecx, word [ebx+24]
    call dpmi_dos_tile_count
    lea edx, [esi-dpmi_ldt]
    sub edx, ebp
    shr edx, 3
    lea eax, [edx+ecx]
    cmp eax, DPMI_LDT_COUNT
    ja .full
.check:
    inc edx
    dec ecx
    jz .fits
    cmp byte [ebp+dpmi_used+edx], 0
    je .check
    cmp byte [ebp+dpmi_used+edx], 5
    je .check
.full:
    popad
    stc
    ret
.fits:
    popad
    clc
    ret

dpmi_dos_translate:
    cmp byte [ebp+dpmi_reflect_vector], 33h
    jne .mux
    cmp word [ebx+36], 0ch
    je dpmi_mouse_handler
.mux:
    cmp byte [ebp+dpmi_reflect_vector], 2fh
    jne .dos
    cmp word [ebx+36], 168ah
    je dpmi_vendor_query
.dos:
    cmp byte [ebp+dpmi_reflect_vector], 21h
    jne .ordinary
    cmp byte [ebx+37], 51h
    je .psp
    cmp byte [ebx+37], 62h
    je .psp
    cmp byte [ebp+dpmi_client16], 0
    jne .dos_memory
    cmp byte [ebx+37], 09h
    je .print
.dos_memory:
    mov byte [ebp+dpmi_dos_via21], 1
    movzx eax, word [ebx+28]
    or eax, 10000h
    mov [ebx+20], eax
    cmp byte [ebx+37], 48h
    je dpmi_dos_allocate
    cmp byte [ebx+37], 49h
    jne .resize
    mov ax, [ebx]
    mov [ebx+28], ax
    jmp dpmi_dos_free
.resize:
    cmp byte [ebx+37], 4ah
    jne .dos16
    mov ax, [ebx]
    mov [ebx+28], ax
    jmp dpmi_dos_resize
.dos16:
    cmp byte [ebp+dpmi_client16], 0
    jne dpmi_dos16
    ; 32-bit clients get the calls that pass a path or a short buffer.
    movzx eax, byte [ebx+37]
    cmp al, 5bh
    je dpmi_dos16
    cmp al, 6ch
    je dpmi_dos16
    sub al, 39h
    cmp al, 15
    jae .ordinary
    ; 39h-3Dh, 3Fh-41h, 43h, 47h
    push edx
    mov edx, 45dfh
    bt edx, eax
    pop edx
    jc dpmi_dos16
    jmp .ordinary
.psp:
    call dpmi_dos_frame
    mov eax, [ebx+36]
    mov [edi+28], eax
    mov word [edi+32], 202h
    mov eax, 21h
    call mon_real_int
    mov ax, [edi+16]
    cmp ax, [ebp+dpmi_psp]
    jne .other_psp
    mov ax, 27h
    jmp .psp_result
.other_psp:
    call dpmi_segment_descriptor
    jc .descriptor_full
.psp_result:
    mov [ebx+24], ax
    jmp mon_dpmi.done
.print:
    mov edx, [ebx+28]
    mov ecx, 65535
.print_next:
    push ecx
    mov ax, [ebx+4]
    mov ecx, 1
    xor edi, edi
    call dpmi_read_buffer
    pop ecx
    jc dpmi_error
    cmp byte [eax], '$'
    je .printed
    pushad
    movzx edx, byte [eax]
    call dpmi_dos_frame
    mov [edi+20], edx
    mov word [edi+28], 0200h
    mov word [edi+32], 202h
    mov eax, 21h
    call mon_real_int
    popad
    inc edx
    loop .print_next
    mov ax, 8021h
    jmp dpmi_error
.printed:
    mov byte [ebx+36], '$'
    jmp mon_dpmi.done
.ordinary:
    call dpmi_dos_frame
    mov al, [ebp+dpmi_reflect_vector]
    call dpmi_vector_irq
    jc .hardware
    call dpmi_register_interrupt
    jnc .hardware
    mov ax, [ebx+4]
    test ax, ax
    jz .ds_ready
    call dpmi_descriptor
    jc dpmi_dos.unsupported
    call dpmi_descriptor_base
    cmp eax, 100000h
    jae dpmi_dos.unsupported
    test al, 0fh
    jnz dpmi_dos.unsupported
    shr eax, 4
.ds_ready:
    mov [edi+36], ax
    mov ax, [ebx]
    test ax, ax
    jz .es_ready
    call dpmi_descriptor
    jc dpmi_dos.unsupported
    call dpmi_descriptor_base
    cmp eax, 100000h
    jae dpmi_dos.unsupported
    test al, 0fh
    jnz dpmi_dos.unsupported
    shr eax, 4
.es_ready:
    mov [edi+34], ax
.reflect:
    lea esi, [ebp+mon_real_int]
    push dword [ebp+dpmi_irq_reflecting]
.reflect_call:
    push esi
    push edi
    lea esi, [ebx+8]
    mov ecx, 8
    rep movsd
    pop edi
    mov word [edi+32], 202h
    movzx eax, byte [ebp+dpmi_reflect_vector]
    call [esp]
    add esp, 4
    pop dword [ebp+dpmi_irq_reflecting]
    cmp byte [ebp+dpmi_reflect_vector], 10h
    jne .registers
    cmp word [ebx+36], 1130h
    jne .registers
    mov ax, [edi+34]
    call dpmi_segment_descriptor
    jc .descriptor_full
    mov [ebx], ax
.registers:
    mov esi, edi
    lea edi, [ebx+8]
    mov ecx, 8
    rep movsd
    and word [ebx+48], 0f72ah
    mov ax, [esi]
    and ax, 08d5h
    or [ebx+48], ax
    jmp mon_dpmi.done
.descriptor_full:
    mov ax, 8011h
    jmp dpmi_error
.hardware:
    call dpmi_pic_reflect
    mov dword [edi+34], 0
    push dword [ebp+dpmi_irq_reflecting]
    ; A real-mode hook can chain to the bridge stub. The stub must not pass this IRQ up again.
    movzx eax, byte [ebp+dpmi_reflect_vector]
    call dpmi_vector_irq
    jnc .irq_ready
    bts [ebp+dpmi_irq_reflecting], eax
.irq_ready:
    lea esi, [ebp+mon_real_irq]
    jmp .reflect_call

; INT 33h 0Ch from protected mode: the driver calls dpmi_mouse_stub (Igor).
dpmi_mouse_handler:
    mov byte [ebp+dpmi_mouse_pending], 0
    mov ax, [ebx]
    mov [ebp+dpmi_mouse_vector+4], ax
    mov eax, [ebx+28]
    DPMI_OFFSET16 eax, ax
    mov [ebp+dpmi_mouse_vector], eax
%ifdef RESIDENT_HOST
    mov al, [ebp+dpmi_nested_depth]
    mov [ebp+dpmi_mouse_depth], al
%endif
    call dpmi_dos_frame
    mov word [edi+28], 0ch
    mov ax, [ebx+32]
    mov [edi+24], ax
    mov word [edi+20], dpmi_mouse_stub
    mov eax, [ebp+mon_real_base]
    shr eax, 4
    mov [edi+34], ax
    mov word [edi+32], 202h
    mov eax, 33h
    call mon_real_int
    jmp mon_dpmi.done

; Carry clear if the supported service has no segment-pointer inputs.
dpmi_register_interrupt:
    mov al, [ebp+dpmi_reflect_vector]
    cmp al, 11h
    je .yes
    cmp al, 12h
    je .yes
    cmp al, 16h
    je .yes
    ; Judge Dredd: JD.EXE asks LAW.EXE for sounds with INT 2Bh.
    cmp al, 2bh
    je .yes
    cmp al, 1ah
    jne .video
    cmp byte [ebx+37], 7
    jbe .yes
    jmp .no
.video:
    cmp al, 10h
    jne .dos
    mov ax, [ebx+36]
    cmp ax, 1130h
    je .yes
    cmp ah, 0fh
    jbe .yes
    ; Palette, display configuration, and VBE mode and window calls pass no pointers.
    cmp ax, 1001h
    jbe .yes
    cmp ax, 1003h
    je .yes
    cmp ah, 12h
    je .yes
    cmp ah, 1ah
    je .yes
    cmp ax, 4f02h
    je .yes
    cmp ax, 4f03h
    je .yes
    cmp ax, 4f05h
    je .yes
    jmp .no
.dos:
    cmp al, 33h
    je .mouse
    cmp al, 2fh
    je .mux
    cmp al, 21h
    jne .no
    mov al, [ebx+37]
    cmp al, 30h
    je .yes
    cmp al, 02h
    je .yes
    cmp al, 19h
    je .yes
    cmp al, 0eh
    je .yes
    cmp al, 2ah
    je .yes
    cmp al, 2ch
    je .yes
    cmp al, 36h
    je .yes
    cmp al, 3eh
    je .yes
    cmp al, 42h
    je .yes
    cmp al, 4dh
    je .yes
    jmp .no
; MSCDEX checks that take no pointers (Napion 3D).
.mux:
    mov ax, [ebx+36]
    cmp ax, 1500h
    je .yes
    cmp ax, 150bh
    je .yes
    cmp ax, 150ch
    je .yes
    jmp .no
.mouse:
    ; Mouse functions with no pointer input or output.
    push edx
    movzx eax, word [ebx+36]
    mov edx, 7c29edffh
    cmp eax, 20h
    jb .mouse_bit
    sub eax, 20h
    mov edx, 453h
.mouse_bit:
    cmp eax, 20h
    jae .mouse_no
    bt edx, eax
    pop edx
    jc .yes
    jmp .no
.mouse_no:
    pop edx
.no:
    stc
    ret
.yes:
    clc
    ret
