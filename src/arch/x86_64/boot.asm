global start

section .text
bits 32
start:
; Set up stack pointer
    mov ebp, stack_top
    mov esp, ebp

    call test_multiboot
    call test_cpuid
    call test_long_mode

    call setup_page_tables
    call enable_paging

    ; load the 64-bit GDT
    lgdt [gdt64.pointer]

    call print_vendorid

    hlt

; prints the vendor id from cpuid
print_vendorid:
    mov eax, 0
    cpuid
    ; target buffer = vga
    mov edi, 0xb8000
    ; vendor id stored in ebx, edx, ecx
    call printdw
    mov ebx, edx
    call printdw
    mov ebx, ecx
    call printdw
    ret

; Prints a 4-character "string" in a double word
; parameter: edi - VGA buffer location (will be incremented by 8)
; parameter: ebx - "string"
printdw:
    call printw
    rol ebx, 16
    call printw
    rol ebx, 16
    ret

; Prints a 2-character "string" in a word
; parameters: edi - VGA buffer location (will be incremented by 4)
; parameters: bx - 16-bit word "string" as 'lh'
printw:
    .C equ 0xFC
    mov byte [edi + 3], .C
    mov byte [edi + 2], bh
    mov byte [edi + 1], .C
    mov byte [edi + 0], bl
    add edi, 4
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

setup_page_tables:
    ; map first P4 entry to P3 table
    mov eax, p3_table
    or eax, 0b11 ; writable|present
    mov [p4_table], eax

    ; map first P3 entry to P2 table
    mov eax, p2_table
    or eax, 0b11 ; writable|present
    mov [p3_table], eax

    ; identity-map each P2 entry to a huge 2MiB page
    mov ecx, 0 ; counter variable

.map_p2_table:
    ; map ecx'th P2 entry to a huge table that starts at address 2MiB*ecx
    mov eax, 0x200000  ; 2MiB
    imul eax, ecx      ; start address of ecx'th page
    or eax, 0b10000011 ; huge|writable|present
    mov [p2_table + ecx * 8], eax ; map ecx'th entry

    inc ecx            ; increase counter
    cmp ecx, 512       ; if counter==512, the whole P2 table is mapped
    jne .map_p2_table  ; else map the next entry

    ret

enable_paging:
    ; load P4 to cr3 register (cpu uses this to access the P4 table)
    mov eax, p4_table
    mov cr3, eax

    ; enable PAE-flag in c4 (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; set the long mode bit in the EFER MSR (model-specific register)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ;enable paging in the cr0 register
    mov eax, cr0
    or eax, 1 << 31
    or eax, 1 << 16
    mov cr0, eax

    ret

section .rodata
gdt64:
    dq 0 ; zero entry
    dq (1<<44) | (1<<47) | (1<<41) | (1<<43) | (1<<53) ; code segment
    dq (1<<44) | (1<<47) | (1<<41) ; data segment
.pointer:
    dw $ - gdt64 - 1
    dq gdt64

; Reserve space for stack
section .bss
align 4096
p4_table:
    resb 4096
p3_table:
    resb 4096
p2_table:
    resb 4096
stack_bottom:
    resb 64
stack_top:
