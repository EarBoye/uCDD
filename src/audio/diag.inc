; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%ifndef DIAG_MACROS
%define DIAG_MACROS 1

; Diagnostic counters (UCDD -status). Both macros build nothing unless
; UCDD_DIAG is set. DIAG_INC: DS is the resident segment. DIAG_INC_CS: any DS.
%macro DIAG_INC 1
%ifdef UCDD_DIAG
    inc word [%1]
%endif
%endmacro

%macro DIAG_INC_CS 1
%ifdef UCDD_DIAG
    inc word [cs:%1]
%endif
%endmacro

; Set the fault value and keep the first fault. %1: site, %2: fault value.
%macro FAULT_SET 2
%ifdef UCDD_DIAG
    mov ax, (%2 << 8) | %1
    call fault_set
%else
    mov byte [fault], %2
%endif
%endmacro

%endif
