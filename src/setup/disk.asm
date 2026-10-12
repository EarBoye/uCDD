; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Disk controller IRQs. A PCI disk controller holds its level-triggered
; request until its real-mode handler runs. If a protected-mode program waits
; in a real-mode call for that disk, the request must go to the handler
; directly, or the program never continues. The driver does this for IRQ 14,
; IRQ 15, the IRQs found here, and the IRQ set by hand in the Disk row.

; Find PCI mass storage controllers (class 01h) and the IRQs that the BIOS
; gave them. A machine without a PCI BIOS has none to find. A controller with
; no interrupt pin, like a chipset IDE port in compatibility mode, uses IRQ 14
; and 15.
disk_scan:
    xor ax, ax
    mov [disk_found], ax
    mov [disk_unknown], al
    mov [disk_pci], al
    ; SET UCDDPCI=OFF skips the scan, for a PCI BIOS that fails under the
    ; memory manager.
    call disk_scan_allowed
    jc .off
    ; The PCI BIOS may use 1 KB of the caller's stack. UCDDSET has 1 KB in all.
    cli
    mov [disk_old_stack], sp
    mov [disk_old_stack+2], ss
    mov ax, cs
    mov ss, ax
    mov sp, disk_stack_top
    sti
    call disk_scan_pci
    cli
    mov ss, [cs:disk_old_stack+2]
    mov sp, [cs:disk_old_stack]
    sti
    ret
.off:
    mov byte [disk_pci], 2
    ret

disk_scan_pci:
    pushad
    push es
    mov ax, 0b101h
    xor edi, edi
    int 1ah
    jc .done
    test ah, ah
    jnz .done
    cmp edx, 20494350h
    jne .done
    mov byte [disk_pci], 1
    mov [disk_last_bus], cl
    xor bh, bh
.bus:
    ; BL holds the device in bits 3 to 7 and the function in bits 0 to 2.
    xor bl, bl
.device:
    xor di, di
    call pci_read_word
    jc .next_device
    cmp cx, 0ffffh
    je .next_device
    mov di, 0eh
    call pci_read_byte
    jc .next_device
    mov [disk_header], cl
.function:
    call disk_function
    ; Bit 7 of the header type marks a device with more than one function.
    test byte [disk_header], 80h
    jz .next_device
.next_function:
    inc bl
    test bl, 7
    jz .device_done
    xor di, di
    call pci_read_word
    jc .next_function
    cmp cx, 0ffffh
    je .next_function
    jmp .function
.next_device:
    and bl, 0f8h
    add bl, 8
.device_done:
    ; BL wraps to 0 after device 31.
    test bl, bl
    jnz .device
    cmp bh, [disk_last_bus]
    jae .done
    inc bh
    jmp .bus
.done:
    pop es
    popad
    ret

; BH bus, BL device and function.
disk_function:
    mov di, 0bh
    call pci_read_byte
    jc .done
    cmp cl, 1
    jne .done
    ; An IDE controller with both channels in compatibility mode (programming
    ; interface bits 0 and 2 clear) uses IRQ 14 and 15. Some report a routed
    ; interrupt line all the same.
    mov di, 0ah
    call pci_read_byte
    jc .done
    cmp cl, 1
    jne .native
    mov di, 09h
    call pci_read_byte
    jc .done
    test cl, 5
    jz .done
.native:
    mov di, 3dh
    call pci_read_byte
    jc .done
    test cl, cl
    jz .done
    mov di, 3ch
    call pci_read_byte
    jc .done
    ; 0FFh means no IRQ. IRQ 0, 1, 2, 8, and 13 cannot be a PCI IRQ.
    cmp cl, 15
    ja .unknown
    movzx cx, cl
    bt word [disk_invalid], cx
    jc .unknown
    bts [disk_found], cx
    ret
.unknown:
    inc byte [disk_unknown]
.done:
    ret

; BH bus, BL device and function, DI register. Return CL, or CF set.
pci_read_byte:
    push ax
    push bx
    push dx
    push si
    push di
    mov ax, 0b108h
    int 1ah
    jmp pci_read_end

; BH bus, BL device and function, DI register. Return CX, or CF set.
pci_read_word:
    push ax
    push bx
    push dx
    push si
    push di
    mov ax, 0b109h
    int 1ah
pci_read_end:
    pop di
    pop si
    pop dx
    pop bx
    jc .failed
    test ah, ah
    jnz .failed
    pop ax
    clc
    ret
.failed:
    pop ax
    stc
    ret

; Return AX: the IRQs that go straight to the real-mode handler. IRQ 14 and
; 15, the PCI disk controllers, and the IRQ set by hand, never the IRQ of the
; physical sound card.
disk_mask:
    push cx
    call disk_used
    or ax, 0c000h
    and ax, 0def8h
    movzx cx, byte [sb_irq]
    btr ax, cx
    pop cx
    ret

; Return AX: the IRQs of the PCI disk controllers and the IRQ set by hand.
disk_used:
    push cx
    mov ax, [disk_found]
    movzx cx, byte [config_disk_irq]
    jcxz .done
    bts ax, cx
.done:
    pop cx
    ret

; Return SI: a warning about the disk IRQs and the sound card IRQs in
; disk_warning, or 0. IRQ 14 and 15 are never sound card IRQs.
disk_check:
    push ax
    push cx
    push di
    call disk_used
    xor si, si
    movzx cx, byte [sb_irq]
    mov di, disk_physical_text
    bt ax, cx
    jc .warn
    movzx cx, byte [virtual_irq]
    mov di, disk_virtual_text
    bt ax, cx
    jc .warn
    movzx cx, byte [virtual_wss_irq]
    mov di, disk_wss_text
    bt ax, cx
    jnc .done
