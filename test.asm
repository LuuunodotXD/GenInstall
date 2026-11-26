VGA_MEM     equ 0xB8000
LARGURA     equ 80
ALTURA      equ 25

inicio:
    ; Limpa a tela
    mov edi, VGA_MEM
    mov al, ' '
    mov ecx, 4000
    rep stosb

.loop:
    ; 1. Apaga a bola na posição atual: offset = (y * 80 + x) * 2
    mov eax, [pos_y]
    imul eax, LARGURA       ; EAX = y * 80 (usando imul!)
    add eax, [pos_x]        ; EAX = y * 80 + x
    imul eax, 2             ; EAX = offset em bytes
    mov edi, VGA_MEM
    add edi, eax
    mov al, ' '
    mov [edi], al

    ; 2. Atualiza posição (pos += vel)
    mov eax, [pos_x]
    add eax, [vel_x]
    mov [pos_x], eax

    mov eax, [pos_y]
    add eax, [vel_y]
    mov [pos_y], eax

    ; 3. Checa colisão horizontal (0 <= x < 80)
    mov eax, [pos_x]
    cmp eax, 0
    jg .checa_dir
    mov eax, 0
    mov [pos_x], eax
    mov eax, [vel_x]
    neg eax                 ; Inverte velocidade X com sinal!
    mov [vel_x], eax
    jmp .checa_y

.checa_dir:
    cmp eax, 79
    jl .checa_y
    mov eax, 79
    mov [pos_x], eax
    mov eax, [vel_x]
    neg eax                 ; Inverte velocidade X
    mov [vel_x], eax

    ; 4. Checa colisão vertical (0 <= y < 25)
.checa_y:
    mov eax, [pos_y]
    cmp eax, 0
    jg .checa_baixo
    mov eax, 0
    mov [pos_y], eax
    mov eax, [vel_y]
    neg eax                 ; Inverte velocidade Y
    mov [vel_y], eax
    jmp .desenhar

.checa_baixo:
    cmp eax, 24
    jl .desenhar
    mov eax, 24
    mov [pos_y], eax
    mov eax, [vel_y]
    neg eax                 ; Inverte velocidade Y
    mov [vel_y], eax

    ; 5. Desenha a bola na nova posição
.desenhar:
    mov eax, [pos_y]
    imul eax, LARGURA
    add eax, [pos_x]
    imul eax, 2
    mov edi, VGA_MEM
    add edi, eax
    mov al, 'O'
    mov [edi], al
    mov al, 0x0E            ; Amarelo brilhante
    mov [edi+1], al

    ; 6. Pequeno delay + checa se apertou ESC para sair
    mov ecx, 0x150000
.delay:
    in al, 0x64
    test al, 1              ; Testa bit de tecla sem alterar AL!
    jz .continua_delay
    in al, 0x60
    cmp al, 0x01            ; ESC?
    jz .sair
.continua_delay:
    sub ecx, 1
    jnz .delay

    jmp .loop

.sair:
    ret

; --- Variáveis de 32 bits (dd) ---
pos_x: dd 10
pos_y: dd 5
vel_x: dd 1
vel_y: dd 1
