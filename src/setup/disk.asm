; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; The Disk row of the main screen: what the PCI scan (disk_scan.asm) found,
; and an IRQ set by hand for a controller it did not find. The driver runs the
; same scan at installation and builds the mask itself.

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
disk_label db 'Disk',0
disk_no_pci_text db 'No PCI BIOS',0
disk_none_text db 'Only IRQ 14 and 15',0
disk_off_text db 'PCI scan off (UCDDPCI)',0
disk_no_irq_text db 'PCI, no IRQ set',0
disk_pci_irq_text db 'PCI on IRQ ',0
disk_more_text db ' +?',0
disk_note db 'Set a disk controller IRQ that uCDD missed. 14 and 15 always work.',0
disk_found_text times 48 db 0
