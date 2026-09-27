; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; uCDD drives, MSCDEX requests, and the play logic.

; Find the CD drives. CF when there is none.
find_units:
    xor bx, bx
    mov ax, 1500h
    int 2fh
    test bx, bx
    jz .none
    cmp bx, 26
    ja .none
    mov [drive_count], bx
    push ds
    pop es
    mov bx, device_list
    mov ax, 1501h
    int 2fh
    mov bx, drive_list
    mov ax, 150dh
    int 2fh
    xor si, si
.device:
    cmp si, [drive_count]
    jae .done
    imul di, si, 5
    mov dl, [device_list+di]
    les di, [device_list+di+1]
    xor eax, eax
    cmp dword [es:di+10], 'UCDD'
    jne .add
    cmp dword [es:di+14], '0001'
    jne .add
    cmp dword [es:di+22], 'uCDD'
    jne .add
    cmp word [es:di+26], 2
    jne .add
    mov eax, [es:di+28]
    cmp dword [audio_control_entry], 0
    jne .add
    mov [audio_control_entry], eax
    mov [audio_subunit], dl
    mov bl, [unit_total]
    mov [default_unit], bl
.add:
    movzx bx, byte [unit_total]
    push bx
    shl bx, 2
    mov [unit_controls+bx], eax
    pop bx
    mov al, [drive_list+si]
    mov [unit_letters+bx], al
    mov [unit_subunits+bx], dl
    inc byte [unit_total]
.next:
    inc si
    jmp .device
.done:
    cmp byte [unit_total], 0
    je .none
    clc
    ret
.none:
    stc
    ret

; AL = unit index.
select_unit:
    mov [unit], al
    movzx bx, al
    mov al, [unit_letters+bx]
    mov [drive_letter], al
    mov al, [unit_subunits+bx]
    mov [subunit], al
    shl bx, 2
    mov eax, [unit_controls+bx]
    mov [control_entry], eax
    mov byte [physical_source], 0
    test eax, eax
    jnz .done
    mov byte [physical_source], 1
.done:
    ret

; AX = operation, DS:DX = data. Return AX from the driver.
call_control:
    cmp dword [control_entry], 0
    je audio_control.none
    push bx
    mov bl, [subunit]
    call far [control_entry]
    pop bx
    ret

audio_control:
    cmp dword [audio_control_entry], 0
    je .none
    push bx
    mov bl, [audio_subunit]
    call far [audio_control_entry]
    pop bx
    ret
.none:
    mov ax, 8001h
    ret

; AL = command, CL = request length.
new_request:
    push ax
    push cx
    push di
    push es
    push ds
    pop es
    mov di, request
    push ax
    xor ax, ax
    mov cx, 13
    rep stosw
    pop ax
    pop es
    pop di
    pop cx
    mov [request], cl
    mov [request+2], al
    pop ax
    ret

; Return AX = request status. CF on error.
send_request:
    push bx
    push cx
    push es
    push ds
    pop es
    mov bx, request
    movzx cx, byte [drive_letter]
    mov ax, 1510h
    int 2fh
    mov ax, [request+3]
    pop es
    pop cx
    pop bx
    test ah, 80h
    jz .ok
    stc
    ret
.ok:
    clc
    ret

; AL = IOCTL code, CX = control block length.
ioctl_input:
    mov ah, 3
    jmp ioctl_request
ioctl_output:
    mov ah, 0ch
ioctl_request:
    mov [control_block], al
    push cx
    mov al, ah
    mov cl, 26
    call new_request
    pop cx
    mov word [request+14], control_block
    mov [request+16], ds
    mov [request+18], cx
    jmp send_request

; Red Book address at DS:SI (frame, second, minute). Return EAX = HSG sector.
redbook_sector:
    movzx eax, byte [si+2]
    imul eax, 60
    movzx edx, byte [si+1]
    add eax, edx
    imul eax, 75
    movzx edx, byte [si]
    add eax, edx
    sub eax, 150
    jnc .done
    xor eax, eax
.done:
    ret

; Read the track table of the selected drive.
read_disc:
    mov byte [disc_present], 0
    mov byte [audio_count], 0
    mov byte [first_audio], 0
    mov byte [play_state], STOPPED
    mov dword [relative], 0
    cmp byte [physical_source], 0
    jne .toc
    mov dx, disc_info
    mov ax, 3
    call call_control
    test ax, ax
    jnz .done
.toc:
    mov al, 10
    mov cx, 7
    call ioctl_input
    jc .done
    mov al, [control_block+1]
    test al, al
    jz .done
    mov [first_track], al
    mov al, [control_block+2]
    mov [last_track], al
    cmp al, MAX_TRACKS
    ja .done
    cmp al, [first_track]
    jb .done
    mov si, control_block+3
    call redbook_sector
    mov [leadout], eax
    movzx bx, byte [last_track]
    inc bx
    shl bx, 2
    mov [track_start+bx], eax
    mov [track_index0+bx], eax
    mov cl, [first_track]
