; from net.asm
extern init_curl
extern get_handle
extern format_ua
extern ping_nation
extern get_response_code
; from libcurl
extern curl_global_cleanup
; from libc
extern exit
extern fgets
extern fopen
extern fclose
extern strtok
extern printf
extern perror
extern sleep
extern puts

section .bss
FGETS_BUF_SIZE equ 512
fgets_buffer:
    resb FGETS_BUF_SIZE

section .data
ping_format:
    db 'Pinged nation %s', 10, 0

http_error_format:
    db 'Failed to ping nation %s: HTTP Error %d', 10, 0

delim:
    db ',', 10, 0

fopen_mode:
    db 'r', 0

fopen_err:
    db 'fopen', 0

argerr_string:
    db 'asmlogin requires 2 arguments: asmlogin nation_name nation_list', 0

section .text
global main
main:
    push r12
    push r13
    push r14
    cmp rdi, 3
    jl .argerr
    mov r13, [rsi+8] ; nation name
    mov r14, [rsi+16] ; nation list
    call init_curl
    call get_handle
    mov r12, rax ; save curl handle
    mov rdi, r13 ; argument 1: nation name
    call format_ua
    mov rdi, r14 ; argument 1: nation list file
    mov rsi, r12 ; argument 2: curl handle
    mov rdx, rax ; argument 3: user agent
    call run_nations_file
    call curl_global_cleanup
    xor rax, rax
    pop r14
    pop r13
    pop r12
    ret
.argerr:
    mov rdi, argerr_string
    call puts
    xor rdi, rdi
    mov dil, 1
    add rsp, 24
    jmp exit

; rdi: file to read from, rsi: curl handle, rdx: user agent header
read_nation_and_ping:
    push rbp ; dummy
    push r12 ; save r12
    push r13 ; save r13
    push r14 ; save r14
    push rdi ; save file
    mov r12, rsi ; save curl handle
    mov r13, rdx ; save user agent
    mov rdi, fgets_buffer
    mov rsi, FGETS_BUF_SIZE
    pop rdx ; pull file
    push rbp ; realign stack
    call fgets ; read one line
    test rax, rax
    jz .eof
    mov rdi, fgets_buffer
    mov rsi, delim
    call strtok
    test rax, rax
    jz .eof
    mov r14, rax ; save nation name
    xor rdi, rdi ; str is null, strtok should reuse the same one
    mov rsi, delim
    call strtok
    test rax, rax
    jz .eof
    mov rdi, r12 ; argument 1: curl handle
    mov rsi, r14 ; argument 2: nation name
    mov rdx, r13 ; argument 3: user agent header
    mov rcx, rax ; argument 4: nation password
    call ping_nation
    mov rdi, r12 ; curl handle
    call get_response_code
    cmp rax, 200
    je .http_ok
    mov rdi, http_error_format ; format string
    mov rsi, r14 ; nation name
    mov rdx, rax ; response code
    call printf
    jmp .eof
.http_ok:
    mov rdi, ping_format
    mov rsi, r14 ; nation name
    call printf
    xor rax, rax
    jmp .end
.eof:
    mov ax, 1
.end:
    pop rbp
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

; rdi: file path, rsi: curl handle, rdx: user agent header
run_nations_file:
    push r12 ; save r12
    push r13 ; save r13
    push r14 ; save r14
    mov r12, rsi ; save curl handle
    mov r13, rdx ; save user agent
    ; rdi already set
    mov rsi, fopen_mode
    call fopen
    test rax, rax
    jz .err
    mov r14, rax
.loop:
    mov rdi, r14 ; argument 1: file handle
    mov rsi, r12 ; argument 2: curl handle
    mov rdx, r13 ; argument 3: user agent header
    call read_nation_and_ping
    test rax, rax
    jnz .end ; eof? break and return
.sleep: ; make sure to comply with API rate limits! we go 1s for safety.
    mov rdi, 1
    call sleep
    cmp ax, 0
    jne .sleep ; if interrupted, sleep again
    jmp .loop
.end:
    pop r14
    pop r13
    pop r12
    ret
.err:
    mov rdi, fopen_err
    call perror
    xor rdi, rdi
    mov dil, 1
    add rsp, 24
    jmp exit