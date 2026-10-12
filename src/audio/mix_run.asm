; SPDX-License-Identifier: GPL-3.0-only

; Short paths through mix_half for the common streams. mix_half's general
; loop tests every mode for every frame. Here a frame is built from three
; pieces picked once per half: a source, an optional middle (disc audio,
; clipping) and a store for the physical card. Each combination must leave
; the same samples and the same state as the general loop: VERIFY_MIX
; builds run both and compare.

; MIX_RUN_LEAVE condition, cause: leave the half to the general loop. Check
; builds count the causes.
%macro MIX_RUN_LEAVE 2
%ifdef VERIFY_MIX
    j%-1 %%stay
    inc dword [verify_reasons+%2*4]
    jmp .no_pop
%%stay:
%else
    j%+1 .no_pop
%endif
%endmacro

; CX=frames. Returns CF clear and AX=entry when the whole half is one of
; these cases, CF set for the general loop. Keeps the other registers.
mix_run_select:
    ; Halved outputs pair frames by the parity of the count.
    test cl, 1
    jnz .no
    cmp byte [sb_dac_enabled], 0
    jne .no
    cmp byte [sb_patch_active], 0
    jne .no
    push bx
    push si
    ; BL: the legacy output filter runs. BH: a sample can leave 16 bits.
    xor bx, bx
    cmp dword [sb_pcm_gain], 65535
    ja .loud
    cmp dword [sb_pcm_gain+4], 65535
    jbe .gain_ready
.loud:
    mov bh, 1
.gain_ready:
    cmp byte [game_source], 0
    jne .filter_ready
    cmp byte [sb_filter_legacy], 0
    je .filter_ready
    cmp byte [sb_filter_bypass], 0
    jne .filter_ready
    mov bl, 1
.filter_ready:
    cmp byte [game_active], 0
    je .quiet
    cmp dword [game_exit_frame], 0
    je .active
    ; A single block: silence follows its last frame.
    mov eax, [game_mix_frame]
    cmp eax, [game_exit_frame]
    jae .quiet
    push edx
    movzx edx, cx
    add eax, edx
    pop edx
    cmp eax, [game_exit_frame]
    MIX_RUN_LEAVE a, 0
    jmp .active
.quiet:
    xor eax, eax
    mov [mix_run_level], eax
    mov [mix_run_level+4], eax
    test bl, bl
    jz .silent
    ; A filter that has settled gives the same sample for every frame.
    mov si, sb_filter_state
    call mix_run_settled
    jne .ringing
    imul eax, [sb_pcm_gain]
    sar eax, 15
    mov [mix_run_level], eax
    mov si, sb_filter_state+8
    call mix_run_settled
    jne .ringing
    imul eax, [sb_pcm_gain+4]
    sar eax, 15
    mov [mix_run_level+4], eax
    or eax, [mix_run_level]
    mov si, mix_run_constant
    jnz .source_ready
.silent:
    mov si, mix_run_constant
    xor bh, bh
    jmp .source_ready
.ringing:
    mov si, mix_run_filter
    mov bh, 1
    jmp .source_ready
.active:
    cmp byte [game_source], 0
    MIX_RUN_LEAVE ne, 1
    cmp byte [sb_input], 0
    MIX_RUN_LEAVE ne, 2
    cmp byte [sb_speaker], 0
    MIX_RUN_LEAVE e, 3
    mov si, [game_dma]
    cmp byte [si+DMA_MASK], 0
    MIX_RUN_LEAVE ne, 4
%ifdef OWN_HOST
    cmp dword [game_physical], 0
    MIX_RUN_LEAVE ne, 5
%endif
    cmp dword [game_limit], 0
    MIX_RUN_LEAVE e, 6
    ; Signed 8-bit data: only the general loop converts it.
    test byte [game_format], 4
    MIX_RUN_LEAVE nz, 13
    or bh, bl
    mov word [mix_run_sign], 0
    cmp byte [game_frame_shift], 0
    jne .not_mono8
    mov si, mix_run_mono8
    test bl, bl
    jz .source_ready
    ; One filter serves both channels while their states agree.
    mov eax, [sb_filter_state]
    cmp eax, [sb_filter_state+8]
    MIX_RUN_LEAVE ne, 7
    mov eax, [sb_filter_state+4]
    cmp eax, [sb_filter_state+12]
    MIX_RUN_LEAVE ne, 7
    mov si, mix_run_mono8_filter
    jmp .source_ready
.not_mono8:
    cmp byte [game_frame_shift], 1
    jne .stereo16
    test byte [game_format], 1
    jnz .mono16
    cmp byte [sb_single], 0
    MIX_RUN_LEAVE ne, 8
    mov si, mix_run_stereo8
    test bl, bl
    jz .source_ready
    mov si, mix_run_stereo8_filter
    jmp .source_ready
.mono16:
    mov si, mix_run_mono16
    jmp .sign
.stereo16:
    cmp byte [game_frame_shift], 2
    MIX_RUN_LEAVE ne, 10
    cmp byte [sb_single], 0
    MIX_RUN_LEAVE ne, 9
    mov si, mix_run_stereo16
.sign:
    test bl, bl
    MIX_RUN_LEAVE nz, 10
    test byte [game_format], 2
    jz .source_ready
    mov word [mix_run_sign], 8000h
.source_ready:
    ; A PCM gain of 32768 in both channels leaves every sample as it is: the
    ; variant of the source without the gain step, when it has one.
    cmp dword [sb_pcm_gain], 32768
    jne .scaled
    cmp dword [sb_pcm_gain+4], 32768
    jne .scaled
    push di
    mov di, mix_run_unity_sources
.unity_source:
    cmp si, [di]
    je .unity_found
    add di, 4
    cmp di, mix_run_unity_sources_end
    jb .unity_source
    pop di
    jmp .scaled
.unity_found:
    mov si, [di+2]
    pop di
.scaled:
    mov [mix_run_source], si
    xor si, si
    cmp byte [cd_valid], 0
    je .no_disc
    ; A disc at the output rate needs no interpolation and no phase.
    mov si, mix_run_disc_rate
    cmp dword [cd_fraction], 0
    jne .disc_gain
    cmp dword [cd_step], 65536
    jne .disc_gain
    cmp dword [cd_step_remainder], 0
    jne .disc_gain
    mov eax, [cd_step_error]
    cmp eax, [output_rate]
    jae .disc_gain
    mov si, mix_run_disc
.disc_gain:
    ; A disc gain of 256 in both channels only halves the samples: the
    ; variants with the suffix _unity.
    cmp dword [cd_gain], 256
    jne .middle_ready
    cmp dword [cd_gain+4], 256
    jne .middle_ready
    cmp si, mix_run_disc
    mov si, mix_run_disc_unity
    je .middle_ready
    mov si, mix_run_disc_rate_unity
    jmp .middle_ready
.no_disc:
    test bh, bh
    jz .middle_ready
    mov si, mix_run_clip
.middle_ready:
    mov ax, mix_run_store_mono
    cmp byte [sound_card], 3
    je .store_ready
    mov ax, mix_run_store_pro
    cmp byte [sound_card], 1
    je .store_ready
    mov ax, mix_run_store_word
    cmp byte [ess_half], 0
    je .store_ready
    mov ax, mix_run_store_half
.store_ready:
    mov [mix_run_store], ax
    test si, si
    jnz .next_ready
    mov si, ax
.next_ready:
    mov [mix_run_next], si
    mov bx, mix_run_enter
    cmp si, ax
    jne .entry_ready
    cmp word [mix_run_source], mix_run_constant
    jne .entry_ready
    mov eax, [mix_run_level]
    or eax, [mix_run_level+4]
    jnz .entry_ready
    mov bx, mix_run_idle
.entry_ready:
    mov ax, bx
    pop si
    pop bx
    clc
    ret
.no_pop:
    pop si
    pop bx
.no:
    stc
    ret

; SI=one channel of sb_filter_state. Returns ZF set and EAX=the output
; when silence in leaves the state as it is.
mix_run_settled:
    push edx
    mov eax, [si]
    sar eax, 14
    imul edx, eax, -8604
    cmp edx, [si+4]
    jne .done
    imul edx, eax, 22436
    add edx, [si+4]
    cmp edx, [si]