.warn:
    ; The text has a # where the IRQ number goes.
    mov si, di
    mov di, disk_warning
.copy:
    lodsb
    cmp al, '#'
    jne .store
    mov ax, cx
    call text_decimal
    jmp .copy
.store:
    stosb
    test al, al
    jnz .copy
    mov si, disk_warning
.done:
    pop di
    pop cx
    pop ax
    ret

; DI buffer. Write the IRQ numbers in AX, lowest first, separated by spaces.
disk_irq_text:
    push ax
    push bx
    push cx
    mov bx, ax
    xor cx, cx
.irq:
    bt bx, cx
    jnc .next
    cmp byte [disk_irq_first], 0
    jne .number
    mov byte [di], ' '
    inc di
.number:
    mov byte [disk_irq_first], 0
    mov ax, cx
    call text_decimal
.next:
    inc cx
    cmp cx, 16
    jb .irq
    mov byte [di], 0
    pop cx
    pop bx
    pop ax
    ret

; Write what the PCI scan found to disk_found_text.
disk_found_describe:
    mov di, disk_found_text
    mov si, disk_no_pci_text
    cmp byte [disk_pci], 0
    je .copy
    mov si, disk_off_text
    cmp byte [disk_pci], 2
    je .copy
    mov si, disk_none_text
    mov ax, [disk_found]
    test ax, ax
    jnz .list
    cmp byte [disk_unknown], 0
    je .copy
    mov si, disk_no_irq_text
.copy:
    jmp copy_text
.list:
    mov si, disk_pci_irq_text
    call copy_text
    mov ax, [disk_found]
    mov byte [disk_irq_first], 1
    call disk_irq_text
    cmp byte [disk_unknown], 0
    je .done
    mov si, disk_more_text
    call copy_text
.done:
    ; The text starts at column 17 and the IRQ field at column 49.
    mov byte [disk_found_text+31], 0
    ret

; Main screen: the Disk row and a warning above the output line.
disk_draw:
    call disk_found_describe
    mov dx, 0804h
    mov si, disk_label
    mov bl, A_BOX
    call put_text
    mov dx, 0811h
    mov si, disk_found_text
    call put_text
    call disk_check
    test si, si
    jz .done
    mov dx, 0d04h
    mov bl, A_TITLE
    call put_text
.done:
    ret

; UCDD -install: report a disk IRQ outside 14 and 15, and any warning.
disk_report:
    call disk_used
    test ax, ax
    jz .warning
    mov di, disk_report_buffer
    mov si, disk_report_text
    call copy_text
    call disk_mask
    mov byte [disk_irq_first], 1
    call disk_irq_text
    mov si, period_line
    call copy_text
    mov si, disk_report_buffer
    call print_text
.warning:
    call disk_check
    test si, si
    jz .done
    call print_text
    mov si, crlf_text
    call print_text
.done:
    ret

; Return CF set if the environment has UCDDPCI=OFF (any case).
disk_scan_allowed:
    push ds
    push si
    push di
    mov ds, [cs:psp]
    mov si, [2ch]
    test si, si
    jz .allowed
    mov ds, si
    xor si, si
.variable:
    cmp byte [si], 0
    je .allowed
    mov di, disk_env_name
.compare:
    mov al, [cs:di]
    test al, al
    jz .found
    mov ah, [si]
    cmp ah, 'a'
    jb .upper
    cmp ah, 'z'
    ja .upper
    sub ah, 20h
.upper:
    cmp ah, al
    jne .skip
    inc si
    inc di
    jmp .compare
.skip:
    lodsb
    test al, al
    jnz .skip
    jmp .variable
.found:
    ; The value must end after OFF.
    cmp byte [si], 0
    jne .skip
    stc
    jmp .done
.allowed:
    clc
.done:
    pop di
    pop si
    pop ds
    ret

disk_irq_list:
    mov si, disk_irq_values
    ret

; 0 shows as a dash: no IRQ set by hand.
text_disk_irq:
    test ax, ax
    jnz text_decimal
    mov byte [di], '-'
    mov byte [di+1], 0
    inc di
    ret

disk_irq_choice:
    choice config_disk_irq,1,disk_irq_list,text_disk_irq,0
disk_irq_values db 10
    dw 0,3,4,5,6,7,9,10,11,12
; IRQs that no PCI device can use.
disk_invalid dw 2107h
disk_found dw 0
disk_unknown db 0
disk_pci db 0
disk_last_bus db 0
disk_header db 0
disk_irq_first db 0
disk_label db 'Disk',0
disk_no_pci_text db 'No PCI BIOS',0
disk_none_text db 'Only IRQ 14 and 15',0
disk_off_text db 'PCI scan off (UCDDPCI)',0
disk_no_irq_text db 'PCI, no IRQ set',0
disk_pci_irq_text db 'PCI on IRQ ',0
disk_more_text db ' +?',0
disk_note db 'Set a disk controller IRQ that uCDD missed. 14 and 15 always work.',0
disk_physical_text db 'The physical card and a disk controller both use IRQ #.',0
disk_virtual_text db 'A disk controller uses IRQ #. Set the virtual SB to a different IRQ.',0
disk_wss_text db 'A disk controller uses IRQ #. Set the virtual WSS to a different IRQ.',0
disk_report_text db 'Disk controller IRQs go to DOS directly: ',0
crlf_text db 13,10,0
disk_env_name db 'UCDDPCI=OFF',0
disk_old_stack dd 0
disk_found_text times 48 db 0
disk_warning times 80 db 0
disk_report_buffer times 80 db 0
    align 2
disk_stack times 2048 db 0
disk_stack_top:
