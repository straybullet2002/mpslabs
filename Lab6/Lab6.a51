; Lab 6 Var 14
; VAREF, В		VAGND, В		T, мкс
;	 	 4			   2 		  4505

		ORG		0000h
		JMP		START
		ORG		0003h				; Вектор прерывания INT0
		JMP		INT0_Handler
		ORG		000Bh				; Вектор прерывания TC0
		JMP		TC0_Handler
		ORG		0053h				; Вектор прерывания АЦП
		JMP		AD_Handler
		ORG		0080h
			
		ADCON	EQU	0C5h
		ADCH	EQU	0C6h
		BUF_1	EQU	0Ah				; Байт для числа 1
		BUF_2	EQU	0Bh				; Байт для числа 2
		PWM0	EQU	0FCh
		PWM1	EQU	0FDh
		PWMP	EQU	0FEh
		DIG_1	EQU	0Ch				; Массив из трёх байт для десятичных цифр

	  MAIN_BUSY BIT	00
		AD_BUSY BIT	01
		TC_BUSY BIT 02
			
START:
		MOV		SP, #30h
		MOV		DPTR, #8000h
		; Fpwm = Fosc/(2*(1+PWMP)*255), где Fosc = 12МГц
		; Отсюда для заданного T = 4505 мкс = 1/Fpwm PWMP = 105d
		MOV		PWMP, #105d
		MOV		PWM0, #0FFh			; Пока нет вычислений, выдаётся уровень 0
		CLR		PSW.1
		CLR		PSW.0				; Выбор банка памяти 0
		MOV		0C0h, #01110111b
		
		; Настройка АЦП
		; 5 бит - ADEX = 0 запуск только программно
		; 3 бит - ADCS = 0 состояние АЦП - не запущен
		; младшие 3 бита - канал AADR
		ANL		ADCON, #11010000b

		MOV		IE, #11000011b		; Разрешение прерывания от АЦП, INT0, TC0
		MOV		TMOD, #00000001b	; TC0 в режиме таймера 16 бит, включение по TR0
		SETB	IT0					; INT0 по переходу 1/0

LOOP:
		JNB		MAIN_BUSY, $		; Флаг будет установлен прерыванием INT0
		CLR		EX0					; Запрещаем INT0
		
		MOV		R0, #08h			; Адрес номера первого канала
		CALL	Run_AD
		JB		AD_BUSY, $
		MOV		BUF_1, R3
			
		MOV		R0, #09h			; Адрес номера второго канала
		CALL	Run_AD
		JB		AD_BUSY, $
		MOV		BUF_2, R3
		
		CALL	Compare_Swap		; В @BUF_1 - большее значение
		CALL	Set_Error_Bit
		CALL	Convert_Digits

		MOV		R1, #3d				; Имеем 3 цифры
Display_Digit_Loop:		
		CALL	Display_Digit		; Вывод в ШИМ
		DEC		R0
		DJNZ	R1, Display_Digit_Loop
		
		MOV		PWM0, #0FFh
		CLR		0C0h.7
		CLR		MAIN_BUSY
		SETB	EX0					; Разрешаем INT0
		JMP		LOOP
			
INT0_Handler:
		MOV		R0, 0C0h			; R0 = P4
		MOV		A, R0
		ANL		A, #00000111b		; Номер первого канала АЦП
		MOV		08h, A
		
		MOV		A, R0
		ANL		A, #01110000b
		SWAP	A					; Номер второго канала АЦП
		MOV		09h, A
		
		SETB	MAIN_BUSY			; Вход в главный цикл		
		RETI			
			
AD_Handler:
		CALL	Read_AD_Exact		; Считываем точное значение из АЦП (2 байта в R1, R2)
		CALL	Store_AD_Exact		; Сохраняем содержимое регистров во внешнюю память
		
		MOV		A, R3				; Округлённое (1 байт) значение из АЦП
		
		CLR		AD_BUSY		
		RETI
		
Run_AD:
		MOV		A, ADCON
		XCHD	A, @R0				; Обмен младшими 4 битами с @R0 (номер канала)
		SETB	AD_BUSY
		MOV		ADCON, A			; Устанавливаем номер канала АЦП
		ORL		ADCON, #8d			; Запуск АЦП
		RET
		
Read_AD_Exact:
		MOV		A, ADCH				; A - старший байт результата преобразования
		RL		A
		RL		A
		MOV		R0, A				; R0 = 54321067
		
		ANL		A, #11111100b		; A = 54321067
		MOV		R2, A				; R2= 54321000
		MOV		A, ADCON
		ANL		A, #11000000b
		RL		A
		RL		A					; A = 000000XX	
		ADD		A, R2				; A = 543210XX
		MOV		R2, A
		
		MOV		A, R0
		ANL		A, #00000011b		; A = 00000067
		MOV		R1, A		
		
		MOV		R3, ADCH			; R3 - старший байт результата преобразования		
		RET
		
Store_AD_Exact:
		MOV		A, R1				; старший байт
		MOVX	@DPTR, A
		INC		DPTR
		
		MOV		A, R2				; младший байт
		MOVX	@DPTR, A
		INC		DPTR
		
		RET
		
Compare_Swap:
		CLR		C
		MOV		A, BUF_1
		SUBB	A, BUF_2			; Если @BUF_1 < @BUF_2, то C = 1
		JNC		Compare_Swap_Exit
		MOV		A, BUF_1
		XCH		A, BUF_2
		XCH		A, BUF_1
Compare_Swap_Exit:
		RET

Set_Error_Bit:
		CLR		C
		MOV		A, BUF_1			; @BUF_1 > @BUF_2
		SUBB	A, BUF_2
		; Для заданных границ (2В;4В) однобайтовое значение даёт точность в 2000/256=7,8125мВ
		; 255мв = 33d
		SUBB	A, #33d
		CPL		C
		MOV		0C0h.7, C
		RET

Convert_Digits:
		; Преобразование байта из BUF_1 в десятичное число
		; и сохранение каждой цифры в память начиная с DIG_1
		MOV		R0, #DIG_1
		MOV		A, BUF_1
		MOV		B, #10d
		DIV		AB
		MOV		@R0, B
		MOV		B, #10d
		DIV		AB
		INC		R0
		MOV		@R0, B
		INC		R0
		MOV		@R0, A		
		RET
		
Wait_Second:
		MOV		R2, #20d
		MOV		TH0, #03Ch
		MOV		TL0, #0B0h			; TH0+TL0 = 50k
		SETB	TC_BUSY
		SETB	TR0					; Запуск таймера TC0
		JB		TC_BUSY, $
		RET
		
TC0_Handler:
		DJNZ	R2, TC0_Reset
		CLR		TR0
		CLR		TC_BUSY
		RETI
TC0_Reset:
		MOV		TH0, #03Ch
		MOV		TL0, #0BAh			; Поправка к 0B0h на время входа в прерывние
		RETI		

Display_Digit:
		MOV		B, #255d
		MOV		A, @R0
		CJNE	A, #0, Duty_Cycle_Not_0
		MOV		A, #10d				; Если дана цифра 0, ставим скважность 10
Duty_Cycle_Not_0:		
		XCH		A, B				; A = 255, B = скважность
		DIV		AB
		CPL		A
		MOV		PWM0, A
		CALL	Wait_Second
		RET

		END