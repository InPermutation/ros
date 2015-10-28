global start

section .text
bits 32
start:
; Set up stack pointer
    mov esp, stack_top

    call test_multiboot

    mov dword [0xb8000], 0x2f4b2f4f
    hlt

; Prints `ERR: ` and the given error code to screen and hangs.
; parameter: error code (in ASCII) in al
error:
    ; 0x4f is red with white text
    mov dword [0xb8000], 0x4f524f45 ; ER
    mov dword [0xb8004], 0x4f3a4f52 ;   R:
    mov dword [0xb8008], 0x4f004f20 ;      0
    mov byte  [0xb800a], al         ; swap ^ with `al`
    hlt

test_multiboot:
    cmp eax, 0x36d76289
    jne .no_multiboot
    ret
.no_multiboot:
    mov al, "0"
    jmp error

; Reserve space for stack
section .bss
stack_bottom:
    resb 64
stack_top:
