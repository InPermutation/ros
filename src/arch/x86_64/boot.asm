global start

section .text
bits 32
start:
; Set up stack pointer
    mov esp, stack_top

    call test_multiboot
    call test_cpuid
    call test_long_mode

    call print_vendorid

    hlt

; prints the vendor id from cpuid
print_vendorid:
    mov eax, 0
    cpuid
    ; set up eax as vga buffer location
    mov eax, 0xb8000
    ; vendor id stored in ebx, edx, ecx
    call printdw
    mov ebx, edx
    call printdw
    mov ebx, ecx
    call printdw
    ret

; Prints a 4-character "string" in a double word
; parameter: eax - VGA buffer location (will be incremented by 8)
; parameter: ebx - "string"
printdw:
    call printw
    shr ebx, 16
    call printw
    ret

; Prints a 2-character "string" in a word
; parameters: eax - VGA buffer location (will be incremented by 4)
; parameters: bx - 16-bit word "string" as 'lh'
printw:
    .C equ 0xFC
    mov byte [eax + 3], .C
    mov byte [eax + 2], bh
    mov byte [eax + 1], .C
    mov byte [eax + 0], bl
    add eax, 4
    ret


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

test_cpuid:
    pushfd               ; Store the FLAGS-register.
    pop eax              ; Restore the A-register.
    mov ecx, eax         ; Set the C-register to the A-register.
    xor eax, 1 << 21     ; Flip the ID-bit, which is bit 21.
    push eax             ; Store the A-register.
    popfd                ; Restore the FLAGS-register.
    pushfd               ; Store the FLAGS-register.
    pop eax              ; Restore the A-register.
    push ecx             ; Store the C-register.
    popfd                ; Restore the FLAGS-register.
    xor eax, ecx         ; Do a XOR-operation on the A-register and the C-register.
    jz .no_cpuid         ; The zero flag is set, no CPUID.
    ret                  ; CPUID is available for use.
.no_cpuid:
    mov al, "1"
    jmp error

test_long_mode:
    mov eax, 0x80000000    ; Set the A-register to 0x80000000.
    cpuid                  ; CPU identification.
    cmp eax, 0x80000001    ; Compare the A-register with 0x80000001.
    jb .no_long_mode       ; It is less, there is no long mode.
    mov eax, 0x80000001    ; Set the A-register to 0x80000001.
    cpuid                  ; CPU identification.
    test edx, 1 << 29      ; Test if the LM-bit, which is bit 29, is set in the D-register.
    jz .no_long_mode       ; They aren't, there is no long mode.
    ret
.no_long_mode:
    mov al, "2"
    jmp error

; Reserve space for stack
section .bss
stack_bottom:
    resb 64
stack_top:
