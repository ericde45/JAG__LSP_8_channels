; replay module amiga 8 voies
;
; - passer à 8 voies modules
; - passer à 2 x lecture LSP
; - remplacer la double lecture de R15 par lecture successive directe







	include	"jaguar.inc"


CLEAR_BSS=1

;---------------------
; DSP
DSP_STACK_SIZE	equ	32	; long words
DSP_USP			equ		(D_ENDRAM-(4*DSP_STACK_SIZE))
DSP_ISP			equ		(DSP_USP-(4*DSP_STACK_SIZE))
LSP_DSP_Audio_frequence					.equ			26000				; real hardware needs lower sample frequencies than emulators 
nb_bits_virgule_offset					.equ			11					; 11 ok DRAM/ 8 avec samples en ram DSP
DSP_DEBUG						.equ			0
LSP_avancer_module				.equ			1								; 1=incremente position dans le module
channel_0		.equ		1
channel_1		.equ		1
channel_2		.equ		1
channel_3		.equ		1
channel_4		.equ		1
channel_5		.equ		1
channel_6		.equ		1
channel_7		.equ		1
;DSP_diviseur_volume_module			.equ			2					; shift le volume
; DSP
;---------------------







.opt "~Oall"

.text

			.68000


	move.l		#$70007,G_END
	move.l		#$70007,D_END
	move.l		#INITSTACK-128, sp	


; clear BSS
	.if			CLEAR_BSS=1
	lea			DEBUT_BSS,a0
	lea			FIN_RAM,a1
	moveq		#0,d0
	
boucle_clean_BSS:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS
; clear stack
	lea			INITSTACK-100,a0
	lea			INITSTACK,a1
	moveq		#0,d0
	
boucle_clean_BSS2:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS2
	.endif

; init malloc
	move.l		#FIN_RAM,pointeur_fin_de_RAM_actuel

;check ntsc ou pal:

	moveq		#0,d0
	move.w		JOYBUTS ,d0

	move.l		#26593900,frequence_Video_Clock			; PAL
	move.l		#415530,frequence_Video_Clock_divisee

	
	btst		#4,d0
	beq.s		jesuisenpal
jesuisenntsc:
	move.l		#26590906,frequence_Video_Clock			; NTSC
	move.l		#415483,frequence_Video_Clock_divisee
jesuisenpal:

; copie du code DSP dans la RAM DSP
	move.l	#0,D_CTRL

	lea		YM_DSP_debut,A0
	lea		D_RAM,A1
	move.l	#YM_DSP_fin-DSP_base_memoire,d0
	lsr.l	#2,d0
	sub.l	#1,D0
boucle_copie_bloc_DSP:
	move.l	(A0)+,(A1)+
	dbf		D0,boucle_copie_bloc_DSP


; init LSP - module
	move.l		#LSP_module_music_data_voies_1_a_4,pointeur_module_music_data
	move.l		#LSP_module_sound_bank,pointeur_module_sound_bank

	move.l		pointeur_module_music_data,a0
	move.l		pointeur_module_sound_bank,a1
	lea			LSPVars,a3
	moveq		#0,d7				; relocation a faire
	bsr			LSP_PlayerInit
	;move.l		m_lspInstruments,a0

; init module 2
	move.l		#LSP_module_music_data_voies_5_a_8,pointeur_module_music_data
	move.l		pointeur_module_music_data,a0
	move.l		pointeur_module_sound_bank,a1
	lea			LSPVars2,a3
	moveq		#0,d7				; relocation a faire
	bsr			LSP_PlayerInit
	


; launch DSP
	move.l	#REGPAGE,D_FLAGS
	move.l	#DSP_routine_init_DSP,D_PC
	move.l	#DSPGO,D_CTRL



main:
	bra.s		main




; ------------------------------------
;          LSP
; ------------------------------------


; ------------------------------------
; Init

LSP_PlayerInit:
; a0: music data (any mem)
; a1: sound bank data (chip mem)
; (a2: 16bit DMACON word address)

;		Out:a0: music BPM pointer (16bits)
;			d0: music len in tick count

; input :
;			A3 = lspvars
;			D7 = flag relocation des samples : 0=pas fait / -1=fait


			cmpi.l		#'LSP1',(a0)+
			bne			.dataError
			move.l		(a0)+,d0		; unique id
			;cmp.l		(a1),d0			; check that sample bank is this one
			;bne			.dataError

			cmpi.w		#$0105,(a0)+			; minimal major & minor version of latest compatible LSPConvert.exe		 = V 1.05
			blt			.dataError

			moveq		#0,d6
			move.w		(a0)+,d6
			move.l		d6,m_currentBpm-LSPVars(a3)		; default BPM
			move.l		d6,LSP_BPM_frequence_replay
			move.w		(a0)+,d6
			move.l		d6,m_escCodeRewind-LSPVars(a3)		; tout en .L
			move.w		(a0)+,d6
			move.l		d6,m_escCodeSetBpm-LSPVars(a3)
			move.l		(a0)+,-(a7)							; nb de ticks du module en tout = temps de replay ( /BPM)
			;move.l	a2,m_dmaconPatch(a3)
			;move.w	#$8000,-1(a2)			; Be sure DMACon word is $8000 (note: a2 should be ODD address)
			moveq		#0,d0
			move.w		(a0)+,d0				; instrument count
			lea			-12(a0),a2				; LSP data has -12 offset on instrument tab ( to win 2 cycles in fast player :) )
			move.l		a2,m_lspInstruments-LSPVars(a3)	; instrument tab addr ( minus 4 )
			subq.w		#1,d0
			move.l		a1,d1

.relocLoop:	
			;bset.b		#0,3(a0)				; bit0 is relocation done flag
			;bne.s		.relocated
			btst		#1,d7
			bne.s		.relocated
			
			move.l		(a0),d5					; pointeur sample
			add.l		d1,d5					; passage de relatif en absolu
			;lsl.l		#nb_bits_virgule_offset,d6
			move.l		d5,(a0)					; pointeur sample

			
			moveq		#0,d6
			move.w		4(a0),d6				; taille en words
			add.l		d6,d6
			move.w		d6,4(a0)				; taille en bytes

			move.l		(a0),a4					
			

			move.l		6(a0),d6					; pointeur sample repeat
			add.l		d1,d6					; passage de relatif en absolu
			cmp.l		d5,d6					; corrige pointeur de repeat avant le debut de l'instrument
			bge.s		.ok_loop
			move.l		d5,d6
.ok_loop:
			;lsl.l		#nb_bits_virgule_offset,d6
			move.l		d6,6(a0)					; pointeur sample repeat
			
			moveq		#0,d6
			move.w		10(a0),d6				; taille repeat en words
			add.l		d6,d6
			move.w		d6,10(a0)				; taille repeat en bytes

.relocated:	
			lea			12(a0),a0
			dbf.w		d0,.relocLoop
		
			move.w		(a0)+,d0				; codes count (+2)
			move.l		a0,m_codeTableAddr-LSPVars(a3)	; code table
			add.w		d0,d0
			add.w		d0,a0
			move.l		(a0)+,d0				; word stream size
			move.l		(a0)+,d1				; byte stream loop point
			move.l		(a0)+,d2				; word stream loop point

			move.l		a0,m_wordStream-LSPVars(a3)
			lea			0(a0,d0.l),a1			; byte stream
			move.l		a1,m_byteStream-LSPVars(a3)
			add.l		d2,a0
			add.l		d1,a1
			move.l		a0,m_wordStreamLoop-LSPVars(a3)
			move.l		a1,m_byteStreamLoop-LSPVars(a3)
			;bset.b		#1,$bfe001				; disabling this fucking Low pass filter!!
			lea			m_currentBpm-LSPVars(a3),a0
			move.l		(a7)+,d0				; music len in frame ticks
			rts

.dataError:	illegal




;-------------------------------------
;
;     DSP
;
;-------------------------------------

	.phrase
YM_DSP_debut:

	.dsp
	.org	D_RAM
DSP_base_memoire:

; CPU interrupt
	.rept	8
		nop
	.endr
; I2S interrupt = #F1B060
	movei	#DSP_LSP_routine_interruption_I2S,r28						; 6 octets
	movei	#D_FLAGS,r30											; 6 octets
	jump	(r28)													; 2 octets
	load	(r30),r29	; read flags								; 2 octets = 16 octets
; Timer 1 interrupt = #F1B30E
	movei	#DSP_LSP_routine_interruption_Timer1,r12						; 6 octets
	movei	#D_FLAGS,r16											; 6 octets
	jump	(r12)													; 2 octets
	load	(r16),r13	; read flags								; 2 octets = 16 octets
; Timer 2 interrupt	 = #F1B818
	movei	#DSP_LSP_routine_interruption_Timer2,r12						; 6 octets
	movei	#D_FLAGS,r16											; 6 octets
	jump	(r12)													; 2 octets
	load	(r16),r13	; read flags								; 2 octets = 16 octets
; External 0 interrupt
	.rept	8
		nop
	.endr
; External 1 interrupt
	.rept	8
		nop
	.endr













; -------------------------------
; DSP : routines en interruption
; -------------------------------
; utilisés : 	R29/R30/R31
; 				R15/ R18/R19/R20/R21/R22/R23/R24/R25/R26/R27/R28
;				


; I2S : replay sample
;	- version simple, lit un octet à chaque fois
;	- puis version plus compleque : lit 1 long, et utilise ses octets
DSP_LSP_routine_interruption_I2S:

	.if		DSP_DEBUG
; change la couleur du fond
	movei	#$777,R26
	movei	#BG,r27
	storew	r26,(r27)
	.endif

; debug eDZ
		;cmpq		#0,R19
		;jr			eq,EDZEDZ
		;nop
		;nop
;EDZEDZ:


		movei		#L_I2S,R27
		movei		#L_I2S+4,R25
		store		R19,(R27)			; write right channel
		store		R18,(R25)			; write left channel



; version complexe avec stockage de 4 octets

; module replay
		movefa		R15,R15


; ----------
; channel 3
;	movei		#LSP_DSP_PAULA_internal_location3,R1
;	movei		#LSP_DSP_PAULA_internal_increment3,R2
;	movei		#LSP_DSP_PAULA_internal_length3,R3
;	movei		#LSP_DSP_PAULA_AUD3LEN,R4
;	movei		#LSP_DSP_PAULA_AUD3L,R5
		;movei		#LSP_DSP_PAULA_internal_location3,R28						; adresse sample actuelle, a virgule
		;movefa		R1,R28
		load		(R15),R28
		;movei		#LSP_DSP_PAULA_internal_increment3,R27
		;movefa		R2,R27
		load		(R15+1),R27
		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		;movei		#LSP_DSP_PAULA_internal_length3,R25				; =FIN
		load		(R15+2),R25
		;movefa		R3,R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel3
		;nop
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		;movei		#LSP_DSP_PAULA_AUD3LEN,R27			; fin, a virgule 
		load		(R15+3),R27
		;movefa		R4,R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		;movei		#LSP_DSP_PAULA_AUD3L,R24			; sample location a virgule
		load		(R15+4),R24
		;movefa		R5,R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
		
DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel3:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
														;shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample 
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		;movei		#LSP_DSP_PAULA_AUD3DAT,R28			; 4 octets actuels
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location3 => LSP_DSP_PAULA_AUD3DAT
		not			R22									; => %11
		load		(R28),R21							; R21 = octets actuels en stock
		and			R22,R25								; R25 = position octet à lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word3
		shlq		#3,R25					; numero d'octet à lire * 8

; il faut rafraichir R21
		load		(R26),R21							; lit 4 nouveaux octets de sample
		store		R21,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word3:
		;movei		#LSP_DSP_PAULA_AUD3VOL,R23/R24	
		subq		#4,R28								; de LSP_DSP_PAULA_AUD3DAT => LSP_DSP_PAULA_AUD3VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet à lire
; ch2
		;movei		#LSP_DSP_PAULA_internal_increment2,R27
		load		(R15+6),R27
		;movefa		R7,R27

		sh			R25,R21								; shift les 4 octets en stock vers la gauche, pour positionner l'octet à lire en haut
		load		(R28),R28							; R23 = volume : 6 bits
		sharq		#24,R21								; descends l'octet à lire
; ch2
		imult		R28,R21								; unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits

; R21=sample channel 3 on 14 bits

; ----------
; channel 2
;	movei		#LSP_DSP_PAULA_internal_location2,R6
;	movei		#LSP_DSP_PAULA_internal_increment2,R7
;	movei		#LSP_DSP_PAULA_internal_length2,R8
;	movei		#LSP_DSP_PAULA_AUD2LEN,R9
;	movei		#LSP_DSP_PAULA_AUD2L,R10
		load		(R27),R27										; R27=increment 16:16
		;movei		#LSP_DSP_PAULA_internal_location2,R28						; adresse sample actuelle, a virgule
		load		(R15+5),R28
		;movefa		R6,R28
		;movei		#LSP_DSP_PAULA_internal_length2,R25				; =FIN
		load		(R15+7),R25
		;movefa		R8,R25

		;movei		#LSP_DSP_PAULA_internal_increment2,R27
		load		(R28),R26										; R26=current pointeur sample 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel2
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		;movei		#LSP_DSP_PAULA_AUD2LEN,R27			; fin, a virgule 
		load		(R15+8),R27
		;movefa		R9,R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		;movei		#LSP_DSP_PAULA_AUD2L,R24			; sample location a virgule
		load		(R15+9),R24
		;movefa		R10,R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
		
DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel2:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
		;shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample 
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		;movei		#LSP_DSP_PAULA_AUD2DAT,R28			; 4 octets actuels
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location2 => LSP_DSP_PAULA_AUD2DAT
		not			R22									; => %11
		load		(R28),R20							; R20 = octets actuels en stock
		and			R22,R25								; R25 = position octet à lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word2
		;nop
		shlq		#3,R25					; numero d'octet à lire * 8

; il faut rafraichir R20
		load		(R26),R20							; lit 4 nouveaux octets de sample
		store		R20,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word2:
		;movei		#LSP_DSP_PAULA_AUD2VOL,R23
		subq		#4,R28								; de LSP_DSP_PAULA_AUD2DAT => LSP_DSP_PAULA_AUD2VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet à lire
; ch1
		;movei		#LSP_DSP_PAULA_internal_increment1,R27
		load		(R15+11),R27
		;movefa		R12,R27

		sh			R25,R20								; shift les 4 octets en stock vers la gauche, pour positionner l'octet à lire en haut
		load		(R28),R28							; R23 = volume : 6 bits
		sharq		#24,R20								; descends l'octet à lire
		imult		R28,R20								; unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits

; R20=sample channel 2 on 14 bits

; ----------
; channel 1
;	movei		#LSP_DSP_PAULA_internal_location1,R11
;	movei		#LSP_DSP_PAULA_internal_increment1,R12
;	movei		#LSP_DSP_PAULA_internal_length1,R13
;	movei		#LSP_DSP_PAULA_AUD1LEN,R14
;	movei		#LSP_DSP_PAULA_AUD1L,R21
		;movei		#LSP_DSP_PAULA_internal_location1,R28						; adresse sample actuelle, a virgule
		load		(R15+10),R28
		;movefa		R11,R28
		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		;movei		#LSP_DSP_PAULA_internal_length1,R25				; =FIN
		load		(R15+12),R25
		;movefa		R13,R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel1
		;nop
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		;movei		#LSP_DSP_PAULA_AUD1LEN,R27			; fin, a virgule 
		load		(R15+13),R27
		;movefa		R14,R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		;movei		#LSP_DSP_PAULA_AUD1L,R24			; sample location a virgule
		load		(R15+14),R24
		;movefa		R21,R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
		
DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel1:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
		;shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample 
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		;movei		#LSP_DSP_PAULA_AUD1DAT,R28			; 4 octets actuels
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location1 => LSP_DSP_PAULA_AUD1DAT
		not			R22									; => %11
		load		(R28),R19							; R19 = octets actuels en stock
		and			R22,R25								; R25 = position octet à lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word1
		;nop
		shlq		#3,R25					; numero d'octet à lire * 8

; il faut rafraichir R19
		load		(R26),R19							; lit 4 nouveaux octets de sample
		store		R19,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word1:
		;movei		#LSP_DSP_PAULA_AUD1VOL,R23
		subq		#4,R28								; de LSP_DSP_PAULA_AUD1DAT => LSP_DSP_PAULA_AUD1VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet à lire
; ch0
		;movei		#LSP_DSP_PAULA_internal_increment0,R27
		load		(R15+16),R27
		;movefa		R17,R27

		sh			R25,R19								; shift les 4 octets en stock vers la gauche, pour positionner l'octet à lire en haut
		load		(R28),R23							; R23 = volume : 6 bits
		sharq		#24,R19								; descends l'octet à lire
; ch0
		;movei		#LSP_DSP_PAULA_internal_location0,R28						; adresse sample actuelle, a virgule
		load		(R15+15),R28
		;movefa		R16,R28

		imult		R23,R19								; unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits

; R19=sample channel 1 on 14 bits

; ----------
; channel 0
;	movei		#LSP_DSP_PAULA_internal_location0,R16
;	movei		#LSP_DSP_PAULA_internal_increment0,R17
;	movei		#LSP_DSP_PAULA_internal_length0,R18
;	movei		#LSP_DSP_PAULA_AUD0LEN,R19
;	movei		#LSP_DSP_PAULA_AUD0L,R20
		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		;movei		#LSP_DSP_PAULA_internal_length0,R25				; =FIN
		load		(R15+17),R25
		;movefa		R18,R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22											; -FFFFFFC
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel0
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		;movei		#LSP_DSP_PAULA_AUD0LEN,R27			; fin, a virgule 
		load		(R15+18),R27
		;movefa		R19,R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		;movei		#LSP_DSP_PAULA_AUD0L,R24			; sample location a virgule
		load		(R15+19),R24
		;movefa		R20,R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
		
DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel0:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample 
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		;movei		#LSP_DSP_PAULA_AUD0DAT,R28			; 4 octets actuels
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location0 => LSP_DSP_PAULA_AUD0DAT
		not			R22									; => %11
		load		(R28),R18							; R18 = octets actuels en stock
		and			R22,R25								; R25 = position octet à lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word0
		shlq		#3,R25					; numero d'octet à lire * 8

; il faut rafraichir R18
		load		(R26),R18							; lit 4 nouveaux octets de sample
		store		R18,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word0:
		;movei		#LSP_DSP_PAULA_AUD0VOL,R23			
		subq		#4,R28								; de LSP_DSP_PAULA_AUD0DAT => LSP_DSP_PAULA_AUD0VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet à lire


; suite
		.if			channel_1=0
			moveq	#0,R19
		.endif
		.if			channel_2=0
			moveq	#0,R20
		.endif
		add			R20,R19				; R19 = right 15 bits unsigned
;--

		sh			R25,R18								; shift les 4 octets en stock vers la gauche, pour positionner l'octet à lire en haut
		load		(R28),R23							; R23 = volume : 6 bits
		sharq		#24,R18								; descends l'octet à lire

; suite

		imult		R23,R18								; unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits

; R18=sample channel 0 on 14 bits




; Stéreo Amiga:
; les canaux 0 et 3 formant la voie stéréo gauche et 1 et 2 la voie stéréo droite
; R18=channel 0
; R19=channel 1
; R20=channel 2
; R21=channel 3
		.if			channel_0=0
			moveq	#0,R18
		.endif
		.if			channel_3=0
			moveq	#0,R21
		.endif

		add			R21,R18				; R18 = left 15 bits signed
		;add			R20,R19				; R19 = right 15 bits signed


; module replay : voies 4 a 7
		movefa		R1,R15

; ----------
; channel 7 => R21
		load		(R15),R28
		load		(R15+1),R27
		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		load		(R15+2),R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel7
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		load		(R15+3),R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		load		(R15+4),R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
		
DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel7:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
														;shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample 
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location3 => LSP_DSP_PAULA_AUD3DAT
		not			R22									; => %11
		load		(R28),R21							; R21 = octets actuels en stock
		and			R22,R25								; R25 = position octet à lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word7
		shlq		#3,R25					; numero d'octet à lire * 8

; il faut rafraichir R21
		load		(R26),R21							; lit 4 nouveaux octets de sample
		store		R21,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word7:
		subq		#4,R28								; de LSP_DSP_PAULA_AUD3DAT => LSP_DSP_PAULA_AUD3VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet à lire
; ch6
		load		(R15+6),R27

		sh			R25,R21								; shift les 4 octets en stock vers la gauche, pour positionner l'octet à lire en haut
		load		(R28),R28							; R23 = volume : 6 bits
		sharq		#24,R21								; descends l'octet à lire
; ch6
		imult		R28,R21								; unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits

; R21=sample channel 7 on 14 bits

; ----------
; channel 6
		load		(R27),R27										; R27=increment 16:16
		
; ajout channel 7
			.if			channel_7=1
			add			R21,R18
			.endif
		
		
		load		(R15+5),R28
		load		(R15+7),R25

		load		(R28),R26										; R26=current pointeur sample 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel6
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		load		(R15+8),R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		load		(R15+9),R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
		
DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel6:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample 
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location2 => LSP_DSP_PAULA_AUD2DAT
		not			R22									; => %11
		load		(R28),R20							; R20 = octets actuels en stock
		and			R22,R25								; R25 = position octet à lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word6
		shlq		#3,R25					; numero d'octet à lire * 8

; il faut rafraichir R20
		load		(R26),R20							; lit 4 nouveaux octets de sample
		store		R20,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word6:
		subq		#4,R28								; de LSP_DSP_PAULA_AUD2DAT => LSP_DSP_PAULA_AUD2VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet à lire
; ch6
		load		(R15+11),R27

		sh			R25,R20								; shift les 4 octets en stock vers la gauche, pour positionner l'octet à lire en haut
		load		(R28),R28							; R23 = volume : 6 bits
		sharq		#24,R20								; descends l'octet à lire
		imult		R28,R20								; unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits

; R20=sample channel 6 on 14 bits

; ----------
; channel 5
		load		(R15+10),R28

; ajout channel 6
			.if			channel_6=1
			add			R20,R19
			.endif

		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		load		(R15+12),R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel5
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		load		(R15+13),R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		load		(R15+14),R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
		
DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel5:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample 
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location1 => LSP_DSP_PAULA_AUD1DAT
		not			R22									; => %11
		load		(R28),R21							; R21 = octets actuels en stock
		and			R22,R25								; R25 = position octet à lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word5
		shlq		#3,R25					; numero d'octet à lire * 8

; il faut rafraichir R21
		load		(R26),R21							; lit 4 nouveaux octets de sample
		store		R21,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word5:
		subq		#4,R28								; de LSP_DSP_PAULA_AUD1DAT => LSP_DSP_PAULA_AUD1VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet à lire
; ch4
		load		(R15+16),R27

		sh			R25,R21								; shift les 4 octets en stock vers la gauche, pour positionner l'octet à lire en haut
		load		(R28),R23							; R23 = volume : 6 bits
		sharq		#24,R21								; descends l'octet à lire
; ch4
		load		(R15+15),R28

		imult		R23,R21								; unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits

; R21=sample channel 5 on 14 bits

; ----------
; channel 4
		load		(R28),R26										; R26=current pointeur sample 16:16
; ajout channel 5
			.if			channel_5=1
			add			R21,R19
			.endif

		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		load		(R15+17),R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22											; -FFFFFFC
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel4
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		load		(R15+18),R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		load		(R15+19),R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
		
DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel4:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample 
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location0 => LSP_DSP_PAULA_AUD0DAT
		not			R22									; => %11
		load		(R28),R20							; R18 = octets actuels en stock
		and			R22,R25								; R25 = position octet à lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word4
		shlq		#3,R25					; numero d'octet à lire * 8

; il faut rafraichir R20
		load		(R26),R20							; lit 4 nouveaux octets de sample
		store		R20,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word4:
		subq		#4,R28								; de LSP_DSP_PAULA_AUD0DAT => LSP_DSP_PAULA_AUD0VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet à lire


		;add			R20,R19				; R19 = right 15 bits unsigned
;--

		sh			R25,R20								; shift les 4 octets en stock vers la gauche, pour positionner l'octet à lire en haut
		load		(R28),R23							; R23 = volume : 6 bits
		sharq		#24,R20								; descends l'octet à lire

; suite

		imult		R23,R20								; unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits

; R20=sample channel 4 on 14 bits


; ajout channel 4
			.if			channel_4=1
			add			R20,R18
			.endif







		
;		movei		#L_I2S,R27
;		movei		#L_I2S+4,R25
;		store		R19,(R27)			; write right channel
;		store		R18,(R25)			; write left channel



		

	.if		DSP_DEBUG
; change la couleur du fond
	movei	#$000,R26
	movei	#BG,r27
	storew	r26,(r27)
	.endif


;------------------------------------	
; return from interrupt I2S
	load	(r31),r28	; return address
	bset	#10,r29		; clear latch 1 = I2S
	;bset	#11,r29		; clear latch 1 = timer 1
	;bset	#12,r29		; clear latch 1 = timer 2
	bclr	#3,r29		; clear IMASK
	addq	#4,r31		; pop from stack
	addqt	#2,r28		; next instruction
	jump	t,(r28)		; return
	store	r29,(r30)	; restore flags


;--------------------------------------------
; ---------------- Timer 1 ------------------
;--------------------------------------------
; autorise interruptions, pour timer I2S
; 
; registres utilisés :
;		R13/R16   /R31
;		R0/R1/R2/R3/R4/R5/R6/R7/R8/R9/R10  R12/R13/R14/R16


DSP_LSP_routine_interruption_Timer1:
	;.if		I2S_during_Timer1=1
	;bclr	#3,r13		; clear IMASK
	;store	r13,(r16)	; restore flags
	;.endif

; gestion replay LSP

	movei		#LSPVars,R14
	load		(R14),R0					; R0 = byte stream

DSP_LSP_Timer1_process:
	moveq		#0,R2
DSP_LSP_Timer1_cloop:

	loadb		(R0),R6						; R6 = byte code
	addq		#1,R0
	
	cmpq		#0,R6
	jr			ne,DSP_LSP_Timer1_swCode
	nop
	movei		#$0100,R3
	add			R3,R2
	jr			DSP_LSP_Timer1_cloop
	nop

DSP_LSP_Timer1_swCode:
	add			R2,R6
	move		R6,R2

	add			R2,R2
	load		(R14+2),R3			; R3=code table / m_codeTableAddr
	add			R2,R3
	movei		#DSP_LSP_Timer1_noInst,R12
	loadw		(R3),R2									; R2 = code
	cmpq		#0,R2
	jump		eq,(R12)
	nop
	load		(R14+3),R4			; R4=escape code rewind / m_escCodeRewind
	movei		#DSP_LSP_Timer1_r_rewind,R12
	cmp			R4,R2
	jump		eq,(R12)
	nop
	load		(R14+4),R4			; R4=escape code set bpm / m_escCodeSetBpm
	movei		#DSP_LSP_Timer1_r_chgbpm,R12
	cmp			R4,R2
	jump		eq,(R12)
	nop

;--------------------------
; gestion des volumes
;--------------------------
; test volume canal 3
	;movei		#DSP_Master_Volume_Music,R4
	;load		(R4),R12						; R12 = master volume, de 0 a 256

	btst		#7,R2
	jr			eq,DSP_LSP_Timer1_noVd
	nop
	loadb		(R0),R4
	movei		#LSP_DSP_PAULA_AUD3VOL_original,R5
	;mult		R12,R4
	addq		#1,R0
	;sharq		#8,R4
	store		R4,(R5)
DSP_LSP_Timer1_noVd:
; test volume canal 2
	btst		#6,R2
	jr			eq,DSP_LSP_Timer1_noVc
	nop
	loadb		(R0),R4
	movei		#LSP_DSP_PAULA_AUD2VOL_original,R5
	;mult		R12,R4
	addq		#1,R0
	;sharq		#8,R4
	store		R4,(R5)
DSP_LSP_Timer1_noVc:
; test volume canal 1
	btst		#5,R2
	jr			eq,DSP_LSP_Timer1_noVb
	nop
	loadb		(R0),R4
	movei		#LSP_DSP_PAULA_AUD1VOL_original,R5
	;mult		R12,R4
	addq		#1,R0
	;sharq		#8,R4
	store		R4,(R5)
DSP_LSP_Timer1_noVb:
; test volume canal 0
	btst		#4,R2
	jr			eq,DSP_LSP_Timer1_noVa
	nop
	loadb		(R0),R4
	movei		#LSP_DSP_PAULA_AUD0VOL_original,R5
	;mult		R12,R4
	addq		#1,R0
	;sharq		#8,R4
	store		R4,(R5)
DSP_LSP_Timer1_noVa:

	.if			LSP_avancer_module=1
	store		R0,(R14)									; store byte stream ptr
	.endif
	addq		#4,R14									; avance a word stream ptr
	load		(R14),R0									; R0 = word stream

;--------------------------
; gestion des notes
;--------------------------
; test period canal 3
	btst		#3,R2
	jr			eq,DSP_LSP_Timer1_noPd
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD3PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPd:
; test period canal 2
	btst		#2,R2
	jr			eq,DSP_LSP_Timer1_noPc
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD2PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPc:
; test period canal 1
	btst		#1,R2
	jr			eq,DSP_LSP_Timer1_noPb
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD1PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPb:
; test period canal 0
	btst		#0,R2
	jr			eq,DSP_LSP_Timer1_noPa
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD0PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPa:

; pas de test des 8 bits du haut en entier pour zapper la lecture des instruments
; tst.w	d0							; d0.w, avec d0.b qui a avancé ! / beq.s	.noInst

	load		(R14+4),R5		; R5= instrument table  ( =+$10)  = a2   / m_lspInstruments-1 = 5-1

;--------------------------
; gestion des instruments
;--------------------------
;--- test instrument voie 3
	movei		#DSP_LSP_Timer1_setIns3,R12
	btst		#15,R2
	jump		ne,(R12)
	nop
	
	movei		#DSP_LSP_Timer1_skip3,R12
	btst		#14,R2
	jump		eq,(R12)
	nop

; repeat voie 3	
	movei		#LSP_DSP_repeat_pointeur3,R3
	movei		#LSP_DSP_repeat_length3,R4
	load		(R3),R3					; pointeur sauvegardé, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD3L,R7
	movei		#LSP_DSP_PAULA_AUD3LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD3L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns3:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD3L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD3LEN,R8
	shlq		#nb_bits_virgule_offset,R6		
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD3L
	addq		#2,R5
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	store		R9,(R8)				; stocke la nouvelle fin a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur3,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4	
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length3,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5
	
; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset3,R12
	btst		#14,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location3,R7
	movei		#LSP_DSP_PAULA_internal_length3,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3
; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD3DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)
	

DSP_LSP_Timer1_noreset3:
DSP_LSP_Timer1_skip3:

;--- test instrument voie 2
	movei		#DSP_LSP_Timer1_setIns2,R12
	btst		#13,R2
	jump		ne,(R12)
	nop
	
	movei		#DSP_LSP_Timer1_skip2,R12
	btst		#12,R2
	jump		eq,(R12)
	nop

; repeat voie 2
	movei		#LSP_DSP_repeat_pointeur2,R3
	movei		#LSP_DSP_repeat_length2,R4
	load		(R3),R3					; pointeur sauvegardé, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD2L,R7
	movei		#LSP_DSP_PAULA_AUD2LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD3L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns2:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD2L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD2LEN,R8
	shlq		#nb_bits_virgule_offset,R6		
	addq		#2,R5
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD3L
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
	store		R9,(R8)				; stocke la nouvelle fin a virgule
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur2,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4	
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length2,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5
	
; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset2,R12
	btst		#12,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location2,R7
	movei		#LSP_DSP_PAULA_internal_length2,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3
; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD2DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)
	

DSP_LSP_Timer1_noreset2:
DSP_LSP_Timer1_skip2:
	
;--- test instrument voie 1
	movei		#DSP_LSP_Timer1_setIns1,R12
	btst		#11,R2
	jump		ne,(R12)
	nop
	
	movei		#DSP_LSP_Timer1_skip1,R12
	btst		#10,R2
	jump		eq,(R12)
	nop

; repeat voie 1
	movei		#LSP_DSP_repeat_pointeur1,R3
	movei		#LSP_DSP_repeat_length1,R4
	load		(R3),R3					; pointeur sauvegardé, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD1L,R7
	movei		#LSP_DSP_PAULA_AUD1LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD3L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns1:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD1L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD1LEN,R8
	shlq		#nb_bits_virgule_offset,R6		
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD3L
	addq		#2,R5
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	store		R9,(R8)				; stocke la nouvelle fin a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur1,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4	
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length1,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5
	
; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset1,R12
	btst		#10,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location1,R7
	movei		#LSP_DSP_PAULA_internal_length1,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3
; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD1DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)
	

DSP_LSP_Timer1_noreset1:
DSP_LSP_Timer1_skip1:
	
;--- test instrument voie 0
	movei		#DSP_LSP_Timer1_setIns0,R12
	btst		#9,R2
	jump		ne,(R12)
	nop
	
	movei		#DSP_LSP_Timer1_skip0,R12
	btst		#8,R2
	jump		eq,(R12)
	nop

; repeat voie 0
	movei		#LSP_DSP_repeat_pointeur0,R3
	movei		#LSP_DSP_repeat_length0,R4
	load		(R3),R3					; pointeur sauvegardé, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD0L,R7
	movei		#LSP_DSP_PAULA_AUD0LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD3L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns0:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD0L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD0LEN,R8
	shlq		#nb_bits_virgule_offset,R6		
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD3L
	addq		#2,R5
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	store		R9,(R8)				; stocke la nouvelle fin a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur0,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4	
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length0,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5
	
; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset0,R12
	btst		#8,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location0,R7
	movei		#LSP_DSP_PAULA_internal_length0,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3

; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD0DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)
	

DSP_LSP_Timer1_noreset0:
DSP_LSP_Timer1_skip0:
	
	

DSP_LSP_Timer1_noInst:
	.if			LSP_avancer_module=1
	store		R0,(R14)			; store word stream (or byte stream if coming from early out)
	.endif


; - fin de la conversion du player LSP

; elements d'emulation Paula
; calcul des increments
; calcul de l'increment a partir de la note Amiga : (3546895 / note) / frequence I2S

; conversion period => increment voie 0
	movei		#DSP_frequence_de_replay_reelle_I2S,R0
	movei		#LSP_DSP_PAULA_internal_increment0,R1
	movei		#LSP_DSP_PAULA_AUD0PER,R2
	load		(R0),R0
	movei		#3546895,R3
	
	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.1
	nop
	moveq		#0,R4
	jr			.2
	nop
.1:
	move		R3,R4
	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.2:
	store		R4,(R1)
; conversion period => increment voie 1
	movei		#LSP_DSP_PAULA_AUD1PER,R2
	movei		#LSP_DSP_PAULA_internal_increment1,R1
	move		R3,R4
	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.12
	nop
	moveq		#0,R4
	jr			.22
	nop
.12:

	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.22:
	store		R4,(R1)

; conversion period => increment voie 2
	movei		#LSP_DSP_PAULA_AUD2PER,R2
	movei		#LSP_DSP_PAULA_internal_increment2,R1
	move		R3,R4
	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.13
	nop
	moveq		#0,R4
	jr			.23
	nop
.13:
	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.23:
	store		R4,(R1)

; conversion period => increment voie 3
	movei		#LSP_DSP_PAULA_AUD3PER,R2
	movei		#LSP_DSP_PAULA_internal_increment3,R1
	move		R3,R4
	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.14
	nop
	moveq		#0,R4
	jr			.24
	nop
.14:
	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.24:
	store		R4,(R1)


;-----------------------
; reduction du volume en fonction du master volume Music
	movei		#DSP_Master_Volume_Music,R4
	movei		#LSP_DSP_PAULA_AUD3VOL_original,R5
	load		(R4),R12						; R12 = master volume, de 0 a 256
	load		(R5),R6
	movei		#LSP_DSP_PAULA_AUD3VOL,R5
	mult		R12,R6
	sharq		#8,R6
	store		R6,(R5)

	movei		#LSP_DSP_PAULA_AUD2VOL_original,R7
	movei		#LSP_DSP_PAULA_AUD1VOL_original,R8
	movei		#LSP_DSP_PAULA_AUD0VOL_original,R5
	load		(R7),R6
	load		(R8),R9
	load		(R5),R3
	mult		R12,R6
	movei		#LSP_DSP_PAULA_AUD2VOL,R7
	mult		R12,R9
	movei		#LSP_DSP_PAULA_AUD1VOL,R8
	mult		R12,R3
	movei		#LSP_DSP_PAULA_AUD0VOL,R5
	sharq		#8,R6
	sharq		#8,R9
	sharq		#8,R3
	store		R6,(R7)
	store		R9,(R8)
	store		R3,(R5)


;--------------------------------------------------
;2eme module : voies 4 a 7

; gestion replay LSP - 2eme partie, module 2, voies 4 à 7

	movei		#LSPVars2,R14
	load		(R14),R0					; R0 = byte stream

DSP_LSP_Timer1_process__module2_voies4_a_7:
	moveq		#0,R2
DSP_LSP_Timer1_cloop__module2_voies4_a_7:

	loadb		(R0),R6						; R6 = byte code
	addq		#1,R0
	
	cmpq		#0,R6
	jr			ne,DSP_LSP_Timer1_swCode__module2_voies4_a_7
	nop
	movei		#$0100,R3
	add			R3,R2
	jr			DSP_LSP_Timer1_cloop__module2_voies4_a_7
	nop

DSP_LSP_Timer1_swCode__module2_voies4_a_7:
	add			R2,R6
	move		R6,R2

	add			R2,R2
	load		(R14+2),R3			; R3=code table / m_codeTableAddr
	add			R2,R3
	movei		#DSP_LSP_Timer1_noInst__module2_voies4_a_7,R12
	loadw		(R3),R2									; R2 = code
	cmpq		#0,R2
	jump		eq,(R12)
	nop
	load		(R14+3),R4			; R4=escape code rewind / m_escCodeRewind
	movei		#DSP_LSP_Timer1_r_rewind__module2_voies4_a_7,R12
	cmp			R4,R2
	jump		eq,(R12)
	nop
	load		(R14+4),R4			; R4=escape code set bpm / m_escCodeSetBpm
	movei		#DSP_LSP_Timer1_r_chgbpm__module2_voies4_a_7,R12
	cmp			R4,R2
	jump		eq,(R12)
	nop

;--------------------------
; gestion des volumes
;--------------------------
; test volume canal 7
	;movei		#DSP_Master_Volume_Music,R4
	;load		(R4),R12						; R12 = master volume, de 0 a 256

	btst		#7,R2
	jr			eq,DSP_LSP_Timer1_noVd__module2_voies4_a_7
	nop
	loadb		(R0),R4
	movei		#LSP_DSP_PAULA_AUD7VOL_original,R5
	;mult		R12,R4
	addq		#1,R0
	;sharq		#8,R4
	store		R4,(R5)
DSP_LSP_Timer1_noVd__module2_voies4_a_7:
; test volume canal 6
	btst		#6,R2
	jr			eq,DSP_LSP_Timer1_noVc__module2_voies4_a_7
	nop
	loadb		(R0),R4
	movei		#LSP_DSP_PAULA_AUD6VOL_original,R5
	;mult		R12,R4
	addq		#1,R0
	;sharq		#8,R4
	store		R4,(R5)
DSP_LSP_Timer1_noVc__module2_voies4_a_7:
; test volume canal 5
	btst		#5,R2
	jr			eq,DSP_LSP_Timer1_noVb__module2_voies4_a_7
	nop
	loadb		(R0),R4
	movei		#LSP_DSP_PAULA_AUD5VOL_original,R5
	;mult		R12,R4
	addq		#1,R0
	;sharq		#8,R4
	store		R4,(R5)
DSP_LSP_Timer1_noVb__module2_voies4_a_7:
; test volume canal 3
	btst		#4,R2
	jr			eq,DSP_LSP_Timer1_noVa__module2_voies4_a_7
	nop
	loadb		(R0),R4
	movei		#LSP_DSP_PAULA_AUD4VOL_original,R5
	;mult		R12,R4
	addq		#1,R0
	;sharq		#8,R4
	store		R4,(R5)
DSP_LSP_Timer1_noVa__module2_voies4_a_7:

	.if			LSP_avancer_module=1
	store		R0,(R14)									; store byte stream ptr
	.endif
	addq		#4,R14									; avance a word stream ptr
	load		(R14),R0									; R0 = word stream

;--------------------------
; gestion des notes
;--------------------------
; test period canal 7
	btst		#3,R2
	jr			eq,DSP_LSP_Timer1_noPd__module2_voies4_a_7
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD7PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPd__module2_voies4_a_7:
; test period canal 6
	btst		#2,R2
	jr			eq,DSP_LSP_Timer1_noPc__module2_voies4_a_7
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD6PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPc__module2_voies4_a_7:
; test period canal 5
	btst		#1,R2
	jr			eq,DSP_LSP_Timer1_noPb__module2_voies4_a_7
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD5PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPb__module2_voies4_a_7:
; test period canal 4
	btst		#0,R2
	jr			eq,DSP_LSP_Timer1_noPa__module2_voies4_a_7
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD4PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPa__module2_voies4_a_7:

; pas de test des 8 bits du haut en entier pour zapper la lecture des instruments
; tst.w	d0							; d0.w, avec d0.b qui a avancé ! / beq.s	.noInst

	load		(R14+4),R5		; R5= instrument table  ( =+$10)  = a2   / m_lspInstruments-1 = 5-1

;--------------------------
; gestion des instruments
;--------------------------
;--- test instrument voie 7
	movei		#DSP_LSP_Timer1_setIns3__module2_voies4_a_7,R12
	btst		#15,R2
	jump		ne,(R12)
	nop
	
	movei		#DSP_LSP_Timer1_skip3__module2_voies4_a_7,R12
	btst		#14,R2
	jump		eq,(R12)
	nop

; repeat voie 7
	movei		#LSP_DSP_repeat_pointeur7,R3
	movei		#LSP_DSP_repeat_length7,R4
	load		(R3),R3					; pointeur sauvegardé, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD7L,R7
	movei		#LSP_DSP_PAULA_AUD7LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD7L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns3__module2_voies4_a_7:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD7L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD7LEN,R8
	shlq		#nb_bits_virgule_offset,R6		
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD7L
	addq		#2,R5
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	store		R9,(R8)				; stocke la nouvelle fin a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur7,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4	
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length7,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5
	
; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset3__module2_voies4_a_7,R12
	btst		#14,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location7,R7
	movei		#LSP_DSP_PAULA_internal_length7,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3
; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD7DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)
	

DSP_LSP_Timer1_noreset3__module2_voies4_a_7:
DSP_LSP_Timer1_skip3__module2_voies4_a_7:

;--- test instrument voie 6
	movei		#DSP_LSP_Timer1_setIns2__module2_voies4_a_7,R12
	btst		#13,R2
	jump		ne,(R12)
	nop
	
	movei		#DSP_LSP_Timer1_skip2__module2_voies4_a_7,R12
	btst		#12,R2
	jump		eq,(R12)
	nop

; repeat voie 6
	movei		#LSP_DSP_repeat_pointeur6,R3
	movei		#LSP_DSP_repeat_length6,R4
	load		(R3),R3					; pointeur sauvegardé, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD6L,R7
	movei		#LSP_DSP_PAULA_AUD6LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD3L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns2__module2_voies4_a_7:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD6L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD6LEN,R8
	shlq		#nb_bits_virgule_offset,R6		
	addq		#2,R5
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD3L
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
	store		R9,(R8)				; stocke la nouvelle fin a virgule
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur6,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4	
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length6,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5
	
; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset2__module2_voies4_a_7,R12
	btst		#12,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location6,R7
	movei		#LSP_DSP_PAULA_internal_length6,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3
; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD6DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)
	

DSP_LSP_Timer1_noreset2__module2_voies4_a_7:
DSP_LSP_Timer1_skip2__module2_voies4_a_7:
	
;--- test instrument voie 1
	movei		#DSP_LSP_Timer1_setIns1__module2_voies4_a_7,R12
	btst		#11,R2
	jump		ne,(R12)
	nop
	
	movei		#DSP_LSP_Timer1_skip1__module2_voies4_a_7,R12
	btst		#10,R2
	jump		eq,(R12)
	nop

; repeat voie 1
	movei		#LSP_DSP_repeat_pointeur5,R3
	movei		#LSP_DSP_repeat_length5,R4
	load		(R3),R3					; pointeur sauvegardé, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD5L,R7
	movei		#LSP_DSP_PAULA_AUD5LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD3L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns1__module2_voies4_a_7:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD5L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD5LEN,R8
	shlq		#nb_bits_virgule_offset,R6		
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD3L
	addq		#2,R5
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	store		R9,(R8)				; stocke la nouvelle fin a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur5,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4	
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length5,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5
	
; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset1__module2_voies4_a_7,R12
	btst		#10,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location5,R7
	movei		#LSP_DSP_PAULA_internal_length5,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3
; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD5DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)
	

DSP_LSP_Timer1_noreset1__module2_voies4_a_7:
DSP_LSP_Timer1_skip1__module2_voies4_a_7:
	
;--- test instrument voie 4
	movei		#DSP_LSP_Timer1_setIns0__module2_voies4_a_7,R12
	btst		#9,R2
	jump		ne,(R12)
	nop
	
	movei		#DSP_LSP_Timer1_skip0__module2_voies4_a_7,R12
	btst		#8,R2
	jump		eq,(R12)
	nop

; repeat voie 4
	movei		#LSP_DSP_repeat_pointeur4,R3
	movei		#LSP_DSP_repeat_length4,R4
	load		(R3),R3					; pointeur sauvegardé, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD4L,R7
	movei		#LSP_DSP_PAULA_AUD4LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD3L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns0__module2_voies4_a_7:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD4L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD4LEN,R8
	shlq		#nb_bits_virgule_offset,R6		
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD3L
	addq		#2,R5
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	store		R9,(R8)				; stocke la nouvelle fin a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur4,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4	
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length4,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5
	
; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset0__module2_voies4_a_7,R12
	btst		#8,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location4,R7
	movei		#LSP_DSP_PAULA_internal_length4,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3

; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD4DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)
	

DSP_LSP_Timer1_noreset0__module2_voies4_a_7:
DSP_LSP_Timer1_skip0__module2_voies4_a_7:
	
	

DSP_LSP_Timer1_noInst__module2_voies4_a_7:
	.if			LSP_avancer_module=1
	store		R0,(R14)			; store word stream (or byte stream if coming from early out)
	.endif


; - fin de la conversion du player LSP

; elements d'emulation Paula
; calcul des increments
; calcul de l'increment a partir de la note Amiga : (3546895 / note) / frequence I2S

; conversion period => increment voie 4
	movei		#DSP_frequence_de_replay_reelle_I2S,R0
	movei		#LSP_DSP_PAULA_internal_increment4,R1
	movei		#LSP_DSP_PAULA_AUD4PER,R2
	load		(R0),R0
	movei		#3546895,R3
	
	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.1__module2_voies4_a_7
	nop
	moveq		#0,R4
	jr			.2__module2_voies4_a_7
	nop
.1__module2_voies4_a_7:
	move		R3,R4
	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.2__module2_voies4_a_7:
	store		R4,(R1)
; conversion period => increment voie 5
	movei		#LSP_DSP_PAULA_AUD5PER,R2
	movei		#LSP_DSP_PAULA_internal_increment5,R1
	move		R3,R4
	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.12__module2_voies4_a_7
	nop
	moveq		#0,R4
	jr			.22__module2_voies4_a_7
	nop
.12__module2_voies4_a_7:

	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.22__module2_voies4_a_7:
	store		R4,(R1)

; conversion period => increment voie 6
	movei		#LSP_DSP_PAULA_AUD6PER,R2
	movei		#LSP_DSP_PAULA_internal_increment6,R1
	move		R3,R4
	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.13__module2_voies4_a_7
	nop
	moveq		#0,R4
	jr			.23__module2_voies4_a_7
	nop
.13__module2_voies4_a_7:
	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.23__module2_voies4_a_7:
	store		R4,(R1)

; conversion period => increment voie 7
	movei		#LSP_DSP_PAULA_AUD7PER,R2
	movei		#LSP_DSP_PAULA_internal_increment7,R1
	move		R3,R4
	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.14__module2_voies4_a_7
	nop
	moveq		#0,R4
	jr			.24__module2_voies4_a_7
	nop
.14__module2_voies4_a_7:
	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.24__module2_voies4_a_7:
	store		R4,(R1)


;-----------------------
; reduction du volume en fonction du master volume Music
	movei		#DSP_Master_Volume_Music,R4
	movei		#LSP_DSP_PAULA_AUD7VOL_original,R5
	load		(R4),R12						; R12 = master volume, de 0 a 256
	load		(R5),R6
	movei		#LSP_DSP_PAULA_AUD7VOL,R5
	mult		R12,R6
	sharq		#8,R6
	store		R6,(R5)

	movei		#LSP_DSP_PAULA_AUD6VOL_original,R7
	movei		#LSP_DSP_PAULA_AUD5VOL_original,R8
	movei		#LSP_DSP_PAULA_AUD4VOL_original,R5
	load		(R7),R6
	load		(R8),R9
	load		(R5),R3
	mult		R12,R6
	movei		#LSP_DSP_PAULA_AUD6VOL,R7
	mult		R12,R9
	movei		#LSP_DSP_PAULA_AUD5VOL,R8
	mult		R12,R3
	movei		#LSP_DSP_PAULA_AUD4VOL,R5
	sharq		#8,R6
	sharq		#8,R9
	sharq		#8,R3
	store		R6,(R7)
	store		R9,(R8)
	store		R3,(R5)




	
;------------------------------------	
; return from interrupt Timer 1
	load	(r31),r12	; return address
	;bset	#10,r13		; clear latch 1 = I2S
	bset	#11,r13		; clear latch 1 = timer 1
	;bset	#12,r13		; clear latch 1 = timer 2
	bclr	#3,r13		; clear IMASK
	addq	#4,r31		; pop from stack
	addqt	#2,r12		; next instruction
	jump	t,(r12)		; return
	store	r13,(r16)	; restore flags

;------------------------------------	
;rewind voies 4 à 7
DSP_LSP_Timer1_r_rewind__module2_voies4_a_7:
;	movei		#LSPVars,R14
;	load		(R14),R0					; R0 = byte stream
	load		(R14+8),R0			; bouclage : R0 = byte stream / m_byteStreamLoop = 8
	movei		#DSP_LSP_Timer1_process__module2_voies4_a_7,R12
	load		(R14+9),R3			; m_wordStreamLoop=9
	jump		(R12)
	store		R3,(R14+1)				; m_wordStream=1

;------------------------------------	
;rewind
DSP_LSP_Timer1_r_rewind:
;	movei		#LSPVars,R14
;	load		(R14),R0					; R0 = byte stream
	load		(R14+8),R0			; bouclage : R0 = byte stream / m_byteStreamLoop = 8
	movei		#DSP_LSP_Timer1_process,R12
	load		(R14+9),R3			; m_wordStreamLoop=9
	jump		(R12)
	store		R3,(R14+1)				; m_wordStream=1


;------------------------------------	
; change bpm
DSP_LSP_Timer1_r_chgbpm:
	movei		#DSP_LSP_Timer1_process,R12
	loadb		(R0),R11
	store		R11,(R14+7)		; R3=nouveau bpm / m_currentBpm = 7
;application nouveau bpm dans Timer 1
	movei	#60*256,R10
	;shlq	#8,R10				; 16 bits de virgule
	div		R11,R10				; 60/bpm
	movei	#24*65536,R9				; 24=> 5 bits
	or		R10,R10
	;shlq	#16,R9
	div		R10,R9				; R9=
	or		R9,R9
	shrq	#8,R9				; R9=frequence replay 
	;move	R9,R11	
; frequence du timer 1
	movei	#182150,R10				; 26593900 / 146 = 182150
	div		R9,R10
	or		R10,R10
	move	R10,R14
	subq	#1,R14					; -1 pour parametrage du timer 1
; 26593900 / 50 = 531 878 => 2 × 73 × 3643 => 146*3643
	movei	#JPIT1,r10				; F10000
	movei	#145*65536,r9				; Timer 1 Pre-scaler
	;shlq	#16,r12
	or		R14,R9
	store	r9,(r10)				; JPIT1 & JPIT2
	jump		(R12)
	addq		#1,R0
;------------------------------------	
; change bpm : 4 a 7
DSP_LSP_Timer1_r_chgbpm__module2_voies4_a_7:
	movei		#DSP_LSP_Timer1_process__module2_voies4_a_7,R12
	loadb		(R0),R11
	store		R11,(R14+7)		; R3=nouveau bpm / m_currentBpm = 7
;application nouveau bpm dans Timer 1
	movei	#60*256,R10
	;shlq	#8,R10				; 16 bits de virgule
	div		R11,R10				; 60/bpm
	movei	#24*65536,R9				; 24=> 5 bits
	or		R10,R10
	;shlq	#16,R9
	div		R10,R9				; R9=
	or		R9,R9
	shrq	#8,R9				; R9=frequence replay 
	;move	R9,R11	
; frequence du timer 1
	movei	#182150,R10				; 26593900 / 146 = 182150
	div		R9,R10
	or		R10,R10
	move	R10,R14
	subq	#1,R14					; -1 pour parametrage du timer 1
; 26593900 / 50 = 531 878 => 2 × 73 × 3643 => 146*3643
	movei	#JPIT1,r10				; F10000
	movei	#145*65536,r9				; Timer 1 Pre-scaler
	;shlq	#16,r12
	or		R14,R9
	store	r9,(r10)				; JPIT1 & JPIT2
	jump		(R12)
	addq		#1,R0


; ------------------- N/A ------------------
DSP_LSP_routine_interruption_Timer2:
; ------------------- N/A ------------------