.track:
    mov [control_block+1], cl
    push cx
    mov al, 11
    mov cx, 7
    call ioctl_input
    pop cx
    jc .done
    mov si, control_block+2
    call redbook_sector
    cmp eax, [leadout]
    jae .done
    movzx bx, cl
    cmp cl, [first_track]
    je .start_ready
    mov si, bx
    dec si
    shl si, 2
    cmp eax, [track_start+si]
    jbe .done
.start_ready:
    mov byte [track_data+bx], 1
    mov dl, [control_block+6]
    and dl, 10h
    mov [track_pre+bx], dl
    test byte [control_block+6], 40h
    jnz .type_ready
    mov byte [track_data+bx], 0
    inc byte [audio_count]
    cmp byte [first_audio], 0
    jne .type_ready
    mov [first_audio], cl
.type_ready:
    shl bx, 2
    mov [track_start+bx], eax
    mov [track_index0+bx], eax
    ; The driver table gives INDEX 00 for gaps before tracks.
    cmp byte [physical_source], 0
    jne .index_ready
    movzx di, cl
    dec di
    imul di, TRACK_SIZE
    mov edx, [disc_info+INFO_TRACKS+di+TRACK_INDEX0]
    sub edx, [disc_info+INFO_ORIGIN]
    jc .index_ready
    cmp edx, eax
    ja .index_ready
    mov [track_index0+bx], edx
.index_ready:
    inc cl
    cmp cl, [last_track]
    jbe .track
    mov byte [disc_present], 1
    mov al, [first_audio]
    test al, al
    jnz .selected
    mov al, [first_track]
.selected:
    mov [track], al
    call build_order
.done:
    ret

; Check the drive for a changed or removed image. Return CF when it changed.
disc_changed:
    cmp byte [physical_source], 0
    jne physical_changed
    mov dx, probe_info
    mov ax, 3
    call call_control
    test ax, ax
    jnz .empty
    cmp byte [disc_present], 0
    je .changed
    mov si, probe_info
    mov di, disc_info
    push ds
    pop es
    mov cx, INFO_SIZE/2
    repe cmpsw
    jne .changed
    clc
    ret
.empty:
    cmp byte [disc_present], 0
    je .same
.changed:
    stc
    ret
.same:
    clc
    ret

; AL = track. Return EDX = end of the track, before the next INDEX 00.
track_end:
    push bx
    movzx bx, al
    inc bx
    shl bx, 2
    mov edx, [track_index0+bx]
    cmp edx, [track_start+bx-4]
    ja .done
    mov edx, [track_start+bx]
.done:
    pop bx
    ret

; AL = track. Return EDX = end of the audio tracks that follow it.
run_end:
    push ax
.next:
    cmp al, [last_track]
    jae .end
    movzx bx, al
    cmp byte [track_data+bx+1], 0
    jne .end
    inc al
    jmp .next
.end:
    call track_end
    pop ax
    ret

; AL = track. Return EDX = the end of the next play request.
plan_end:
    cmp byte [repeat_mode], REPEAT_ONE
    je track_end
    cmp byte [shuffle], 0
    jne track_end
    jmp run_end

; AL = track. Return AL = the next audio track, or 0.
next_audio:
.next:
    cmp al, [last_track]
    jae .none
    inc al
    movzx bx, al
    cmp byte [track_data+bx], 0
    jne .next
    ret
.none:
    xor al, al
    ret

previous_audio:
.next:
    cmp al, [first_track]
    jbe .none
    dec al
    movzx bx, al
    cmp byte [track_data+bx], 0
    jne .next
    ret
.none:
    xor al, al
    ret

last_audio:
    mov al, [last_track]
    inc al
    call previous_audio
    ret

; EAX = start, EDX = end. Return CF on error.
play_range:
    cmp byte [physical_source], 0
    jne physical_play
    cmp edx, eax
    jbe .fail
    mov [range_end], edx
    sub edx, eax
    push eax
    mov al, 84h
    mov cl, 22
    call new_request
    pop eax
    mov [request+14], eax
    mov [request+18], edx
    mov [position], eax
    call send_request
    jc .fail
    mov byte [play_state], PLAYING
    mov byte [replan], 0
    clc
    ret
.fail:
    mov si, message_play_error
    call show_message
    stc
    ret

; AL = track. Play it from the start.
play_track:
    cmp byte [disc_present], 0
    je .done
    test al, al
    jz .done
    cmp al, [last_track]
    ja .done
    movzx bx, al
    cmp byte [track_data+bx], 0
    jne .data
    mov [track], al
    mov dword [relative], 0
    shl bx, 2
    push dword [track_start+bx]
    call plan_end
    pop eax
    call play_range