.done:
    pop edx
    ret

; Nothing plays: the half is silence.
mix_run_idle:
    movzx eax, cx
    add [game_mix_frame], eax
    xor eax, eax
    cmp byte [sound_card], 3
    je .mono
    cmp byte [sound_card], 1
    je .pro
    cmp byte [ess_half], 0
    jne .half
    ; A frame is one doubleword.
    rep stosd
    jmp mix_half.half_complete
.half:
    mov [pro_pair_left], eax
    mov [pro_pair_right], eax
    shr cx, 1
    rep stosd
    jmp mix_half.half_complete
.pro:
    mov [pro_pair_left], eax
    mov [pro_pair_right], eax
    mov al, 80h
    rep stosb
    jmp mix_half.half_complete
.mono:
    mov [sb_mono_left], eax
    mov [pro_pair_left], eax
    shr cx, 1
    mov al, 80h
    rep stosb
    jmp mix_half.half_complete

mix_run_enter:
    movzx eax, cx
    add [game_mix_frame], eax
    jmp [mix_run_source]

; The phase passed the end of the game's block.
mix_run_wrap:
.again:
    sub ebp, [game_limit]
    cmp byte [sb_tail_valid], 0
    je .check
    mov byte [sb_tail_valid], 0
    mov fs, [game_segment]
    mov ax, [game_offset]
    mov [sb_tail_read_offset], ax
.check:
    cmp ebp, [game_limit]
    jae .again
    ret

%macro MIX_RUN_ADVANCE 0
    add ebp, [game_step]
    cmp ebp, [game_limit]
    jb %%placed
    call mix_run_wrap
%%placed:
%endmacro

%macro MIX_RUN_GAIN 0
    imul edx, [sb_pcm_gain]
    sar edx, 15
    imul esi, [sb_pcm_gain+4]
    sar esi, 15
%endmacro

%macro MIX_RUN_CLIP 1
    cmp %1, 32767
    jle %%low
    mov %1, 32767
%%low:
    cmp %1, -32768
    jge %%done
    mov %1, -32768
%%done:
%endmacro

; Sources. Each leaves the frame in EDX and ESI. The set with the suffix
; _unity, for a PCM gain of 32768 in both channels, leaves out the gain
; step: (x*32768)>>15 is x while x takes 17 bits, and a sample here is a
; 16-bit one halved, or that through sb_filter, whose gain stays below 1.5.
; %1 is the suffix, %2 whether the gain applies.
%macro MIX_RUN_SOURCES 2
%if %2
mix_run_constant:
    mov edx, [mix_run_level]
    mov esi, [mix_run_level+4]
    jmp [mix_run_next]
%endif

; Silence into a filter that still rings.
mix_run_filter%1:
    xor edx, edx
    xor esi, esi
    call sb_filter
%if %2
    MIX_RUN_GAIN
%endif
    jmp [mix_run_next]

mix_run_mono8%1:
    mov eax, ebp
    shr eax, 16
    add ax, [sb_tail_read_offset]
    mov si, ax
    movzx edx, byte [fs:si]
    sub edx, 128
    shl edx, 7
    mov esi, edx
    MIX_RUN_ADVANCE
%if %2
    MIX_RUN_GAIN
%endif
    jmp [mix_run_next]

mix_run_mono8_filter%1:
    mov eax, ebp
    shr eax, 16
    add ax, [sb_tail_read_offset]
    mov si, ax
    movzx edx, byte [fs:si]
    sub edx, 128
    shl edx, 7
    MIX_RUN_ADVANCE
    ; sb_filter for one channel, kept in both channels' state.
    imul esi, edx, 638
    mov eax, esi
    add eax, [sb_filter_state]
    sar eax, 14
    mov edx, eax
    imul eax, 22436
    lea eax, [eax+esi*2]
    add eax, [sb_filter_state+4]
    mov [sb_filter_state], eax
    mov [sb_filter_state+8], eax
    imul eax, edx, -8604
    add eax, esi
    mov [sb_filter_state+4], eax
    mov [sb_filter_state+12], eax
    mov esi, edx
