; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; 16-bit clients such as Borland RTM expect the host to translate DOS calls.
; Pointer data goes through a real-mode buffer after the bridge stacks.

HOST_PROTECTED
; EBX=client frame of an INT 21h call.
dpmi_dos16:
    cld
    movzx eax, word [ebp+dpmi_bridge_real_segment]
    add eax, 128
    mov [ebp+dpmi_xfer_segment], ax
    shl eax, 4
    mov [ebp+dpmi_xfer_linear], eax
    call .reload
    mov al, [ebx+37]
    cmp al, 09h
    je .print
    cmp al, 1ah
    je .set_dta
    cmp al, 2fh
    je .get_dta
    cmp al, 25h
    je .set_vector
    cmp al, 35h
    je .get_vector
    cmp al, 38h
    je .country
    cmp al, 3fh
    je .read
    cmp al, 40h
    je .write
    cmp al, 44h
    je .ioctl
    cmp al, 47h
    je .cwd
    cmp al, 4eh
    je .find_first
    cmp al, 4fh
    je .find_next
    cmp al, 50h
    je .set_psp
    cmp al, 51h
    je .psp
    cmp al, 62h
    je .psp
    cmp al, 56h
    je .rename
    cmp al, 5ah
    je .temp
    cmp al, 6ch
    je .open_extended
    ; These functions take an ASCIIZ path at DS:DX.
    cmp al, 39h
    jb .other
    cmp al, 3dh
    jbe .path
    cmp al, 41h
    je .path
    cmp al, 43h
    je .path
    cmp al, 5bh
    je .path
.other:
    movzx eax, al
    cmp eax, 80h
    jae .mapped
    bt [ebp+dpmi_dos16_plain], eax
    jc .plain
.mapped:
    ; Other functions get DS and ES only when they address the first MB.
    cmp al, 4bh
    je .bad_pointer
    cmp al, 31h
    je .bad_pointer
    test al, al
    jz .bad_pointer
    mov ax, [ebx+4]
    call .segment
    jc .bad_pointer
    mov [edi+36], ax
    mov ax, [ebx]
    call .segment
    jc .bad_pointer
    mov [edi+34], ax
    call .call
    jmp .result
.plain:
    ; These functions use no pointer. DS and ES address the buffer.
    mov ax, [ebp+dpmi_xfer_segment]
    mov [edi+34], ax
    mov [edi+36], ax
    call .call
    mov al, [ebx+37]
    cmp al, 34h
    je .map_es
    cmp al, 52h
    je .map_es
    cmp al, 1bh
    je .map_ds
    cmp al, 1ch
    je .map_ds
    cmp al, 1fh
    je .map_ds
    cmp al, 32h
    je .map_ds
    jmp .result
.map_es:
    mov ax, [edi+34]
    cmp ax, [ebp+dpmi_xfer_segment]
    je .result
    call dpmi_segment_descriptor
    jc .result
    mov [ebx], ax
    jmp .result
.map_ds:
    cmp byte [edi+28], 0ffh
    je .result
    mov ax, [edi+36]
    cmp ax, [ebp+dpmi_xfer_segment]
    je .result
    call dpmi_segment_descriptor
    jc .result
    mov [ebx+4], ax
    jmp .result

.path:
    mov ax, [ebx+4]
    movzx edx, word [ebx+28]
    xor ecx, ecx
    call .string_in
    jc .bad_pointer
    call .buffer_ds
    mov word [edi+20], 0
    call .call
    jmp .keep_dx

.open_extended:
    mov ax, [ebx+4]
    movzx edx, word [ebx+12]
    xor ecx, ecx
    call .string_in
    jc .bad_pointer
    call .buffer_ds
    mov word [edi+4], 0
    call .call
    mov eax, [ebx+12]
    mov [edi+4], eax
    jmp .result

.rename:
    mov ax, [ebx+4]
    movzx edx, word [ebx+28]
    xor ecx, ecx
    call .string_in
    jc .bad_pointer
    mov ax, [ebx]
    movzx edx, word [ebx+8]
    mov ecx, 128
    call .string_in
    jc .bad_pointer
    call .buffer_ds
    mov [edi+34], ax
    mov word [edi+20], 0
    mov word [edi], 128
    call .call
    mov eax, [ebx+8]
    mov [edi], eax
    jmp .keep_dx

