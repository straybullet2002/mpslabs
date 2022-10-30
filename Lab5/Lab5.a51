; !X | (Y & !Z)
; CP = L, P = H
;X	Y	Z	!X	!Z	Y&!Z	!X|Y&!Z
;0	0	0	1	1	0		1
;0	0	1	1	0	0		1
;0	1	0	1	1	1		1
;0	1	1	1	0	0		1
;1	0	0	0	1	0		0
;1	0	1	0	0	0		0
;1	1	0	0	1	1		1
;1	1	1	0	0	0		0
; Lab 5 var 14
; Вид обмена: Вывод 
; Режим работы: 3
; Скорость обмена: 110 бод
; Интервал: 1 секунда

		ORG		0000h
		JMP		INIT_VALUES
		ORG		000Bh
		JMP		TC0_Handler
		;ORG		001Bh
		;JMP		TC1_Handler
		;ORG		0023h
		;JMP		UART_Handler
		ORG		0030h
			
INIT_VALUES:
		MOV		DPTR, #8000h
		
		MOV		A, #10011000b
		MOVX	@DPTR, A
		INC		DPTR
		
		MOV		A, #10111010b
		MOVX	@DPTR, A
		INC		DPTR
		
		MOV		A, #01010100b
		MOVX	@DPTR, A
		INC		DPTR
		
		MOV		A, #01111110b
		MOVX	@DPTR, A
		INC		DPTR
		
START:
		MOV		SP, #25h
		CLR		09					; Флаг разрешения начала записи
		MOV		R0, #20
		MOV		IE, #10000010b		; Включение прерывания от TC0
		MOV		SCON, #11010000b	; Режим порта - 3
		MOV		TMOD, #00100001b	; Режим TC0 - 1 (16 бит), TC - 2 (auto-reload)
		ANL		PCON, #01111111b	; SMOD = 0 (без удвоения скорости)
		
		; 6 MHz
		MOV		TH0, #03Ch			; Переполнение TC0 через 50к тактов
		MOV		TL0, #0B0h
		; 12 MHz
		
		; 6 MHz
		MOV		TH1, #72h
		; 12 MHz
		;MOV		TH1, #0FEh			; Сброс параметров счётчика для обмена со скоростью 110 бод
		;MOV		TL1, #0EBh

		CLR		08					; Сброс флага работы с верхней половиной упакованных данных 
		MOV		0C0h, #00111111b	; P4.6 - переключение интервала, P4.7 - ошибка
		
		SETB	TR0
		SETB	TR1

RESTART:
		MOV		R5, #8d
		MOV		DPTR, #8000h
LOOP:
		JNB		09, $
		CLR		09
		
		CLR		0C0h.7
		CALL	NEXT_VALUE
				
		MOV		C, P
		CPL		C
		MOV		TB8, C				; Дополнение до нечётного числа единиц в байте
		MOV		SBUF, A
		JNB		TI, $
		CLR		TI
		DJNZ	R5, LOOP
		JMP		RESTART
		
NEXT_VALUE_HIGH:
		ANL		A, #00F0h			; A = HI(A)
		SWAP	A
		INC		DPTR
		JMP	NEXT_VALUE_CALC
NEXT_VALUE_LOW:
		ANL		A, #000Fh			; A = LO(A)
		JMP	NEXT_VALUE_CALC
NEXT_VALUE:
		MOVX	A, @DPTR
		JB		08, NEXT_VALUE_HIGH
		JMP	NEXT_VALUE_LOW
NEXT_VALUE_CALC:
		CPL		08
		CALL	CALC
		SWAP	A
		RET

CALC:
		CLR		C
		RRC		A					; C = Z
		MOV		00, C
		RRC		A					; C = Y
		MOV		01, C
		RRC		A					; C = X
		MOV		02, C
		RRC		A					; C = F (sample)
		MOV		03, C
		
		MOV		C, 01				;C=Y
		ANL 	C, /00				;C=Y * !Z
		ORL 	C, /02				;C=!X | (Y * !Z)
		
		JC		RES_IS_1
		JNB		03, RES_MATCH
		JMP		RES_NOT_MATCH		
RES_IS_1:
		JB		03, RES_MATCH
RES_NOT_MATCH:
		SETB	0C0h.7
RES_MATCH:
		RRC		A					; A = Rxyz_0000, C = 0
		RET
			
TC0_Handler:
		; С поправкой на +6 тактов
		; 6 MHz
		MOV		TH0, #09Eh
		MOV		TL0, #05Eh
		; 12 MHz
		;MOV		TH0, #03Ch
		;MOV		TL0, #0B6h
		DJNZ	R0, TC0_Out
		MOV		R0, #20
		SETB	09
		CPL		0C0h.6
TC0_Out:
		RETI
		
TC1_Handler:
		RETI

UART_Handler:
		CLR 	TI
		RETI
		
		END
			