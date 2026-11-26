VGA_MEM     equ 0xB8000
COR_HEADER  equ 0x1F        ; Branco brilhante sobre fundo azul
COR_LABEL   equ 0x0B        ; Ciano claro sobre preto
COR_VALOR   equ 0x0E        ; Amarelo sobre preto
COR_TEXTO   equ 0x07        ; Cinza claro sobre preto
COR_ASCII   equ 0x0A        ; Verde claro sobre preto

inicio:
    db 0xFA
    
    ; Limpa a tela inteira com fundo preto (0x00)
    mov edi, VGA_MEM
    mov al, 0
    mov ecx, 4000
    rep stosb

    ; Desenha a barra de título (Linha 0)
    mov edi, VGA_MEM
    mov ecx, 80
.barra_topo:
    mov al, ' '
    mov [edi], al
    mov al, COR_HEADER
    mov [edi+1], al
    add edi, 2
    sub ecx, 1
    jnz .barra_topo

    mov esi, str_titulo
    mov edi, VGA_MEM
    add edi, 4
    mov bl, COR_HEADER
    call print_str

    ; Desenha rótulos fixos na tela
    mov esi, str_rtc
    mov edi, 0xB8140        ; Linha 2, Coluna 0 (0xB8000 + 2*160)
    mov bl, COR_LABEL
    call print_str

    mov esi, str_kbd
    mov edi, 0xB8280        ; Linha 4, Coluna 0 (0xB8000 + 4*160)
    mov bl, COR_LABEL
    call print_str

    mov esi, str_mem_hdr
    mov edi, 0xB8460        ; Linha 7, Coluna 0 (0xB8000 + 7*160)
    mov bl, COR_HEADER
    call print_str

    mov esi, str_ajuda
    mov edi, 0xB8F00        ; Linha 24, Coluna 0 (0xB8000 + 24*160)
    mov bl, COR_LABEL
    call print_str

; =========================================================================
; LOOP PRINCIPAL DE ATUALIZAÇÃO EM TEMPO REAL
; =========================================================================
.loop_principal:
    ; 1. Lê e imprime Hora (RTC CMOS porta 0x70 / 0x71)
    mov edi, 0xB8140
    add edi, 32             ; Coluna 16

    mov al, 0x04            ; Registrador CMOS: Horas
    call ler_cmos
    mov bl, COR_VALOR
    call print_hex8
    mov al, ':'
    call print_char

    mov al, 0x02            ; Registrador CMOS: Minutos
    call ler_cmos
    call print_hex8
    mov al, ':'
    call print_char

    mov al, 0x00            ; Registrador CMOS: Segundos
    call ler_cmos
    call print_hex8

    mov al, ' '
    call print_char
    mov al, ' '
    call print_char

    mov al, 0x07            ; Registrador CMOS: Dia
    call ler_cmos
    call print_hex8
    mov al, '/'
    call print_char

    mov al, 0x08            ; Registrador CMOS: Mês
    call ler_cmos
    call print_hex8
    mov al, '/'
    call print_char

    mov al, 0x09            ; Registrador CMOS: Ano
    call ler_cmos
    call print_hex8

    ; 2. Imprime Status e Último Scancode do Teclado
    mov edi, 0xB8280
    add edi, 32
    mov bl, COR_VALOR

    in al, 0x64             ; Porta de status PS/2
    call print_hex8

    add edi, 24             ; Pula para o campo Scancode
    mov al, [ultimo_scan]
    call print_hex8

    ; 3. Desenha o Hex Dump de 128 bytes (8 linhas x 16 bytes)
    call desenhar_hexdump

    ; 4. Verifica se há tecla pressionada
    in al, 0x64
    test al, 1
    jz .loop_principal      ; Sem tecla, continua atualizando ao vivo

    in al, 0x60             ; Lê scancode
    mov [ultimo_scan], al

    cmp al, 0x01            ; ESC -> Sai para o shell
    jz .sair

    cmp al, 0x11            ; Tecla 'W' -> Sobe endereço (-16 bytes)
    jnz .checa_s
    mov eax, [addr_dump]
    sub eax, 16
    mov [addr_dump], eax
    jmp .loop_principal

.checa_s:
    cmp al, 0x1F            ; Tecla 'S' -> Desce endereço (+16 bytes)
    jnz .loop_principal
    mov eax, [addr_dump]
    add eax, 16
    mov [addr_dump], eax
    jmp .loop_principal

