; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

HOST_PROTECTED
%define DPMI_LOCK_BASE 3e0000h
%define DPMI_LOCK_LEVELS 4
%define DPMI_LOCK_PAGES 7
dpmi_locked_init:
    pushad
    xor ebx, ebx
.page:
%ifdef DPMI_LOCK_FAIL_PAGE
    cmp ebx, DPMI_LOCK_FAIL_PAGE
    je .bad
%endif
%ifdef DPMI_LOCK_FAIL_SECOND
    cmp ebx, 1
    je .bad
%endif
    call dpmi_page_allocate
    jc .bad
    mov [ebp+dpmi_locked_pages+ebx*4], edx
    mov edi, [ebp+dpmi_locked_linear+ebx*4]
    shr edi, 10
    add edi, 0ffc00000h
    mov eax, [edi]
    mov [ebp+dpmi_locked_ptes+ebx*4], eax
    or edx, 7
    mov [edi], edx
    call dpmi_flush
    mov edi, [ebp+dpmi_locked_linear+ebx*4]
    xor eax, eax
    mov ecx, 1024
    cld
    rep stosd
    inc ebx
    cmp ebx, DPMI_LOCK_PAGES
    jb .page
    mov dword [ebp+dpmi_ldt+6*8], 00003fffh
    mov dword [ebp+dpmi_ldt+6*8+4], 0040f23eh
    mov dword [ebp+dpmi_ldt+7*8], 0e0000fffh
    mov dword [ebp+dpmi_ldt+7*8+4], 0040f23fh
    mov word [ebp+dpmi_used+6], 0404h
    mov dword [ebp+dpmi_locked_cursor], 4096
    mov dword [ebp+dpmi_locked_depth], 0
    mov dword [ebp+dpmi_stack_depth], 0
    popad
    clc
    ret
.bad:
    call dpmi_locked_free
    popad
    stc
    ret

dpmi_locked_free:
    pushad
    xor ebx, ebx
.page:
    mov edx, [ebp+dpmi_locked_pages+ebx*4]
    test edx, edx
    jz .next
    mov eax, [ebp+dpmi_locked_ptes+ebx*4]
    mov edi, [ebp+dpmi_locked_linear+ebx*4]
    shr edi, 10
    mov [0ffc00000h+edi], eax
    call dpmi_flush
    call dpmi_page_free
    mov dword [ebp+dpmi_locked_pages+ebx*4], 0
.next:
    inc ebx
    cmp ebx, DPMI_LOCK_PAGES
    jb .page
    popad
    ret

; EBX points to a five-dword protected interrupt frame minus 40 bytes.
dpmi_locked_capture:
    test byte [ebx+44], 3
    jz .done
    cmp word [ebx+56], DPMI_IRQ_SS
    jne .done
    push eax
    mov eax, [ebx+52]
    mov [ebp+dpmi_locked_cursor], eax
    pop eax
.done:
    ret

; EBX=client frame that starts with ES and DS. Keep the segments of the
; client's last protected-mode entry for interrupts that arrive in real mode.
dpmi_record_segments:
    test byte [ebx+44], 3
    jz .done
    test byte [ebx+50], 2
    jnz .done
    push eax
    mov eax, [ebx]
    mov [ebp+dpmi_client_segs], ax
    mov eax, [ebx+4]
    mov [ebp+dpmi_client_segs+2], ax
    mov [ebp+dpmi_client_segs+4], fs
    mov [ebp+dpmi_client_segs+6], gs
    pop eax
.done:
    ret

; Load the recorded FS and GS. Return ES in AX and DS in DX.
dpmi_client_segments:
    push ecx
    mov ecx, [ebp+dpmi_client_segs+4]
    call dpmi_load_fs_gs
    mov dx, 2bh
    mov ax, [ebp+dpmi_client_segs+2]
    call dpmi_usable_selector
    push eax
    mov ax, [ebp+dpmi_client_segs]
    call dpmi_usable_selector
    pop edx
    pop ecx
    ret

; ECX=FS in the low word and GS in the high word. Unusable selectors load 0.
dpmi_load_fs_gs:
    push eax
    push edx
    xor edx, edx
    mov ax, cx
    call dpmi_usable_selector
    mov fs, ax
    shr ecx, 16
    mov ax, cx
    call dpmi_usable_selector
    mov gs, ax
    pop edx
    pop eax
    ret

; Replace AX with DX when AX is not a present readable segment.
dpmi_usable_selector:
    push ecx
    verr ax
    jnz .other
    lar ecx, ax
    test ch, 80h
    jnz .done
.other:
    mov ax, dx
.done:
    pop ecx
    ret

dpmi_client_segs times 4 dw 0
dpmi_raw_segs dd 0

dpmi_deliver_hardware:
    call dpmi_locked_capture
    call dpmi_stack_acquire
    push esi
    mov edx, [esi]
    mov ax, [esi+4]
    call dpmi_code_target
    pop esi
    jc dpmi_locked_abort
    mov edi, [ebp+dpmi_locked_cursor]
    mov edx, edi
    sub edi, 28
    mov [ebp+dpmi_locked_cursor], edi
    add edi, DPMI_LOCK_BASE
    mov [edi+20], edx
    mov dword [edi+24], 48495251h
    mov eax, [ebx+40]
    mov [edi], eax
    mov eax, [ebx+44]
    mov [edi+4], eax
    mov eax, [ebx+48]
    call dpmi_virtual_flags
    mov [edi+8], eax
    mov eax, [ebx+52]
    mov [edi+12], eax
    mov eax, [ebx+56]
    mov [edi+16], eax
    cmp byte [ebp+dpmi_client16], 0
    jne .word_frame
    sub edi, 12
    mov dword [edi], dpmi_locked_return
    mov dword [edi+4], 3bh
    mov dword [edi+8], 2
    jmp .framed
.word_frame:
    ; A 16-bit handler returns with a 16-bit IRET.
    sub edi, 6
    mov word [edi], dpmi_locked_return
    mov word [edi+2], DPMI_STUB16
    mov word [edi+4], 2
.framed:
    sub edi, DPMI_LOCK_BASE
    mov [ebx+52], edi
    mov dword [ebx+56], DPMI_IRQ_SS
    mov eax, [esi]
    mov [ebx+40], eax
    movzx eax, word [esi+4]
    mov [ebx+44], eax
    and word [ebx+48], 0feffh
    or word [ebx+48], 200h
    mov word [ebp+dpmi_vif], 0
    inc dword [ebp+dpmi_locked_depth]
    jmp mon_dpmi.done

dpmi_locked_return:
    int 0f4h
    ud2

dpmi_locked_done:
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
    cmp dword [ebp+dpmi_locked_depth], 0
    je dpmi_locked_abort
    cmp word [esp+44], 3bh
    je .stub
    cmp word [esp+44], DPMI_STUB16
    jne dpmi_locked_abort
.stub:
    cmp dword [esp+40], dpmi_locked_return+2
    jne dpmi_locked_abort
    cmp word [esp+56], DPMI_IRQ_SS
    jne dpmi_locked_abort
    mov esi, [esp+52]
    mov eax, [ebp+dpmi_stack_depth]
    test eax, eax
    jz dpmi_locked_abort
    shl eax, 12
    sub eax, 28
    cmp esi, eax
    ja dpmi_locked_abort
    sub eax, 4096-28
    cmp esi, eax
    jb dpmi_locked_abort
    add esi, DPMI_LOCK_BASE
    cmp dword [esi+24], 48495251h
    jne dpmi_locked_abort
    mov eax, [esi+20]
    mov edx, [esp+52]
    add edx, 28
    cmp eax, edx
    jne dpmi_locked_abort
    push esi
    mov edx, [esi]
    mov ax, [esi+4]
    call dpmi_code_target
    pop esi
    jc dpmi_locked_abort
    mov edx, [esi+12]
    mov ax, [esi+16]
    call dpmi_stack_target
    jc dpmi_locked_abort
    lea edi, [esp+40]
    mov ecx, 5
    cld
    rep movsd
    dec dword [ebp+dpmi_locked_depth]
    mov eax, [esp+48]
    call dpmi_restore_flags
    mov [esp+48], eax
    call dpmi_stack_release
    jmp mon_dpmi.done

dpmi_hardware_room:
%ifdef RESIDENT_HOST
    ; Hold client interrupts while the CD refill runs inside DOS.
    cmp byte [ebp+resident_refill_busy], 0
    jne .full
%endif
    cmp dword [ebp+dpmi_stack_depth], DPMI_LOCK_LEVELS
    jb .available
.full:
    stc
    ret
.available:
    clc
    ret

dpmi_stack_acquire:
    push eax
    mov eax, [ebp+dpmi_stack_depth]
    cmp eax, DPMI_LOCK_LEVELS
    jae dpmi_locked_abort
    push edx
    mov edx, [ebp+dpmi_locked_cursor]
    mov [ebp+dpmi_stack_cursors+eax*4], edx
    pop edx
    inc eax
    mov [ebp+dpmi_stack_depth], eax
    shl eax, 12
    mov [ebp+dpmi_locked_cursor], eax
    pop eax
    ret

dpmi_stack_release:
    push eax
    mov eax, [ebp+dpmi_stack_depth]
    test eax, eax
    jz dpmi_locked_abort
    dec eax
    mov [ebp+dpmi_stack_depth], eax
    mov eax, [ebp+dpmi_stack_cursors+eax*4]
    mov [ebp+dpmi_locked_cursor], eax
    pop eax
    ret

dpmi_stack_depth dd 0
dpmi_stack_cursors times DPMI_LOCK_LEVELS dd 0

dpmi_locked_abort:
    mov word [ebp+mon_status], 14
    mov byte [ebp+dpmi_exit_code], 1
    jmp dpmi_finish

dpmi_locked_linear dd 3fe000h,DPMI_LOCK_BASE,3fa000h,3fb000h,DPMI_LOCK_BASE+4096,DPMI_LOCK_BASE+8192,DPMI_LOCK_BASE+12288
dpmi_locked_pages times DPMI_LOCK_PAGES dd 0
dpmi_locked_ptes times DPMI_LOCK_PAGES dd 0
dpmi_locked_cursor dd 4096
HOST_REAL
dpmi_locked_depth dd 0
HOST_PROTECTED
dpmi_exception_sp dd 0
dpmi_exception_cursor dd 0
