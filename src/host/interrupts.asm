; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

HOST_PROTECTED
; EBX points to the normalized exception frame.
dpmi_step_check:
    HOST_COUNT decode, 0
    pushad
    mov dword [esp+12], 0
.next:
    mov dword [ebp+dpmi_step_code], 0
    cmp byte [ebp+dpmi_sti_shadow], 0
    je .shadow_ready
    mov eax, [ebx+48]
    cmp eax, [ebp+dpmi_sti_ip]
    jne .done
    mov ax, [ebx+52]
    cmp ax, [ebp+dpmi_sti_cs]
    jne .done
.shadow_ready:
    mov ax, [ebx+52]
    call dpmi_step_code_size
    jc .done
.decode:
    mov [ebp+dpmi_step_address_size], cl
    mov word [ebp+dpmi_step_segment], 0ffffh
    xor edi, edi
    xor edx, edx
.prefix:
    cmp edi, 15
    jae .done
    call .fetch
    jc .done
    inc edi
    cmp al, 66h
    jne .other_prefix
    test dl, 1
    jnz .prefix
    or dl, 1
    xor ecx, 6
    jmp .prefix
.other_prefix:
    cmp al, 0f2h
    je .rep_prefix
    cmp al, 0f3h
    je .rep_prefix
    cmp al, 26h
    je .es_prefix
    cmp al, 2eh
    je .cs_prefix
    cmp al, 36h
    je .ss_prefix
    cmp al, 3eh
    je .ds_prefix
    cmp al, 64h
    je .fs_prefix
    cmp al, 65h
    je .gs_prefix
    cmp al, 67h
    jne .opcode
    test dl, 2
    jnz .prefix
    or dl, 2
    xor byte [ebp+dpmi_step_address_size], 6
    jmp .prefix
.rep_prefix:
    or dl, 4
    jmp .prefix
.es_prefix:
    mov ax, [ebx]
    jmp .segment_prefix
.cs_prefix:
    mov ax, [ebx+52]
    jmp .segment_prefix
.ss_prefix:
    mov ax, [ebx+64]
    jmp .segment_prefix
.ds_prefix:
    mov ax, [ebx+4]
    jmp .segment_prefix
.fs_prefix:
    mov ax, fs
    jmp .segment_prefix
.gs_prefix:
    mov ax, gs
.segment_prefix:
    mov [ebp+dpmi_step_segment], ax
    jmp .prefix
.opcode:
    cmp byte [ebp+dpmi_sti_shadow], 0
    jne .ordinary_opcode
    test dl, 4
    jz .ordinary_opcode
    cmp al, 0a4h
    je .repeat
    cmp al, 0a5h
    je .repeat
    cmp al, 0aah
    je .repeat
    cmp al, 0abh
    je .repeat
.ordinary_opcode:
    cmp al, 0fh
    je .extended
    cmp al, 17h
    je .pop_ss
    cmp al, 8eh
    je .mov_ss
    cmp al, 0fbh
    je .sti_enable
    cmp al, 9ch
    je .push_flags
    cmp al, 0cfh
    je .iret
    cmp al, 9dh
    jne .simple
    push edi
    call .stack
    jc .bad_stack
    mov edx, [ebx+56]
    cmp ecx, 4
    jne .pop_word
    mov edx, [esi]
    jmp .pop_value
.pop_word:
    mov dx, [esi]
.pop_value:
    cmp byte [ebp+dpmi_sti_shadow], 0
    je .pop_tf_ready
    mov eax, edx
    shr eax, 8
    and al, 1
    mov [ebp+dpmi_sti_tf], al
.pop_tf_ready:
    mov eax, ecx
    call .adjust_stack
    and edx, 0fffc8effh
    test edx, 200h
    jnz .pop_enabled
    call dpmi_clear_vif
    or edx, 200h
    cmp byte [ebp+dpmi_step_active], 0
    je .pop_quiet
    or edx, 100h
.pop_quiet:
    mov [ebx+56], edx
    pop edi
    add [ebx+48], edi
    jmp .next
.pop_enabled:
    mov [ebx+56], edx
    pop edi
    jmp .enable
.sti_enable:
    call dpmi_sti_begin
    jmp .done
.enable:
    mov byte [ebp+dpmi_vif], 1
    mov byte [ebp+dpmi_step_active], 0
    and word [ebx+56], 0feffh
    or word [ebx+56], 200h
    add [ebx+48], edi
    jmp .done
.push_flags:
    push edi
    mov eax, ecx
    neg eax
    call .adjust_stack
    call .write_stack
    jc .bad_push
    mov eax, [ebx+56]
    call dpmi_virtual_flags
    cmp ecx, 4
    jne .push_word
    mov [esi], eax
    jmp .pushed
.push_word:
    mov [esi], ax
.pushed:
    pop edi
    add [ebx+48], edi
    jmp .next
.iret:
    push ecx
    imul ecx, 3
    call .stack
    pop ecx
    jc .done
    cmp ecx, 4
    jne .iret_word
    mov eax, [esi]
    mov edx, [esi+4]
    mov edi, [esi+8]
    call .iret_target
    jc .done
    push eax
    mov eax, 12
    call .adjust_stack
    pop eax
    jmp .iret_frame
.iret_word:
    movzx eax, word [esi]
    movzx edx, word [esi+2]
    movzx edi, word [esi+4]
    call .iret_target
    jc .done
    push eax
    mov eax, 6
    call .adjust_stack
    pop eax
.iret_frame:
    mov [ebx+48], eax
    mov [ebx+52], edx
    mov edx, edi
    cmp byte [ebp+dpmi_sti_shadow], 0
    je .iret_tf_ready
    shr edi, 8
    and edi, 1
    mov eax, edi
    mov [ebp+dpmi_sti_tf], al
.iret_tf_ready:
    and edx, 0fffd8effh
    test edx, 200h
    jnz .iret_enabled
    call dpmi_clear_vif
    or edx, 200h
    cmp byte [ebp+dpmi_step_active], 0
    je .iret_quiet
    or edx, 100h
.iret_quiet:
    mov [ebx+56], edx
    jmp .next
.iret_enabled:
    mov [ebx+56], edx
    xor edi, edi
    jmp .enable
.iret_target:
    push eax
    push edx
    mov edx, eax
    mov ax, [esp]
    call dpmi_code_target
    pop edx
    pop eax
    ret
.mov_ss:
    call .fetch
    jc .done
    mov dl, al
    and dl, 38h
    cmp dl, 10h
    jne .done
    cmp al, 0c0h
    jb .memory_ss
    and eax, 7
    movzx eax, byte [ebp+.register_offsets+eax]
    mov ax, [ebx+eax]
    call .ss_selector
    jc .done
    inc edi
    jmp .loaded_ss
.memory_ss:
    call .effective_address
    jc .done
    push ecx
    push edi
    mov ecx, 2
    xor edi, edi
    call dpmi_buffer
    pop edi
    pop ecx
    jc .done
    mov ax, [eax]
    call .ss_selector
    jc .done
    jmp .loaded_ss
.extended:
    call .fetch
    jc .done
    cmp al, 0b2h
    je .extended_lss
    mov al, 0fh
    jmp .simple
.extended_lss:
    inc edi
    call .effective_address
    jc .done
    push ecx
    push edi
    add ecx, 2
    xor edi, edi
    call dpmi_buffer
    pop edi
    pop ecx
    jc .done
    mov esi, eax
    mov ax, [esi+ecx]
    push esi
    call .ss_selector
    pop esi
    jc .done
    push eax
    movzx edx, byte [ebp+dpmi_step_modrm]
    shr edx, 3
    and edx, 7
    movzx edx, byte [ebp+.register_offsets+edx]
    cmp ecx, 4
    jne .lss_word
    mov eax, [esi]
    mov [ebx+edx], eax
    jmp .lss_loaded
