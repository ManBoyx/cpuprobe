# cpuprobe.s : sonde CPU en x86-64 pur, sans libc.
#
#   as --64 cpuprobe.s -o cpuprobe.o && ld cpuprobe.o -o cpuprobe && ./cpuprobe
#
# Tout passe par cpuid et les syscalls Linux (write = 1, exit = 60).
# Convention interne : r12-r15 et rbx tiennent l'état de _start, les
# routines en dessous ne les touchent pas mais écrasent le reste.

.intel_syntax noprefix
.globl _start

.equ BENCH_ITERS, 100000000

.macro feat reg, bit, name
    .byte \reg, \bit
    .asciz "\name"
.endm

.section .rodata

s_titre:    .asciz "cpuprobe : x86-64, syscalls directs, zéro libc\n\n"
s_vendor:   .asciz "vendeur    : "
s_modele:   .asciz "modèle     : "
s_sig:      .asciz "signature  : "
s_fam:      .asciz "famille    : "
s_mod:      .asciz "   modèle : "
s_step:     .asciz "   stepping : "
s_flags:    .asciz "flags      : "
s_wrap:     .asciz "\n             "
s_bench:    .asciz "bench      : "
s_ticks:    .asciz " ticks TSC pour 100000000 imul chaînés\n"
s_perop:    .asciz "             soit "
s_perop2:   .asciz " ticks TSC par imul (latence 3 cycles attendue)\n"
s_nl:       .asciz "\n"
s_sp:       .asciz " "
s_dot:      .asciz "."
s_zero:     .asciz "0"
hexdigits:  .ascii "0123456789abcdef"

# Table des flags : registre (0 = leaf1 edx, 1 = leaf1 ecx, 2 = leaf7 ebx),
# numéro de bit, nom. Terminée par un octet 0xFF.
feat_table:
    feat 0, 0,  "fpu"
    feat 0, 4,  "tsc"
    feat 0, 5,  "msr"
    feat 0, 8,  "cx8"
    feat 0, 9,  "apic"
    feat 0, 15, "cmov"
    feat 0, 23, "mmx"
    feat 0, 24, "fxsr"
    feat 0, 25, "sse"
    feat 0, 26, "sse2"
    feat 0, 28, "htt"
    feat 1, 0,  "sse3"
    feat 1, 1,  "pclmulqdq"
    feat 1, 9,  "ssse3"
    feat 1, 12, "fma"
    feat 1, 13, "cx16"
    feat 1, 19, "sse4.1"
    feat 1, 20, "sse4.2"
    feat 1, 22, "movbe"
    feat 1, 23, "popcnt"
    feat 1, 25, "aes"
    feat 1, 26, "xsave"
    feat 1, 28, "avx"
    feat 1, 29, "f16c"
    feat 1, 30, "rdrand"
    feat 2, 3,  "bmi1"
    feat 2, 5,  "avx2"
    feat 2, 8,  "bmi2"
    feat 2, 9,  "erms"
    feat 2, 16, "avx512f"
    feat 2, 18, "rdseed"
    feat 2, 19, "adx"
    feat 2, 29, "sha"
    .byte 0xFF

.section .data

feat_regs:  .long 0, 0, 0
vendor:     .space 12
            .byte 0
brand:      .space 48
            .byte 0

.section .text

# write_n : rsi = buffer, rdx = longueur
write_n:
    mov eax, 1
    mov edi, 1
    syscall
    ret

# puts : rdi = chaîne terminée par 0, pas de saut de ligne ajouté
puts:
    mov rsi, rdi
    xor edx, edx
1:  cmp byte ptr [rsi + rdx], 0
    je 2f
    inc rdx
    jmp 1b
2:  call write_n
    ret

# print_dec : rdi = entier non signé
print_dec:
    sub rsp, 32
    lea r8, [rsp + 32]
    mov rsi, r8
    mov rax, rdi
    mov ecx, 10
1:  xor edx, edx
    div rcx
    add dl, '0'
    dec rsi
    mov [rsi], dl
    test rax, rax
    jnz 1b
    mov rdx, r8
    sub rdx, rsi
    call write_n
    add rsp, 32
    ret

# print_hex : rdi = valeur, esi = nombre de chiffres (1..16)
print_hex:
    sub rsp, 24
    mov word ptr [rsp], 0x7830          # "0x" en little-endian
    lea r9, [rip + hexdigits]
    mov rax, rdi
    mov ecx, 16
    sub ecx, esi
    shl ecx, 2
    rol rax, cl                         # aligne les chiffres voulus en haut
    lea r8, [rsp + 2]
    mov r10d, esi
1:  rol rax, 4
    mov edx, eax
    and edx, 0xF
    mov dl, [r9 + rdx]
    mov [r8], dl
    inc r8
    dec r10d
    jnz 1b
    mov rdx, r8
    sub rdx, rsp
    mov rsi, rsp
    call write_n
    add rsp, 24
    ret

_start:
    lea rdi, [rip + s_titre]
    call puts

    # leaf 0 : plus haute feuille standard + chaîne vendeur (ebx, edx, ecx)
    xor eax, eax
    cpuid
    mov r15d, eax
    lea rdi, [rip + vendor]
    mov [rdi], ebx
    mov [rdi + 4], edx
    mov [rdi + 8], ecx
    lea rdi, [rip + s_vendor]
    call puts
    lea rdi, [rip + vendor]
    call puts
    lea rdi, [rip + s_nl]
    call puts

    # feuilles 0x80000002..4 : nom commercial, 3 x 16 octets
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000004
    jb .Lpas_de_nom
    lea rdi, [rip + brand]
    mov esi, 0x80000002
1:  mov eax, esi
    cpuid
    mov [rdi], eax
    mov [rdi + 4], ebx
    mov [rdi + 8], ecx
    mov [rdi + 12], edx
    add rdi, 16
    inc esi
    cmp esi, 0x80000004
    jbe 1b
    lea rdi, [rip + s_modele]
    call puts
    lea rdi, [rip + brand]
2:  cmp byte ptr [rdi], ' '             # Intel aligne à droite avec des espaces
    jne 3f
    inc rdi
    jmp 2b
3:  call puts
    lea rdi, [rip + s_nl]
    call puts
.Lpas_de_nom:

    # leaf 1 : signature + flags ; leaf 7 : flags étendus
    mov eax, 1
    cpuid
    mov [rip + feat_regs], edx
    mov [rip + feat_regs + 4], ecx
    mov r12d, eax
    cmp r15d, 7
    jb 1f
    mov eax, 7
    xor ecx, ecx
    cpuid
    mov [rip + feat_regs + 8], ebx
1:

    lea rdi, [rip + s_sig]
    call puts
    mov edi, r12d
    mov esi, 8
    call print_hex
    lea rdi, [rip + s_nl]
    call puts

    # décodage famille / modèle : les champs étendus ne comptent que
    # si la famille de base vaut 0xF (famille) ou 6 / 0xF (modèle)
    mov ecx, r12d
    shr ecx, 8
    and ecx, 0xF
    mov r13d, ecx
    cmp ecx, 0xF
    jne 1f
    mov edx, r12d
    shr edx, 20
    and edx, 0xFF
    add r13d, edx
1:  mov r14d, r12d
    shr r14d, 4
    and r14d, 0xF
    cmp ecx, 6
    je 2f
    cmp ecx, 0xF
    jne 3f
2:  mov edx, r12d
    shr edx, 12
    and edx, 0xF0
    add r14d, edx
3:  mov ebx, r12d
    and ebx, 0xF

    lea rdi, [rip + s_fam]
    call puts
    mov edi, r13d
    call print_dec
    lea rdi, [rip + s_mod]
    call puts
    mov edi, r14d
    call print_dec
    lea rdi, [rip + s_step]
    call puts
    mov edi, ebx
    call print_dec
    lea rdi, [rip + s_nl]
    call puts

    # flags : on parcourt la table, chaque entrée a une taille variable
    lea rdi, [rip + s_flags]
    call puts
    lea r13, [rip + feat_table]
    xor r14d, r14d
.Lflag:
    movzx eax, byte ptr [r13]
    cmp eax, 0xFF
    je .Lflags_fin
    movzx ecx, byte ptr [r13 + 1]
    lea rdx, [r13 + 2]
    mov rsi, rdx
1:  cmp byte ptr [rsi], 0
    je 2f
    inc rsi
    jmp 1b
2:  lea r13, [rsi + 1]
    lea r8, [rip + feat_regs]
    mov eax, [r8 + rax * 4]
    bt eax, ecx
    jnc .Lflag
    mov rdi, rdx
    call puts
    lea rdi, [rip + s_sp]
    call puts
    inc r14d
    test r14d, 7
    jnz .Lflag
    lea rdi, [rip + s_wrap]
    call puts
    jmp .Lflag
.Lflags_fin:
    lea rdi, [rip + s_nl]
    call puts
    lea rdi, [rip + s_nl]
    call puts

    # bench : chaîne de dépendances sur imul, donc on mesure la latence
    # et pas le débit. lfence garde rdtsc dans l'ordre.
    lfence
    rdtsc
    shl rdx, 32
    or rax, rdx
    mov r12, rax
    mov eax, 3
    mov ecx, BENCH_ITERS
1:  imul rax, rax, 3
    dec ecx
    jnz 1b
    lfence
    rdtsc
    shl rdx, 32
    or rax, rdx
    sub rax, r12
    mov r12, rax

    lea rdi, [rip + s_bench]
    call puts
    mov rdi, r12
    call print_dec
    lea rdi, [rip + s_ticks]
    call puts

    # ticks par itération en virgule fixe, 2 décimales
    imul rax, r12, 100
    xor edx, edx
    mov ecx, BENCH_ITERS
    div rcx
    xor edx, edx
    mov ecx, 100
    div rcx
    mov r13d, edx
    mov r14, rax
    lea rdi, [rip + s_perop]
    call puts
    mov rdi, r14
    call print_dec
    lea rdi, [rip + s_dot]
    call puts
    cmp r13d, 10
    jae 1f
    lea rdi, [rip + s_zero]
    call puts
1:  mov edi, r13d
    call print_dec
    lea rdi, [rip + s_perop2]
    call puts

    mov eax, 60
    xor edi, edi
    syscall
