; gosh do I love hardcoding constants that could change at any time
CURL_GLOBAL_SSL equ 1 ; curl.h from version 8.9.1 - line 2976
CURLOPT_VERBOSE equ 41 ; curl.h from version 8.9.1 - line 1257
CURLOPT_URL equ 10002 ; curl.h from version 8.9.1 - line 1114
CURLOPT_ERRORBUFFER equ 10010 ; curl.h from version 8.9.1 - line 1138
CURLOPT_HTTPHEADER equ 10023 ; curl.h from version 8.9.1 - line 1200
CURLOPT_WRITEDATA equ 10001 ; curl.h from version 8.9.1 - line 1111
CURLOPT_WRITEFUNCTION equ 20011 ; curl.h from version 8.9.1 - line 1142
CURL_ERROR_SIZE equ 256 ; curl.h from version 8.9.1 - line 847
CURLINFO_RESPONSE_CODE equ 2097154 ; curl.h from version 8.9.1 - line 2868

; from libcurl
extern curl_global_init
extern curl_easy_init
extern curl_easy_setopt
extern curl_slist_append
extern curl_slist_free_all
extern curl_easy_perform
extern curl_easy_getinfo
; from libc
extern snprintf
extern perror
extern puts
extern exit

section .bss
curl_error_buffer:
    resb CURL_ERROR_SIZE

UA_BUFFER_SIZE equ 512
user_agent_buffer:
    resb UA_BUFFER_SIZE

PW_BUFFER_SIZE equ 256
password_buffer:
    resb PW_BUFFER_SIZE

PING_API_BUFFER_SIZE equ 512
ping_api_url_buffer:
    resb PING_API_BUFFER_SIZE

section .data
perror_string:
    db 'curl', 0

ua_format:
    db 'User-Agent: asmlogin by Merethin, used by %s', 0

printf_err_msg:
    db 'snprintf', 0

ping_api_url:
    db 'https://www.nationstates.net/cgi-bin/api.cgi?nation=%s&q=ping', 0

password_header_format:
    db 'X-Password: %s', 0

section .text
global init_curl
init_curl:
    push rbp ; align the stack
    mov rdi, CURL_GLOBAL_SSL ; don't set CURL_GLOBAL_WIN32 because this is not WIN32-compatible
    call curl_global_init
    cmp ax, 0
    je .end
    mov rdi, perror_string
    call perror
    xor rdi, rdi
    mov dil, 1
    pop rbp ; align the stack
    jmp exit ; tail call return optimization
.end:
    pop rbp ; align the stack
    ret

dummy_write:
    mov rax, rdx
    ret

global get_handle
get_handle:
    push r12 ; callee-saved
    call curl_easy_init
    mov r12, rax ; save handle
    mov rdi, rax ; parameter 1: cURL handle
    mov rsi, CURLOPT_ERRORBUFFER ; parameter 2: CURLOPT_ERRORBUFFER
    mov rdx, curl_error_buffer ; parameter 3: pointer to our buffer
    call curl_easy_setopt
    cmp rax, 0
    jne .early_err
    mov rdi, r12 ; parameter 1: cURL handle
    mov rsi, CURLOPT_WRITEDATA ; parameter 2: CURLOPT_WRITEDATA
    xor rdx, rdx ; parameter 3: null
    call curl_easy_setopt
    cmp rax, 0
    jne .err
    mov rdi, r12 ; parameter 1: cURL handle
    mov rsi, CURLOPT_WRITEFUNCTION ; parameter 2: CURLOPT_WRITEFUNCTION
    mov rdx, dummy_write ; parameter 3: function that discards all the data
    call curl_easy_setopt
    cmp rax, 0
    jne .err
    mov rax, r12
    pop r12 ; restore
    ret
.err:
    mov rdi, curl_error_buffer
    call puts
.early_err:
    xor rdi, rdi
    mov dil, 1
    pop rbp ; align the stack
    jmp exit ; tail call return optimization

; rdi: nation name
; returns user agent in rax
global format_ua
format_ua:
    push rbp ; align the stack
    mov rcx, rdi ; first variadic arg (nation name)
    mov rdi, user_agent_buffer ; str (buffer)
    mov rsi, UA_BUFFER_SIZE ; size
    mov rdx, ua_format ; format
    xor rax, rax ; no floating point variadic args
    call snprintf
    cmp rax, 0
    jge .end ; if less than 0, printf error
    mov rdi, printf_err_msg
    call perror
    xor rdi, rdi
    mov dil, 1
    pop rbp ; align the stack
    jmp exit ; tail call return optimization
.end:
    mov rax, user_agent_buffer
    pop rbp ; align the stack
    ret

; rdi: curl handle, rsi: api url, rdx: user agent header, rcx: password header
perform_api_request:
    ; preserve these three and align the stack
    push r12
    push r13
    push rcx
    mov r12, rdi ; save handle
    mov r13, rsi ; save url
    xor rdi, rdi ; slist (null)
    mov rsi, rdx ; header
    call curl_slist_append
    cmp rax, 0
    je .err
    pop rcx
    push rbp
    mov rdi, rax ; slist (previous)
    mov rsi, rcx ; header
    call curl_slist_append
    cmp rax, 0
    je .err
    pop rbp
    push rax ; save slist
    mov rdi, r12 ; parameter 1: cURL handle
    mov rsi, CURLOPT_HTTPHEADER ; parameter 2: CURLOPT_HTTPHEADER
    mov rdx, rax ; parameter 3: slist
    call curl_easy_setopt
    mov rdi, r12 ; parameter 1: cURL handle
    mov rsi, CURLOPT_URL ; parameter 2: CURLOPT_URL
    mov rdx, r13 ; parameter 3: api url
    call curl_easy_setopt
    mov rdi, r12 ; parameter 1: cURL handle
    call curl_easy_perform
    cmp rax, 0
    jne .err
    pop rdi ; retrieve slist
    push rbp ; realign the stack
    call curl_slist_free_all
    pop rbp
    pop r13
    pop r12
    ret
.err:
    mov rdi, curl_error_buffer
    call puts
    xor rdi, rdi
    mov dil, 1
    pop rbp ; align the stack
    jmp exit ; tail call return optimization

; rdi: curl handle, rsi: nation name, rdx: user agent header, rcx: password
global ping_nation
ping_nation:
    push r12 ; save r12
    push r13 ; save r13
    push r14 ; save r14
    mov r12, rdi ; save curl handle
    mov r13, rdx ; save user agent
    mov r14, rcx ; save password
    mov rcx, rsi ; first variadic arg (nation name)
    mov rdi, ping_api_url_buffer ; str (buffer)
    mov rsi, PING_API_BUFFER_SIZE ; size
    mov rdx, ping_api_url ; format
    xor rax, rax ; no floating point variadic args
    call snprintf
    cmp rax, 0
    jl .err ; if less than 0, printf error
    mov rdi, password_buffer ; str (buffer)
    mov rsi, PW_BUFFER_SIZE ; size
    mov rdx, password_header_format ; format
    mov rcx, r14 ; first variadic arg (password)
    xor rax, rax ; no floating point variadic args
    call snprintf
    cmp rax, 0
    jl .err ; if less than 0, printf error
    mov rdi, r12 ; curl handle
    mov rsi, ping_api_url_buffer ; api url
    mov rdx, r13 ; user agent header
    mov rcx, password_buffer ; password
    pop r14 ; restore r14
    pop r13 ; restore r13
    pop r12 ; restore r12
    jmp perform_api_request ; tail call return optimization
.err:
    mov rdi, printf_err_msg
    call perror
    xor rdi, rdi
    mov dil, 1
    pop rbp ; align the stack, restoring the values doesn't really matter since we're terminating
    jmp exit ; tail call return optimization

; rdi: curl handle
global get_response_code
get_response_code:
    ; rdi already set
    mov rsi, CURLINFO_RESPONSE_CODE ; parameter 2: CURLINFO_RESPONSE_CODE
    sub rsp, 8 ; make some space
    mov rdx, rsp ; parameter 3
    call curl_easy_getinfo
    pop rax
    ret