%if %2
    MIX_RUN_GAIN
%endif
    jmp [mix_run_next]

mix_run_stereo8%1:
    MIX_RUN_STEREO8
%if %2
    MIX_RUN_GAIN
%endif
    jmp [mix_run_next]

mix_run_stereo8_filter%1:
    MIX_RUN_STEREO8
    call sb_filter
%if %2
    MIX_RUN_GAIN
%endif
    jmp [mix_run_next]

mix_run_mono16%1:
    mov eax, ebp
    shr eax, 16
    shl ax, 1
    add ax, [sb_tail_read_offset]
    mov si, ax
    mov dx, [fs:si]
    xor dx, [mix_run_sign]
    movsx edx, dx
    sar edx, 1
    mov esi, edx
    MIX_RUN_ADVANCE
%if %2
    MIX_RUN_GAIN
%endif
    jmp [mix_run_next]

mix_run_stereo16%1:
    mov eax, ebp
    shr eax, 16
    shl ax, 2
    add ax, [sb_tail_read_offset]
    mov si, ax
    mov dx, [fs:si]
    mov ax, [fs:si+2]
    xor dx, [mix_run_sign]
    xor ax, [mix_run_sign]
    movsx edx, dx
    movsx esi, ax
    sar edx, 1
    sar esi, 1
    MIX_RUN_ADVANCE
%if %2
    MIX_RUN_GAIN
%endif
    jmp [mix_run_next]
%endmacro

%macro MIX_RUN_STEREO8 0
    mov eax, ebp
    shr eax, 16
    shl ax, 1
    add ax, [sb_tail_read_offset]
    mov si, ax
    movzx edx, byte [fs:si]
    movzx esi, byte [fs:si+1]
    sub edx, 128
    sub esi, 128
    shl edx, 7
    shl esi, 7
    MIX_RUN_ADVANCE
%endmacro

MIX_RUN_SOURCES , 1
MIX_RUN_SOURCES _unity, 0

; Each source with a gain step and its variant without one.
mix_run_unity_sources:
    dw mix_run_filter, mix_run_filter_unity
    dw mix_run_mono8, mix_run_mono8_unity
    dw mix_run_mono8_filter, mix_run_mono8_filter_unity
    dw mix_run_stereo8, mix_run_stereo8_unity
    dw mix_run_stereo8_filter, mix_run_stereo8_filter_unity
    dw mix_run_mono16, mix_run_mono16_unity
    dw mix_run_stereo16, mix_run_stereo16_unity
mix_run_unity_sources_end:

; Middles. MIX_RUN_CD_SCALE register, channel: the disc sample scaled by the
; channel's gain, (x*gain)>>9. The variants with the suffix _unity serve a
; gain of 256 in both channels, where that is x>>1.
%macro MIX_RUN_CD_SCALE 3
%if %3
    sar %1, 1
%else
    imul %1, [cd_gain+%2]
    sar %1, 9
%endif
%endmacro

; Disc audio at another rate than the output's: the general loop's
; cd_interpolate and phase step, in line. %1 is the suffix, %2 whether the
; gain is unity.
%macro MIX_RUN_DISC_RATE 2
mix_run_disc_rate%1:
    ; cd_interpolate multiplies by half the phase: a difference of two
    ; samples takes 17 bits. With a half of zero it has nothing to add.
    mov eax, [cd_fraction]
    shr eax, 1
    jz %%whole
    mov [mix_run_fraction], eax
    ; The frame waits on the stack: each channel takes two registers.
    push edx
    push esi
    movsx edx, word [gs:bx+4]
    movsx eax, word [gs:bx]
    sub edx, eax
    imul edx, [mix_run_fraction]
    sar edx, 15
    add eax, edx
    MIX_RUN_CD_SCALE eax, 0, %2
    movsx esi, word [gs:bx+6]
    movsx edx, word [gs:bx+2]
    sub esi, edx
    imul esi, [mix_run_fraction]
    sar esi, 15
    add edx, esi
    MIX_RUN_CD_SCALE edx, 4, %2
    pop esi
    add esi, edx
    pop edx
    add edx, eax