.sair:
    ; Limpa tela antes de voltar ao shell
    mov edi, VGA_MEM
    mov al, 0
    mov ecx, 4000
    rep stosb

    db 0xFB
    ret

; =========================================================================
; SUB-ROTINAS DO MONITOR
; =========================================================================

; Lê registrador CMOS em AL -> retorna valor em AL
ler_cmos:
    out 0x70, al
    in al, 0x71
    ret

; Desenha 8 linhas de 16 bytes a partir de [addr_dump]
desenhar_hexdump:
    mov esi, [addr_dump]    ; Endereço atual de leitura na RAM
    mov edi, 0xB85A0        ; Linha 9 da VGA (0xB8000 + 9*160)
    mov ecx, 8              ; 8 linhas

.linha:
    push ecx
    push edi                ; Salva início da linha na VGA

    ; Imprime o endereço de 32 bits (ex: 00020000:)
    mov eax, esi
    mov bl, COR_LABEL
    call print_hex32
    mov al, ':'
    call print_char
    mov al, ' '
    call print_char

    ; Imprime 16 bytes em Hexadecimal
    mov ecx, 16
    push esi                ; Salva ponteiro da RAM para o painel ASCII
.byte_hex:
    mov al, [esi]
    mov bl, COR_TEXTO
    call print_hex8
    mov al, ' '
    call print_char
    add esi, 1
    sub ecx, 1
    jnz .byte_hex

    ; Imprime coluna ASCII ao lado (16 caracteres)
    pop esi                 ; Restaura ponteiro da RAM desta linha
    mov al, '|'
    mov bl, COR_LABEL
    call print_char

    mov ecx, 16
.byte_ascii:
    mov al, [esi]
    cmp al, 32              ; Caractere imprimível (>= 32 e <= 126)?
    jl .nao_imprimivel
    cmp al, 126
    jg .nao_imprimivel
    jmp .imprime_asc
.nao_imprimivel:
    mov al, '.'             ; Substitui bytes de controle por '.'
.imprime_asc:
    mov bl, COR_ASCII
    call print_char
    add esi, 1
    sub ecx, 1
    jnz .byte_ascii

    mov al, '|'
    mov bl, COR_LABEL
    call print_char

    pop edi
    add edi, 160            ; Avança para a próxima linha da VGA (80 * 2)
    pop ecx
    sub ecx, 1
    jnz .linha
    ret

; Imprime caractere em AL com cor em BL na posição EDI (avança EDI em 2)
print_char:
    mov [edi], al
    mov [edi+1], bl
    add edi, 2
    ret

; Imprime string terminada em 0 (ESI) com cor BL na posição EDI
print_str:
.next:
    mov al, [esi]
    cmp al, 0
    jz .fim
    call print_char
    add esi, 1
    jmp .next
.fim:
    ret

; Imprime byte em AL como 2 dígitos Hex (cor BL)
print_hex8:
    push eax
    shr al, 4               ; Nibble alto
    call .nibble
    pop eax
    and al, 0x0F            ; Nibble baixo
    call .nibble
    ret
.nibble:
    cmp al, 10
    jl .digito
    add al, 55              ; 'A' (65) - 10 = 55
    jmp .out
.digito:
    add al, 48              ; '0' (48)
.out:
    call print_char
    ret

; Imprime valor de 32 bits em EAX como 8 dígitos Hex
print_hex32:
    push eax
    shr eax, 24
    call print_hex8
    pop eax

    push eax
    shr eax, 16
    call print_hex8
    pop eax

    push eax
    shr eax, 8
    call print_hex8
    pop eax

    call print_hex8
    ret

; =========================================================================
; DADOS E VARIÁVEIS
; =========================================================================
addr_dump:   dd 0x00020000  ; Começa inspecionando o próprio programa na RAM!
ultimo_scan: db 0

str_titulo:  db "FREEROOT OS - MONITOR DE HARDWARE & RAM (RING 0)", 0
str_rtc:     db "RTC CMOS (UTC):", 0
str_kbd:     db "KBD Status:      Scancode:", 0
str_mem_hdr: db "ENDERECO  00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F  ASCII", 0
str_ajuda:   db "[W/S] Navegar RAM (+/- 16 bytes)   [ESC] Voltar ao Shell", 0