.temp:
    mov ax, [ebx+4]
    movzx edx, word [ebx+28]
    xor ecx, ecx
    call .string_in
    jc .bad_pointer
    ; DOS appends a name of up to 13 bytes to the path.
    push edi
    mov edi, [ebp+dpmi_xfer_linear]
    xor eax, eax
    mov ecx, 128
    repne scasb
    sub edi, [ebp+dpmi_xfer_linear]
    lea ecx, [edi+13]
    pop edi
    mov [ebp+dpmi_dos16_chunk], ecx
    mov ax, [ebx+4]
    movzx edx, word [ebx+28]
    call .write_ptr
    jc .bad_pointer
    push eax
    call .buffer_ds
    mov word [edi+20], 0
    call .call
    pop eax
    test byte [edi+32], 1
    jnz .keep_dx
    mov ecx, [ebp+dpmi_dos16_chunk]
    push edi
    mov edi, eax
    mov esi, [ebp+dpmi_xfer_linear]
.temp_copy:
    lodsb
    stosb
    test al, al
    loopnz .temp_copy
    pop edi
    jmp .keep_dx

.print:
    mov ax, [ebx+4]
    movzx edx, word [ebx+28]
    push edi
    xor edi, edi
    call dpmi_dos16_span
    pop edi
    jc .bad_pointer
    push edi
    mov esi, eax
    mov edi, [ebp+dpmi_xfer_linear]
.print_copy:
    lodsb
    stosb
    cmp al, '$'
    je .print_ready
    loop .print_copy
    mov byte [edi-1], '$'
.print_ready:
    pop edi
    call .buffer_ds
    mov word [edi+20], 0
    call .call
    jmp .keep_dx

.read:
    movzx ecx, word [ebx+32]
    test ecx, ecx
    jz .write_empty
    mov ax, [ebx+4]
    movzx edx, word [ebx+28]
    call .write_ptr
    jc .bad_pointer
    mov [ebp+dpmi_dos16_target], eax
    mov dword [ebp+dpmi_dos16_done], 0
    movzx eax, word [ebx+32]
    mov [ebp+dpmi_dos16_left], eax
.read_chunk:
    call .chunk
    mov byte [edi+29], 3fh
    call .call
    test byte [edi+32], 1
    jnz .transfer_error
    movzx ecx, word [edi+28]
    push edi
    mov esi, [ebp+dpmi_xfer_linear]
    mov edi, [ebp+dpmi_dos16_target]
    push ecx
    rep movsb
    pop ecx
    mov [ebp+dpmi_dos16_target], edi
    pop edi
    jmp .transfer_next

.write:
    movzx ecx, word [ebx+32]
    test ecx, ecx
    jz .write_empty
    mov ax, [ebx+4]
    movzx edx, word [ebx+28]
    call .read_ptr
    jc .bad_pointer
    mov [ebp+dpmi_dos16_target], eax
    mov dword [ebp+dpmi_dos16_done], 0
    movzx eax, word [ebx+32]
    mov [ebp+dpmi_dos16_left], eax
.write_chunk:
    call .chunk
    push edi
    mov esi, [ebp+dpmi_dos16_target]
    mov edi, [ebp+dpmi_xfer_linear]
    rep movsb
    mov [ebp+dpmi_dos16_target], esi
    pop edi
    mov byte [edi+29], 40h
    call .call
    test byte [edi+32], 1
    jnz .transfer_error
    movzx ecx, word [edi+28]
.transfer_next:
    add [ebp+dpmi_dos16_done], ecx
    sub [ebp+dpmi_dos16_left], ecx
    cmp ecx, [ebp+dpmi_dos16_chunk]
    jb .transfer_done
    cmp dword [ebp+dpmi_dos16_left], 0
    jne .transfer_more
.transfer_done:
    mov eax, [ebp+dpmi_dos16_done]
    mov [ebx+36], ax
    and byte [ebx+48], 0feh
    jmp mon_dpmi.done
.transfer_more:
    cmp byte [ebx+37], 3fh
    je .read_chunk
    jmp .write_chunk
.transfer_error:
    ; A later chunk error returns the bytes already moved.
    cmp dword [ebp+dpmi_dos16_done], 0
    jne .transfer_done
    mov ax, [edi+28]
    mov [ebx+36], ax
    or byte [ebx+48], 1
    jmp mon_dpmi.done
.write_empty:
    ; A zero count reads nothing or sets the file size.
    call .buffer_ds
    mov word [edi+20], 0
    call .call
    jmp .keep_dx