;DSP_pad1
;DSP_pad2
; lecture des 2 pads
; Pads : mask = xxxx xxCx xxBx 2580 147* oxAP 369# RLDU
; dispos : R0 à R12
	movei		#DSP_pad1,R11
	movei		#DSP_pad2,R12
	movei		#JOYSTICK,R0

	movei		#%00001111000000000000000000000000,R2		; mask port 1
	movei		#%00000000000000000000000000000011,R3		; mask port 1

	movei		#%11110000000000000000000000000000,R5		; mask port 2
	movei		#%00000000000000000000000000001100,R6		; mask port 2



; row 0
	MOVEI		#$817e,R1			; =81<<8 + 0111 1110 = (A Pause) + (Right Left Down Up) / 81 pour bit 15 pour output + bit 8 pour  conserver le son ON : pad 1 & 2
									; 1110 = row 0 of joypad = Pause A Up Down Left Right
	storew		R1,(R0)				; lecture row 0
	nop
	load		(R0),R1
	;movei		#$F000000C,R3		; mask port 2
	
; row0 = Pause A Up Down Left Right
; 0000 1111 0000 0000 0000 0000 0000 0011
;      RLDU                            Ap
	move		R1,R10				; stocke pour lecture port 2
	
	move		R1,R4
	move		R10,R7
	and			R3,R4		
	and			R6,R7		
	and			R2,R1				
	and			R5,R10				
	shlq		#8,R4				; R4=Ap xxxx xxxx
	shlq		#6,R7				; R4=Ap xxxx xxxx
	shrq		#24,R1				; R1=RLDU
	shrq		#28,R10				; R10=RLDU
	or			R4,R1
	or			R7,R10
	move		R1,R8
	move		R10,R9



; row 1
	MOVEI		#$81BD,R1			; #($81 << 8)|(%1011 << 4)|(%1101),(a2) ; (B D) + (1 4 7 *)
	storew		R1,(R0)				; lecture row 1
	nop
	load		(R0),R1
; row1 = 
; 0000 1111 0000 0000 0000 0000 0000 0011
;      147*                            BD
	move		R1,R10				; stocke pour lecture port 2
;row1 port 1&2

	move		R1,R4
	move		R10,R7
	and			R3,R4
	and			R6,R7		
	shlq		#20,R4
	shlq		#18,R7				
	and			R2,R1				
	and			R5,R10				
	shrq		#12,R1				; R1=147*
	shrq		#16,R10				; R10=147*
	or			R1,R4
	or			R7,R10
	or			R4,R8				; R8= BD xxxx 147* xxAp xxxx RLDU
	or			R10,R9


; row 2
	MOVEI		#$81DB,R1			; #($81 << 8)|(%1101 << 4)|(%1011),(a2) ; (C E) + (2 5 8 0)
	storew		R1,(R0)				; lecture row 2
	nop
	load		(R0),R1
	move		R1,R10				; stocke pour lecture port 2

; row2 = 
; 0000 1111 0000 0000 0000 0000 0000 0011
;      2580                            CE
; 24,8,22,12
	move		R1,R4
	move		R10,R7
	and			R3,R4
	and			R6,R7		
	shlq		#24,R4
	shlq		#22,R7				
	and			R2,R1				
	and			R5,R10				
	shrq		#8,R1				; R1=147*
	shrq		#12,R10				; R10=147*
	or			R1,R4
	or			R7,R10
	or			R4,R8				; R8= BD xxxx 147* xxAp xxxx RLDU
	or			R10,R9



; row 3
	MOVEI		#$81E7,R1			; #($81 << 8)|(%1110 << 4)|(%0111),(a2) ; (Option F) + (3 6 9 #)
	storew		R1,(R0)				; lecture row 3
	nop
	load		(R0),R1
; row3 = 
; 0000 1111 0000 0000 0000 0000 0000 0011
;      369#                            oF
; l10,r20,l8,r24
	move		R1,R10				; stocke pour lecture port 2

	move		R1,R4
	move		R10,R7
	and			R3,R4
	and			R6,R7		
	shlq		#10,R4
	shlq		#8,R7				
	and			R2,R1				
	and			R5,R10				
	shrq		#20,R1				; R1=147*
	shrq		#24,R10				; R10=147*
	or			R1,R4
	or			R7,R10
	or			R4,R8				; R8= BD xxxx 147* xxAp xxxx RLDU
	or			R10,R9

	
	
	not			R8
	not			R9
	store		R8,(R11)
	store		R9,(R12)
	
	
									
									
									
;------------------------------------	
; return from interrupt Timer 2
	load	(r31),r12	; return address
	bset	#12,r13		; clear latch 1 = timer 2
	bclr	#3,r13		; clear IMASK
	addq	#4,r31		; pop from stack
	addqt	#2,r12		; next instruction
	jump	t,(r12)		; return
	store	r13,(r16)	; restore flags


;------------------------------------------
;------------------------------------------
; ------------- main DSP ------------------
;------------------------------------------
;------------------------------------------

DSP_routine_init_DSP:
; assume run from bank 1
	movei	#DSP_ISP+(DSP_STACK_SIZE*4),r31			; init isp
	moveq	#0,r1
	moveta	r31,r31									; ISP (bank 0)
	nop
	movei	#DSP_USP+(DSP_STACK_SIZE*4),r31			; init usp

; calculs des frequences deplacé dans DSP
; sclk I2S
	movei	#LSP_DSP_Audio_frequence,R0
	movei	#frequence_Video_Clock_divisee,R1
	load	(R1),R1
	shlq	#8,R1
	div		R0,R1
	movei	#128,R2
	add		R2,R1			; +128 = +0.5
	shrq	#8,R1
	subq	#1,R1
	movei	#DSP_parametre_de_frequence_I2S,r2
	store	R1,(R2)
;calcul inverse
	addq	#1,R1
	add		R1,R1			; *2
	add		R1,R1			; *2
	shlq	#4,R1			; *16
	movei	#frequence_Video_Clock,R0
	load	(R0),R0
	div		R1,R0
	movei	#DSP_frequence_de_replay_reelle_I2S,R2
	store	R0,(R2)
	

; init I2S
	movei	#SCLK,r10
	movei	#SMODE,r11
	movei	#DSP_parametre_de_frequence_I2S,r12
	movei	#%001101,r13			; SMODE bascule sur RISING
	load	(r12),r12				; SCLK
	store	r12,(r10)
	store	r13,(r11)


; init Timer 1
; frq = 24/(60/bpm)
	movei	#LSP_BPM_frequence_replay,R11
	load	(R11),R11
	movei	#60*256,R10
	;shlq	#8,R10				; 16 bits de virgule
	div		R11,R10				; 60/bpm
	movei	#24*65536,R9				; 24=> 5 bits
	or		R10,R10
	;shlq	#16,R9
	div		R10,R9				; R9=
	or		R9,R9
	shrq	#8,R9				; R9=frequence replay 
	
	move	R9,R11	
	

; frequence du timer 1
	movei	#182150,R10				; 26593900 / 146 = 182150
	div		R11,R10
	or		R10,R10
	move	R10,R13

	subq	#1,R13					; -1 pour parametrage du timer 1
	
	

; 26593900 / 50 = 531 878 => 2 × 73 × 3643 => 146*3643
	movei	#JPIT1,r10				; F10000
	;movei	#JPIT2,r11				; F10002
	movei	#145*65536,r12				; Timer 1 Pre-scaler
	;shlq	#16,r12
	or		R13,R12
	
	store	r12,(r10)				; JPIT1 & JPIT2


; init timer 2
	movei	#JPIT3,r10				; F10004
	;movei	#JPIT4,r11				; F10006
	movei	#145*65536,r12			; Timer 1 Pre-scaler
	movei	#955-1,r13				; 951=200hz
	or		R13,R12
	store	r12,(r10)				; JPIT1 & JPIT2


;----------------------------
; variables pour movfa
; R0/R1/R15 : OK
	movei		#$FFFFFFFC,R0									; OK
	movei		#LSP_variables_table2,R1
	movei		#LSP_variables_table,R15
	moveta		R15,R15
;----------------------------


; registres du son R18 et R19
	moveq	#0,R18
	moveta	R18,R18
	moveta	R18,R19
	

; enable interrupts
	movei	#D_FLAGS,r30
	movei	#D_I2SENA|D_TIM1ENA|D_TIM2ENA|REGPAGE,r29			; I2S+Timer 1+timer 2
	;movei	#D_I2SENA|D_TIM1ENA|REGPAGE,r29			; I2S+Timer 1
	;movei	#D_I2SENA|REGPAGE,r29					; I2S only
	;movei	#D_TIM1ENA|REGPAGE,r29					; Timer 1 only
	;movei	#D_TIM2ENA|REGPAGE,r29					; Timer 2 only
	store	r29,(r30)







; registres bloqués par movefa : R0/R1/R15

DSP_boucle_centrale:
	;movei	#DSP_boucle_centrale,R28
	;jump	(R28)
	;nop

; decompression LZ4 DSP
; 
; 3 inputs :
; input: R20 : packed buffer
;		 R21 : output buffer
;		 R5  : LZ4 packed block size (in bytes)	

	movei	#LZ4_pointeur_sur_bloc_a_decompresser,R6
	load	(R6),R20
	cmpq	#0,R20
	jr		eq,DSP_boucle_centrale
	nop
	
	movei	#lz4_taille_du_bloc_compresse,R2
	movei	#LZ4_pointeur_sur_bloc_de_destination,R4
	load	(R2),R5
	load	(R4),R21
	
	;moveq	#0,R23
	;store	R23,(R6)			; mets a zero l'adresse du bloc a decompresser


; input: R20 : packed buffer
;		 R21 : output buffer
;		 R5  : LZ4 packed block size (in bytes)	

; A4 => R24
; A0 => R20
; A1 => R21
; A3 => R23
; D0 => R0  => R5
; D1 => R1  => R6
; D2 => R2
; D4 => R4

; adresse saut 1 => R10
; adresse saut 2 => R11

; R12=$FF pour mask
; R13=tmp

DSP_nb_fois_tempo_depack		.equ		0

lz4_depack_smallest_DSP:
			move	R20,R24
			add		R5,R24	; packed buffer end
			moveq	#0,R5
			moveq	#0,R2
			moveq	#$F,R4
			movei	#$FF,R12

.tokenLoop_smallest_DSP:
			loadb	(R20),R5
			.rept		DSP_nb_fois_tempo_depack
			nop
			or		R5,R5
			nop
			.endr
			addq	#1,R20
			move	R5,R6
			shrq	#4,R6
			movei	#.lenOffset_smallest_DSP,R10
			cmpq	#0,R6
			jump	eq,(R10)
			nop
			
.readLen_smallest1_DSP:	
			movei	#.readEnd_smallest1_DSP,R11
			cmp		R6,R4					; cmp.B !!!!
			jump	ne,(R11)
			nop

.readLoop_smallest1_DSP:
			loadb	(R20),R2
			.rept		DSP_nb_fois_tempo_depack
			nop
			or		R2,R2
			nop
			.endr
			addq	#1,R20
			add		R2,R6				; final len could be > 64KiB
			
			not		R2
			and		R12,R2				; not R2.b
			movei	#.readLoop_smallest1_DSP,R10
			cmpq	#0,R2
			jump	eq,(R10)
			nop
	