.lss_word:
    mov ax, [esi]
    mov [ebx+edx], ax
.lss_loaded:
    pop eax
    jmp .loaded_ss
.pop_ss:
    push edi
    call .stack
    jc .bad_stack
    mov ax, [esi]
    call .ss_selector
    jc .bad_stack
    push eax
    mov eax, ecx
    call .adjust_stack
    pop eax
    pop edi
.loaded_ss:
    mov [ebx+64], ax
    add [ebx+48], edi
    cmp byte [ebp+dpmi_sti_shadow], 0
    je .next
    mov eax, [ebx+48]
    mov [ebp+dpmi_sti_ip], eax
    jmp .next
.ss_selector:
    push eax
    mov dl, al
    and dl, 3
    cmp dl, 3
    jne .bad_ss
    call dpmi_descriptor
    jc .bad_ss
    mov al, [esi+5]
    and al, 0fah
    cmp al, 0f2h
    jne .bad_ss
    pop eax
    clc
    ret
.bad_ss:
    pop eax
    stc
    ret
.register_offsets:
    db 36,32,28,24,60,16,12,8
.address16_first:
    db 24,24,16,16,12,8,16,24
.address16_second:
    db 12,8,12,8,0ffh,0ffh,0ffh,0ffh
.effective_address:
    push ecx
    mov ax, [ebx+4]
    mov [ebp+dpmi_step_ea_segment], ax
    call .fetch
    jc .ea_bad
    inc edi
    mov [ebp+dpmi_step_modrm], al
    cmp al, 0c0h
    jae .ea_bad
    xor esi, esi
    cmp byte [ebp+dpmi_step_address_size], 4
    je .address32
    and eax, 7
    cmp al, 6
    jne .base16
    test byte [ebp+dpmi_step_modrm], 0c0h
    jz .disp16
.base16:
    movzx edx, byte [ebp+.address16_first+eax]
    movzx esi, word [ebx+edx]
    movzx edx, byte [ebp+.address16_second+eax]
    cmp dl, 0ffh
    je .base16_segment
    movzx edx, word [ebx+edx]
    add esi, edx
.base16_segment:
    cmp al, 2
    je .stack_segment
    cmp al, 3
    je .stack_segment
    cmp al, 6
    je .stack_segment
    jmp .mod_displacement
.address32:
    and eax, 7
    cmp al, 4
    jne .base32
    call .fetch
    jc .ea_bad
    inc edi
    mov edx, eax
    shr edx, 3
    and edx, 7
    cmp dl, 4
    je .base32
    movzx edx, byte [ebp+.register_offsets+edx]
    mov esi, [ebx+edx]
    mov edx, eax
    shr edx, 6
    mov ecx, edx
    shl esi, cl
.base32:
    and eax, 7
    cmp al, 5
    jne .base32_value
    test byte [ebp+dpmi_step_modrm], 0c0h
    jz .disp32
.base32_value:
    movzx edx, byte [ebp+.register_offsets+eax]
    add esi, [ebx+edx]
    cmp al, 4
    je .stack_segment
    cmp al, 5
    jne .mod_displacement
.stack_segment:
    mov dx, [ebx+64]
    mov [ebp+dpmi_step_ea_segment], dx
.mod_displacement:
    mov al, [ebp+dpmi_step_modrm]
    and al, 0c0h
    jz .ea_done
    cmp al, 40h
    je .disp8
    cmp byte [ebp+dpmi_step_address_size], 2
    je .disp16
.disp32:
    mov ecx, 4
    jmp .displacement
.disp16:
    mov ecx, 2
    jmp .displacement
.disp8:
    mov ecx, 1
.displacement:
    call .read_code
    jc .ea_bad
    add edi, ecx
    cmp ecx, 1
    jne .unsigned_displacement
    movsx eax, al
.unsigned_displacement:
    add esi, eax
.ea_done:
    cmp byte [ebp+dpmi_step_address_size], 2
    jne .wide_address
    movzx esi, si
.wide_address:
    mov edx, esi
    mov ax, [ebp+dpmi_step_segment]
    cmp ax, 0ffffh
    jne .ea_selector
    mov ax, [ebp+dpmi_step_ea_segment]
.ea_selector:
    pop ecx
    clc
    ret
.ea_bad:
    pop ecx
    stc
    ret
.fetch:
    push ecx
    mov ecx, 1
    call .read_code
    pop ecx
    ret
.read_code:
    push edx
    push edi
    ; Reuse validated addresses, not instruction bytes.
    lea edx, [edi+ecx]
    cmp edx, 15
    ja .code_bad
    mov eax, [ebp+dpmi_step_code]
    test eax, eax
    jz .code_validate
    mov edx, [ebx+48]
    sub edx, [ebp+dpmi_step_code_ip]
    jc .code_validate
    add edx, edi
    jc .code_validate
    add edx, ecx
    jc .code_validate
    cmp edx, 32
    ja .code_validate
    sub edx, ecx
    add eax, edx
    jmp .code_load
.code_validate:
    mov dword [ebp+dpmi_step_code], 0
    ; Earlier steps can leave a validated window of code.
    cmp byte [ebp+dpmi_window_ready], 0
    je .window_miss
    mov eax, [ebx+48]
    sub eax, [ebp+dpmi_window_start]
    cmp eax, [ebp+dpmi_window_room]
    ja .window_miss
    add eax, [ebp+dpmi_window_linear]
    jmp .code_cached
.window_miss:
    push ecx
    push edi
    mov ax, [ebx+52]
    mov edx, [ebx+48]
    mov ecx, 32
    mov edi, 2
    call dpmi_code_buffer
    pop edi
    pop ecx
    jc .code_uncached
    call dpmi_step_window
.code_cached:
    mov [ebp+dpmi_step_code], eax
    mov edx, [ebx+48]
    mov [ebp+dpmi_step_code_ip], edx
    add eax, edi
    jmp .code_load
.code_uncached:
    mov edx, [ebx+48]
    add edx, edi
    jc .code_bad
    mov ax, [ebx+52]
    mov edi, 2
    call dpmi_code_buffer
    jc .code_bad
.code_load:
    cmp ecx, 4
    je .code_dword
    cmp ecx, 2
    je .code_word
    movzx eax, byte [eax]
    jmp .code_done
.code_word:
    movzx eax, word [eax]
    jmp .code_done
.code_dword:
    mov eax, [eax]
.code_done:
    pop edi
    pop edx
    clc
    ret
.code_bad:
    pop edi
    pop edx
    stc
    ret
.bad_push:
    mov eax, ecx
    call .adjust_stack
.bad_stack:
    pop edi
    jmp .done
.simple:
    cmp word [ebp+dpmi_vif], 0100h
    jne .done
    cmp byte [ebp+dpmi_sti_shadow], 0
    jne .done
    cmp dword [esp+12], 16
    jae .done
    test dl, 6
    jnz .done
    mov edx, [ebp+dpmi_debug_regs+28]
    test dl, 0ffh
    jnz .done
    cmp al, 8dh
    je .simple_lea
    cmp al, 0fh
    je .simple_movzx
    cmp al, 50h
    jb .simple_segment_push
    cmp al, 5fh
    jbe .simple_stack_register
.simple_segment_push:
    cmp al, 06h
    je .simple_push_segment
    cmp al, 0eh
    je .simple_push_segment
    cmp al, 16h
    je .simple_push_segment
    cmp al, 1eh
    je .simple_push_segment
    cmp al, 0f6h
    je .simple_test_byte
    cmp byte [ebp+dpmi_step_address_size], 4
    je .simple_dispatch
    cmp al, 0ebh
    je .simple_jump
    cmp al, 70h
    jb .simple_small_register
    cmp al, 7fh
    jbe .simple_branch
.simple_small_register:
    cmp al, 83h
    je .simple_adjust_immediate
    cmp al, 8bh
    je .simple_nonbranch
    cmp al, 40h
    jb .done
    cmp al, 4fh
    jbe .simple_count_register
    cmp al, 0b0h
    jb .simple_word_register
    cmp al, 0bfh
    jbe .simple_move
    jmp .done
.simple_word_register:
    cmp al, 86h
    jb .done
    cmp al, 8bh
    ja .done
    jmp .simple_move
.simple_dispatch:
    cmp al, 40h
    jb .simple_other
    cmp al, 4fh
    jbe .simple_count_register
.simple_other:
    cmp al, 3dh
    je .simple_compare_accumulator
    cmp al, 81h
    je .simple_compare_immediate
    cmp al, 83h
    je .simple_adjust_immediate
    cmp al, 0ffh
    je .simple_count_operand
    cmp al, 0ebh
    je .simple_jump
    cmp al, 0e4h
    je .simple_io
    cmp al, 0f7h
    je .simple_negate
    cmp al, 0e4h
    ja .simple_io
    cmp al, 70h
    jb .simple_nonbranch
    cmp al, 7fh
    jbe .simple_branch
.simple_nonbranch:
    cmp al, 23h
    je .simple_memory
    cmp al, 3bh
    je .simple_memory
    cmp al, 8bh
    jne .simple_move
    call .fetch
    jc .done
    cmp al, 0c0h
    mov al, 8bh
    jb .simple_memory
.simple_move:
    mov dl, al
    cmp al, 0b0h
    jb .simple_register
    cmp al, 0bfh
    ja .done
    and eax, 7
    test dl, 8
    jnz .simple_immediate_word
    movzx esi, byte [ebp+dpmi_byte_registers+eax]
    mov ecx, 1
    jmp .simple_immediate
.simple_immediate_word:
    cmp eax, 4
    je .done
    movzx esi, byte [ebp+dpmi_full_registers+eax]
.simple_immediate:
    call .read_code
    jc .done
    add edi, ecx
    cmp ecx, 4
    je .simple_store_dword
    cmp ecx, 2
    je .simple_store_word
    mov [ebx+esi], al
    jmp .simple_advance
.simple_push_segment:
    cmp ecx, 2
    jne .done
    mov esi, 0
    cmp al, 06h
    je .simple_push_value
    mov esi, 52
    cmp al, 0eh
    je .simple_push_value
    mov esi, 64
    cmp al, 16h
    je .simple_push_value
    mov esi, 4
    jmp .simple_push_value
.simple_lea:
    call .fetch
    jc .done
    cmp al, 0c0h
    jae .done
    mov esi, eax
    shr esi, 3
    and esi, 7
    movzx esi, byte [ebp+dpmi_full_registers+esi]
    push esi
    call .effective_address
    pop esi
    jc .done
    cmp ecx, 2
    jne .simple_lea_wide
    mov [ebx+esi], dx
    jmp .simple_advance
.simple_lea_wide:
    mov [ebx+esi], edx
    jmp .simple_advance
.simple_movzx:
    call .fetch
    jc .done
    cmp al, 0b6h
    je .simple_movzx_byte
    cmp al, 0b7h
    jne .done
    cmp ecx, 4
    jne .done
    mov esi, 2
    jmp .simple_movzx_width
.simple_movzx_byte:
    mov esi, 1
.simple_movzx_width:
    push ecx
    push esi
    inc edi
    call .fetch
    jc .simple_movzx_bad_width
    mov esi, eax
    shr esi, 3
    and esi, 7
    movzx esi, byte [ebp+dpmi_full_registers+esi]
    push esi
    mov ecx, [esp+4]
    cmp al, 0c0h
    jb .simple_movzx_memory
    and eax, 7
    cmp ecx, 1
    jne .simple_movzx_register_word
    movzx esi, byte [ebp+dpmi_byte_registers+eax]
    jmp .simple_movzx_register
.simple_movzx_register_word:
    movzx esi, byte [ebp+dpmi_full_registers+eax]
.simple_movzx_register:
    lea eax, [ebx+esi]
    inc edi
    jmp .simple_movzx_read
.simple_movzx_memory:
    call .effective_address
    jc .simple_movzx_bad_target
    push edi
    xor edi, edi
    call dpmi_read_buffer
    pop edi
    jc .simple_movzx_bad_target
.simple_movzx_read:
    cmp ecx, 1
    jne .simple_movzx_read_word
    movzx edx, byte [eax]
    jmp .simple_movzx_store
.simple_movzx_read_word:
    movzx edx, word [eax]
.simple_movzx_store:
    pop esi
    add esp, 4
    pop ecx
    cmp ecx, 2
    jne .simple_lea_wide
    mov [ebx+esi], dx
    jmp .simple_advance
.simple_movzx_bad_target:
    add esp, 4
.simple_movzx_bad_width:
    add esp, 8
    jmp .done
.simple_stack_register:
    mov edx, eax
    and eax, 7
    cmp eax, 4
    je .done
    movzx esi, byte [ebp+dpmi_full_registers+eax]
    test dl, 8
    jnz .simple_pop_register
.simple_push_value:
    mov eax, [ebx+esi]
    push edi
    push dword [ebx+60]
    push eax
    mov eax, ecx
    neg eax
    call .adjust_stack
    call .write_stack
    jc .simple_push_bad
    pop eax
    cmp ecx, 2
    jne .simple_push_dword
    mov [esi], ax
    jmp .simple_push_done
.simple_push_dword:
    mov [esi], eax
.simple_push_done:
    add esp, 4
    pop edi
    jmp .simple_advance
.simple_push_bad:
    add esp, 4
    pop dword [ebx+60]
    pop edi
    jmp .done
.simple_pop_register:
    push edi
    push esi
    call .stack
    jc .simple_pop_bad
    cmp ecx, 2
    jne .simple_pop_dword
    movzx edx, word [esi]
    jmp .simple_pop_loaded
.simple_pop_dword:
    mov edx, [esi]
.simple_pop_loaded:
    pop esi
    mov eax, ecx
    call .adjust_stack
    cmp ecx, 2
    jne .simple_pop_store_dword
    mov [ebx+esi], dx
    jmp .simple_pop_done
.simple_pop_store_dword:
    mov [ebx+esi], edx
.simple_pop_done:
    pop edi
    jmp .simple_advance
.simple_pop_bad:
    pop esi
    pop edi
    jmp .done
.simple_test_byte:
    call .fetch
    jc .done
    test al, 38h
    jnz .done
    mov ecx, 1
    cmp al, 0c0h
    jb .simple_test_memory
    and eax, 7
    movzx esi, byte [ebp+dpmi_byte_registers+eax]
    add esi, ebx
    inc edi
    jmp .simple_test_value
.simple_test_memory:
    call .effective_address
    jc .done
    push edi
    xor edi, edi
    call dpmi_read_buffer
    pop edi
    jc .done
    mov esi, eax
.simple_test_value:
    movzx eax, byte [esi]
    push eax
    call .fetch
    pop edx
    jc .done
    inc edi
    test dl, al
    jmp .simple_flags
.simple_store_word:
    mov [ebx+esi], ax
    jmp .simple_advance
.simple_store_dword:
    mov [ebx+esi], eax
    jmp .simple_advance
.simple_register:
    cmp al, 86h
    jb .done
    cmp al, 8bh
    ja .done
    call .fetch
    jc .done
    cmp al, 0c0h
    jb .done
    inc edi
    mov esi, eax
    and eax, 7
    shr esi, 3
    and esi, 7
    test dl, 1
    jnz .simple_full
    mov ecx, 1
    movzx eax, byte [ebp+dpmi_byte_registers+eax]
    movzx esi, byte [ebp+dpmi_byte_registers+esi]
    jmp .simple_direction