.done:
    ret
.data:
    mov si, message_data_track
    jmp show_message

stop_audio:
    cmp byte [physical_source], 0
    jne physical_stop
    mov al, 85h
    mov cl, 13
    call new_request
    jmp send_request

stop:
    cmp byte [play_state], STOPPED
    je .done
    cmp byte [play_state], PAUSED
    je .reset
    call stop_audio
.reset:
    call stop_audio
    mov byte [play_state], STOPPED
    mov dword [relative], 0
.done:
    ret

play_pause:
    cmp byte [disc_present], 0
    je no_disc
    cmp byte [play_state], PLAYING
    je .pause
    cmp byte [play_state], PAUSED
    je .resume
    mov al, [track]
    jmp play_track
.pause:
    cmp byte [physical_source], 0
    je .pause_ready
    call physical_position
.pause_ready:
    call stop_audio
    mov byte [play_state], PAUSED
    ret
.resume:
    cmp byte [physical_source], 0
    jne .replan
    cmp byte [replan], 0
    jne .replan
    mov al, 88h
    mov cl, 13
    call new_request
    call send_request
    jc .replan
    mov byte [play_state], PLAYING
    ret
.replan:
    mov al, [track]
    call plan_end
    mov eax, [position]
    jmp play_range

no_disc:
    mov si, message_no_disc
    jmp show_message

; Play the current track again with a new end after a mode change.
replan_play:
    cmp byte [play_state], PLAYING
    jne .later
    mov al, [track]
    call plan_end
    mov eax, [position]
    jmp play_range
.later:
    mov byte [replan], 1
    ret

; AL = track. Play it, or select it when stopped.
go_track:
    test al, al
    jz .done
    cmp byte [play_state], STOPPED
    je .select
    jmp play_track
.select:
    mov [track], al
    mov dword [relative], 0
.done:
    ret

next_track:
    cmp byte [disc_present], 0
    je no_disc
    cmp byte [shuffle], 0
    jne .shuffle
    mov al, [track]
    call next_audio
    test al, al
    jnz go_track
    mov al, [first_audio]
    jmp go_track
.shuffle:
    mov al, [order_index]
    inc al
    cmp al, [order_count]
    jb .order
    xor al, al
.order:
    mov [order_index], al
    movzx bx, al
    mov al, [order+bx]
    jmp go_track

previous_track:
    cmp byte [disc_present], 0
    je no_disc
    cmp byte [play_state], PLAYING
    jne .previous
    cmp dword [relative], 3*75
    jb .previous
    mov al, [track]
    jmp play_track
.previous:
    cmp byte [shuffle], 0
    jne .shuffle
    mov al, [track]
    call previous_audio
    test al, al
    jnz go_track
    call last_audio
    jmp go_track
.shuffle:
    mov al, [order_index]
    test al, al
    jnz .back
    mov al, [order_count]
.back:
    dec al
    mov [order_index], al
    movzx bx, al
    mov al, [order+bx]
    jmp go_track

; AX = signed seconds.
seek:
    cmp byte [play_state], STOPPED
    je .done
    movsx eax, ax
    imul eax, 75
    add eax, [position]
    movzx bx, byte [track]
    shl bx, 2
    cmp eax, [track_start+bx]
    jge .low_ok
    mov eax, [track_start+bx]
.low_ok:
    mov edx, [range_end]
    sub edx, 75
    cmp eax, edx
    jl .high_ok
    mov eax, edx
.high_ok:
    mov edx, [range_end]
    jmp play_range
.done:
    ret

; EAX = fraction of the current track in 1/65536 units.
seek_fraction:
    cmp byte [disc_present], 0
    je .done
    push eax
    mov al, [track]
    call track_end
    movzx bx, byte [track]
    shl bx, 2
    mov ecx, [track_start+bx]
    sub edx, ecx
    pop eax
    mul edx
    shrd eax, edx, 16
    add eax, ecx
    push eax
    mov al, [track]
    call plan_end
    pop eax
    jmp play_range
.done:
    ret

toggle_shuffle:
    xor byte [shuffle], 1
    call build_order
    jmp replan_play

cycle_repeat:
    inc byte [repeat_mode]
    cmp byte [repeat_mode], REPEAT_ALL
    jbe .ready
    mov byte [repeat_mode], REPEAT_OFF
.ready:
    jmp replan_play

; Make a random order of the audio tracks. The current track is first.
build_order:
    mov byte [order_count], 0
    mov byte [order_index], 0
    cmp byte [disc_present], 0
    je .done
    mov al, [first_track]