.cwd:
    mov ax, [ebx+4]
    movzx edx, word [ebx+12]
    mov ecx, 64
    call .write_ptr
    jc .bad_pointer
    push eax
    call .buffer_ds
    mov word [edi+4], 0
    call .call
    pop eax
    test byte [edi+32], 1
    jnz .cwd_done
    push edi
    mov edi, eax
    mov esi, [ebp+dpmi_xfer_linear]
    mov ecx, 64
    rep movsb
    pop edi
.cwd_done:
    mov eax, [ebx+12]
    mov [edi+4], eax
    jmp .result

.country:
    cmp word [ebx+28], 0ffffh
    je .plain
    mov ax, [ebx+4]
    movzx edx, word [ebx+28]
    mov ecx, 34
    call .write_ptr
    jc .bad_pointer
    push eax
    call .buffer_ds
    mov word [edi+20], 0
    call .call
    pop eax
    test byte [edi+32], 1
    jnz .keep_dx
    push edi
    mov edi, eax
    mov esi, [ebp+dpmi_xfer_linear]
    mov ecx, 34
    rep movsb
    pop edi
    jmp .keep_dx

.ioctl:
    mov al, [ebx+36]
    cmp al, 0ch
    je .bad_pointer
    cmp al, 0dh
    je .bad_pointer
    cmp al, 2
    jb .plain
    cmp al, 5
    ja .plain
    ; Subfunctions 02h to 05h move CX bytes at DS:DX.
    movzx ecx, word [ebx+32]
    test ecx, ecx
    jz .write_empty
    cmp ecx, DPMI_XFER_BYTES
    ja .bad_pointer
    mov ax, [ebx+4]
    movzx edx, word [ebx+28]
    call .write_ptr
    jc .bad_pointer
    push eax
    push edi
    mov esi, eax
    mov edi, [ebp+dpmi_xfer_linear]
    rep movsb
    pop edi
    call .buffer_ds
    mov word [edi+20], 0
    call .call
    pop eax
    test byte [edi+32], 1
    jnz .keep_dx
    test byte [ebx+36], 1
    jnz .keep_dx
    movzx ecx, word [edi+28]
    cmp cx, [ebx+32]
    jbe .ioctl_copy
    movzx ecx, word [ebx+32]
.ioctl_copy:
    push edi
    mov edi, eax
    mov esi, [ebp+dpmi_xfer_linear]
    rep movsb
    pop edi
    jmp .keep_dx

.set_dta:
    mov ax, [ebx+4]
    mov [ebp+dpmi_dos16_dta], ax
    mov ax, [ebx+28]
    mov [ebp+dpmi_dos16_dta+2], ax
    jmp mon_dpmi.done
.get_dta:
    mov ax, [ebp+dpmi_dos16_dta]
    mov [ebx], ax
    mov ax, [ebp+dpmi_dos16_dta+2]
    mov [ebx+24], ax
    jmp mon_dpmi.done

.find_first:
    mov ax, [ebx+4]
    movzx edx, word [ebx+28]
    xor ecx, ecx
    call .string_in
    jc .bad_pointer
    mov ax, [ebp+dpmi_dos16_dta]
    movzx edx, word [ebp+dpmi_dos16_dta+2]
    mov ecx, 43
    call .write_ptr
    jc .bad_pointer
    jmp .find
.find_next:
    ; The client DTA holds the search state.
    mov ax, [ebp+dpmi_dos16_dta]
    movzx edx, word [ebp+dpmi_dos16_dta+2]
    mov ecx, 43
    call .write_ptr
    jc .bad_pointer
    push edi
    mov esi, eax
    mov edi, [ebp+dpmi_xfer_linear]
    add edi, DPMI_XFER_DTA
    mov ecx, 43
    rep movsb
    pop edi
.find:
    ; Search with a DTA in the buffer, then restore the real-mode DTA.
    mov ax, 2f00h
    call .side_call
    mov [ebp+dpmi_dos16_real_dta], eax
    mov ax, 1a00h
    mov cx, [ebp+dpmi_xfer_segment]
    mov dx, DPMI_XFER_DTA
    call .side_call
    call .buffer_ds
    mov word [edi+20], 0
    call .call
    mov ax, 1a00h
    mov cx, [ebp+dpmi_dos16_real_dta+2]
    mov dx, [ebp+dpmi_dos16_real_dta]
    call .side_call
    test byte [edi+32], 1
    jnz .keep_dx
    mov ax, [ebp+dpmi_dos16_dta]
    movzx edx, word [ebp+dpmi_dos16_dta+2]
    mov ecx, 43
    call .write_ptr
    jc .keep_dx
    push edi
    mov edi, eax
    mov esi, [ebp+dpmi_xfer_linear]
    add esi, DPMI_XFER_DTA
    mov ecx, 43
    rep movsb
    pop edi
    jmp .keep_dx