.simple_full:
    cmp eax, 4
    jne .simple_source_stack
    cmp dl, 8bh
    jne .done
.simple_source_stack:
    cmp esi, 4
    jne .simple_full_offsets
    cmp dl, 89h
    jne .done
.simple_full_offsets:
    movzx eax, byte [ebp+dpmi_full_registers+eax]
    movzx esi, byte [ebp+dpmi_full_registers+esi]
.simple_direction:
    cmp dl, 88h
    jb .simple_exchange
    test dl, 2
    jz .simple_copy
    xchg eax, esi
.simple_copy:
    cmp ecx, 4
    je .simple_copy_dword
    cmp ecx, 2
    je .simple_copy_word
    mov dl, [ebx+esi]
    mov [ebx+eax], dl
    jmp .simple_advance
.simple_copy_word:
    mov dx, [ebx+esi]
    mov [ebx+eax], dx
    jmp .simple_advance
.simple_copy_dword:
    mov edx, [ebx+esi]
    mov [ebx+eax], edx
    jmp .simple_advance
.simple_exchange:
    cmp ecx, 4
    je .simple_exchange_dword
    cmp ecx, 2
    je .simple_exchange_word
    mov dl, [ebx+esi]
    xchg dl, [ebx+eax]
    mov [ebx+esi], dl
    jmp .simple_advance
.simple_exchange_word:
    mov dx, [ebx+esi]
    xchg dx, [ebx+eax]
    mov [ebx+esi], dx
    jmp .simple_advance
.simple_exchange_dword:
    mov edx, [ebx+esi]
    xchg edx, [ebx+eax]
    mov [ebx+esi], edx
    jmp .simple_advance
.simple_memory:
    push eax
    call .fetch
    jc .simple_memory_bad_opcode
    cmp al, 0c0h
    jae .simple_memory_bad_opcode
    shr eax, 3
    and eax, 7
    cmp eax, 4
    je .simple_memory_bad_opcode
    movzx esi, byte [ebp+dpmi_full_registers+eax]
    push esi
    call .effective_address
    jc .simple_memory_bad_target
    push edi
    xor edi, edi
    call dpmi_read_buffer
    pop edi
    jc .simple_memory_bad_target
    cmp ecx, 2
    jne .simple_memory_dword
    movzx edx, word [eax]
    jmp .simple_memory_loaded
.simple_memory_dword:
    mov edx, [eax]
.simple_memory_loaded:
    pop esi
    pop eax
    cmp al, 8bh
    je .simple_memory_move
    cmp al, 23h
    mov eax, [ebx+esi]
    je .simple_and
    cmp ecx, 2
    jne .simple_compare_dword
    cmp ax, dx
    jmp .simple_flags
.simple_compare_dword:
    cmp eax, edx
    jmp .simple_flags
.simple_and:
    cmp ecx, 2
    jne .simple_and_dword
    and ax, dx
    mov [ebx+esi], ax
    jmp .simple_flags
.simple_and_dword:
    and eax, edx
    mov [ebx+esi], eax
    jmp .simple_flags
.simple_memory_move:
    cmp ecx, 2
    jne .simple_memory_move_dword
    mov [ebx+esi], dx
    jmp .simple_advance
.simple_memory_move_dword:
    mov [ebx+esi], edx
    jmp .simple_advance
.simple_memory_bad_target:
    pop esi
.simple_memory_bad_opcode:
    pop eax
    jmp .done
.simple_negate:
    call .fetch
    jc .done
    cmp al, 0d8h
    jb .done
    cmp al, 0dfh
    ja .done
    and eax, 7
    cmp eax, 4
    je .done
    movzx esi, byte [ebp+dpmi_full_registers+eax]
    inc edi
    mov eax, [ebx+esi]
    cmp ecx, 2
    jne .simple_negate_dword
    neg ax
    mov [ebx+esi], ax
    jmp .simple_flags
.simple_negate_dword:
    neg eax
    mov [ebx+esi], eax
.simple_flags:
    pushfd
    pop edx
    mov ecx, 8d5h
.simple_flag_mask:
    and edx, ecx
    not ecx
    and [ebx+56], ecx
    or [ebx+56], edx
    jmp .simple_advance
.simple_count_register:
    mov edx, eax
    and eax, 7
    cmp eax, 4
    je .done
    movzx esi, byte [ebp+dpmi_full_registers+eax]
    add esi, ebx
    jmp .simple_count
.simple_count_operand:
    call .fetch
    jc .done
    mov edx, eax
    and edx, 38h
    cmp edx, 8
    ja .done
    push edx
    mov edx, 1
    call .simple_operand
    pop edx
    jc .done
.simple_count:
    test dl, 8
    jnz .simple_decrement
    cmp ecx, 2
    jne .simple_increment_dword
    inc word [esi]
    jmp .simple_count_flags
.simple_increment_dword:
    inc dword [esi]
    jmp .simple_count_flags
.simple_decrement:
    cmp ecx, 2
    jne .simple_decrement_dword
    dec word [esi]
    jmp .simple_count_flags
.simple_decrement_dword:
    dec dword [esi]
.simple_count_flags:
    pushfd
    pop edx
    mov ecx, 8d4h
    jmp .simple_flag_mask
.simple_compare_accumulator:
    call .read_code
    jc .done
    add edi, ecx
    lea esi, [ebx+36]
    call dpmi_step_accumulator_loop
    jnc .done
    jmp .simple_compare_flags
.simple_compare_immediate:
    push eax
    call .fetch
    jc .simple_compare_bad
    and al, 38h
    cmp al, 38h
    jne .simple_compare_bad
    xor edx, edx
    call .simple_operand
    jc .simple_compare_bad
    pop eax
    cmp al, 83h
    je .simple_compare_byte
    call .read_code
    jc .done
    add edi, ecx
    jmp .simple_compare_value
.simple_compare_byte:
    call .fetch
    jc .done
    inc edi
    movsx eax, al
.simple_compare_value:
    call dpmi_step_count_loop
    jnc .done
.simple_compare_flags:
    cmp ecx, 2
    jne .simple_compare_immediate_dword
    cmp [esi], ax
    jmp .simple_flags
.simple_compare_immediate_dword:
    cmp [esi], eax
    jmp .simple_flags
.simple_compare_bad:
    pop eax
    jmp .done
.simple_adjust_immediate:
    call .fetch
    jc .done
    cmp al, 0c0h
    jb .simple_adjust_other
    mov edx, eax
    and edx, 38h
    jz .simple_adjust_register
    cmp edx, 28h
    jne .simple_adjust_other
.simple_adjust_register:
    and eax, 7
    movzx esi, byte [ebp+dpmi_full_registers+eax]
    inc edi
    call .fetch
    jc .done
    inc edi
    movsx eax, al
    test edx, edx
    jnz .simple_subtract_register
    cmp ecx, 2
    jne .simple_add_dword
    add [ebx+esi], ax
    jmp .simple_flags
.simple_add_dword:
    add [ebx+esi], eax
    jmp .simple_flags
.simple_subtract_register:
    cmp ecx, 2
    jne .simple_subtract_dword
    sub [ebx+esi], ax
    jmp .simple_flags
.simple_subtract_dword:
    sub [ebx+esi], eax
    jmp .simple_flags
.simple_adjust_other:
    cmp byte [ebp+dpmi_step_address_size], 4
    jne .done
    mov al, 83h
    jmp .simple_compare_immediate
; EDX is zero for a read, one for a write. Return the operand in ESI.
.simple_operand:
    push edx
    call .fetch
    jc .simple_operand_bad
    cmp al, 0c0h
    jb .simple_operand_memory
    and eax, 7
    cmp eax, 4
    je .simple_operand_bad
    movzx esi, byte [ebp+dpmi_full_registers+eax]
    add esi, ebx
    inc edi
    pop edx
    clc
    ret
.simple_operand_memory:
    call .effective_address
    jc .simple_operand_bad
    push edi
    mov edi, [esp+4]
    test edi, edi
    jnz .simple_operand_write
    call dpmi_read_buffer
    jmp .simple_operand_checked
.simple_operand_write:
    call dpmi_buffer
.simple_operand_checked:
    pop edi
    pop edx
    mov esi, eax
    ret
.simple_operand_bad:
    pop edx
    stc
    ret
.simple_jump:
    cmp edi, 1
    jne .done
    call .fetch
    jc .done
    inc edi
    movsx eax, al
    add edi, eax
    jmp .simple_branch_target
.simple_branch:
    cmp edi, 1
    jne .done
    mov esi, eax
    call .fetch
    jc .done
    inc edi
    movsx eax, al
    mov edx, [ebx+56]
    mov ecx, esi
    and ecx, 0eh
    cmp ecx, 0ch
    jae .simple_branch_signed
    shr ecx, 1
    test edx, [ebp+.simple_condition_masks+ecx*4]
    setnz dl
    jmp .simple_branch_decide
.simple_branch_signed:
    mov ecx, edx
    shr ecx, 4
    xor ecx, edx
    and ecx, 80h
    and edx, 40h
    test esi, 2
    jnz .simple_branch_signed_zero
    xor edx, edx
.simple_branch_signed_zero:
    or edx, ecx
    setnz dl
.simple_branch_decide:
    and esi, 1
    xor edx, esi
    test dl, 1
    jz .simple_advance
    add edi, eax
    jmp .simple_branch_target
.simple_condition_masks:
    dd 800h,1,40h,41h,80h,4
.simple_branch_target:
    mov edx, [ebx+48]
    add edx, edi
    cmp byte [ebp+dpmi_window_size], 2
    jne .simple_branch_wide
    movzx edx, dx
.simple_branch_wide:
    mov ax, [ebx+52]
    call dpmi_code_target
    jc .done
    jmp .simple_advance
.simple_io:
    cmp al, 0efh
    ja .done
    cmp al, 0ech
    jae .simple_io_dx
    cmp al, 0e7h
    ja .done
    push eax
    call .fetch
    movzx edx, al
    pop eax
    jc .done
    inc edi
    jmp .simple_io_width
.simple_io_dx:
    movzx edx, word [ebx+28]
.simple_io_width:
    test al, 1
    jnz .simple_io_direction
    mov cl, 1
.simple_io_direction:
    test al, 2
    setnz ch
    bt [ebp+mon_bitmap], edx
    jnc .done
    mov eax, [ebx+36]
    push ebx
    push ecx
    push edi
    call dpmi_pic_io
    pop edi
    pop ecx
    pop ebx
    jc .done
    test ch, ch
    jnz .simple_io_advance
    cmp cl, 1
    jne .simple_io_word
    mov [ebx+36], al
    jmp .simple_io_advance
.simple_io_word:
    cmp cl, 2
    jne .simple_io_dword
    mov [ebx+36], ax
    jmp .simple_io_advance
.simple_io_dword:
    mov [ebx+36], eax
.simple_io_advance:
    add [ebx+48], edi
    inc dword [esp+12]
    jmp .next
.simple_advance:
    add [ebx+48], edi
    cmp byte [ebp+dpmi_window_size], 2
    jne .simple_advanced
    and dword [ebx+48], 0ffffh
.simple_advanced:
    inc dword [esp+12]
    jmp .next
.done:
    popad
    ret
.repeat:
    test byte [ebp+dpmi_debug_regs+28], 0ffh
    jnz .done
    cmp dword [esp+12], 0
    jne .done
    sub esp, 48
    mov [esp], eax
    test al, 1
    jnz .repeat_width
    mov ecx, 1
.repeat_width:
    mov [esp+4], ecx
    mov [esp+8], edi
    mov eax, [ebx+32]
    mov edx, [ebx+8]
    mov esi, [ebx+12]
    cmp byte [ebp+dpmi_step_address_size], 2
    jne .repeat_count
    movzx eax, ax
    movzx edx, dx
    movzx esi, si
.repeat_count:
    mov [esp+16], eax
    mov [esp+20], esi
    mov [esp+24], edx
    test eax, eax
    jz .repeat_complete
    cmp eax, 64
    jbe .repeat_bound
    mov eax, 64
.repeat_bound:
    mov [esp+12], eax
    cmp byte [ebp+dpmi_step_address_size], 2
    jne .repeat_validate
    mov edi, 24
.repeat_wrap:
    mov eax, [esp+edi]
    test word [ebx+56], 400h
    jnz .repeat_capacity
    xor eax, 0ffffh
.repeat_capacity:
    xor edx, edx
    div dword [esp+4]
    inc eax
    cmp eax, [esp+12]
    jae .repeat_wrap_next
    mov [esp+12], eax
.repeat_wrap_next:
    cmp edi, 20
    je .repeat_validate
    cmp byte [esp], 0aah
    jae .repeat_validate
    mov edi, 20
    jmp .repeat_wrap
.repeat_validate:
    mov ecx, [esp+12]
    imul ecx, [esp+4]
    mov [esp+36], ecx
    mov esi, ecx
    sub esi, [esp+4]
    mov [esp+40], esi
    mov edx, [esp+24]
    test word [ebx+56], 400h
    jz .repeat_destination
    sub edx, esi
    jc .repeat_done
.repeat_destination:
    mov ax, [ebx]
    mov edi, 1
    call dpmi_buffer
    jc .repeat_done
    test word [ebx+56], 400h
    jz .repeat_destination_ready
    add eax, [esp+40]
.repeat_destination_ready:
    mov [esp+32], eax
    cmp byte [esp], 0aah
    jae .repeat_copy
    mov edx, [esp+20]
    test word [ebx+56], 400h
    jz .repeat_source
    sub edx, [esp+40]
    jc .repeat_done
.repeat_source:
    mov ax, [ebp+dpmi_step_segment]
    cmp ax, 0ffffh
    jne .repeat_source_selector
    mov ax, [ebx+4]
.repeat_source_selector:
    xor edi, edi
    call dpmi_buffer
    jc .repeat_done
    test word [ebx+56], 400h
    jz .repeat_source_ready
    add eax, [esp+40]
.repeat_source_ready:
    mov [esp+28], eax
.repeat_copy:
    mov esi, [esp+28]
    mov edi, [esp+32]
    mov ecx, [esp+12]
    cld
    test word [ebx+56], 400h
    jz .repeat_direction
    std
.repeat_direction:
    cmp byte [esp], 0aah
    jae .repeat_store
    cmp dword [esp+4], 1
    je .repeat_move_byte
    cmp dword [esp+4], 2
    je .repeat_move_word
    rep movsd
    jmp .repeat_advance
.repeat_move_byte:
    rep movsb
    jmp .repeat_advance
.repeat_move_word:
    rep movsw
    jmp .repeat_advance
.repeat_store:
    mov eax, [ebx+36]
    cmp dword [esp+4], 1
    je .repeat_store_byte
    cmp dword [esp+4], 2
    je .repeat_store_word
    rep stosd
    jmp .repeat_advance
.repeat_store_byte:
    rep stosb
    jmp .repeat_advance
.repeat_store_word:
    rep stosw
.repeat_advance:
    cld
    mov dword [esp+60], 1
    mov eax, [esp+36]
    test word [ebx+56], 400h
    jz .repeat_delta
    neg eax
.repeat_delta:
    mov edx, [esp+16]
    sub edx, [esp+12]
    cmp byte [ebp+dpmi_step_address_size], 2
    je .repeat_advance16
    mov [ebx+32], edx
    add [ebx+8], eax
    cmp byte [esp], 0aah
    jae .repeat_remaining
    add [ebx+12], eax
    jmp .repeat_remaining
.repeat_advance16:
    mov [ebx+32], dx
    add [ebx+8], ax
    cmp byte [esp], 0aah
    jae .repeat_remaining
    add [ebx+12], ax
.repeat_remaining:
    test edx, edx
    jnz .repeat_done
.repeat_complete:
    mov eax, [esp+8]
    add [ebx+48], eax
    mov dword [esp+60], 1
    add esp, 48
    jmp .next
.repeat_done:
    add esp, 48
    jmp .done
.stack:
    push dword 0
    jmp .stack_access
.write_stack:
    push dword 1
.stack_access:
    mov ax, [ebx+64]
    call dpmi_descriptor
    jc .return
    mov edx, [ebx+60]
    test byte [esi+6], 40h
    jnz .stack_size
    movzx edx, dx
.stack_size:
    mov ax, [ebx+64]
    mov edi, [esp]
    call dpmi_buffer
    jc .return
    mov esi, eax
.return:
    lea esp, [esp+4]
    ret
.adjust_stack:
    pushad
    mov ecx, eax
    mov ax, [ebx+64]
    call dpmi_descriptor
    jc .adjust_done
    test byte [esi+6], 40h
    jnz .adjust_wide
    add word [ebx+60], cx
    jmp .adjust_done
.adjust_wide:
    add [ebx+60], ecx
.adjust_done:
    popad
    ret

; INC EAX, CMP AX/EAX, immediate, and a backward JL/JB/JNE. Limit to 64 trips.
dpmi_step_accumulator_loop:
    pushad
    sub esp, 8
    mov [esp+4], edi
    mov ax, [ebx+52]
    mov edx, [ebx+48]
    test edx, edx
    jz .bad
    dec edx
    mov ecx, 8
    mov edi, 2
    call dpmi_code_buffer
    jc .bad
    mov esi, eax
    and eax, 4095
    cmp eax, 4096-8
    ja .bad
    cmp byte [esi], 40h
    jne .bad
    mov edi, [esp+4]
    cmp dword [esp+8+24], 2
    jne .dword_code
    cmp edi, 4
    jne .bad
    cmp word [esi+1], 3d66h
    jne .bad
    jmp .branch
.dword_code:
    cmp edi, 5
    jne .bad
    cmp byte [esi+1], 3dh
    jne .bad
.branch:
    movzx eax, byte [esi+edi+1]
    cmp al, 72h
    je .condition
    cmp al, 7ch
    je .condition
    cmp al, 75h
    jne .bad
.condition:
    mov [esp], eax
    movsx eax, byte [esi+edi+2]
    lea eax, [eax+edi+3]
    test eax, eax
    jnz .bad
    mov esi, [esp+8+4]
    mov edi, [esp+8+28]
    mov ecx, 64
.loop:
    cmp dword [esp+8+24], 2
    jne .dword
    cmp [esi], di
    jmp .flags
.dword:
    cmp [esi], edi
.flags:
    pushfd
    pop edx
    cmp byte [esp], 72h
    je .below
    cmp byte [esp], 75h
    je .unequal
    mov eax, edx
    shr eax, 4
    xor eax, edx
    test al, 80h
    jnz .body
    jmp .exit
.below:
    test dl, 1
    jnz .body
    jmp .exit
.unequal:
    test dl, 40h
    jnz .exit
.body:
    bt edx, 0
    inc dword [esi]
    pushfd
    pop edx
    dec ecx
    jnz .loop
    jmp .complete
.exit:
    mov eax, [esp+4]
    add eax, 2
    add [ebx+48], eax
.complete:
    and edx, 8d5h
    and dword [ebx+56], ~8d5h
    or [ebx+56], edx
    add esp, 8
    popad
    clc
    ret
.bad:
    add esp, 8
    popad
    stc
    ret

; ESI=operand, EAX=immediate, ECX=width, EDI=compare length. CF on fallback.
; Run at most 64 stack-counter iterations after validating code and memory.
dpmi_step_count_loop:
    pushad
    sub esp, 24
    mov [esp+16], edi
    mov dword [esp+12], 0
    mov ax, [ebx+52]
    mov edx, [ebx+48]
    mov ecx, 64
    mov edi, 2
    call dpmi_code_buffer
    jc .bad
    mov esi, eax
    and eax, 4095
    cmp eax, 4096-64
    ja .bad
    mov [esp], esi
    xor edi, edi
    cmp byte [esi], 66h
    jne .prefix
    inc edi
.prefix:
    mov al, [esi+edi]
    cmp al, 81h
    je .operand
    cmp al, 83h
    jne .bad
.operand:
    cmp byte [esi+edi+1], 7dh
    jne .bad
    movsx edx, byte [esi+edi+2]
    mov [esp+20], dl
    add edx, [ebx+16]
    mov ax, [ebx+64]
    mov ecx, 4
    mov edi, 1
    call dpmi_buffer
    jc .bad
    cmp eax, [esp+24+4]
    jne .bad
    mov [esp+4], eax
    mov edx, eax
    and edx, 4095
    cmp edx, 4096-4
    ja .bad
    ; A writable alias of the code must use the ordinary decoder.
    shr eax, 12
    mov eax, [0ffc00000h+eax*4]
    mov edx, esi
    shr edx, 12
    xor eax, [0ffc00000h+edx*4]
    and eax, 0fffff000h
    jnz .separate
    mov eax, [esp+4]
    and eax, 4095
    mov edx, esi
    and edx, 4095
    sub eax, edx
    cmp eax, 64
    jb .bad
    cmp eax, -3
    jae .bad
.separate:
    mov edi, [esp+16]
    movzx eax, byte [esi+edi]
    cmp al, 72h
    je .condition
    cmp al, 7ch
    je .condition
    cmp al, 75h
    jne .bad
.condition:
    mov [esp+8], eax
    movsx eax, byte [esi+edi+1]
    lea edi, [edi+eax+2]
    call .jumps
    jc .bad
    cmp byte [esi+edi], 8bh
    jne .increment
    movzx eax, byte [esi+edi+1]
    mov edx, eax
    and dl, 0c7h
    cmp dl, 45h
    jne .bad
    mov dl, [esi+edi+2]
    cmp dl, [esp+20]
    jne .bad
    shr eax, 3
    and eax, 7
    cmp eax, 4
    je .bad
    cmp eax, 5
    je .bad
    movzx eax, byte [ebp+dpmi_full_registers+eax]
    add eax, ebx
    mov [esp+12], eax
    add edi, 3
    cmp edi, 61
    ja .bad
.increment:
    cmp word [esi+edi], 45ffh
    jne .bad
    mov al, [esi+edi+2]
    cmp al, [esp+20]
    jne .bad
    add edi, 3
    call .jumps
    jc .bad
    test edi, edi
    jnz .bad
    mov esi, [esp+4]
    mov edi, [esp+24+28]
    mov ecx, 64
.loop:
    cmp dword [esp+24+24], 2
    jne .dword
    cmp [esi], di
    jmp .flags
.dword:
    cmp [esi], edi
.flags:
    pushfd
    pop edx
    cmp byte [esp+8], 72h
    je .below
    cmp byte [esp+8], 75h
    je .unequal
    mov eax, edx
    shr eax, 4
    xor eax, edx
    test al, 80h
    jnz .body
    jmp .exit
.below:
    test dl, 1
    jnz .body
    jmp .exit
.unequal:
    test dl, 40h
    jnz .exit
.body:
    mov eax, [esp+12]
    test eax, eax
    jz .count
    push edx
    mov edx, [esi]
    mov [eax], edx
    pop edx