.readEnd_smallest1_DSP:	

.litcopy_smallest_DSP:
			loadb	(R20),R13
			.rept		DSP_nb_fois_tempo_depack
			nop
			or		R13,R13
			nop
			.endr
			storeb	R13,(R21)
			addq	#1,R20
			addq	#1,R21
			movei	#.litcopy_smallest_DSP,R10
			subq	#1,R6
			cmpq	#0,R6
			jump	ne,(R10)
			nop

			; end test is always done just after literals
			movei	#.readEnd_smallest_DSP,R11
			cmp		R20,R24
			jump	eq,(R11)
			nop
			
.lenOffset_smallest_DSP:
			loadb	(R20),R6	; read 16bits offset, little endian, unaligned
			.rept		DSP_nb_fois_tempo_depack
			nop
			or		R6,R6
			nop
			.endr
			addq	#1,R20
			loadb	(R20),R13
			.rept		DSP_nb_fois_tempo_depack
			nop
			or		R13,R13
			nop
			.endr
			addq	#1,R20
			shlq	#8,R13
			add		R13,R6
			
			move	R21,R23
			sub		R6,R23		; R6/d1 bits 31..16 are always 0 here

			moveq	#$F,R6
			and		R5,R6		; and.w	d0,d1 .W !!!

.readLen_smallest2_DSP:	
			movei	#.readEnd_smallest2_DSP,R11
			cmp		R6,R4					; cmp.B !!!!
			jump	ne,(R11)
			nop

.readLoop_smallest2_DSP:	
			loadb	(R20),R2
			.rept		DSP_nb_fois_tempo_depack
			nop
			or		R2,R2
			nop
			.endr
			addq	#1,R20
			add		R2,R6				; final len could be > 64KiB
			
			not		R2
			and		R12,R2				; not R2.b
			movei	#.readLoop_smallest2_DSP,R10
			cmpq	#0,R2
			jump	eq,(R10)
			nop
		
.readEnd_smallest2_DSP:
			addq	#4,R6

.copy_smallest_DSP:
			loadb	(R23),R13
			.rept		DSP_nb_fois_tempo_depack
			nop
			or		R13,R13
			nop
			.endr
			storeb	R13,(R21)
			.rept		DSP_nb_fois_tempo_depack
			nop
			or		R13,R13
			nop
			.endr
			addq	#1,R23
			addq	#1,R21
			movei	#.copy_smallest_DSP,R10
			movei	#.tokenLoop_smallest_DSP,R11
			subq	#1,R6
			jump	ne,(R10)
			nop
			jump	(R11)
			nop

.readLen_smallest_DSP:	
			movei	#.readEnd_smallest_DSP,R11
			cmp		R6,R4					; cmp.B !!!!
			jump	ne,(R11)
			nop

.readLoop_smallest_DSP:	
			loadb	(R20),R2
			.rept		DSP_nb_fois_tempo_depack
			nop
			or		R2,R2
			nop
			.endr
			addq	#1,R20
			add		R2,R6				; final len could be > 64KiB
			or		R2,R2
			
			not		R2
			and		R12,R2				; not R2.b
			or		R2,R2
			movei	#.readLoop_smallest_DSP,R10
			cmpq	#0,R2
			jump	eq,(R10)
			nop
	
.readEnd_smallest_DSP:	

			movei	#LZ4_pointeur_sur_bloc_a_decompresser,R6
			moveq	#0,R23
			movei	#DSP_boucle_centrale,R4
			store	R23,(R6)			; mets a zero l'adresse du bloc a decompresser / decompression terminée


			jump	(R4)
			nop






	.phrase

LZ4_pointeur_sur_bloc_a_decompresser:				dc.l			0
LZ4_pointeur_sur_bloc_de_destination:				dc.l			-1
lz4_taille_du_bloc_compresse:						dc.l			0

LSP_DSP_flag:										dc.l			0				; DSP replay flag 0=OFF / 1=ON
LSP_DSP_oldflag:									dc.l			0

DSP_frequence_de_replay_reelle_I2S:					dc.l			0
DSP_UN_sur_frequence_de_replay_reelle_I2S:			dc.l			0
DSP_parametre_de_frequence_I2S:						dc.l			0

LSP_PAULA:
; variables Paula
; channel 0
LSP_DSP_PAULA_AUD0L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location
LSP_DSP_PAULA_AUD0LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !
LSP_DSP_PAULA_AUD0PER:				dc.l			0				; period , a transformer en increment
LSP_DSP_PAULA_AUD0VOL:				dc.l			0				; volume
LSP_DSP_PAULA_AUD0DAT:				dc.l			0				; long word en cours d'utilisation / stocké / buffering
LSP_DSP_PAULA_internal_location0:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played
LSP_DSP_PAULA_internal_increment0:	dc.l			0				; internal register : increment linked to period 16:16
LSP_DSP_PAULA_internal_length0:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played
LSP_DSP_repeat_pointeur0:			dc.l			silence<<nb_bits_virgule_offset
LSP_DSP_repeat_length0:				dc.l			(silence+4)<<nb_bits_virgule_offset
; channel 1
LSP_DSP_PAULA_AUD1L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location
LSP_DSP_PAULA_AUD1LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !
LSP_DSP_PAULA_AUD1PER:				dc.l			0				; period , a transformer en increment
LSP_DSP_PAULA_AUD1VOL:				dc.l			0				; volume
LSP_DSP_PAULA_AUD1DAT:				dc.l			0				; long word en cours d'utilisation / stocké / buffering
LSP_DSP_PAULA_internal_location1:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played
LSP_DSP_PAULA_internal_increment1:	dc.l			0				; internal register : increment linked to period 16:16
LSP_DSP_PAULA_internal_length1:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played
LSP_DSP_repeat_pointeur1:			dc.l			silence<<nb_bits_virgule_offset
LSP_DSP_repeat_length1:				dc.l			(silence+4)<<nb_bits_virgule_offset
; channel 2
LSP_DSP_PAULA_AUD2L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location
LSP_DSP_PAULA_AUD2LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !
LSP_DSP_PAULA_AUD2PER:				dc.l			0				; period , a transformer en increment
LSP_DSP_PAULA_AUD2VOL:				dc.l			0				; volume
LSP_DSP_PAULA_AUD2DAT:				dc.l			0				; long word en cours d'utilisation / stocké / buffering
LSP_DSP_PAULA_internal_location2:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played
LSP_DSP_PAULA_internal_increment2:	dc.l			0				; internal register : increment linked to period 16:16
LSP_DSP_PAULA_internal_length2:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played
LSP_DSP_repeat_pointeur2:			dc.l			silence<<nb_bits_virgule_offset
LSP_DSP_repeat_length2:				dc.l			(silence+4)<<nb_bits_virgule_offset
; channel 3
LSP_DSP_PAULA_AUD3L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location																0				0
LSP_DSP_PAULA_AUD3LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !																		+4				+1
LSP_DSP_PAULA_AUD3PER:				dc.l			0				; period , a transformer en increment																			+8				+2
LSP_DSP_PAULA_AUD3VOL:				dc.l			0				; volume																										+12				+3
LSP_DSP_PAULA_AUD3DAT:				dc.l			0				; long word en cours d'utilisation / stocké / buffering															+16				+4
LSP_DSP_PAULA_internal_location3:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played						+20				+5
LSP_DSP_PAULA_internal_increment3:	dc.l			0				; internal register : increment linked to period 16:16															+24				+6
LSP_DSP_PAULA_internal_length3:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played							+28				+7
LSP_DSP_repeat_pointeur3:			dc.l			silence<<nb_bits_virgule_offset																		;							+32				+8
LSP_DSP_repeat_length3:				dc.l			(silence+4)<<nb_bits_virgule_offset																	;							+36				+9 / 32
; channel 4
LSP_DSP_PAULA_AUD4L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location																0				0
LSP_DSP_PAULA_AUD4LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !																		+4				+1
LSP_DSP_PAULA_AUD4PER:				dc.l			0				; period , a transformer en increment																			+8				+2
LSP_DSP_PAULA_AUD4VOL:				dc.l			0				; volume																										+12				+3
LSP_DSP_PAULA_AUD4DAT:				dc.l			0				; long word en cours d'utilisation / stocké / buffering															+16				+4
LSP_DSP_PAULA_internal_location4:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played						+20				+5
LSP_DSP_PAULA_internal_increment4:	dc.l			0				; internal register : increment linked to period 16:16															+24				+6
LSP_DSP_PAULA_internal_length4:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played							+28				+7
LSP_DSP_repeat_pointeur4:			dc.l			silence<<nb_bits_virgule_offset																		;							+32				+8
LSP_DSP_repeat_length4:				dc.l			(silence+4)<<nb_bits_virgule_offset																	;							+36				+9 / 32
; channel 5
LSP_DSP_PAULA_AUD5L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location																0				0
LSP_DSP_PAULA_AUD5LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !																		+4				+1
LSP_DSP_PAULA_AUD5PER:				dc.l			0				; period , a transformer en increment																			+8				+2
LSP_DSP_PAULA_AUD5VOL:				dc.l			0				; volume																										+12				+3
LSP_DSP_PAULA_AUD5DAT:				dc.l			0				; long word en cours d'utilisation / stocké / buffering															+16				+4
LSP_DSP_PAULA_internal_location5:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played						+20				+5
LSP_DSP_PAULA_internal_increment5:	dc.l			0				; internal register : increment linked to period 16:16															+24				+6
LSP_DSP_PAULA_internal_length5:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played							+28				+7
LSP_DSP_repeat_pointeur5:			dc.l			silence<<nb_bits_virgule_offset																		;							+32				+8
LSP_DSP_repeat_length5:				dc.l			(silence+4)<<nb_bits_virgule_offset																	;							+36				+9 / 32
; channel 6
LSP_DSP_PAULA_AUD6L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location																0				0
LSP_DSP_PAULA_AUD6LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !																		+4				+1
LSP_DSP_PAULA_AUD6PER:				dc.l			0				; period , a transformer en increment																			+8				+2
LSP_DSP_PAULA_AUD6VOL:				dc.l			0				; volume																										+12				+3
LSP_DSP_PAULA_AUD6DAT:				dc.l			0				; long word en cours d'utilisation / stocké / buffering															+16				+4
LSP_DSP_PAULA_internal_location6:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played						+20				+5
LSP_DSP_PAULA_internal_increment6:	dc.l			0				; internal register : increment linked to period 16:16															+24				+6
LSP_DSP_PAULA_internal_length6:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played							+28				+7
LSP_DSP_repeat_pointeur6:			dc.l			silence<<nb_bits_virgule_offset																		;							+32				+8
LSP_DSP_repeat_length6:				dc.l			(silence+4)<<nb_bits_virgule_offset																	;							+36				+9 / 32
; channel 7
LSP_DSP_PAULA_AUD7L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location																0				0
LSP_DSP_PAULA_AUD7LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !																		+4				+1
LSP_DSP_PAULA_AUD7PER:				dc.l			0				; period , a transformer en increment																			+8				+2
LSP_DSP_PAULA_AUD7VOL:				dc.l			0				; volume																										+12				+3
LSP_DSP_PAULA_AUD7DAT:				dc.l			0				; long word en cours d'utilisation / stocké / buffering															+16				+4
LSP_DSP_PAULA_internal_location7:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played						+20				+5
LSP_DSP_PAULA_internal_increment7:	dc.l			0				; internal register : increment linked to period 16:16															+24				+6
LSP_DSP_PAULA_internal_length7:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played							+28				+7
LSP_DSP_repeat_pointeur7:			dc.l			silence<<nb_bits_virgule_offset																		;							+32				+8
LSP_DSP_repeat_length7:				dc.l			(silence+4)<<nb_bits_virgule_offset																	;							+36				+9 / 32



