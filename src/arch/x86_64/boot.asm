global start

section .text
bits 32
start:
    mov al, 0x58
    jmp error

; Prints `ERR: ` and the given error code to screen and hangs.
; parameter: error code (in ASCII) in al
error:
    mov dword [0xb8000], 0x4f524f45
    mov dword [0xb8004], 0x4f3a4f52
    mov dword [0xb8008], 0x4f004f20
    mov byte  [0xb800a], al
    hlt