.count:
    bt edx, 0
    inc dword [esi]
    pushfd
    pop edx
    dec ecx
    jnz .loop
    jmp .complete
.exit:
    mov eax, [esp+16]
    add eax, 2
    add [ebx+48], eax
.complete:
    and edx, 8d5h
    and dword [ebx+56], ~8d5h
    or [ebx+56], edx
    add esp, 24
    popad
    clc
    ret
.bad:
    add esp, 24
    popad
    stc
    ret
.jumps:
    mov ecx, 3
.jump:
    cmp edi, 61
    ja .jump_bad
    cmp byte [esi+edi], 0ebh
    jne .jump_done
    movsx eax, byte [esi+edi+1]
    lea edi, [edi+eax+2]
    dec ecx
    jnz .jump
.jump_bad:
    stc
    ret
.jump_done:
    clc
    ret

; AX=code selector. Return ECX=4 or 2 for the code size, or CF. The
; window of validated code stays while the selector, its descriptor and the
; page tables do not change.
dpmi_step_code_size:
    push edx
    cmp ax, [ebp+dpmi_window_cs]
    jne .lookup
    mov edx, [ebp+dpmi_page_generation]
    cmp edx, [ebp+dpmi_window_generation]
    jne .lookup
    mov esi, [ebp+dpmi_window_descriptor]
    mov edx, [esi]
    cmp edx, [ebp+dpmi_window_bytes]
    jne .lookup
    mov edx, [esi+4]
    cmp edx, [ebp+dpmi_window_bytes+4]
    jne .lookup
    movzx ecx, byte [ebp+dpmi_window_size]
    pop edx
    clc
    ret
.lookup:
    mov byte [ebp+dpmi_window_ready], 0
    mov word [ebp+dpmi_window_cs], 0
    push eax
    call dpmi_descriptor
    pop eax
    jc .bad
    mov [ebp+dpmi_window_cs], ax
    mov [ebp+dpmi_window_descriptor], esi
    mov edx, [esi]
    mov [ebp+dpmi_window_bytes], edx
    mov edx, [esi+4]
    mov [ebp+dpmi_window_bytes+4], edx
    mov edx, [ebp+dpmi_page_generation]
    mov [ebp+dpmi_window_generation], edx
    mov ecx, 4
    test byte [esi+6], 40h
    jnz .size
    mov ecx, 2
.size:
    mov [ebp+dpmi_window_size], cl
    pop edx
    clc
    ret
.bad:
    pop edx
    stc
    ret

; EAX=linear address of the 32 validated bytes at the client EIP. Try to
; validate up to the end of the next page. Keep all registers.
dpmi_step_window:
    pushad
    mov byte [ebp+dpmi_window_ready], 0
    mov edx, [ebx+48]
    mov ecx, eax
    and ecx, 4095
    neg ecx
    add ecx, 8192
    ; Do not pass the segment limit.
    movzx esi, word [ebp+dpmi_window_bytes]
    movzx eax, byte [ebp+dpmi_window_bytes+6]
    and eax, 0fh
    shl eax, 16
    or esi, eax
    test byte [ebp+dpmi_window_bytes+6], 80h
    jz .limit
    shl esi, 12
    or esi, 0fffh
.limit:
    sub esi, edx
    jb .done
    inc esi
    jz .length
    cmp ecx, esi
    jbe .length
    mov ecx, esi
.length:
    cmp ecx, 32
    jb .done
    mov ax, [ebx+52]
    mov edi, 2
    call dpmi_code_buffer
    jnc .ready
    ; The next page can be absent. Try the current page only.
    mov ecx, [esp+28]
    and ecx, 4095
    neg ecx
    add ecx, 4096
    cmp ecx, 32
    jb .done
    mov ax, [ebx+52]
    call dpmi_code_buffer
    jc .done
.ready:
    mov [ebp+dpmi_window_linear], eax
    mov [ebp+dpmi_window_start], edx
    sub ecx, 32
    mov [ebp+dpmi_window_room], ecx
    mov byte [ebp+dpmi_window_ready], 1
.done:
    popad
    ret

; EBX=frame of a CLI, CX=mask. When a PUSHF just before the CLI put the flags
; on the stack, or PUSHF and POP reg did, AND that image with CX. With IF off,
; PUSHF pushed the physical IF: clear IF. With IF on after an NT leak, the image
; was pushed with IF on: clear NT.
dpmi_quiet_image:
    pushad
    mov ax, [ebx+52]
    mov edx, [ebx+48]
    sub edx, 2
    jc .done
    mov ecx, 2
    mov edi, 2
    call dpmi_code_buffer
    jc .done
    cmp byte [eax+1], 9ch
    je .stack
    cmp byte [eax], 9ch
    jne .done
    movzx eax, byte [eax+1]
    sub al, 58h
    cmp al, 7
    ja .done
    cmp al, 4
    je .done
    movzx eax, byte [ebp+dpmi_full_registers+eax]
    add eax, ebx
    jmp .image
.stack:
    mov ax, [ebx+64]
    call dpmi_descriptor
    jc .done
    mov edx, [ebx+60]
    test byte [esi+6], 40h
    jnz .wide
    movzx edx, dx
.wide:
    mov ax, [ebx+64]
    mov ecx, 2
    mov edi, 1
    call dpmi_buffer
    jc .done
.image:
    ; The frame has no NT here; the image has the physical NT.
    mov cx, [eax]
    xor cx, [ebx+56]
    test cx, 0bfffh
    jnz .done
    mov ecx, [esp+24]
    and [eax], cx
.done:
    popad
    ret

; EBX=frame. CF when a ring-3 frame has TF outside stepping and the STI
; shadow. Stepping that a handler stopped can leave this TF. 0.9.4 treated it
; as IF on, and without that Settlers II loads about 7 s slower.
dpmi_tf_loaded:
    test byte [ebx+57], 1
    jz .no
    test byte [ebx+52], 3
    jz .no
    cmp byte [ebp+dpmi_step_active], 0
    jne .no
    cmp byte [ebp+dpmi_sti_shadow], 0
    jne .no
    stc
    ret
.no:
    clc
    ret

; EBX=frame of a host service entry (ES, DS, PUSHAD, EIP, CS, EFLAGS).
dpmi_tf_entry:
    push ebx
    sub ebx, 8
    call dpmi_tf_loaded
    jnc .done
    call dpmi_tf_fired
.done:
    pop ebx
    ret

; EBX=frame from dpmi_tf_loaded. Clear TF and turn the virtual IF on.
dpmi_tf_fired:
    and word [ebx+56], 0feffh
    mov byte [ebp+dpmi_vif], 1
    ret

; CF when a handler runs: a bridged IRQ, a locked IRQ handler, an exception
; handler or a real-mode callback.
dpmi_top_level:
    cmp dword [ebp+dpmi_locked_depth], 0
    jne .nested
    cmp dword [ebp+dpmi_bridge_depth], 0
    jne .nested
    cmp byte [ebp+dpmi_exception_active], 0
    jne .nested
    cmp byte [ebp+dpmi_callback_active], 0
    jne .nested
    clc
    ret
.nested:
    stc
    ret

; EAX holds physical flags on entry and client flags on return. NT marks an
; image with the virtual IF off: see dpmi_quiet_entry.
dpmi_virtual_flags:
    and eax, 0ffffbdffh
    cmp byte [ebp+dpmi_vif], 0
    je .disabled
    or eax, 200h
    jmp .trace
.disabled:
    or eax, 4000h
.trace:
    cmp byte [ebp+dpmi_sti_shadow], 0
    je .ordinary_tf
    and eax, 0fffffeffh
    cmp byte [ebp+dpmi_sti_tf], 0
    je .done
    or eax, 100h
    ret