offset_LSP_DSP_PAULA_internal_location0		.equ			((LSP_DSP_PAULA_internal_location0-LSP_PAULA)/4)


LSP_DSP_PAULA_AUD0VOL_original:				dc.l			0				; volume
LSP_DSP_PAULA_AUD1VOL_original:				dc.l			0				; volume
LSP_DSP_PAULA_AUD2VOL_original:				dc.l			0				; volume
LSP_DSP_PAULA_AUD3VOL_original:				dc.l			0				; volume
LSP_DSP_PAULA_AUD4VOL_original:				dc.l			0				; volume
LSP_DSP_PAULA_AUD5VOL_original:				dc.l			0				; volume
LSP_DSP_PAULA_AUD6VOL_original:				dc.l			0				; volume
LSP_DSP_PAULA_AUD7VOL_original:				dc.l			0				; volume


; tableau des variables
LSP_variables_table:				; = alt R15
; channel 3
		dc.l		LSP_DSP_PAULA_internal_location3
		dc.l		LSP_DSP_PAULA_internal_increment3
		dc.l		LSP_DSP_PAULA_internal_length3
		dc.l		LSP_DSP_PAULA_AUD3LEN
		dc.l		LSP_DSP_PAULA_AUD3L
;channel 2
		dc.l		LSP_DSP_PAULA_internal_location2
		dc.l		LSP_DSP_PAULA_internal_increment2
		dc.l		LSP_DSP_PAULA_internal_length2
		dc.l		LSP_DSP_PAULA_AUD2LEN
		dc.l		LSP_DSP_PAULA_AUD2L
;channel 1
		dc.l		LSP_DSP_PAULA_internal_location1
		dc.l		LSP_DSP_PAULA_internal_increment1
		dc.l		LSP_DSP_PAULA_internal_length1
		dc.l		LSP_DSP_PAULA_AUD1LEN
		dc.l		LSP_DSP_PAULA_AUD1L
;channel 0
		dc.l		LSP_DSP_PAULA_internal_location0
		dc.l		LSP_DSP_PAULA_internal_increment0
		dc.l		LSP_DSP_PAULA_internal_length0
		dc.l		LSP_DSP_PAULA_AUD0LEN
		dc.l		LSP_DSP_PAULA_AUD0L

LSP_variables_table2:				; = alt R1
; channel 7
		dc.l		LSP_DSP_PAULA_internal_location7
		dc.l		LSP_DSP_PAULA_internal_increment7
		dc.l		LSP_DSP_PAULA_internal_length7
		dc.l		LSP_DSP_PAULA_AUD7LEN
		dc.l		LSP_DSP_PAULA_AUD7L
;channel 6
		dc.l		LSP_DSP_PAULA_internal_location6
		dc.l		LSP_DSP_PAULA_internal_increment6
		dc.l		LSP_DSP_PAULA_internal_length6
		dc.l		LSP_DSP_PAULA_AUD6LEN
		dc.l		LSP_DSP_PAULA_AUD6L
;channel 5
		dc.l		LSP_DSP_PAULA_internal_location5
		dc.l		LSP_DSP_PAULA_internal_increment5
		dc.l		LSP_DSP_PAULA_internal_length5
		dc.l		LSP_DSP_PAULA_AUD5LEN
		dc.l		LSP_DSP_PAULA_AUD5L
;channel 4
		dc.l		LSP_DSP_PAULA_internal_location4
		dc.l		LSP_DSP_PAULA_internal_increment4
		dc.l		LSP_DSP_PAULA_internal_length4
		dc.l		LSP_DSP_PAULA_AUD4LEN
		dc.l		LSP_DSP_PAULA_AUD4L




LSPVars:
m_byteStream:		dc.l	0	;  0 :  byte stream							0
m_wordStream:		dc.l	0	;  4 :  word stream							1
m_codeTableAddr:	dc.l	0	;  8 :  code table addr						2
m_escCodeRewind:	dc.l	0	; 12 :  rewind special escape code			3
m_escCodeSetBpm:	dc.l	0	; 16 :  set BPM escape code					4
m_lspInstruments:	dc.l	0	; 20 :  LSP instruments table addr			5
m_relocDone:		dc.l	0	; 24 :  reloc done flag						6
m_currentBpm:		dc.l	0	; 28 :  current BPM							7
m_byteStreamLoop:	dc.l	0	; 32 :  byte stream loop point				8
m_wordStreamLoop:	dc.l	0	; 36 :  word stream loop point				9

LSPVars2:
m_byteStream_module2:		dc.l	0	;  0 :  byte stream							0
m_wordStream_module2:		dc.l	0	;  4 :  word stream							1
m_codeTableAddr_module2:	dc.l	0	;  8 :  code table addr						2
m_escCodeRewind_module2:	dc.l	0	; 12 :  rewind special escape code			3
m_escCodeSetBpm_module2:	dc.l	0	; 16 :  set BPM escape code					4
m_lspInstruments_module2:	dc.l	0	; 20 :  LSP instruments table addr			5
m_relocDone_module2:		dc.l	0	; 24 :  reloc done flag						6
m_currentBpm_module2:		dc.l	0	; 28 :  current BPM							7
m_byteStreamLoop_module2:	dc.l	0	; 32 :  byte stream loop point				8
m_wordStreamLoop_module2:	dc.l	0	; 36 :  word stream loop point				9



LSP_BPM_frequence_replay:		dc.l			25
;DSP_diviseur_de_volume_global_module:			dc.l			DSP_diviseur_volume_module
DSP_Master_Volume_Music:						dc.l			256									; volume de 0 a 256
;DSP_Master_Volume_Sounds:						dc.l			256									; volume de 0 a 256


; pads
; Pads : mask = xxxxxxCx xxBx2580 147*oxAP 369#RLDU
; U235 format
;------------------------------------------------------------------------------------------------ Joypad Section

										; Pads : mask = xxxxxxCx xxBx2580 147*oxAP 369#RLDU

; 												Bit numbers for buttons in the mask for testing individual bits
U235SE_BBUT_UP			EQU		0		; Up
U235SE_BBUT_U			EQU		0
U235SE_BBUT_DOWN		EQU		1		; Down
U235SE_BBUT_D			EQU		1
U235SE_BBUT_LEFT		EQU		2		; Left
U235SE_BBUT_L			EQU		2
U235SE_BBUT_RIGHT		EQU		3		; Right
U235SE_BBUT_R			EQU		3		
U235SE_BBUT_HASH		EQU		4		; Hash (#)
U235SE_BBUT_9			EQU		5		; 9
U235SE_BBUT_6			EQU		6		; 6
U235SE_BBUT_3			EQU		7		; 3
U235SE_BBUT_PAUSE		EQU		8		; Pause
U235SE_BBUT_A			EQU		9		; A button
U235SE_BBUT_OPTION		EQU		11		; Option
U235SE_BBUT_STAR		EQU		12		; Star 
U235SE_BBUT_7			EQU		13		; 7
U235SE_BBUT_4			EQU		14		; 4
U235SE_BBUT_1			EQU		15		; 1
U235SE_BBUT_0			EQU		16		; 0 (zero)
U235SE_BBUT_8			EQU		17		; 8
U235SE_BBUT_5			EQU		18		; 5
U235SE_BBUT_2			EQU		19		; 2
U235SE_BBUT_B			EQU		21		; B button
U235SE_BBUT_C			EQU		25		; C button

; 												Numerical representations
U235SE_BUT_UP			EQU		1		; Up
U235SE_BUT_U			EQU		1
U235SE_BUT_DOWN			EQU		2		; Down
U235SE_BUT_D			EQU		2
U235SE_BUT_LEFT			EQU		4		; Left
U235SE_BUT_L			EQU		4
U235SE_BUT_RIGHT		EQU		8		; Right
U235SE_BUT_R			EQU		8		
U235SE_BUT_HASH			EQU		16		; Hash (#)
U235SE_BUT_9			EQU		32		; 9
U235SE_BUT_6			EQU		64		; 6
U235SE_BUT_3			EQU		$80		; 3
U235SE_BUT_PAUSE		EQU		$100	; Pause
U235SE_BUT_A			EQU		$200	; A button
U235SE_BUT_OPTION		EQU		$800	; Option
U235SE_BUT_STAR			EQU		$1000	; Star 
U235SE_BUT_7			EQU		$2000	; 7
U235SE_BUT_4			EQU		$4000	; 4
U235SE_BUT_1			EQU		$8000	; 1
U235SE_BUT_0			EQU		$10000	; 0 (zero)
U235SE_BUT_8			EQU		$20000	; 8
U235SE_BUT_5			EQU		$40000	; 5
U235SE_BUT_2			EQU		$80000	; 2
U235SE_BUT_B			EQU		$200000	; B button
U235SE_BUT_C			EQU		$2000000; C button

; xxxxxxCx xxBx2580 147*oxAP 369#RLDU
DSP_pad1:				dc.l		0
DSP_pad2:				dc.l		0


; DATAs DSP
		.dphrase


	.phrase

;---------------------
; FIN DE LA RAM DSP
YM_DSP_fin:
;---------------------


SOUND_DRIVER_SIZE			.equ			YM_DSP_fin-DSP_base_memoire
	.print	"--- Sound driver code size (DSP): ", /u SOUND_DRIVER_SIZE, " bytes / 8192 ---"
	.print	"---------------------------------------------------------------"


	.dphrase	


        .68000

silence:		
		dc.l			$0
		dc.l			$0
fin_silence:
		dc.l			$0
		dc.l			$0


.phrase
LSP_module_music_data_voies_1_a_4:
	.incbin			"LSP/Jalaga/8voies/menu_1.lsmusic"
.phrase
LSP_module_music_data_voies_5_a_8:
	.incbin			"LSP/Jalaga/8voies/menu_2.lsmusic"
.phrase
LSP_module_sound_bank:
	.incbin			"LSP/Jalaga/8voies/menu_1.lsbank"



.phrase
	.BSS
.phrase
DEBUT_BSS:


pointeur_fin_de_RAM_actuel:			ds.l		1

; DSP
	.phrase
frequence_Video_Clock:					ds.l				1
frequence_Video_Clock_divisee :			ds.l				1
pointeur_module_music_data:			ds.l		1
pointeur_module_sound_bank:			ds.l		1





	
FIN_RAM:
