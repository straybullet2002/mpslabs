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
;Lab 4
;№ варианта		Параметры импульса		Таймер		Режим
;14				T = 1250	t = 430		TC1			2


		ORG		0000h
		LJMP	INIT_VALUES
		ORG		0003h				; Вектор прерывания INT0
		LJMP	INT_Handler
		ORG		001Bh				; Вектор прерывания TC1
		LJMP	TC_Handler
		ORG	0030h
		
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
		MOV		22h, #86d			; t = 430_000=250*86*20
		MOV		23h, #164d			; T-t = 820_000=250*164*20
		
		MOV		R3, 23h				; Длина внутреннего цикла
		MOV		R2, #20d			; Длина внешнего цикла
		
		MOV		IE, #10001001b		; Разрешаем прерывания от TC1 и INT0
		MOV		IP, #00001000b		; Приоритет TC1 высокий
		MOV		TMOD, #00100000b	; TC1 включение по TR1, таймер, в режиме 2
		MOV		TH1, #6d			; Срабатывание через 250 тактов
		MOV		TL1, TH1
		SETB	IT0					; INT0 по переходу 1/0		
		SETB	TR1					; Запуск TC1
		
		CLR		08					; Сброс флага работы с верхней половиной упакованных данных 
		MOV		0C0h, #01010000b	; Сброс каналов порта P4 (4 линия на вход, 6 для временной диаграммы, 7 - ошибка)
		
		ACALL	PROGRAM_RESTART
		ACALL	NEXT_VALUE
		AJMP	$
		
PROGRAM_RESTART:
		MOV		R5, #4				; Количество записей таблицы истинности/2
		MOV		DPTR, #8000h
		RET

NEXT_VALUE_HIGH:
		ANL		A, #00F0h			; A = HI(A)
		SWAP	A
		AJMP	NEXT_VALUE_CALC
NEXT_VALUE_LOW:
		ANL		A, #000Fh			; A = LO(A)
		AJMP	NEXT_VALUE_CALC
NEXT_VALUE:
		MOVX	A, @DPTR
		JB		08, NEXT_VALUE_HIGH
		AJMP	NEXT_VALUE_LOW
NEXT_VALUE_CALC:
		ACALL	CALC
		SWAP	A
		ACALL	DISPLAY
		RET

CALC:
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
		AJMP	RES_NOT_MATCH		
RES_IS_1:
		JB		03, RES_MATCH
RES_NOT_MATCH:
		SETB	0C0h.7
RES_MATCH:
		RRC		A					; A = Rxyz_0000, C = 0
		RET
		
DISPLAY:
		XRL		0C0h, A
		RET
		
TC_01:
		CPL		08					; Переключим флаг работы с верхней половиной упакованных данных  
		JB		08, TC_Call
		INC		DPTR
		DJNZ	R5, TC_Call
		ACALL	PROGRAM_RESTART		
TC_Call:
		ACALL	NEXT_VALUE
TC_Swap:
		MOV		R7, A				; Сохраним текущее значение A
		MOV		A, 22h
		XCH		A, 23h
		XCH		A, 22h
		MOV		R3, 22h				; Установим верное значение длины внутреннего цикла
		MOV		R7, A				; Восстановим A
TC_Exit:
		RETI
TC_Handler:
		DJNZ	R3, TC_Exit
		MOV		R3, 22h
		DJNZ	R2, TC_Exit
		MOV		R2, #20d		
		CPL		0C0h.6				; Переключим бит для временной диаграммы
		JB		0C0h.6, TC_01
		ANL		0C0h, #00010000b	; Очистим P4
		AJMP	TC_Swap
		
INT_High:
		CLR		39					;  24h = 0xxx_xxxx
		SWAP	A					; A = P4.4000_0000
		ORL		A, 24h				; A = P4.4xxx_xxxx
		AJMP	INT_Set
INT_Low:
		CLR		35					;  24h = xxxx_0xxx
		ORL		A, 24h				; A = xxxx_P4.4xxx
INT_Set:		
		MOVX	@DPTR, A
		MOV		A, R6				; Восстановим A
		;SETB	0C0h.4
		RETI
INT_Handler:
		MOV		R6, A				; Сохраним текущее значение A
		MOVX	A, @DPTR
		MOV		24h, A
		MOV		A, 0C0h				; A = P4
		ANL		A, #00010000b		; A = 000_P4.4_0000
		RR		A					; A = 0000_P4.4_000
		JB		08, INT_High
		AJMP	INT_Low

		END