.ordinary_tf:
    cmp byte [ebp+dpmi_step_active], 0
    je .done
    and eax, 0fffffeffh
.done:
    ret

; EAX holds client flags. Keep physical IRQ delivery enabled.
dpmi_restore_flags:
    mov word [ebp+dpmi_vif], 1
    test eax, 200h
    jnz .done
    call dpmi_clear_vif
.done:
    and eax, 0fffd8fffh
    or eax, 202h
    ret

; Clear the virtual IF. A handler does not step: the host sees its return.
dpmi_clear_vif:
    mov byte [ebp+dpmi_vif], 0
    cmp dword [ebp+dpmi_locked_depth], 0
    jne .handler
    cmp byte [ebp+dpmi_exception_active], 0
    jne .handler
    cmp byte [ebp+dpmi_callback_active], 0
    je .done
.handler:
    mov byte [ebp+dpmi_step_active], 0
.done:
    ret

; A top-level client with the virtual IF off and no stepping runs with NT. IRET
; then faults (dpmi_task_return), and PUSHF marks its image with NT. A POPF or
; IRET that loads an image without NT clears NT: the next host entry turns the
; virtual IF on. dpmi_virtual_flags marks host images the same way.

; EBX is a five-dword protected frame minus 40 bytes, at entry from the client.
dpmi_quiet_entry:
    mov byte [ebp+dpmi_quiet_nt], 0
    test byte [ebx+44], 3
    jz .done
    test byte [ebx+50], 2
    jnz .done
    test byte [ebx+49], 40h
    jz .clear
    and byte [ebx+49], 0bfh
    mov byte [ebp+dpmi_quiet_nt], 1
    ; With IF on, code loaded an image pushed with IF off.
    cmp byte [ebp+dpmi_quiet], 2
    jne .done
    mov byte [ebp+dpmi_quiet_leak], 1
    jmp .done
.clear:
    cmp byte [ebp+dpmi_quiet], 1
    jne .done
    cmp word [ebp+dpmi_vif], 0
    jne .done
    mov byte [ebp+dpmi_vif], 1
.done:
    ret

; EBX is a five-dword protected frame minus 40 bytes, at return to the client.
dpmi_quiet_exit:
    test byte [ebx+44], 3
    jz .done
    test byte [ebx+50], 2
    jnz .done
    and byte [ebx+49], 0bfh
    mov byte [ebp+dpmi_quiet], 0
    call dpmi_top_level
    jc .done
    mov byte [ebp+dpmi_quiet], 2
    cmp word [ebp+dpmi_vif], 0
    jne .done
    mov byte [ebp+dpmi_quiet], 1
    or byte [ebx+49], 40h
.done:
    ret

; EBX=frame of an exception. CF when it is not an IRET that faulted on NT. With
; the virtual IF off, the decoder runs the IRET. Otherwise the code loaded an
; image with NT: clear NT in the image that the IRET loads. The host then runs
; the IRET without NT, and the IRET does not change the virtual IF. Another
; #TS on NT is stepped once without NT.
dpmi_task_return:
    cmp byte [ebp+dpmi_quiet_nt], 0
    je .no
    cmp dword [ebx+40], 10
    je .vector
    cmp dword [ebx+40], 13
    jne .no
.vector:
    pushad
    mov esi, [ebx+48]
.prefix:
    mov ax, [ebx+52]
    mov edx, esi
    mov ecx, 1
    mov edi, 2
    call dpmi_code_buffer
    jc .bad
    cmp byte [eax], 66h
    jne .opcode
    inc esi
    mov eax, esi
    sub eax, [ebx+48]
    cmp eax, 2
    ja .bad
    jmp .prefix
.opcode:
    cmp byte [eax], 0cfh
    jne .bad
    cmp word [ebp+dpmi_vif], 0
    jne .image
    mov esi, [ebx+48]
    mov di, [ebx+52]
    call dpmi_step_check
    cmp esi, [ebx+48]
    jne .handled
    cmp di, [ebx+52]
    jne .handled
    ; The decoder rejected it.
.step:
    mov byte [ebp+dpmi_step_active], 1
    or byte [ebx+57], 1
    jmp .handled
.image:
    xor edx, edx
    cmp esi, [ebx+48]
    je .size
    mov edx, 6
.size:
    mov ax, [ebx+52]
    call dpmi_step_code_size
    jc .handled
    xor ecx, edx
    mov ax, [ebx+64]
    call dpmi_descriptor
    jc .handled
    mov edx, [ebx+60]
    test byte [esi+6], 40h
    jnz .wide
    movzx edx, dx
.wide:
    lea edx, [edx+ecx*2]
    mov ax, [ebx+64]
    mov ecx, 2
    mov edi, 1
    call dpmi_buffer
    jc .handled
    and byte [eax+1], 0bfh
.handled:
    popad
    clc
    ret
.bad:
    cmp dword [ebx+40], 10
    je .step
    popad
.no:
    stc
    ret

HOST_REAL
dpmi_vif db 1
dpmi_step_active db 0
HOST_PROTECTED
dpmi_quiet db 0
dpmi_quiet_nt db 0
dpmi_quiet_leak db 0
dpmi_step_address_size db 0
dpmi_step_segment dw 0
dpmi_step_ea_segment dw 0
dpmi_step_modrm db 0
dpmi_step_code dd 0
dpmi_step_code_ip dd 0
dpmi_page_generation dd 0
dpmi_window_generation dd 0
dpmi_window_descriptor dd 0
dpmi_window_bytes dd 0, 0
dpmi_window_start dd 0
dpmi_window_room dd 0
dpmi_window_linear dd 0
dpmi_window_cs dw 0
dpmi_window_size db 0
dpmi_window_ready db 0

HOST_PROTECTED
; EBX is a normalized frame; EDI is the decoded STI length.
dpmi_sti_begin:
    cmp byte [ebp+dpmi_vif], 0
    jne .enabled
    mov eax, [ebx+56]
    call dpmi_virtual_flags
    shr eax, 8
    and al, 1
    mov [ebp+dpmi_sti_tf], al
    mov ax, [ebx+52]
    mov [ebp+dpmi_sti_cs], ax
    mov eax, [ebx+48]
    add eax, edi
    mov [ebp+dpmi_sti_ip], eax
    mov byte [ebp+dpmi_sti_shadow], 1
.enabled:
    mov byte [ebp+dpmi_vif], 1
    mov byte [ebp+dpmi_step_active], 0
    or word [ebx+56], 200h
    add [ebx+48], edi
    ret

; EBX is the common five-dword return frame minus40 bytes.
dpmi_sti_arrival:
    cmp byte [ebp+dpmi_sti_shadow], 0
    je .done
    test byte [ebx+44], 3
    jz .done
    mov eax, [ebx+40]
    cmp eax, [ebp+dpmi_sti_ip]
    jne dpmi_sti_retire
    mov ax, [ebx+44]
    cmp ax, [ebp+dpmi_sti_cs]
    jne dpmi_sti_retire
.done:
    ret

dpmi_sti_retire:
    mov byte [ebp+dpmi_sti_shadow], 0
    cmp byte [ebp+dpmi_step_active], 0
    jne .done
    and word [ebx+48], 0feffh
    cmp byte [ebp+dpmi_sti_tf], 0
    je .done
    or word [ebx+48], 100h
.done:
    ret
%ifndef RESIDENT_HOST
HOST_REAL
dpmi_sti_shadow db 0
dpmi_sti_tf db 0
dpmi_sti_cs dw 0
dpmi_sti_ip dd 0
HOST_PROTECTED
%endif

HOST_PROTECTED
dpmi_full_registers db 36,32,28,24,60,16,12,8
dpmi_byte_registers db 36,32,28,24,37,33,29,25
HOST_REAL