.psp:
    call .call
    mov ax, [edi+16]
    cmp ax, [ebp+dpmi_psp]
    jne .psp_other
    mov word [edi+16], 27h
    jmp .result
.psp_other:
    call dpmi_segment_descriptor
    jc .result
    mov [edi+16], ax
    jmp .result
.set_psp:
    mov ax, [ebx+24]
    cmp ax, 27h
    jne .psp_base
    mov ax, [ebp+dpmi_psp]
    jmp .psp_set
.psp_base:
    call dpmi_descriptor
    jc .bad_pointer
    call dpmi_descriptor_base
    cmp eax, 100000h
    jae .bad_pointer
    test al, 0fh
    jnz .bad_pointer
    shr eax, 4
.psp_set:
    lea edi, [ebp+dpmi_dos_regs]
    mov [edi+16], ax
    call .call
    mov eax, [ebx+24]
    mov [edi+16], eax
    jmp .result

.get_vector:
    ; In protected mode these functions use the protected-mode vector.
    movzx eax, byte [ebx+36]
    imul ecx, eax, 6
    mov edx, [ebp+mon_vectors+ecx]
    mov cx, [ebp+mon_vectors+ecx+4]
    test cx, cx
    jnz .vector_ready
    imul edx, eax, 3
    add edx, dpmi_default_vectors
    mov cx, DPMI_STUB16
.vector_ready:
    mov [ebx], cx
    mov [ebx+24], dx
    jmp mon_dpmi.done
.set_vector:
    mov ax, [ebx+4]
    movzx edx, word [ebx+28]
    test ax, ax
    jz .vector_write
    call dpmi_code_target
    jc .vector_bad
.vector_write:
    movzx ecx, byte [ebx+36]
    imul ecx, 6
    mov [ebp+mon_vectors+ecx], edx
    mov ax, [ebx+4]
    mov [ebp+mon_vectors+ecx+4], ax
    call dpmi_bridge_update
%ifdef RESIDENT_HOST
    movzx eax, byte [ebp+dpmi_guest_vector]
    imul eax, 6
    cmp word [ebp+mon_vectors+eax+4], 0
    setne byte [ebp+dpmi_audio_pm_handler]
%endif
    jmp mon_dpmi.done
.vector_bad:
    or byte [ebx+48], 1
    jmp mon_dpmi.done

.keep_dx:
    mov eax, [ebx+28]
    mov [edi+20], eax
.result:
    mov esi, edi
    lea edi, [ebx+8]
    mov ecx, 8
    rep movsd
    and word [ebx+48], 0f72ah
    mov ax, [esi]
    and ax, 08d5h
    or [ebx+48], ax
    jmp mon_dpmi.done
.bad_pointer:
    mov word [ebx+36], 1
    or byte [ebx+48], 1
    jmp mon_dpmi.done

; Load the client registers into the real-mode register structure at EDI.
.reload:
    call dpmi_dos_frame
    push edi
    lea esi, [ebx+8]
    mov ecx, 8
    rep movsd
    pop edi
    mov word [edi+32], 202h
    ret
.buffer_ds:
    mov ax, [ebp+dpmi_xfer_segment]
    mov [edi+36], ax
    ret
; AX=function, CX:DX=pointer. Keep the main register structure.
; Return EAX=ES:BX.
.side_call:
    push edi
    lea edi, [ebp+dpmi_dos16_side]
    mov [edi+28], ax
    mov [edi+20], dx
    mov [edi+36], cx
    mov dword [edi+46], 0
    mov word [edi+32], 202h
    mov eax, 21h
    call mon_real_int
    mov ax, [edi+34]
    shl eax, 16
    mov ax, [edi+16]
    pop edi
    ret
; AX=selector. Return AX=real segment, or CF when the base is not a
; paragraph in the first MB.
.segment:
    test ax, ax
    jz .segment_done
    push esi
    push edx
    call dpmi_descriptor
    jc .segment_bad
    call dpmi_descriptor_base
    cmp eax, 100000h
    jae .segment_bad
    test al, 0fh
    jnz .segment_bad
    shr eax, 4
    pop edx
    pop esi
.segment_done:
    clc
    ret
.segment_bad:
    pop edx
    pop esi
    stc
    ret
.call:
    mov word [edi+32], 202h
    mov eax, 21h
    jmp mon_real_int