.collect:
    movzx bx, al
    cmp byte [track_data+bx], 0
    jne .skip
    movzx bx, byte [order_count]
    mov [order+bx], al
    inc byte [order_count]
.skip:
    inc al
    cmp al, [last_track]
    jbe .collect
    movzx cx, byte [order_count]
.mix:
    cmp cx, 1
    jbe .current
    call random
    xor dx, dx
    div cx
    dec cx
    mov bx, cx
    mov si, dx
    mov al, [order+bx]
    xchg al, [order+si]
    mov [order+bx], al
    jmp .mix
.current:
    movzx cx, byte [order_count]
    xor si, si
    mov al, [track]
.find:
    cmp si, cx
    jae .done
    cmp [order+si], al
    je .swap
    inc si
    jmp .find
.swap:
    xchg al, [order]
    mov [order+si], al
.done:
    ret

; Return AX = a random number.
random:
    push edx
    mov eax, [random_seed]
    imul eax, 1103515245
    add eax, 12345
    mov [random_seed], eax
    shr eax, 16
    pop edx
    ret

; The current play request ended.
play_end:
    mov byte [play_state], STOPPED
    cmp byte [repeat_mode], REPEAT_ONE
    je .again
    cmp byte [shuffle], 0
    jne .shuffle
    mov al, [track]
    call next_audio
    test al, al
    jnz play_track
    mov al, [first_audio]
    mov [track], al
    mov dword [relative], 0
    cmp byte [repeat_mode], REPEAT_ALL
    je play_track
    ret
.again:
    mov al, [track]
    jmp play_track
.shuffle:
    mov al, [order_index]
    inc al
    cmp al, [order_count]
    jb .order
    mov byte [order_index], 0
    cmp byte [repeat_mode], REPEAT_ALL
    jne .finished
    mov al, [order]
    mov [track], al
    call build_order
    xor al, al
.order:
    mov [order_index], al
    movzx bx, al
    mov al, [order+bx]
    jmp play_track
.finished:
    mov al, [order]
    mov [track], al
    mov dword [relative], 0
    ret

; Read the position of the audio. AX = request status.
read_position:
    mov al, 12
    mov cx, 11
    call ioctl_input
    jc .done
    mov al, [control_block+2]
    mov ah, al
    shr ah, 4
    and al, 0fh
    aad
    test al, al
    jz .absolute
    cmp al, [last_track]
    ja .absolute
    mov [track], al
.absolute:
    mov si, control_block+8
    mov al, [si]
    xchg al, [si+2]
    mov [si], al
    call redbook_sector
    mov [position], eax
    movzx bx, byte [track]
    shl bx, 2
    sub eax, [track_start+bx]
    mov [relative], eax
.done:
    ret

; Called once per frame.
poll_drive:
    cmp byte [physical_source], 0
    je .media
    cmp byte [play_state], PLAYING
    je physical_poll
.media:
    dec byte [disc_timer]
    jnz .state
    mov byte [disc_timer], 35
    call disc_changed
    jnc .state
    mov byte [play_state], STOPPED
    call read_disc
    ret
.state:
    cmp byte [physical_source], 0
    jne .done
    cmp byte [play_state], STOPPED
    je .done
    dec byte [poll_timer]
    jnz .done
    mov byte [poll_timer], 5
    mov al, 15
    mov cx, 11
    call ioctl_input
    jc .done
    mov dl, [control_block+1]
    cmp byte [play_state], PLAYING
    jne .paused
    test ah, 2
    jnz read_position
    test dl, 1
    jnz .now_paused
    jmp play_end
.now_paused:
    mov byte [play_state], PAUSED
    ret
.paused:
    test ah, 2
    jz .still
    mov byte [play_state], PLAYING
    ret
.still:
    test dl, 1
    jnz .done
    mov byte [play_state], STOPPED
.done:
    ret

; AL = 0 to 255.
set_volume:
    mov [volume], al
    cmp byte [physical_source], 0
    jne physical_volume
    mov [control_block+2], al
    mov [control_block+4], al
    mov byte [control_block+1], 0
    mov byte [control_block+3], 1
    mov word [control_block+5], 2
    mov word [control_block+7], 3
    mov al, 3
    mov cx, 9
    jmp ioctl_output

read_volume:
    cmp byte [physical_source], 0
    je .read
    mov byte [volume], 255
    ret
.read:
    mov al, 4
    mov cx, 9
    call ioctl_input
    jc .done
    mov al, [control_block+2]
    mov [volume], al
.done:
    ret

next_unit:
    call stop
    call hook_remove
    mov al, [unit]
    inc al
    cmp al, [unit_total]
    jb .select
    xor al, al
.select:
    call select_unit
    call read_disc
    call read_volume
    jmp hook_install
