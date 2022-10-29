; Lab 3 variant 14
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
;Lab 3 variant 14
;№ варианта		Параметры импульса		Источники прерываний
;14				T = 1250	t = 430		INT0	ПИ


		ORG		0000h
		LJMP	INIT_VALUES
		ORG		0003h				; Переход на обработчик INT0
		LJMP	INT0_HANDLER
		ORG		000Bh				; Переход на обработчик ПИ
		LJMP	TC0_HANDLER
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
		MOV		IE, #10000011b	; Разрешаем прерывания INT0 и TC0
		MOV		IP, #00000010b	; Приоритет INT0 = 0, TC0 = 1
		SETB	IT0				; INT0 по переходу 1/0
		MOV		TMOD, #0110b	; TC0 работа по TR0 в режиме счётчика 2 (автосброс)
		MOV		TH0, #0FFh
		MOV		TL0, #0FFh
		SETB	TR0				; Включаем таймер

GAME_RESET:
		MOV		R5, #4			; Количество записей таблицы истинности/2
		MOV		DPTR, #8000h
		MOV		0C0h, #0		; Сброс каналов порта P4
LOOP:
		;CLR		0C0h.7			; Сбросим флаг признака ошибки
		CLR		08				; Сбросим флаг работы с верхними битами
		MOVX	A, @DPTR		; Считываем из внешней памяти упакованные данные
		MOV		R0, A
		ANL		A, #000Fh		; A = LO(A)
		ACALL	CALC
		SWAP	A
		ACALL	DISPLAY
		SETB	0C0h.5
		ACALL	DELAY_SIG_ON
		MOV		0C0h, #0
		ACALL	DELAY_SIG_OFF
		
		;CLR		0C0h.7			; Сбросим флаг признака ошибки
		SETB	08				; Установим флаг работы с верхними битами
		MOV		A, R0
		ANL		A, #00F0h		; A = HI(A)
		SWAP	A		
		ACALL	CALC
		SWAP	A
		ACALL	DISPLAY
		SETB	0C0h.5
		ACALL	DELAY_SIG_ON
		MOV		0C0h, #0
		ACALL	DELAY_SIG_OFF
		
		INC		DPTR
		DJNZ	R5, LOOP
		AJMP	GAME_RESET

CALC:
		RRC		A				; C = Z
		MOV		00, C
		RRC		A				; C = Y
		MOV		01, C
		RRC		A				; C = X
		MOV		02, C
		RRC		A				; C = F (sample)
		MOV		03, C
		
		MOV		C, 01			;C=Y
		ANL 	C, /00			;C=Y * !Z
		ORL 	C, /02			;C=!X | (Y * !Z)
		
		JC		RES_IS_1
		JNB		03, RES_MATCH
		AJMP	RES_NOT_MATCH
		
RES_IS_1:
		JB		03, RES_MATCH
RES_NOT_MATCH:
		SETB	0C0h.7
RES_MATCH:
		RRC		A				; A = Rxyz_0000, C = 0
		RET
		
DISPLAY:
		ANL		0C0h, #10000000b
		ORL		0C0h, A
		RET
		
DELAY_MS_OUTER:
		MOV		R2, #10
DELAY_MS_INNER:
		MOV		R3, B
		DJNZ	R3, $
		DJNZ	R2, DELAY_MS_INNER 
		DJNZ	R1, DELAY_MS_OUTER
		RET
		
DELAY_SIG_ON:
		MOV		R1, #215		; t/2 = 430/2
		MOV		B, #100
		AJMP	DELAY_MS_OUTER
DELAY_SIG_OFF:
		MOV		R1, #205		; (T-t)/2 = (1250-430)/2 = 410
		MOV		B, #200
		AJMP	DELAY_MS_OUTER
		

INT0_HIGH:
		ANL		A, #01111111b
		AJMP	INT0_OUT		
INT0_HANDLER:
		MOV		R6, A			; Сохраним текущее значение A
		MOVX	A, @DPTR
		JB		08, INT0_HIGH
		ANL		A, #11110111b
INT0_OUT:
		MOVX	@DPTR, A
		MOV		A, R6			; Восстановим значение A
		RETI
		
TC0_HIGH:
		ORL		A, #10000000b
		AJMP	TC0_OUT
TC0_HANDLER:
		MOV		R6, A			; Сохраним текущее значение A
		MOVX	A, @DPTR
		JB		08, TC0_HIGH
		ORL		A, #00001000b
TC0_OUT:
		MOVX	@DPTR, A
		MOV		A, R6			; Восстановим значение A
		RETI

GAMEOVER:	
		END