; Set up the next chunk: BX and CX from the client, DS:DX at the buffer.
.chunk:
    mov ecx, [ebp+dpmi_dos16_left]
    cmp ecx, DPMI_XFER_BYTES
    jbe .chunk_size
    mov ecx, DPMI_XFER_BYTES
.chunk_size:
    mov [ebp+dpmi_dos16_chunk], ecx
    mov ax, [ebx+24]
    mov [edi+16], ax
    mov [edi+24], cx
    call .buffer_ds
    mov word [edi+20], 0
    ret
; Copy the ASCIIZ string at AX:EDX to the buffer at ECX. CF on a bad string.
.string_in:
    push edi
    push ecx
    xor edi, edi
    call dpmi_dos16_span
    pop edi
    jc .string_bad
    cmp ecx, 128
    jbe .string_size
    mov ecx, 128
.string_size:
    mov esi, eax
    add edi, [ebp+dpmi_xfer_linear]
.string_copy:
    lodsb
    stosb
    test al, al
    jz .string_done
    loop .string_copy
.string_bad:
    pop edi
    stc
    ret
.string_done:
    pop edi
    clc
    ret
; AX:EDX for ECX bytes. Return EAX=linear.
.read_ptr:
    push edi
    xor edi, edi
    call dpmi_buffer
    pop edi
    ret
.write_ptr:
    push edi
    mov edi, 1
    call dpmi_buffer
    pop edi
    ret

; AX=selector, EDX=offset, EDI=access. Return EAX=linear and ECX=bytes up to
; the segment limit, at most DPMI_XFER_BYTES. Keep EBX, EDX, ESI, EDI.
dpmi_dos16_span:
    push esi
    push edx
    push ecx
    mov ecx, 1
    push eax
    call dpmi_buffer
    pop ecx
    jc .bad
    push eax
    mov ax, cx
    call dpmi_descriptor
    movzx ecx, byte [esi+6]
    and ecx, 0fh
    shl ecx, 16
    mov cx, [esi]
    test byte [esi+6], 80h
    jz .limit
    shl ecx, 12
    or ecx, 0fffh
.limit:
    ; An expand-down segment ends at 0FFFFh or 0FFFFFFFFh.
    mov dl, [esi+5]
    and dl, 0ch
    cmp dl, 4
    jne .upper
    mov ecx, 0ffffh
    test byte [esi+6], 40h
    jz .upper
    or ecx, -1
.upper:
    sub ecx, [esp+8]
    inc ecx
    jz .most
    cmp ecx, DPMI_XFER_BYTES
    jbe .count
.most:
    mov ecx, DPMI_XFER_BYTES
.count:
    pop eax
    add esp, 4
    pop edx
    pop esi
    clc
    ret
.bad:
    pop ecx
    pop edx
    pop esi
    stc
    ret

dpmi_xfer_segment dw 0
dpmi_xfer_linear dd 0
dpmi_dos16_dta dw 0, 0
dpmi_dos16_target dd 0
dpmi_dos16_done dd 0
dpmi_dos16_left dd 0
dpmi_dos16_chunk dd 0
dpmi_dos16_real_dta dd 0
dpmi_dos16_side times 50 db 0

%macro DPMI_DOS16_PLAIN 1-*
    %assign %%w0 0
    %assign %%w1 0
    %assign %%w2 0
    %assign %%w3 0
    %rep %0
        %if %1 < 32
            %assign %%w0 %%w0 | (1 << %1)
        %elif %1 < 64
            %assign %%w1 %%w1 | (1 << (%1-32))
        %elif %1 < 96
            %assign %%w2 %%w2 | (1 << (%1-64))
        %else
            %assign %%w3 %%w3 | (1 << (%1-96))
        %endif
        %rotate 1
    %endrep
    dd %%w0 & 0ffffffffh, %%w1 & 0ffffffffh, %%w2 & 0ffffffffh, %%w3 & 0ffffffffh
%endmacro
; DOS functions with no pointer input.
dpmi_dos16_plain:
    DPMI_DOS16_PLAIN 01h, 02h, 03h, 04h, 05h, 06h, 07h, 08h, 0bh, 0dh, 0eh, 18h, 19h, 1bh, 1ch, 1dh,         1eh, 1fh, 20h, 2ah, 2bh, 2ch, 2dh, 2eh, 30h, 32h, 33h, 34h, 36h, 37h, 3eh, 42h, 44h, 45h, 46h,         4dh, 52h, 54h, 57h, 58h, 59h, 5ch, 66h, 67h, 68h, 6ah, 6bh