%%phase:
    ; The disc's phase for the next frame: the error against the output rate
    ; first, since it carries into the frame count.
    mov eax, [cd_step_error]
    add eax, [cd_step_remainder]
    sub eax, [output_rate]
    jae %%carry
    add eax, [output_rate]
    mov [cd_step_error], eax
    mov eax, [cd_fraction]
    add eax, [cd_step]
    jmp %%advance
%%carry:
    mov [cd_step_error], eax
    mov eax, [cd_fraction]
    add eax, [cd_step]
    inc eax
%%advance:
    ; The high word of cd_fraction is zero: every writer masks it.
    mov [cd_fraction], ax
    shr eax, 16
    shl ax, 2
    add bx, ax
    jmp mix_run_clip
%%whole:
    movsx eax, word [gs:bx]
    MIX_RUN_CD_SCALE eax, 0, %2
    add edx, eax
    movsx eax, word [gs:bx+2]
    MIX_RUN_CD_SCALE eax, 4, %2
    add esi, eax
    jmp %%phase
%endmacro

MIX_RUN_DISC_RATE , 0
MIX_RUN_DISC_RATE _unity, 1

; Disc audio at the output rate.
%macro MIX_RUN_DISC 2
mix_run_disc%1:
    movsx eax, word [gs:bx]
    MIX_RUN_CD_SCALE eax, 0, %2
    add edx, eax
    movsx eax, word [gs:bx+2]
    MIX_RUN_CD_SCALE eax, 4, %2
    add esi, eax
    add bx, 4
    jmp mix_run_clip
%endmacro

MIX_RUN_DISC _unity, 1
MIX_RUN_DISC , 0
mix_run_clip:
    MIX_RUN_CLIP edx
    MIX_RUN_CLIP esi
    jmp [mix_run_store]

; Stores.
mix_run_store_word:
    mov [es:di], dx
    mov [es:di+2], si
    add di, 4
    dec cx
    jz mix_half.half_complete
    jmp [mix_run_source]

; Half the frame rate: the mean of each two frames.
mix_run_store_half:
    test cl, 1
    jnz .second
    mov [pro_pair_left], edx
    mov [pro_pair_right], esi
    dec cx
    jmp [mix_run_source]
.second:
    add edx, [pro_pair_left]
    sar edx, 1
    add esi, [pro_pair_right]
    sar esi, 1
    mov [es:di], dx
    mov [es:di+2], si
    add di, 4
    dec cx
    jz mix_half.half_complete
    jmp [mix_run_source]

; Sound Blaster Pro: 8-bit stereo at half the frame rate.
mix_run_store_pro:
    test cl, 1
    jnz .second
    mov [pro_pair_left], edx
    mov [pro_pair_right], esi
    dec cx
    jmp [mix_run_source]
.second:
    add edx, [pro_pair_left]
    add edx, 256
    sar edx, 9
    cmp edx, 127
    jle .left
    mov edx, 127
.left:
    add esi, [pro_pair_right]
    add esi, 256
    sar esi, 9
    cmp esi, 127
    jle .right
    mov esi, 127
.right:
    mov ax, si
    mov ah, al
    mov al, dl
    xor ax, 8080h
    mov [es:di], ax
    add di, 2
    dec cx
    jz mix_half.half_complete
    jmp [mix_run_source]

; Sound Blaster: 8-bit mono at half the frame rate.
mix_run_store_mono:
    mov [sb_mono_left], edx
    add edx, esi
    test cl, 1
    jnz .second
    mov [pro_pair_left], edx
    dec cx
    jmp [mix_run_source]
.second:
    add edx, [pro_pair_left]
    add edx, 512
    sar edx, 10
    cmp edx, 127
    jle .level
    mov edx, 127
.level:
    xor dl, 80h
    mov [es:di], dl
    inc di
    dec cx
    jz mix_half.half_complete
    jmp [mix_run_source]

mix_run_source dw 0
mix_run_next dw 0
mix_run_store dw 0
mix_run_sign dw 0
mix_run_level dd 0, 0
mix_run_fraction dd 0

%ifdef VERIFY_MIX
%include "audio/mix_verify.asm"
%endif
