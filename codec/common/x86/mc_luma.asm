;*!
;* \copy
;*     Copyright (c)  2009-2013, Cisco Systems
;*     All rights reserved.
;*
;*     Redistribution and use in source and binary forms, with or without
;*     modification, are permitted provided that the following conditions
;*     are met:
;*
;*        * Redistributions of source code must retain the above copyright
;*          notice, this list of conditions and the following disclaimer.
;*
;*        * Redistributions in binary form must reproduce the above copyright
;*          notice, this list of conditions and the following disclaimer in
;*          the documentation and/or other materials provided with the
;*          distribution.
;*
;*     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;*     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;*     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
;*     FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
;*     COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
;*     INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
;*     BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
;*     LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
;*     CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
;*     LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
;*     ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;*     POSSIBILITY OF SUCH DAMAGE.
;*
;*
;*  mc_luma.asm
;*
;*  Abstract
;*      sse2 motion compensation
;*
;*  History
;*      17/08/2009 Created
;*
;*
;*************************************************************************/
%include "asm_inc.asm"

;*******************************************************************************
; Local Data (Read Only)
;*******************************************************************************
SECTION .rodata align=32

;*******************************************************************************
; Various memory constants (trigonometric values or rounding values)
;*******************************************************************************

%ifdef HAVE_AVX2
ALIGN 32
dwm32768_256:
    times 16 dw -32768
maddubsw_m2p10_m40m40_p10m2_p0p0_256:
    times 4 db -2, 10, -40, -40, 10, -2, 0, 0
dwm1024_256:
    times 16 dw -1024
dd32768_256:
    times 8 dd 32768
maddubsw_p1m5_256:
    times 16 db 1, -5
maddubsw_m5p1_256:
    times 16 db -5, 1
db20_256:
    times 32 db 20
maddubsw_m5p20_256:
    times 16 db -5, 20
maddubsw_p20m5_256:
    times 16 db 20, -5
h264_w0x10_256:
    times 16 dw 16
dw32_256:
    times 16 dw 32
%endif ; HAVE_AVX2

ALIGN 16
shufb_32435465768798A9:
    db 3, 2, 4, 3, 5, 4, 6, 5, 7, 6, 8, 7, 9, 8, 10, 9
shufb_011267784556ABBC:
    db 0, 1, 1, 2, 6, 7, 7, 8, 4, 5, 5, 6, 0Ah, 0Bh, 0Bh, 0Ch
maddubsw_p1m5_p1m5_m5p1_m5p1_128:
    times 2 db 1, -5, 1, -5, -5, 1, -5, 1
maddubsw_m2p10_m40m40_p10m2_p0p0_128:
    times 2 db -2, 10, -40, -40, 10, -2, 0, 0
dwm1024_128:
    times 8 dw -1024
dd32768_128:
    times 4 dd 32768
maddubsw_p1m5_128:
    times 8 db 1, -5
maddubsw_m5p1_128:
    times 8 db -5, 1
db20_128:
    times 16 db 20
maddubsw_m5p20_128:
    times 8 db -5, 20
maddubsw_p20m5_128:
    times 8 db 20, -5
h264_w0x10_1:
    dw 16, 16, 16, 16, 16, 16, 16, 16
ALIGN 16
h264_mc_hc_32:
    dw 32, 32, 32, 32, 32, 32, 32, 32


;*******************************************************************************
; Code
;*******************************************************************************

SECTION .text

%ifdef X86_32_PICASM

%macro MOVEIMM_DW16 1
    pcmpeqw      %1,  %1
    psrlw        %1,  15
    psllw        %1,  4
%endmacro

%macro MOVEIMM_DW32 1
    pcmpeqw      %1,  %1
    psrlw        %1,  15
    psllw        %1,  5
%endmacro

%endif

;*******************************************************************************
; void McHorVer20WidthEq4_mmx( const uint8_t *pSrc,
;                       int iSrcStride,
;                       uint8_t *pDst,
;                       int iDstStride,
;                       int iHeight)
;*******************************************************************************
WELS_EXTERN McHorVer20WidthEq4_mmx
    %assign  push_num 0
    LOAD_5_PARA
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d

    sub r0, 2
    WELS_Zero mm7
%ifdef X86_32_PICASM
    MOVEIMM_DW16 mm6
%else
    movq mm6, [h264_w0x10_1]
%endif
.height_loop:
    movd mm0, [r0]
    punpcklbw mm0, mm7
    movd mm1, [r0+5]
    punpcklbw mm1, mm7
    movd mm2, [r0+1]
    punpcklbw mm2, mm7
    movd mm3, [r0+4]
    punpcklbw mm3, mm7
    movd mm4, [r0+2]
    punpcklbw mm4, mm7
    movd mm5, [r0+3]
    punpcklbw mm5, mm7

    paddw mm2, mm3
    paddw mm4, mm5
    psllw mm4, 2
    psubw mm4, mm2
    paddw mm0, mm1
    paddw mm0, mm4
    psllw mm4, 2
    paddw mm0, mm4
    paddw mm0, mm6
    psraw mm0, 5
    packuswb mm0, mm7
    movd [r2], mm0

    add r0, r1
    add r2, r3
    dec r4
    jnz .height_loop

    WELSEMMS
    LOAD_5_PARA_POP
    ret

;*******************************************************************************
; Macros and other preprocessor constants
;*******************************************************************************


%macro SSE_LOAD_8P 3
    movq %1, %3
    punpcklbw %1, %2
%endmacro

%macro FILTER_HV_W8 9
    paddw   %1, %6
%ifdef X86_32_PICASM
    MOVEIMM_DW16 %8
    paddw   %1, %8
%else
    paddw   %1, [h264_w0x10_1]
%endif
    movdqa  %8, %3
    movdqa  %7, %2
    paddw   %8, %4
    paddw   %7, %5
    psllw   %8, 2
    psubw   %8, %7
    paddw   %1, %8
    psllw   %8, 2
    paddw   %1, %8
    psraw   %1, 5
    WELS_Zero %8
    packuswb %1, %8
    movq    %9, %1
%endmacro


%macro FILTER_HV_W4 9
paddw   %1, %6
%ifdef X86_32_PICASM
MOVEIMM_DW16 %8
paddw   %1, %8
%else
paddw   %1, [h264_w0x10_1]
%endif
movdqa  %8, %3
movdqa  %7, %2
paddw   %8, %4
paddw   %7, %5
psllw   %8, 2
psubw   %8, %7
paddw   %1, %8
psllw   %8, 2
paddw   %1, %8
psraw   %1, 5
WELS_Zero %8
packuswb %1, %8
movd    %9, %1
%endmacro


;*******************************************************************************
; Code
;*******************************************************************************

SECTION .text

;***********************************************************************
; void McHorVer22Width8HorFirst_sse2(const int16_t *pSrc,
;                       int16_t iSrcStride,
;                       uint8_t *pDst,
;                       int32_t iDstStride
;                       int32_t iHeight
;                       )
;***********************************************************************
WELS_EXTERN McHorVer22Width8HorFirst_sse2
    %assign  push_num 0
    LOAD_5_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    pxor xmm7, xmm7

    sub r0, r1              ;;;;;;;;need more 5 lines.
    sub r0, r1

.yloop_width_8:
    movq xmm0, [r0]
    punpcklbw xmm0, xmm7
    movq xmm1, [r0+5]
    punpcklbw xmm1, xmm7
    movq xmm2, [r0+1]
    punpcklbw xmm2, xmm7
    movq xmm3, [r0+4]
    punpcklbw xmm3, xmm7
    movq xmm4, [r0+2]
    punpcklbw xmm4, xmm7
    movq xmm5, [r0+3]
    punpcklbw xmm5, xmm7

    paddw xmm2, xmm3
    paddw xmm4, xmm5
    psllw xmm4, 2
    psubw xmm4, xmm2
    paddw xmm0, xmm1
    paddw xmm0, xmm4
    psllw xmm4, 2
    paddw xmm0, xmm4
    movdqa [r2], xmm0

    add r0, r1
    add r2, r3
    dec r4
    jnz .yloop_width_8
    POP_XMM
    LOAD_5_PARA_POP
    ret

;*******************************************************************************
; void McHorVer20WidthEq8_sse2(  const uint8_t *pSrc,
;                       int iSrcStride,
;                                               uint8_t *pDst,
;                                               int iDstStride,
;                                               int iHeight,
;                      );
;*******************************************************************************
WELS_EXTERN McHorVer20WidthEq8_sse2
    %assign  push_num 0
    LOAD_5_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    lea r0, [r0-2]            ;pSrc -= 2;

    pxor xmm7, xmm7
%ifdef X86_32_PICASM
    MOVEIMM_DW16 xmm6
%else
    movdqa xmm6, [h264_w0x10_1]
%endif
.y_loop:
    movq xmm0, [r0]
    punpcklbw xmm0, xmm7
    movq xmm1, [r0+5]
    punpcklbw xmm1, xmm7
    movq xmm2, [r0+1]
    punpcklbw xmm2, xmm7
    movq xmm3, [r0+4]
    punpcklbw xmm3, xmm7
    movq xmm4, [r0+2]
    punpcklbw xmm4, xmm7
    movq xmm5, [r0+3]
    punpcklbw xmm5, xmm7

    paddw xmm2, xmm3
    paddw xmm4, xmm5
    psllw xmm4, 2
    psubw xmm4, xmm2
    paddw xmm0, xmm1
    paddw xmm0, xmm4
    psllw xmm4, 2
    paddw xmm0, xmm4
    paddw xmm0, xmm6
    psraw xmm0, 5

    packuswb xmm0, xmm7
    movq [r2], xmm0

    lea r2, [r2+r3]
    lea r0, [r0+r1]
    dec r4
    jnz near .y_loop

    POP_XMM
    LOAD_5_PARA_POP
    ret

;*******************************************************************************
; void McHorVer20WidthEq16_sse2(  const uint8_t *pSrc,
;                       int iSrcStride,
;                                               uint8_t *pDst,
;                                               int iDstStride,
;                                               int iHeight,
;                      );
;*******************************************************************************
WELS_EXTERN McHorVer20WidthEq16_sse2
    %assign  push_num 0
    LOAD_5_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    lea r0, [r0-2]            ;pSrc -= 2;

    pxor xmm7, xmm7
%ifdef X86_32_PICASM
    MOVEIMM_DW16 xmm6
%else
    movdqa xmm6, [h264_w0x10_1]
%endif
.y_loop:

    movq xmm0, [r0]
    punpcklbw xmm0, xmm7
    movq xmm1, [r0+5]
    punpcklbw xmm1, xmm7
    movq xmm2, [r0+1]
    punpcklbw xmm2, xmm7
    movq xmm3, [r0+4]
    punpcklbw xmm3, xmm7
    movq xmm4, [r0+2]
    punpcklbw xmm4, xmm7
    movq xmm5, [r0+3]
    punpcklbw xmm5, xmm7

    paddw xmm2, xmm3
    paddw xmm4, xmm5
    psllw xmm4, 2
    psubw xmm4, xmm2
    paddw xmm0, xmm1
    paddw xmm0, xmm4
    psllw xmm4, 2
    paddw xmm0, xmm4
    paddw xmm0, xmm6
    psraw xmm0, 5
    packuswb xmm0, xmm7
    movq [r2], xmm0

    movq xmm0, [r0+8]
    punpcklbw xmm0, xmm7
    movq xmm1, [r0+5+8]
    punpcklbw xmm1, xmm7
    movq xmm2, [r0+1+8]
    punpcklbw xmm2, xmm7
    movq xmm3, [r0+4+8]
    punpcklbw xmm3, xmm7
    movq xmm4, [r0+2+8]
    punpcklbw xmm4, xmm7
    movq xmm5, [r0+3+8]
    punpcklbw xmm5, xmm7

    paddw xmm2, xmm3
    paddw xmm4, xmm5
    psllw xmm4, 2
    psubw xmm4, xmm2
    paddw xmm0, xmm1
    paddw xmm0, xmm4
    psllw xmm4, 2
    paddw xmm0, xmm4
    paddw xmm0, xmm6
    psraw xmm0, 5
    packuswb xmm0, xmm7
    movq [r2+8], xmm0

    lea r2, [r2+r3]
    lea r0, [r0+r1]
    dec r4
    jnz near .y_loop

    POP_XMM
    LOAD_5_PARA_POP
    ret


;*******************************************************************************
; void McHorVer02WidthEq8_sse2( const uint8_t *pSrc,
;                       int iSrcStride,
;                       uint8_t *pDst,
;                       int iDstStride,
;                       int iHeight )
;*******************************************************************************
WELS_EXTERN McHorVer02WidthEq8_sse2
    %assign  push_num 0
    LOAD_5_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    sub r0, r1
    sub r0, r1

    WELS_Zero xmm7

    SSE_LOAD_8P xmm0, xmm7, [r0]
    SSE_LOAD_8P xmm1, xmm7, [r0+r1]
    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm2, xmm7, [r0]
    SSE_LOAD_8P xmm3, xmm7, [r0+r1]
    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm4, xmm7, [r0]
    SSE_LOAD_8P xmm5, xmm7, [r0+r1]

.start:
    FILTER_HV_W8 xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
    dec r4
    jz near .xx_exit

    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm6, xmm7, [r0]
    FILTER_HV_W8 xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, [r2+r3]
    dec r4
    jz near .xx_exit

    lea r2, [r2+2*r3]
    SSE_LOAD_8P xmm7, xmm0, [r0+r1]
    FILTER_HV_W8 xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, [r2]
    dec r4
    jz near .xx_exit

    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm0, xmm1, [r0]
    FILTER_HV_W8 xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, [r2+r3]
    dec r4
    jz near .xx_exit

    lea r2, [r2+2*r3]
    SSE_LOAD_8P xmm1, xmm2, [r0+r1]
    FILTER_HV_W8 xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, [r2]
    dec r4
    jz near .xx_exit

    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm2, xmm3, [r0]
    FILTER_HV_W8 xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, xmm4, [r2+r3]
    dec r4
    jz near .xx_exit

    lea r2, [r2+2*r3]
    SSE_LOAD_8P xmm3, xmm4, [r0+r1]
    FILTER_HV_W8 xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, [r2]
    dec r4
    jz near .xx_exit

    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm4, xmm5, [r0]
    FILTER_HV_W8 xmm7, xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, [r2+r3]
    dec r4
    jz near .xx_exit

    lea r2, [r2+2*r3]
    SSE_LOAD_8P xmm5, xmm6, [r0+r1]
    jmp near .start

.xx_exit:
    POP_XMM
    LOAD_5_PARA_POP
    ret

;***********************************************************************
; Code
;***********************************************************************

SECTION .text



;***********************************************************************
; void McHorVer02Height9Or17_sse2(  const uint8_t *pSrc,
;                       int32_t iSrcStride,
;                       uint8_t *pDst,
;                       int32_t iDstStride,
;                       int32_t iWidth,
;                       int32_t iHeight )
;***********************************************************************
WELS_EXTERN McHorVer02Height9Or17_sse2
    %assign  push_num 0
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d

%ifndef X86_32
    push r12
    push r13
    push r14
    mov  r12, r0
    mov  r13, r2
    mov  r14, r5
%endif

    shr r4, 3
    sub r0, r1
    sub r0, r1

.xloop:
    WELS_Zero xmm7
    SSE_LOAD_8P xmm0, xmm7, [r0]
    SSE_LOAD_8P xmm1, xmm7, [r0+r1]
    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm2, xmm7, [r0]
    SSE_LOAD_8P xmm3, xmm7, [r0+r1]
    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm4, xmm7, [r0]
    SSE_LOAD_8P xmm5, xmm7, [r0+r1]

    FILTER_HV_W8 xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
    dec r5
    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm6, xmm7, [r0]
    movdqa xmm0,xmm1
    movdqa xmm1,xmm2
    movdqa xmm2,xmm3
    movdqa xmm3,xmm4
    movdqa xmm4,xmm5
    movdqa xmm5,xmm6
    add r2, r3
    sub r0, r1

.start:
    FILTER_HV_W8 xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm6, xmm7, [r0]
    FILTER_HV_W8 xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, [r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    SSE_LOAD_8P xmm7, xmm0, [r0+r1]
    FILTER_HV_W8 xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, [r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm0, xmm1, [r0]
    FILTER_HV_W8 xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, [r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    SSE_LOAD_8P xmm1, xmm2, [r0+r1]
    FILTER_HV_W8 xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, [r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm2, xmm3, [r0]
    FILTER_HV_W8 xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, xmm4, [r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    SSE_LOAD_8P xmm3, xmm4, [r0+r1]
    FILTER_HV_W8 xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, [r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    SSE_LOAD_8P xmm4, xmm5, [r0]
    FILTER_HV_W8 xmm7, xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, [r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    SSE_LOAD_8P xmm5, xmm6, [r0+r1]
    jmp near .start

.x_loop_dec:
    dec r4
    jz  near .xx_exit
%ifdef X86_32
    mov r0, arg1
    mov r2, arg3
    mov r5, arg6
%else
    mov r0, r12
    mov r2, r13
    mov r5, r14
%endif
    sub r0, r1
    sub r0, r1
    add r0, 8
    add r2, 8
    jmp near .xloop

.xx_exit:
%ifndef X86_32
    pop r14
    pop r13
    pop r12
%endif
    POP_XMM
    LOAD_6_PARA_POP
    ret


;***********************************************************************
; void McHorVer02Height5_sse2(  const uint8_t *pSrc,
;                       int32_t iSrcStride,
;                       uint8_t *pDst,
;                       int32_t iDstStride,
;                       int32_t iWidth,
;                       int32_t iHeight )
;***********************************************************************
WELS_EXTERN McHorVer02Height5_sse2
%assign  push_num 0
LOAD_6_PARA
PUSH_XMM 8
SIGN_EXTENSION  r1, r1d
SIGN_EXTENSION  r3, r3d
SIGN_EXTENSION  r4, r4d
SIGN_EXTENSION  r5, r5d

%ifndef X86_32
push r12
push r13
push r14
mov  r12, r0
mov  r13, r2
mov  r14, r5
%endif

shr r4, 2
sub r0, r1
sub r0, r1

.xloop:
WELS_Zero xmm7
SSE_LOAD_8P xmm0, xmm7, [r0]
SSE_LOAD_8P xmm1, xmm7, [r0+r1]
lea r0, [r0+2*r1]
SSE_LOAD_8P xmm2, xmm7, [r0]
SSE_LOAD_8P xmm3, xmm7, [r0+r1]
lea r0, [r0+2*r1]
SSE_LOAD_8P xmm4, xmm7, [r0]
SSE_LOAD_8P xmm5, xmm7, [r0+r1]

FILTER_HV_W4 xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
dec r5
lea r0, [r0+2*r1]
SSE_LOAD_8P xmm6, xmm7, [r0]
movdqa xmm0,xmm1
movdqa xmm1,xmm2
movdqa xmm2,xmm3
movdqa xmm3,xmm4
movdqa xmm4,xmm5
movdqa xmm5,xmm6
add r2, r3
sub r0, r1

.start:
FILTER_HV_W4 xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
SSE_LOAD_8P xmm6, xmm7, [r0]
FILTER_HV_W4 xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, [r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
SSE_LOAD_8P xmm7, xmm0, [r0+r1]
FILTER_HV_W4 xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, [r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
SSE_LOAD_8P xmm0, xmm1, [r0]
FILTER_HV_W4 xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, [r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
SSE_LOAD_8P xmm1, xmm2, [r0+r1]
FILTER_HV_W4 xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, [r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
SSE_LOAD_8P xmm2, xmm3, [r0]
FILTER_HV_W4 xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, xmm4, [r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
SSE_LOAD_8P xmm3, xmm4, [r0+r1]
FILTER_HV_W4 xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, [r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
SSE_LOAD_8P xmm4, xmm5, [r0]
FILTER_HV_W4 xmm7, xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, [r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
SSE_LOAD_8P xmm5, xmm6, [r0+r1]
jmp near .start

.x_loop_dec:
dec r4
jz  near .xx_exit
%ifdef X86_32
mov r0, arg1
mov r2, arg3
mov r5, arg6
%else
mov r0, r12
mov r2, r13
mov r5, r14
%endif
sub r0, r1
sub r0, r1
add r0, 4
add r2, 4
jmp near .xloop

.xx_exit:
%ifndef X86_32
pop r14
pop r13
pop r12
%endif
POP_XMM
LOAD_6_PARA_POP
ret


;***********************************************************************
; void McHorVer20Width9Or17_sse2(       const uint8_t *pSrc,
;                       int32_t iSrcStride,
;                       uint8_t *pDst,
;                       int32_t iDstStride,
;                       int32_t iWidth,
;                       int32_t iHeight
;                      );
;***********************************************************************
WELS_EXTERN McHorVer20Width9Or17_sse2
    %assign  push_num 0
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
    sub r0, 2
    pxor xmm7, xmm7

    cmp r4, 9
    jne near .width_17

.yloop_width_9:
    movq xmm0, [r0]
    punpcklbw xmm0, xmm7
    movq xmm1, [r0+5]
    punpcklbw xmm1, xmm7
    movq xmm2, [r0+1]
    punpcklbw xmm2, xmm7
    movq xmm3, [r0+4]
    punpcklbw xmm3, xmm7
    movq xmm4, [r0+2]
    punpcklbw xmm4, xmm7
    movq xmm5, [r0+3]
    punpcklbw xmm5, xmm7

    movdqa xmm7, xmm2
    paddw   xmm7, xmm3
    movdqa xmm6, xmm4
    paddw   xmm6, xmm5
    psllw xmm6, 2
    psubw xmm6, xmm7
    paddw xmm0, xmm1
    paddw xmm0, xmm6
    psllw xmm6, 2
    paddw xmm0, xmm6
%ifdef X86_32_PICASM
    MOVEIMM_DW16 xmm6
    paddw xmm0, xmm6
%else
    paddw xmm0, [h264_w0x10_1]
%endif
    psraw  xmm0, 5
    packuswb xmm0, xmm0
    movd [r2], xmm0

    pxor  xmm7, xmm7
    movq xmm0, [r0+6]
    punpcklbw xmm0, xmm7

    paddw xmm4, xmm1
    paddw xmm5, xmm3
    psllw xmm5, 2
    psubw xmm5, xmm4
    paddw xmm2, xmm0
    paddw xmm2, xmm5
    psllw xmm5, 2
    paddw xmm2, xmm5
%ifdef X86_32_PICASM
    paddw xmm2, xmm6
%else
    paddw xmm2, [h264_w0x10_1]
%endif
    psraw  xmm2, 5
    packuswb xmm2, xmm2
    movq [r2+1], xmm2

    add r0, r1
    add r2, r3
    dec r5
    jnz .yloop_width_9
    POP_XMM
    LOAD_6_PARA_POP
    ret


.width_17:
.yloop_width_17:
    movq xmm0, [r0]
    punpcklbw xmm0, xmm7
    movq xmm1, [r0+5]
    punpcklbw xmm1, xmm7
    movq xmm2, [r0+1]
    punpcklbw xmm2, xmm7
    movq xmm3, [r0+4]
    punpcklbw xmm3, xmm7
    movq xmm4, [r0+2]
    punpcklbw xmm4, xmm7
    movq xmm5, [r0+3]
    punpcklbw xmm5, xmm7

    paddw xmm2, xmm3
    paddw xmm4, xmm5
    psllw xmm4, 2
    psubw xmm4, xmm2
    paddw xmm0, xmm1
    paddw xmm0, xmm4
    psllw xmm4, 2
    paddw xmm0, xmm4
%ifdef X86_32_PICASM
    MOVEIMM_DW16 xmm6
    paddw xmm0, xmm6
%else
    paddw xmm0, [h264_w0x10_1]
%endif
    psraw  xmm0, 5
    packuswb xmm0, xmm0
    movq [r2], xmm0

    movq xmm0, [r0+8]
    punpcklbw xmm0, xmm7
    movq xmm1, [r0+5+8]
    punpcklbw xmm1, xmm7
    movq xmm2, [r0+1+8]
    punpcklbw xmm2, xmm7
    movq xmm3, [r0+4+8]
    punpcklbw xmm3, xmm7
    movq xmm4, [r0+2+8]
    punpcklbw xmm4, xmm7
    movq xmm5, [r0+3+8]
    punpcklbw xmm5, xmm7

    movdqa xmm7, xmm2
    paddw   xmm7, xmm3
    movdqa xmm6, xmm4
    paddw   xmm6, xmm5
    psllw xmm6, 2
    psubw xmm6, xmm7
    paddw xmm0, xmm1
    paddw xmm0, xmm6
    psllw xmm6, 2
    paddw xmm0, xmm6
%ifdef X86_32_PICASM
    MOVEIMM_DW16 xmm6
    paddw xmm0, xmm6
%else
    paddw xmm0, [h264_w0x10_1]
%endif
    psraw  xmm0, 5
    packuswb xmm0, xmm0
    movd [r2+8], xmm0


    pxor  xmm7, xmm7
    movq xmm0, [r0+6+8]
    punpcklbw xmm0, xmm7

    paddw xmm4, xmm1
    paddw xmm5, xmm3
    psllw xmm5, 2
    psubw xmm5, xmm4
    paddw xmm2, xmm0
    paddw xmm2, xmm5
    psllw xmm5, 2
    paddw xmm2, xmm5
%ifdef X86_32_PICASM
    paddw xmm2, xmm6
%else
    paddw xmm2, [h264_w0x10_1]
%endif
    psraw  xmm2, 5
    packuswb xmm2, xmm2
    movq [r2+9], xmm2
    add r0, r1
    add r2, r3
    dec r5
    jnz .yloop_width_17
    POP_XMM
    LOAD_6_PARA_POP
    ret


;***********************************************************************
; void McHorVer20Width5_sse2(       const uint8_t *pSrc,
;                       int32_t iSrcStride,
;                       uint8_t *pDst,
;                       int32_t iDstStride,
;                       int32_t iWidth,
;                       int32_t iHeight
;                      );
;***********************************************************************
WELS_EXTERN McHorVer20Width5_sse2
%assign  push_num 0
LOAD_6_PARA
PUSH_XMM 8
SIGN_EXTENSION  r1, r1d
SIGN_EXTENSION  r3, r3d
SIGN_EXTENSION  r4, r4d
SIGN_EXTENSION  r5, r5d
sub r0, 2
pxor xmm7, xmm7

.yloop_width_5:
movq xmm0, [r0]
punpcklbw xmm0, xmm7
movq xmm1, [r0+5]
punpcklbw xmm1, xmm7
movq xmm2, [r0+1]
punpcklbw xmm2, xmm7
movq xmm3, [r0+4]
punpcklbw xmm3, xmm7
movq xmm4, [r0+2]
punpcklbw xmm4, xmm7
movq xmm5, [r0+3]
punpcklbw xmm5, xmm7

movdqa xmm7, xmm2
paddw   xmm7, xmm3
movdqa xmm6, xmm4
paddw   xmm6, xmm5
psllw xmm6, 2
psubw xmm6, xmm7
paddw xmm0, xmm1
paddw xmm0, xmm6
psllw xmm6, 2
paddw xmm0, xmm6
%ifdef X86_32_PICASM
MOVEIMM_DW16 xmm6
paddw xmm0, xmm6
%else
paddw xmm0, [h264_w0x10_1]
%endif
psraw  xmm0, 5
packuswb xmm0, xmm0
movd [r2], xmm0

pxor  xmm7, xmm7
movq xmm0, [r0+6]
punpcklbw xmm0, xmm7

paddw xmm4, xmm1
paddw xmm5, xmm3
psllw xmm5, 2
psubw xmm5, xmm4
paddw xmm2, xmm0
paddw xmm2, xmm5
psllw xmm5, 2
paddw xmm2, xmm5
%ifdef X86_32_PICASM
paddw xmm2, xmm6
%else
paddw xmm2, [h264_w0x10_1]
%endif
psraw  xmm2, 5
packuswb xmm2, xmm2
movd [r2+1], xmm2

add r0, r1
add r2, r3
dec r5
jnz .yloop_width_5
POP_XMM
LOAD_6_PARA_POP
ret


;***********************************************************************
;void McHorVer22HorFirst_sse2
;                           (const uint8_t *pSrc,
;                           int32_t iSrcStride,
;                           uint8_t * pTap,
;                           int32_t iTapStride,
;                           int32_t iWidth,int32_t iHeight);
;***********************************************************************
WELS_EXTERN McHorVer22HorFirst_sse2
    %assign  push_num 0
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
    pxor xmm7, xmm7
    sub r0, r1              ;;;;;;;;need more 5 lines.
    sub r0, r1

    cmp r4, 9
    jne near .width_17

.yloop_width_9:
    movq xmm0, [r0]
    punpcklbw xmm0, xmm7
    movq xmm1, [r0+5]
    punpcklbw xmm1, xmm7
    movq xmm2, [r0+1]
    punpcklbw xmm2, xmm7
    movq xmm3, [r0+4]
    punpcklbw xmm3, xmm7
    movq xmm4, [r0+2]
    punpcklbw xmm4, xmm7
    movq xmm5, [r0+3]
    punpcklbw xmm5, xmm7

    movdqa xmm7, xmm2
    paddw   xmm7, xmm3
    movdqa xmm6, xmm4
    paddw   xmm6, xmm5
    psllw xmm6, 2
    psubw xmm6, xmm7
    paddw xmm0, xmm1
    paddw xmm0, xmm6
    psllw xmm6, 2
    paddw xmm0, xmm6
    movd [r2], xmm0

    pxor  xmm7, xmm7
    movq xmm0, [r0+6]
    punpcklbw xmm0, xmm7

    paddw xmm4, xmm1
    paddw xmm5, xmm3
    psllw xmm5, 2
    psubw xmm5, xmm4
    paddw xmm2, xmm0
    paddw xmm2, xmm5
    psllw xmm5, 2
    paddw xmm2, xmm5
    movq [r2+2], xmm2
    movhps [r2+2+8], xmm2

    add r0, r1
    add r2, r3
    dec r5
    jnz .yloop_width_9
    POP_XMM
    LOAD_6_PARA_POP
    ret


.width_17:
.yloop_width_17:
    movq xmm0, [r0]
    punpcklbw xmm0, xmm7
    movq xmm1, [r0+5]
    punpcklbw xmm1, xmm7
    movq xmm2, [r0+1]
    punpcklbw xmm2, xmm7
    movq xmm3, [r0+4]
    punpcklbw xmm3, xmm7
    movq xmm4, [r0+2]
    punpcklbw xmm4, xmm7
    movq xmm5, [r0+3]
    punpcklbw xmm5, xmm7

    paddw xmm2, xmm3
    paddw xmm4, xmm5
    psllw xmm4, 2
    psubw xmm4, xmm2
    paddw xmm0, xmm1
    paddw xmm0, xmm4
    psllw xmm4, 2
    paddw xmm0, xmm4
    movdqa [r2], xmm0

    movq xmm0, [r0+8]
    punpcklbw xmm0, xmm7
    movq xmm1, [r0+5+8]
    punpcklbw xmm1, xmm7
    movq xmm2, [r0+1+8]
    punpcklbw xmm2, xmm7
    movq xmm3, [r0+4+8]
    punpcklbw xmm3, xmm7
    movq xmm4, [r0+2+8]
    punpcklbw xmm4, xmm7
    movq xmm5, [r0+3+8]
    punpcklbw xmm5, xmm7

    movdqa xmm7, xmm2
    paddw   xmm7, xmm3
    movdqa xmm6, xmm4
    paddw   xmm6, xmm5
    psllw xmm6, 2
    psubw xmm6, xmm7
    paddw xmm0, xmm1
    paddw xmm0, xmm6
    psllw xmm6, 2
    paddw xmm0, xmm6
    movd [r2+16], xmm0


    pxor  xmm7, xmm7
    movq xmm0, [r0+6+8]
    punpcklbw xmm0, xmm7

    paddw xmm4, xmm1
    paddw xmm5, xmm3
    psllw xmm5, 2
    psubw xmm5, xmm4
    paddw xmm2, xmm0
    paddw xmm2, xmm5
    psllw xmm5, 2
    paddw xmm2, xmm5
    movq [r2+18], xmm2
    movhps [r2+18+8], xmm2

    add r0, r1
    add r2, r3
    dec r5
    jnz .yloop_width_17
    POP_XMM
    LOAD_6_PARA_POP
    ret


%macro FILTER_VER 9
    paddw  %1, %6
    movdqa %7, %2
    movdqa %8, %3


    paddw %7, %5
    paddw %8, %4

    psubw  %1, %7
    psraw   %1, 2
    paddw  %1, %8
    psubw  %1, %7
    psraw   %1, 2
    paddw  %8, %1
%ifdef X86_32_PICASM
    MOVEIMM_DW32 %7
    paddw  %8, %7
%else
    paddw  %8, [h264_mc_hc_32]
%endif
    psraw   %8, 6
    packuswb %8, %8
    movq %9, %8
%endmacro
;***********************************************************************
;void McHorVer22Width8VerLastAlign_sse2(
;                                           const uint8_t *pTap,
;                                           int32_t iTapStride,
;                                           uint8_t * pDst,
;                                           int32_t iDstStride,
;                                           int32_t iWidth,
;                                           int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer22Width8VerLastAlign_sse2
    %assign  push_num 0
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
%ifndef X86_32
    push r12
    push r13
    push r14
    mov  r12, r0
    mov  r13, r2
    mov  r14, r5
%endif

    shr r4, 3

.width_loop:
    movdqa xmm0, [r0]
    movdqa xmm1, [r0+r1]
    lea r0, [r0+2*r1]
    movdqa xmm2, [r0]
    movdqa xmm3, [r0+r1]
    lea r0, [r0+2*r1]
    movdqa xmm4, [r0]
    movdqa xmm5, [r0+r1]

    FILTER_VER xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
    dec r5
    lea r0, [r0+2*r1]
    movdqa xmm6, [r0]

    movdqa xmm0, xmm1
    movdqa xmm1, xmm2
    movdqa xmm2, xmm3
    movdqa xmm3, xmm4
    movdqa xmm4, xmm5
    movdqa xmm5, xmm6

    add r2, r3
    sub r0, r1

.start:
    FILTER_VER xmm0,xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    movdqa xmm6, [r0]
    FILTER_VER xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0,[r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    movdqa xmm7, [r0+r1]
    FILTER_VER  xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, [r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    movdqa xmm0, [r0]
    FILTER_VER  xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2,[r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    movdqa xmm1, [r0+r1]
    FILTER_VER  xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,[r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    movdqa xmm2, [r0]
    FILTER_VER  xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,[r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    movdqa xmm3, [r0+r1]
    FILTER_VER  xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,xmm5,[r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    movdqa xmm4, [r0]
    FILTER_VER  xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,xmm5,xmm6, [r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    movdqa xmm5, [r0+r1]
    jmp near .start

.x_loop_dec:
    dec r4
    jz near .exit
%ifdef X86_32
    mov r0, arg1
    mov r2, arg3
    mov r5, arg6
%else
    mov r0, r12
    mov r2, r13
    mov r5, r14
%endif
    add r0, 16
    add r2, 8
    jmp .width_loop

.exit:
%ifndef X86_32
    pop r14
    pop r13
    pop r12
%endif
    POP_XMM
    LOAD_6_PARA_POP
    ret

;***********************************************************************
;void McHorVer22Width8VerLastUnAlign_sse2(
;                                           const uint8_t *pTap,
;                                           int32_t iTapStride,
;                                           uint8_t * pDst,
;                                           int32_t iDstStride,
;                                           int32_t iWidth,
;                                           int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer22Width8VerLastUnAlign_sse2
    %assign  push_num 0
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
%ifndef X86_32
    push r12
    push r13
    push r14
    mov  r12, r0
    mov  r13, r2
    mov  r14, r5
%endif
    shr r4, 3

.width_loop:
    movdqu xmm0, [r0]
    movdqu xmm1, [r0+r1]
    lea r0, [r0+2*r1]
    movdqu xmm2, [r0]
    movdqu xmm3, [r0+r1]
    lea r0, [r0+2*r1]
    movdqu xmm4, [r0]
    movdqu xmm5, [r0+r1]

    FILTER_VER xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
    dec r5
    lea r0, [r0+2*r1]
    movdqu xmm6, [r0]

    movdqa xmm0, xmm1
    movdqa xmm1, xmm2
    movdqa xmm2, xmm3
    movdqa xmm3, xmm4
    movdqa xmm4, xmm5
    movdqa xmm5, xmm6

    add r2, r3
    sub r0, r1

.start:
    FILTER_VER xmm0,xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    movdqu xmm6, [r0]
    FILTER_VER xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0,[r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    movdqu xmm7, [r0+r1]
    FILTER_VER  xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, [r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    movdqu xmm0, [r0]
    FILTER_VER  xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2,[r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    movdqu xmm1, [r0+r1]
    FILTER_VER  xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,[r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    movdqu xmm2, [r0]
    FILTER_VER  xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,[r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    movdqu xmm3, [r0+r1]
    FILTER_VER  xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,xmm5,[r2]
    dec r5
    jz near .x_loop_dec

    lea r0, [r0+2*r1]
    movdqu xmm4, [r0]
    FILTER_VER  xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,xmm5,xmm6, [r2+r3]
    dec r5
    jz near .x_loop_dec

    lea r2, [r2+2*r3]
    movdqu xmm5, [r0+r1]
    jmp near .start

.x_loop_dec:
    dec r4
    jz near .exit
%ifdef X86_32
    mov r0, arg1
    mov r2, arg3
    mov r5, arg6
%else
    mov r0, r12
    mov r2, r13
    mov r5, r14
%endif
    add r0, 16
    add r2, 8
    jmp .width_loop

.exit:
%ifndef X86_32
    pop r14
    pop r13
    pop r12
%endif
    POP_XMM
    LOAD_6_PARA_POP
    ret


;***********************************************************************
;void McHorVer22Width5HorFirst_sse2
;                           (const uint8_t *pSrc,
;                           int32_t iSrcStride,
;                           uint8_t * pTap,
;                           int32_t iTapStride,
;                           int32_t iWidth,int32_t iHeight);
;***********************************************************************
WELS_EXTERN McHorVer22Width5HorFirst_sse2
%assign  push_num 0
LOAD_6_PARA
PUSH_XMM 8
SIGN_EXTENSION  r1, r1d
SIGN_EXTENSION  r3, r3d
SIGN_EXTENSION  r4, r4d
SIGN_EXTENSION  r5, r5d
pxor xmm7, xmm7
sub r0, r1              ;;;;;;;;need more 5 lines.
sub r0, r1

.yloop_width_5:
movq xmm0, [r0]
punpcklbw xmm0, xmm7
movq xmm1, [r0+5]
punpcklbw xmm1, xmm7
movq xmm2, [r0+1]
punpcklbw xmm2, xmm7
movq xmm3, [r0+4]
punpcklbw xmm3, xmm7
movq xmm4, [r0+2]
punpcklbw xmm4, xmm7
movq xmm5, [r0+3]
punpcklbw xmm5, xmm7

movdqa xmm7, xmm2
paddw   xmm7, xmm3
movdqa xmm6, xmm4
paddw   xmm6, xmm5
psllw xmm6, 2
psubw xmm6, xmm7
paddw xmm0, xmm1
paddw xmm0, xmm6
psllw xmm6, 2
paddw xmm0, xmm6
movd [r2], xmm0

pxor  xmm7, xmm7
movq xmm0, [r0+6]
punpcklbw xmm0, xmm7

paddw xmm4, xmm1
paddw xmm5, xmm3
psllw xmm5, 2
psubw xmm5, xmm4
paddw xmm2, xmm0
paddw xmm2, xmm5
psllw xmm5, 2
paddw xmm2, xmm5
movq [r2+2], xmm2
movhps [r2+2+8], xmm2

add r0, r1
add r2, r3
dec r5
jnz .yloop_width_5
POP_XMM
LOAD_6_PARA_POP
ret


%macro FILTER_VER_4 9
paddw  %1, %6
movdqa %7, %2
movdqa %8, %3


paddw %7, %5
paddw %8, %4

psubw  %1, %7
psraw   %1, 2
paddw  %1, %8
psubw  %1, %7
psraw   %1, 2
paddw  %8, %1
%ifdef X86_32_PICASM
MOVEIMM_DW32 %7
paddw  %8, %7
%else
paddw  %8, [h264_mc_hc_32]
%endif
psraw   %8, 6
packuswb %8, %8
movd %9, %8
%endmacro


;***********************************************************************
;void McHorVer22Width4VerLastAlign_sse2(
;                                           const uint8_t *pTap,
;                                           int32_t iTapStride,
;                                           uint8_t * pDst,
;                                           int32_t iDstStride,
;                                           int32_t iWidth,
;                                           int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer22Width4VerLastAlign_sse2
%assign  push_num 0
LOAD_6_PARA
PUSH_XMM 8
SIGN_EXTENSION  r1, r1d
SIGN_EXTENSION  r3, r3d
SIGN_EXTENSION  r4, r4d
SIGN_EXTENSION  r5, r5d
%ifndef X86_32
push r12
push r13
push r14
mov  r12, r0
mov  r13, r2
mov  r14, r5
%endif

shr r4, 2

.width_loop:
movdqa xmm0, [r0]
movdqa xmm1, [r0+r1]
lea r0, [r0+2*r1]
movdqa xmm2, [r0]
movdqa xmm3, [r0+r1]
lea r0, [r0+2*r1]
movdqa xmm4, [r0]
movdqa xmm5, [r0+r1]

FILTER_VER_4 xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
dec r5
lea r0, [r0+2*r1]
movdqa xmm6, [r0]

movdqa xmm0, xmm1
movdqa xmm1, xmm2
movdqa xmm2, xmm3
movdqa xmm3, xmm4
movdqa xmm4, xmm5
movdqa xmm5, xmm6

add r2, r3
sub r0, r1

.start:
FILTER_VER_4 xmm0,xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
movdqa xmm6, [r0]
FILTER_VER_4 xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0,[r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
movdqa xmm7, [r0+r1]
FILTER_VER_4  xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, [r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
movdqa xmm0, [r0]
FILTER_VER_4  xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2,[r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
movdqa xmm1, [r0+r1]
FILTER_VER_4  xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,[r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
movdqa xmm2, [r0]
FILTER_VER_4  xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,[r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
movdqa xmm3, [r0+r1]
FILTER_VER_4  xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,xmm5,[r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
movdqa xmm4, [r0]
FILTER_VER_4  xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,xmm5,xmm6, [r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
movdqa xmm5, [r0+r1]
jmp near .start

.x_loop_dec:
dec r4
jz near .exit
%ifdef X86_32
mov r0, arg1
mov r2, arg3
mov r5, arg6
%else
mov r0, r12
mov r2, r13
mov r5, r14
%endif
add r0, 8
add r2, 4
jmp .width_loop

.exit:
%ifndef X86_32
pop r14
pop r13
pop r12
%endif
POP_XMM
LOAD_6_PARA_POP
ret


;***********************************************************************
;void McHorVer22Width4VerLastUnAlign_sse2(
;                                           const uint8_t *pTap,
;                                           int32_t iTapStride,
;                                           uint8_t * pDst,
;                                           int32_t iDstStride,
;                                           int32_t iWidth,
;                                           int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer22Width4VerLastUnAlign_sse2
%assign  push_num 0
LOAD_6_PARA
PUSH_XMM 8
SIGN_EXTENSION  r1, r1d
SIGN_EXTENSION  r3, r3d
SIGN_EXTENSION  r4, r4d
SIGN_EXTENSION  r5, r5d
%ifndef X86_32
push r12
push r13
push r14
mov  r12, r0
mov  r13, r2
mov  r14, r5
%endif
shr r4, 2

.width_loop:
movdqu xmm0, [r0]
movdqu xmm1, [r0+r1]
lea r0, [r0+2*r1]
movdqu xmm2, [r0]
movdqu xmm3, [r0+r1]
lea r0, [r0+2*r1]
movdqu xmm4, [r0]
movdqu xmm5, [r0+r1]

FILTER_VER_4 xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
dec r5
lea r0, [r0+2*r1]
movdqu xmm6, [r0]

movdqa xmm0, xmm1
movdqa xmm1, xmm2
movdqa xmm2, xmm3
movdqa xmm3, xmm4
movdqa xmm4, xmm5
movdqa xmm5, xmm6

add r2, r3
sub r0, r1

.start:
FILTER_VER_4 xmm0,xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, [r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
movdqu xmm6, [r0]
FILTER_VER_4 xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0,[r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
movdqu xmm7, [r0+r1]
FILTER_VER_4  xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, [r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
movdqu xmm0, [r0]
FILTER_VER_4  xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2,[r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
movdqu xmm1, [r0+r1]
FILTER_VER_4  xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,[r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
movdqu xmm2, [r0]
FILTER_VER_4  xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,[r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
movdqu xmm3, [r0+r1]
FILTER_VER_4  xmm6, xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,xmm5,[r2]
dec r5
jz near .x_loop_dec

lea r0, [r0+2*r1]
movdqu xmm4, [r0]
FILTER_VER_4  xmm7, xmm0, xmm1, xmm2, xmm3,xmm4,xmm5,xmm6, [r2+r3]
dec r5
jz near .x_loop_dec

lea r2, [r2+2*r3]
movdqu xmm5, [r0+r1]
jmp near .start

.x_loop_dec:
dec r4
jz near .exit
%ifdef X86_32
mov r0, arg1
mov r2, arg3
mov r5, arg6
%else
mov r0, r12
mov r2, r13
mov r5, r14
%endif
add r0, 8
add r2, 4
jmp .width_loop

.exit:
%ifndef X86_32
pop r14
pop r13
pop r12
%endif
POP_XMM
LOAD_6_PARA_POP
ret


; px_ab=%1 px_cd=%2 px_ef=%3 maddubsw_ab=%4 maddubsw_cd=%5 maddubsw_ef=%6 tmp=%7
%macro SSSE3_FilterVertical_8px 7
    pmaddubsw       %1, %4
    movdqa          %7, %2
    pmaddubsw       %7, %5
    paddw           %1, %7
    movdqa          %7, %3
    pmaddubsw       %7, %6
    paddw           %1, %7
%ifdef X86_32_PICASM
    MOVEIMM_DW16    %7
    paddw            %1, %7
%else
    paddw           %1, [h264_w0x10_1]
%endif
    psraw           %1, 5
%endmacro

; px_a=%1 px_f=%2 px_bc=%3 px_de=%4 maddubsw_bc=%5 maddubsw_de=%6 tmp=%7,%8
%macro SSSE3_FilterVertical2_8px 8
    movdqa          %8, %2
    pxor            %7, %7
    punpcklbw       %1, %7
    punpcklbw       %8, %7
    paddw           %1, %8
    movdqa          %7, %3
    pmaddubsw       %7, %5
    paddw           %1, %7
    movdqa          %7, %4
    pmaddubsw       %7, %6
    paddw           %1, %7
%ifdef X86_32_PICASM
    MOVEIMM_DW16    %7
    paddw            %1, %7
%else
    paddw           %1, [h264_w0x10_1]
%endif
    psraw           %1, 5
%endmacro

; pixels=%1 shufb_32435465768798A9=%2 shufb_011267784556ABBC=%3 maddubsw_p1m5_p1m5_m5p1_m5p1=%4 tmp=%5,%6
%macro SSSE3_FilterHorizontalbw_8px 6
    movdqa          %5, %1
    pshufb          %1, %2
    pshufb          %5, %3
    pshufd          %6, %1, 10110001b
%ifdef X86_32_PICASM
    push            r0
    mov             r0, esp
    and             esp, 0xfffffff0
    push            0x14141414    ;db20_128
    push            0x14141414
    push            0x14141414
    push            0x14141414
    pmaddubsw       %1, [esp]
    mov             esp, r0
    pop             r0
%else
    pmaddubsw       %1, [db20_128]
%endif
    pmaddubsw       %5, %4
    pmaddubsw       %6, %4
    paddw           %1, %5
    paddw           %1, %6
%endmacro

; pixels=%1 shufb_32435465768798A9=%2 shufb_011267784556ABBC=%3 maddubsw_p1m5_p1m5_m5p1_m5p1=%4 tmp=%5,%6
%macro SSSE3_FilterHorizontal_8px 6
    SSSE3_FilterHorizontalbw_8px %1, %2, %3, %4, %5, %6
%ifdef X86_32_PICASM
    MOVEIMM_DW16    %5
    paddw           %1, %5
%else
    paddw           %1, [h264_w0x10_1]
%endif
    psraw           %1, 5
%endmacro

; px0=%1 px1=%2 shufb_32435465768798A9=%3 shufb_011267784556ABBC=%4 maddubsw_p1m5_p1m5_m5p1_m5p1=%5 tmp=%6,%7
%macro SSSE3_FilterHorizontalbw_2x4px 7
    movdqa          %6, %1
    movdqa          %7, %2
    pshufb          %1, %3
    pshufb          %2, %3
    punpcklqdq      %1, %2
    pshufb          %6, %4
    pshufb          %7, %4
    punpcklqdq      %6, %7
    pshufd          %7, %1, 10110001b
%ifdef X86_32_PICASM
    push            r0
    mov             r0, esp
    and             esp, 0xfffffff0
    push            0x14141414    ;db20_128
    push            0x14141414
    push            0x14141414
    push            0x14141414
    pmaddubsw       %1, [esp]
    mov             esp, r0
    pop             r0
%else
    pmaddubsw       %1, [db20_128]
%endif
    pmaddubsw       %6, %5
    pmaddubsw       %7, %5
    paddw           %1, %6
    paddw           %1, %7
%endmacro

; px0=%1 px1=%2 shufb_32435465768798A9=%3 shufb_011267784556ABBC=%4 maddubsw_p1m5_p1m5_m5p1_m5p1=%5 tmp=%6,%7
%macro SSSE3_FilterHorizontal_2x4px 7
    SSSE3_FilterHorizontalbw_2x4px %1, %2, %3, %4, %5, %6, %7
%ifdef X86_32_PICASM
    MOVEIMM_DW16    %6
    paddw           %1, %6
%else
    paddw           %1, [h264_w0x10_1]
%endif
    psraw           %1, 5
%endmacro

; pixels=%1 -32768>>scale=%2 tmp=%3
%macro SSSE3_FilterHorizontalbw_2px 3
%ifdef X86_32_PICASM
    push            r1
    mov             r1, esp
    and             esp, 0xfffffff0
    push            0x0000fe0a
    push            0xd8d80afe
    push            0x0000fe0a
    push            0xd8d80afe
    pmaddubsw       %1, [esp]
    mov             esp, r1
    pop             r1
%else
    pmaddubsw       %1, [maddubsw_m2p10_m40m40_p10m2_p0p0_128]
%endif
    pmaddwd         %1, %2
    pshufd          %3, %1, 10110001b
    paddd           %1, %3
%endmacro

; pixels=%1 tmp=%2
%macro SSSE3_FilterHorizontal_2px 2
%ifdef X86_32_PICASM
    push            r1
    mov             r1, esp
    and             esp, 0xfffffff0
    push            0x0000fe0a
    push            0xd8d80afe
    push            0x0000fe0a
    push            0xd8d80afe
    pmaddubsw       %1, [esp]
    push            0xfc00fc00
    push            0xfc00fc00
    push            0xfc00fc00
    push            0xfc00fc00
    pmaddwd         %1, [esp]
    pshufd          %2, %1, 10110001b
    paddd           %1, %2
    push            0x00008000
    push            0x00008000
    push            0x00008000
    push            0x00008000
    paddd           %1, [esp]
    mov             esp, r1
    pop             r1
%else
    SSSE3_FilterHorizontalbw_2px %1, [dwm1024_128], %2
    paddd           %1, [dd32768_128]
%endif
%endmacro

; px0=%1 px1=%2 px2=%3 px3=%4 px4=%5 px5=%6 tmp=%7
%macro SSE2_FilterVerticalw_8px 7
    paddw           %1, %6
    movdqa          %7, %2
    paddw           %7, %5
    psubw           %1, %7
    psraw           %1, 2
    psubw           %1, %7
    movdqa          %7, %3
    paddw           %7, %4
    paddw           %1, %7
    psraw           %1, 2
%ifdef X86_32_PICASM
    paddw           %1, %7
    MOVEIMM_DW32    %7
    paddw           %1, %7
%else
    paddw           %7, [h264_mc_hc_32]
    paddw           %1, %7
%endif
    psraw           %1, 6
%endmacro

;***********************************************************************
; void McHorVer02_ssse3(const uint8_t *pSrc,
;                       int32_t iSrcStride,
;                       uint8_t *pDst,
;                       int32_t iDstStride,
;                       int32_t iWidth,
;                       int32_t iHeight)
;***********************************************************************

WELS_EXTERN McHorVer02_ssse3
%define p_src         r0
%define i_srcstride   r1
%define p_dst         r2
%define i_dststride   r3
%define i_width       r4
%define i_height      r5
%define i_srcstride3  r6
    %assign push_num 0
%ifdef X86_32
    push            r6
    %assign push_num 1
%endif
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
    sub             p_src, i_srcstride
    sub             p_src, i_srcstride
    lea             i_srcstride3, [3 * i_srcstride]
    cmp             i_width, 4
    jg              .width8or16

%ifdef X86_32_PICASM
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    movdqu          xmm6, [esp]
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    movdqu          xmm7, [esp]
    push            0x14141414    ;db20_128
    push            0x14141414
    push            0x14141414
    push            0x14141414
%endif
    movd            xmm0, [p_src]
    movd            xmm4, [p_src + i_srcstride]
    punpcklbw       xmm0, xmm4
    movd            xmm1, [p_src + 2 * i_srcstride]
    punpcklbw       xmm4, xmm1
    punpcklqdq      xmm0, xmm4
    movd            xmm4, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    punpcklbw       xmm1, xmm4
    movd            xmm2, [p_src]
    punpcklbw       xmm4, xmm2
    punpcklqdq      xmm1, xmm4
    movd            xmm4, [p_src + i_srcstride]
    lea             p_src, [p_src + 2 * i_srcstride]
    punpcklbw       xmm2, xmm4
    movd            xmm3, [p_src]
    punpcklbw       xmm4, xmm3
    punpcklqdq      xmm2, xmm4
%ifdef X86_32_PICASM
    movdqu          xmm5, [esp]
    SSSE3_FilterVertical_8px xmm0, xmm1, xmm2, xmm6, xmm5, xmm7, xmm4
    add             esp, 48
%else
    movdqa          xmm5, [db20_128]
    SSSE3_FilterVertical_8px xmm0, xmm1, xmm2, [maddubsw_p1m5_128], xmm5, [maddubsw_m5p1_128], xmm4
%endif
    packuswb        xmm0, xmm0
    movd            [p_dst], xmm0
    psrlq           xmm0, 32
    movd            [p_dst + i_dststride], xmm0
    lea             p_dst, [p_dst + 2 * i_dststride]
    movd            xmm4, [p_src + i_srcstride]
    punpcklbw       xmm3, xmm4
    movd            xmm0, [p_src + 2 * i_srcstride]
    punpcklbw       xmm4, xmm0
    punpcklqdq      xmm3, xmm4
%ifdef X86_32_PICASM
    SSSE3_FilterVertical_8px xmm1, xmm2, xmm3, xmm6, xmm5, xmm7, xmm4
%else
    SSSE3_FilterVertical_8px xmm1, xmm2, xmm3, [maddubsw_p1m5_128], xmm5, [maddubsw_m5p1_128], xmm4
%endif
    packuswb        xmm1, xmm1
    movd            [p_dst], xmm1
    psrlq           xmm1, 32
    movd            [p_dst + i_dststride], xmm1
    cmp             i_height, 5
    jl              .width4_height_le5_done
    lea             p_dst, [p_dst + 2 * i_dststride]
    movd            xmm4, [p_src + i_srcstride3]
    punpcklbw       xmm0, xmm4
    jg              .width4_height_ge8
%ifdef X86_32_PICASM
    SSSE3_FilterVertical_8px xmm2, xmm3, xmm0, xmm6, xmm5, xmm7, xmm4
%else
    SSSE3_FilterVertical_8px xmm2, xmm3, xmm0, [maddubsw_p1m5_128], xmm5, [maddubsw_m5p1_128], xmm4
%endif
    packuswb        xmm2, xmm2
    movd            [p_dst], xmm2
.width4_height_le5_done:
    POP_XMM
    LOAD_6_PARA_POP
%ifdef X86_32
    pop             r6
%endif
    ret
.width4_height_ge8:
    lea             p_src, [p_src + 4 * i_srcstride]
    movd            xmm1, [p_src]
    punpcklbw       xmm4, xmm1
    punpcklqdq      xmm0, xmm4
%ifdef X86_32_PICASM
    SSSE3_FilterVertical_8px xmm2, xmm3, xmm0, xmm6, xmm5, xmm7, xmm4
%else
    SSSE3_FilterVertical_8px xmm2, xmm3, xmm0, [maddubsw_p1m5_128], xmm5, [maddubsw_m5p1_128], xmm4
%endif
    packuswb        xmm2, xmm2
    movd            [p_dst], xmm2
    psrlq           xmm2, 32
    movd            [p_dst + i_dststride], xmm2
    lea             p_dst, [p_dst + 2 * i_dststride]
    movd            xmm4, [p_src + i_srcstride]
    punpcklbw       xmm1, xmm4
    movd            xmm2, [p_src + 2 * i_srcstride]
    punpcklbw       xmm4, xmm2
    punpcklqdq      xmm1, xmm4
%ifdef X86_32_PICASM
    SSSE3_FilterVertical_8px xmm3, xmm0, xmm1, xmm6, xmm5, xmm7, xmm4
%else
    SSSE3_FilterVertical_8px xmm3, xmm0, xmm1, [maddubsw_p1m5_128], xmm5, [maddubsw_m5p1_128], xmm4
%endif
    packuswb        xmm3, xmm3
    movd            [p_dst], xmm3
    psrlq           xmm3, 32
    movd            [p_dst + i_dststride], xmm3
    cmp             i_height, 9
    jl              .width4_height_ge8_done
    lea             p_dst, [p_dst + 2 * i_dststride]
    movd            xmm4, [p_src + i_srcstride3]
    punpcklbw       xmm2, xmm4
%ifdef X86_32_PICASM
    SSSE3_FilterVertical_8px xmm0, xmm1, xmm2, xmm6, xmm5, xmm7, xmm4
%else
    SSSE3_FilterVertical_8px xmm0, xmm1, xmm2, [maddubsw_p1m5_128], xmm5, [maddubsw_m5p1_128], xmm4
%endif
    packuswb        xmm0, xmm0
    movd            [p_dst], xmm0
.width4_height_ge8_done:
    POP_XMM
    LOAD_6_PARA_POP
%ifdef X86_32
    pop             r6
%endif
    ret

.width8or16:
    sub             i_height, 1
    push            i_height
%xdefine i_ycnt i_height
%define i_height [r7]
.xloop:
    push            p_src
    push            p_dst
%ifdef X86_32_PICASM
    push            i_width
    mov             i_width, esp
    and             esp, 0xfffffff0
    push            0xfb01fb01    ;[esp+64]maddubsw_p1m5_128
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0x14141414    ;[esp+48]db20_128
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x01fb01fb    ;[esp+32]maddubsw_m5p1_128
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x14fb14fb    ;[esp+16]maddubsw_m5p20_128
    push            0x14fb14fb
    push            0x14fb14fb
    push            0x14fb14fb
    push            0xfb14fb14    ;[esp] maddubsw_p20m5_128
    push            0xfb14fb14
    push            0xfb14fb14
    push            0xfb14fb14
%endif
    test            i_ycnt, 1
    jnz             .yloop_begin_even
    movq            xmm0, [p_src]
    movq            xmm1, [p_src + i_srcstride]
    punpcklbw       xmm0, xmm1
    movq            xmm2, [p_src + 2 * i_srcstride]
    movq            xmm3, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    punpcklbw       xmm2, xmm3
    movq            xmm4, [p_src]
    movq            xmm5, [p_src + i_srcstride]
    lea             p_src, [p_src + 2 * i_srcstride]
    punpcklbw       xmm4, xmm5
%ifdef X86_32_PICASM
    SSSE3_FilterVertical_8px xmm0, xmm2, xmm4, [esp+64], [esp+48], [esp+32], xmm7
%else
    SSSE3_FilterVertical_8px xmm0, xmm2, xmm4, [maddubsw_p1m5_128], [db20_128], [maddubsw_m5p1_128], xmm7
%endif
    packuswb        xmm0, xmm0
    movlps          [p_dst], xmm0
    add             p_dst, i_dststride
    jmp             .yloop
.yloop_begin_even:
    movq            xmm1, [p_src]
    movq            xmm2, [p_src + i_srcstride]
    movq            xmm3, [p_src + 2 * i_srcstride]
    add             p_src, i_srcstride3
    punpcklbw       xmm2, xmm3
    movq            xmm4, [p_src]
    movq            xmm5, [p_src + i_srcstride]
    lea             p_src, [p_src + 2 * i_srcstride]
    punpcklbw       xmm4, xmm5
.yloop:
    movq            xmm6, [p_src]
%ifdef X86_32_PICASM
    SSSE3_FilterVertical2_8px xmm1, xmm6, xmm2, xmm4, [esp+16], [esp], xmm0, xmm7
%else
    SSSE3_FilterVertical2_8px xmm1, xmm6, xmm2, xmm4, [maddubsw_m5p20_128], [maddubsw_p20m5_128], xmm0, xmm7
%endif
    movq            xmm7, [p_src + i_srcstride]
    punpcklbw       xmm6, xmm7
%ifdef X86_32_PICASM
    SSSE3_FilterVertical_8px xmm2, xmm4, xmm6, [esp+64], [esp+48], [esp+32], xmm0
%else
    SSSE3_FilterVertical_8px xmm2, xmm4, xmm6, [maddubsw_p1m5_128], [db20_128], [maddubsw_m5p1_128], xmm0
%endif
    packuswb        xmm1, xmm2
    movlps          [p_dst], xmm1
    movhps          [p_dst + i_dststride], xmm1
    lea             p_dst, [p_dst + 2 * i_dststride]
    movq            xmm0, [p_src + 2 * i_srcstride]
%ifdef X86_32_PICASM
    SSSE3_FilterVertical2_8px xmm3, xmm0, xmm4, xmm6, [esp+16], [esp], xmm2, xmm1
%else
    SSSE3_FilterVertical2_8px xmm3, xmm0, xmm4, xmm6, [maddubsw_m5p20_128], [maddubsw_p20m5_128], xmm2, xmm1
%endif
    movq            xmm1, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    punpcklbw       xmm0, xmm1
%ifdef X86_32_PICASM
    SSSE3_FilterVertical_8px xmm4, xmm6, xmm0, [esp+64], [esp+48], [esp+32], xmm2
%else
    SSSE3_FilterVertical_8px xmm4, xmm6, xmm0, [maddubsw_p1m5_128], [db20_128], [maddubsw_m5p1_128], xmm2
%endif
    packuswb        xmm3, xmm4
    movlps          [p_dst], xmm3
    movhps          [p_dst + i_dststride], xmm3
    cmp             i_ycnt, 4
    jle             .yloop_exit
    lea             p_dst, [p_dst + 2 * i_dststride]
    movq            xmm2, [p_src]
%ifdef X86_32_PICASM
    SSSE3_FilterVertical2_8px xmm5, xmm2, xmm6, xmm0, [esp+16], [esp], xmm4, xmm3
%else
    SSSE3_FilterVertical2_8px xmm5, xmm2, xmm6, xmm0, [maddubsw_m5p20_128], [maddubsw_p20m5_128], xmm4, xmm3
%endif
    movq            xmm3, [p_src + i_srcstride]
    punpcklbw       xmm2, xmm3
%ifdef X86_32_PICASM
    SSSE3_FilterVertical_8px xmm6, xmm0, xmm2, [esp+64], [esp+48], [esp+32], xmm4
%else
    SSSE3_FilterVertical_8px xmm6, xmm0, xmm2, [maddubsw_p1m5_128], [db20_128], [maddubsw_m5p1_128], xmm4
%endif
    packuswb        xmm5, xmm6
    movlps          [p_dst], xmm5
    movhps          [p_dst + i_dststride], xmm5
    lea             p_dst, [p_dst + 2 * i_dststride]
    movq            xmm4, [p_src + 2 * i_srcstride]
%ifdef X86_32_PICASM
    SSSE3_FilterVertical2_8px xmm7, xmm4, xmm0, xmm2, [esp+16], [esp], xmm6, xmm5
%else
    SSSE3_FilterVertical2_8px xmm7, xmm4, xmm0, xmm2, [maddubsw_m5p20_128], [maddubsw_p20m5_128], xmm6, xmm5
%endif
    movq            xmm5, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    punpcklbw       xmm4, xmm5
%ifdef X86_32_PICASM
    SSSE3_FilterVertical_8px xmm0, xmm2, xmm4, [esp+64], [esp+48], [esp+32], xmm6
%else
    SSSE3_FilterVertical_8px xmm0, xmm2, xmm4, [maddubsw_p1m5_128], [db20_128], [maddubsw_m5p1_128], xmm6
%endif
    packuswb        xmm7, xmm0
    movlps          [p_dst], xmm7
    movhps          [p_dst + i_dststride], xmm7
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_ycnt, 8
    jg              .yloop
.yloop_exit:
%ifdef X86_32_PICASM
    mov             esp, i_width
    pop             i_width
%endif
    pop             p_dst
    pop             p_src
    sub             i_width, 8
    jle             .width8or16_done
    add             p_src, 8
    add             p_dst, 8
    mov             i_ycnt, i_height
    jmp             .xloop
.width8or16_done:
    pop             i_ycnt
    POP_XMM
    LOAD_6_PARA_POP
%ifdef X86_32
    pop             r6
%endif
    ret
%undef p_src
%undef i_srcstride
%undef i_srcstride3
%undef p_dst
%undef i_dststride
%undef i_width
%undef i_height
%undef i_ycnt


;*******************************************************************************
; void McHorVer20_ssse3(const uint8_t *pSrc,
;                       int iSrcStride,
;                       uint8_t *pDst,
;                       int iDstStride,
;                       int iWidth,
;                       int iHeight);
;*******************************************************************************

WELS_EXTERN McHorVer20_ssse3
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_dststride  r3
%define i_width      r4
%define i_height     r5
    %assign  push_num 0
    LOAD_6_PARA
    PUSH_XMM 7
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
%ifdef X86_32_PICASM
    push            0x090a0809        ;shufb_32435465768798A9
    push            0x07080607
    push            0x05060405
    push            0x03040203
    movdqu          xmm4, [esp]
    push            0x0c0b0b0a
    push            0x06050504
    push            0x08070706
    push            0x02010100
    movdqu          xmm5, [esp]
    push            0x01fb01fb
    push            0xfb01fb01
    push            0x01fb01fb
    push            0xfb01fb01
    movdqu          xmm6, [esp]
    add             esp, 48
%else
    movdqa          xmm4, [shufb_32435465768798A9]
    movdqa          xmm5, [shufb_011267784556ABBC]
    movdqa          xmm6, [maddubsw_p1m5_p1m5_m5p1_m5p1_128]
%endif
    cmp             i_width, 8
    je              .width8_yloop
    jg              .width16_yloop
.width4_yloop:
    movdqu          xmm0, [p_src - 2]
    movdqu          xmm1, [p_src + i_srcstride - 2]
    lea             p_src, [p_src + 2 * i_srcstride]
    SSSE3_FilterHorizontal_2x4px xmm0, xmm1, xmm4, xmm5, xmm6, xmm2, xmm3
    packuswb        xmm0, xmm0
    movd            [p_dst], xmm0
    psrlq           xmm0, 32
    movd            [p_dst + i_dststride], xmm0
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_height, 2
    jg              .width4_yloop
    POP_XMM
    LOAD_6_PARA_POP
    ret
.width8_yloop:
    movdqu          xmm0, [p_src - 2]
    movdqu          xmm1, [p_src + i_srcstride - 2]
    lea             p_src, [p_src + 2 * i_srcstride]
    SSSE3_FilterHorizontal_8px xmm0, xmm4, xmm5, xmm6, xmm2, xmm3
    SSSE3_FilterHorizontal_8px xmm1, xmm4, xmm5, xmm6, xmm2, xmm3
    packuswb        xmm0, xmm1
    movlps          [p_dst], xmm0
    movhps          [p_dst + i_dststride], xmm0
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_height, 2
    jg              .width8_yloop
    POP_XMM
    LOAD_6_PARA_POP
    ret
.width16_yloop:
    movdqu          xmm0, [p_src - 2]
    movdqu          xmm1, [p_src + 6]
    add             p_src, i_srcstride
    SSSE3_FilterHorizontal_8px xmm0, xmm4, xmm5, xmm6, xmm2, xmm3
    SSSE3_FilterHorizontal_8px xmm1, xmm4, xmm5, xmm6, xmm2, xmm3
    packuswb        xmm0, xmm1
    MOVDQ           [p_dst], xmm0
    add             p_dst, i_dststride
    sub             i_height, 1
    jg              .width16_yloop
    POP_XMM
    LOAD_6_PARA_POP
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_dststride
%undef i_width
%undef i_height


;***********************************************************************
; void McHorVer20Width5Or9Or17_ssse3(const uint8_t *pSrc,
;                                    int32_t iSrcStride,
;                                    uint8_t *pDst,
;                                    int32_t iDstStride,
;                                    int32_t iWidth,
;                                    int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer20Width5Or9Or17_ssse3
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_dststride  r3
%define i_width      r4
%define i_height     r5
    %assign  push_num 0
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
%ifdef X86_32_PICASM
    push            0x090a0809        ;shufb_32435465768798A9
    push            0x07080607
    push            0x05060405
    push            0x03040203
    movdqu          xmm5, [esp]
    push            0x0c0b0b0a
    push            0x06050504
    push            0x08070706
    push            0x02010100
    movdqu          xmm6, [esp]
    push            0x01fb01fb
    push            0xfb01fb01
    push            0x01fb01fb
    push            0xfb01fb01
    movdqu          xmm7, [esp]
    add             esp, 48
%else
    movdqa          xmm5, [shufb_32435465768798A9]
    movdqa          xmm6, [shufb_011267784556ABBC]
    movdqa          xmm7, [maddubsw_p1m5_p1m5_m5p1_m5p1_128]
%endif
    cmp             i_width, 9
    je              .width9_yloop
    jg              .width17_yloop
.width5_yloop:
    movdqu          xmm0, [p_src - 2]
    add             p_src, i_srcstride
    SSSE3_FilterHorizontal_8px xmm0, xmm5, xmm6, xmm7, xmm1, xmm2
    packuswb        xmm0, xmm0
    movdqa          xmm1, xmm0
    psrlq           xmm1, 8
    movd            [p_dst], xmm0
    movd            [p_dst + 1], xmm1
    add             p_dst, i_dststride
    sub             i_height, 1
    jg              .width5_yloop
    POP_XMM
    LOAD_6_PARA_POP
    ret
.width9_yloop:
    movdqu          xmm0, [p_src - 2]
    movdqu          xmm4, [p_src + i_srcstride - 2]
    lea             p_src, [p_src + 2 * i_srcstride]
    movdqa          xmm3, xmm0
    punpckhqdq      xmm3, xmm4
    SSSE3_FilterHorizontal_2px xmm3, xmm2
    SSSE3_FilterHorizontal_8px xmm0, xmm5, xmm6, xmm7, xmm1, xmm2
    packuswb        xmm3, xmm0
    movd            [p_dst + 5], xmm3
    movhps          [p_dst], xmm3
    add             p_dst, i_dststride
    SSSE3_FilterHorizontal_8px xmm4, xmm5, xmm6, xmm7, xmm1, xmm2
    packuswb        xmm4, xmm4
    psrldq          xmm3, 4
    movd            [p_dst + 5], xmm3
    movlps          [p_dst], xmm4
    add             p_dst, i_dststride
    sub             i_height, 2
    jg              .width9_yloop
    POP_XMM
    LOAD_6_PARA_POP
    ret
.width17_yloop:
    movdqu          xmm0, [p_src - 2]
    movdqu          xmm3, [p_src + 6]
    add             p_src, i_srcstride
    movdqa          xmm4, xmm3
    SSSE3_FilterHorizontal_8px xmm0, xmm5, xmm6, xmm7, xmm1, xmm2
    SSSE3_FilterHorizontal_8px xmm3, xmm5, xmm6, xmm7, xmm1, xmm2
    packuswb        xmm0, xmm3
    movdqu          xmm1, [p_src - 2]
    movdqu          xmm3, [p_src + 6]
    add             p_src, i_srcstride
    punpckhqdq      xmm4, xmm3
    SSSE3_FilterHorizontal_2px xmm4, xmm2
    packuswb        xmm4, xmm4
    movd            [p_dst + 13], xmm4
    MOVDQ           [p_dst], xmm0
    add             p_dst, i_dststride
    psrldq          xmm4, 4
    movd            [p_dst + 13], xmm4
    SSSE3_FilterHorizontal_8px xmm1, xmm5, xmm6, xmm7, xmm0, xmm2
    SSSE3_FilterHorizontal_8px xmm3, xmm5, xmm6, xmm7, xmm0, xmm2
    packuswb        xmm1, xmm3
    MOVDQ           [p_dst], xmm1
    add             p_dst, i_dststride
    sub             i_height, 2
    jg              .width17_yloop
    POP_XMM
    LOAD_6_PARA_POP
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_dststride
%undef i_width
%undef i_height


;*******************************************************************************
; void McHorVer20Width4U8ToS16_ssse3(const uint8_t *pSrc,
;                                    int iSrcStride,
;                                    int16_t *pDst,
;                                    int iHeight);
;*******************************************************************************

WELS_EXTERN McHorVer20Width4U8ToS16_ssse3
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_height     r3
    %assign  push_num 0
    LOAD_4_PARA
    PUSH_XMM 7
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    sub             p_src, i_srcstride
    sub             p_src, i_srcstride
%ifdef X86_32_PICASM
    push            0x090a0809        ;shufb_32435465768798A9
    push            0x07080607
    push            0x05060405
    push            0x03040203
    movdqu          xmm4, [esp]
    push            0x0c0b0b0a
    push            0x06050504
    push            0x08070706
    push            0x02010100
    movdqu          xmm5, [esp]
    push            0x01fb01fb
    push            0xfb01fb01
    push            0x01fb01fb
    push            0xfb01fb01
    movdqu          xmm6, [esp]
    add             esp, 48
%else
    movdqa          xmm4, [shufb_32435465768798A9]
    movdqa          xmm5, [shufb_011267784556ABBC]
    movdqa          xmm6, [maddubsw_p1m5_p1m5_m5p1_m5p1_128]
%endif
    sub             i_height, 1
.yloop:
    movdqu          xmm0, [p_src - 2]
    movdqu          xmm1, [p_src + i_srcstride - 2]
    lea             p_src, [p_src + 2 * i_srcstride]
    SSSE3_FilterHorizontalbw_2x4px xmm0, xmm1, xmm4, xmm5, xmm6, xmm2, xmm3
    movdqa          [p_dst], xmm0
    add             p_dst, 16
    sub             i_height, 2
    jg              .yloop
    ; Height % 2 remainder.
    movdqu          xmm0, [p_src - 2]
    SSSE3_FilterHorizontalbw_8px xmm0, xmm4, xmm5, xmm6, xmm2, xmm3
    movlps          [p_dst], xmm0
    POP_XMM
    LOAD_4_PARA_POP
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_height


;***********************************************************************
; void McHorVer02Width4S16ToU8_ssse3(const int16_t *pSrc,
;                                    uint8_t *pDst,
;                                    int32_t iDstStride,
;                                    int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer02Width4S16ToU8_ssse3
%define p_src        r0
%define p_dst        r1
%define i_dststride  r2
%define i_height     r3
%define i_srcstride  8
    %assign  push_num 0
    LOAD_4_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r2, r2d
    SIGN_EXTENSION  r3, r3d
    movdqa          xmm0, [p_src +  0 * i_srcstride]
    movdqu          xmm1, [p_src +  1 * i_srcstride]
    movdqa          xmm2, [p_src +  2 * i_srcstride]
    movdqu          xmm3, [p_src +  3 * i_srcstride]
    movdqa          xmm4, [p_src +  4 * i_srcstride]
    movdqu          xmm5, [p_src +  5 * i_srcstride]
    movdqa          xmm6, [p_src +  6 * i_srcstride]
    SSE2_FilterVerticalw_8px xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm7
    packuswb        xmm0, xmm0
    movd            [p_dst], xmm0
    psrlq           xmm0, 32
    movd            [p_dst + i_dststride], xmm0
    lea             p_dst, [p_dst + 2 * i_dststride]
    movdqu          xmm7, [p_src +  7 * i_srcstride]
    movdqa          xmm0, [p_src +  8 * i_srcstride]
    SSE2_FilterVerticalw_8px xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm1
    packuswb        xmm2, xmm2
    movd            [p_dst], xmm2
    psrlq           xmm2, 32
    movd            [p_dst + i_dststride], xmm2
    cmp             i_height, 4
    jle             .done
    lea             p_dst, [p_dst + 2 * i_dststride]
    movdqu          xmm1, [p_src +  9 * i_srcstride]
    movdqa          xmm2, [p_src + 10 * i_srcstride]
    SSE2_FilterVerticalw_8px xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm3
    packuswb        xmm4, xmm4
    movd            [p_dst], xmm4
    psrlq           xmm4, 32
    movd            [p_dst + i_dststride], xmm4
    lea             p_dst, [p_dst + 2 * i_dststride]
    movdqu          xmm3, [p_src + 11 * i_srcstride]
    SSE2_FilterVerticalw_8px xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, xmm5
    packuswb        xmm6, xmm6
    movd            [p_dst], xmm6
    psrlq           xmm6, 32
    movd            [p_dst + i_dststride], xmm6
.done:
    POP_XMM
    LOAD_4_PARA_POP
    ret
%undef p_src
%undef p_dst
%undef i_dststride
%undef i_height
%undef i_srcstride


;***********************************************************************
; void McHorVer20Width8U8ToS16_ssse3(const uint8_t *pSrc,
;                                    int16_t iSrcStride,
;                                    int16_t *pDst,
;                                    int32_t iDstStride,
;                                    int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer20Width8U8ToS16_ssse3
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_dststride  r3
%define i_height     r4
    %assign  push_num 0
    LOAD_5_PARA
    PUSH_XMM 7
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    sub             p_src, i_srcstride
    sub             p_src, i_srcstride
%ifdef X86_32_PICASM
    push            0x090a0809        ;shufb_32435465768798A9
    push            0x07080607
    push            0x05060405
    push            0x03040203
    movdqu          xmm4, [esp]
    push            0x0c0b0b0a
    push            0x06050504
    push            0x08070706
    push            0x02010100
    movdqu          xmm5, [esp]
    push            0x01fb01fb
    push            0xfb01fb01
    push            0x01fb01fb
    push            0xfb01fb01
    movdqu          xmm6, [esp]
    add             esp, 48
%else
    movdqa          xmm4, [shufb_32435465768798A9]
    movdqa          xmm5, [shufb_011267784556ABBC]
    movdqa          xmm6, [maddubsw_p1m5_p1m5_m5p1_m5p1_128]
%endif
    sub             i_height, 1
.yloop:
    movdqu          xmm0, [p_src - 2]
    movdqu          xmm1, [p_src + i_srcstride - 2]
    lea             p_src, [p_src + 2 * i_srcstride]
    SSSE3_FilterHorizontalbw_8px xmm0, xmm4, xmm5, xmm6, xmm2, xmm3
    MOVDQ           [p_dst], xmm0
    add             p_dst, i_dststride
    SSSE3_FilterHorizontalbw_8px xmm1, xmm4, xmm5, xmm6, xmm2, xmm3
    MOVDQ           [p_dst], xmm1
    add             p_dst, i_dststride
    sub             i_height, 2
    jg              .yloop
    jl              .done
    movdqu          xmm0, [p_src - 2]
    SSSE3_FilterHorizontalbw_8px xmm0, xmm4, xmm5, xmm6, xmm2, xmm3
    MOVDQ           [p_dst], xmm0
.done:
    POP_XMM
    LOAD_5_PARA_POP
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_dststride
%undef i_height


;***********************************************************************
; void McHorVer02Width5S16ToU8_ssse3(const int16_t *pSrc,
;                                    int32_t iTapStride,
;                                    uint8_t *pDst,
;                                    int32_t iDstStride,
;                                    int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer02Width5S16ToU8_ssse3
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_dststride  r3
%define i_height     r4
%define i_srcstride3 r5
    %assign  push_num 0
%ifdef X86_32
    push            r5
    %assign  push_num 1
%endif
    LOAD_5_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    lea             i_srcstride3, [3 * i_srcstride]
    movdqa          xmm0, [p_src]
    movdqa          xmm1, [p_src + i_srcstride]
    movdqa          xmm2, [p_src + 2 * i_srcstride]
    movdqa          xmm3, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    movdqa          xmm4, [p_src]
    movdqa          xmm5, [p_src + i_srcstride]
    SSE2_FilterVerticalw_8px xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6
    movdqa          xmm6, [p_src + 2 * i_srcstride]
    packuswb        xmm0, xmm0
    movdqa          xmm7, xmm0
    psrlq           xmm7, 8
    movd            [p_dst + 1], xmm7
    movd            [p_dst], xmm0
    add             p_dst, i_dststride
    SSE2_FilterVerticalw_8px xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7
    movdqa          xmm7, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    packuswb        xmm1, xmm1
    movdqa          xmm0, xmm1
    psrlq           xmm0, 8
    movd            [p_dst + 1], xmm0
    movd            [p_dst], xmm1
    add             p_dst, i_dststride
    SSE2_FilterVerticalw_8px xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0
    movdqa          xmm0, [p_src]
    packuswb        xmm2, xmm2
    movdqa          xmm1, xmm2
    psrlq           xmm1, 8
    movd            [p_dst + 1], xmm1
    movd            [p_dst], xmm2
    add             p_dst, i_dststride
    SSE2_FilterVerticalw_8px xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1
    packuswb        xmm3, xmm3
    movdqa          xmm2, xmm3
    psrlq           xmm2, 8
    movd            [p_dst + 1], xmm2
    movd            [p_dst], xmm3
    add             p_dst, i_dststride
    movdqa          xmm1, [p_src + i_srcstride]
    SSE2_FilterVerticalw_8px xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2
    packuswb        xmm4, xmm4
    movdqa          xmm3, xmm4
    psrlq           xmm3, 8
    movd            [p_dst + 1], xmm3
    movd            [p_dst], xmm4
    cmp             i_height, 5
    jle             .done
    add             p_dst, i_dststride
    movdqa          xmm2, [p_src + 2 * i_srcstride]
    SSE2_FilterVerticalw_8px xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3
    movdqa          xmm3, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    packuswb        xmm5, xmm5
    movdqa          xmm4, xmm5
    psrlq           xmm4, 8
    movd            [p_dst + 1], xmm4
    movd            [p_dst], xmm5
    add             p_dst, i_dststride
    SSE2_FilterVerticalw_8px xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, xmm4
    movdqa          xmm4, [p_src]
    packuswb        xmm6, xmm6
    movdqa          xmm5, xmm6
    psrlq           xmm5, 8
    movd            [p_dst + 1], xmm5
    movd            [p_dst], xmm6
    add             p_dst, i_dststride
    SSE2_FilterVerticalw_8px xmm7, xmm0, xmm1, xmm2, xmm3, xmm4, xmm5
    packuswb        xmm7, xmm7
    movdqa          xmm6, xmm7
    psrlq           xmm6, 8
    movd            [p_dst + 1], xmm6
    movd            [p_dst], xmm7
    add             p_dst, i_dststride
    movdqa          xmm5, [p_src + i_srcstride]
    SSE2_FilterVerticalw_8px xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6
    packuswb        xmm0, xmm0
    movdqa          xmm7, xmm0
    psrlq           xmm7, 8
    movd            [p_dst + 1], xmm7
    movd            [p_dst], xmm0
.done:
    POP_XMM
    LOAD_5_PARA_POP
%ifdef X86_32
    pop             r5
%endif
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_dststride
%undef i_height
%undef i_srcstride3


;***********************************************************************
; void McHorVer20Width9Or17U8ToS16_ssse3(const uint8_t *pSrc,
;                                        int32_t iSrcStride,
;                                        int16_t *pDst,
;                                        int32_t iDstStride,
;                                        int32_t iWidth,
;                                        int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer20Width9Or17U8ToS16_ssse3
%define p_src       r0
%define i_srcstride r1
%define p_dst       r2
%define i_dststride r3
%define i_width     r4
%define i_height    r5
    %assign  push_num 0
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
    sub             p_src, i_srcstride
    sub             p_src, i_srcstride
    pcmpeqw         xmm4, xmm4
    psllw           xmm4, 15                                ; dw -32768
%ifdef X86_32_PICASM
    push            0x090a0809        ;shufb_32435465768798A9
    push            0x07080607
    push            0x05060405
    push            0x03040203
    movdqu          xmm5, [esp]
    push            0x0c0b0b0a
    push            0x06050504
    push            0x08070706
    push            0x02010100
    movdqu          xmm6, [esp]
    push            0x01fb01fb
    push            0xfb01fb01
    push            0x01fb01fb
    push            0xfb01fb01
    movdqu          xmm7, [esp]
    add             esp, 48
%else
    movdqa          xmm5, [shufb_32435465768798A9]
    movdqa          xmm6, [shufb_011267784556ABBC]
    movdqa          xmm7, [maddubsw_p1m5_p1m5_m5p1_m5p1_128]
%endif
    cmp             i_width, 9
    jne             .width17_yloop

.width9_yloop:
    movdqu          xmm0, [p_src - 2]
    movdqa          xmm3, xmm0
    SSSE3_FilterHorizontalbw_8px xmm0, xmm5, xmm6, xmm7, xmm1, xmm2
    movdqu          xmm2, [p_src + i_srcstride - 2]
    lea             p_src, [p_src + 2 * i_srcstride]
    punpckhqdq      xmm3, xmm2
    SSSE3_FilterHorizontalbw_2px xmm3, xmm4, xmm1
    movlps          [p_dst + 10], xmm3
    MOVDQ           [p_dst], xmm0
    add             p_dst, i_dststride
    movhps          [p_dst + 10], xmm3
    SSSE3_FilterHorizontalbw_8px xmm2, xmm5, xmm6, xmm7, xmm1, xmm0
    MOVDQ           [p_dst], xmm2
    add             p_dst, i_dststride
    sub             i_height, 2
    jg              .width9_yloop
    POP_XMM
    LOAD_6_PARA_POP
    ret

.width17_yloop:
    movdqu          xmm0, [p_src - 2]
    movdqu          xmm3, [p_src + 6]
    add             p_src, i_srcstride
    SSSE3_FilterHorizontalbw_8px xmm0, xmm5, xmm6, xmm7, xmm1, xmm2
    MOVDQ           [p_dst], xmm0
    movdqa          xmm0, xmm3
    SSSE3_FilterHorizontalbw_8px xmm3, xmm5, xmm6, xmm7, xmm1, xmm2
    movdqu          xmm2, [p_src + 6]
    punpckhqdq      xmm0, xmm2
    SSSE3_FilterHorizontalbw_2px xmm0, xmm4, xmm1
    movdqu          xmm1, [p_src - 2]
    add             p_src, i_srcstride
    movlps          [p_dst + 26], xmm0
    MOVDQ           [p_dst + 16], xmm3
    add             p_dst, i_dststride
    movhps          [p_dst + 26], xmm0
    SSSE3_FilterHorizontalbw_8px xmm1, xmm5, xmm6, xmm7, xmm0, xmm3
    MOVDQ           [p_dst], xmm1
    SSSE3_FilterHorizontalbw_8px xmm2, xmm5, xmm6, xmm7, xmm0, xmm3
    MOVDQ           [p_dst + 16], xmm2
    add             p_dst, i_dststride
    sub             i_height, 2
    jg              .width17_yloop
    POP_XMM
    LOAD_6_PARA_POP
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_dststride
%undef i_width
%undef i_height


;***********************************************************************
; void McHorVer02WidthGe8S16ToU8_ssse3(const int16_t *pSrc,
;                                      int32_t iSrcStride,
;                                      uint8_t *pDst,
;                                      int32_t iDstStride,
;                                      int32_t iWidth,
;                                      int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer02WidthGe8S16ToU8_ssse3
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_dststride  r3
%define i_width      r4
%define i_height     r5
%define i_srcstride3 r6
    %assign  push_num 0
%ifdef X86_32
    push            r6
    %assign  push_num 1
%endif
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
    sub             i_height, 1
    push            i_height
    lea             i_srcstride3, [3 * i_srcstride]
    test            i_width, 1
    jz              .width_loop
    push            p_src
    push            p_dst
    lea             p_src, [p_src + 2 * i_width - 2]
    add             p_dst, i_width
    movd            xmm0, [p_src]
    punpcklwd       xmm0, [p_src + i_srcstride]
    movd            xmm1, [p_src + 2 * i_srcstride]
    add             p_src, i_srcstride3
    punpcklwd       xmm1, [p_src]
    punpckldq       xmm0, xmm1
    movd            xmm1, [p_src + i_srcstride]
    cmp             i_height, 4
    je              .filter5_unalign
    punpcklwd       xmm1, [p_src + 2 * i_srcstride]
    movd            xmm2, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    punpcklwd       xmm2, [p_src]
    punpckldq       xmm1, xmm2
    punpcklqdq      xmm0, xmm1
.height_loop_unalign:
    movd            xmm1, [p_src + i_srcstride]
    palignr         xmm1, xmm0, 2
    movd            xmm2, [p_src + 2 * i_srcstride]
    palignr         xmm2, xmm1, 2
    movd            xmm3, [p_src + i_srcstride3]
    palignr         xmm3, xmm2, 2
    lea             p_src, [p_src + 4 * i_srcstride]
    movd            xmm4, [p_src]
    palignr         xmm4, xmm3, 2
    movd            xmm5, [p_src + i_srcstride]
    palignr         xmm5, xmm4, 2
    SSE2_FilterVerticalw_8px xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm7
    packuswb        xmm0, xmm0
    movdqa          xmm6, xmm0
    pslld           xmm6, 24
    movd            [p_dst - 4], xmm6
    movlps          [p_dst + 4 * i_dststride - 8], xmm6
    add             p_dst, i_dststride
    movdqa          xmm6, xmm0
    pslld           xmm6, 16
    movd            [p_dst - 4], xmm6
    movlps          [p_dst + 4 * i_dststride - 8], xmm6
    add             p_dst, i_dststride
    movdqa          xmm6, xmm0
    pslld           xmm6, 8
    movd            [p_dst - 4], xmm6
    movd            [p_dst + i_dststride - 4], xmm0
    lea             p_dst, [p_dst + 4 * i_dststride]
    movlps          [p_dst - 8], xmm6
    movlps          [p_dst + i_dststride - 8], xmm0
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_height, 8
    jle             .height_loop_unalign_exit
    movd            xmm1, [p_src + 2 * i_srcstride]
    palignr         xmm1, xmm5, 2
    movd            xmm0, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    punpcklwd       xmm0, [p_src]
    palignr         xmm0, xmm1, 4
    jmp             .height_loop_unalign
.height_loop_unalign_exit:
    movddup         xmm6, [p_src + 2 * i_srcstride - 6]
    SSE2_FilterVerticalw_8px xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7
    packuswb        xmm1, xmm1
    movlps          [p_dst - 8], xmm1
    jmp             .unalign_done
.filter5_unalign:
    pslldq          xmm0, 8
    palignr         xmm1, xmm0, 2
    movd            xmm2, [p_src + 2 * i_srcstride]
    palignr         xmm2, xmm1, 2
    movd            xmm3, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    palignr         xmm3, xmm2, 2
    movd            xmm4, [p_src]
    palignr         xmm4, xmm3, 2
    movd            xmm5, [p_src + i_srcstride]
    palignr         xmm5, xmm4, 2
    movd            xmm6, [p_src + 2 * i_srcstride]
    palignr         xmm6, xmm5, 2
    SSE2_FilterVerticalw_8px xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7
    packuswb        xmm1, xmm1
    movdqa          xmm0, xmm1
    psrlq           xmm1,  8
    movdqa          xmm2, xmm0
    psrlq           xmm2, 16
    movdqa          xmm3, xmm0
    psrlq           xmm3, 24
    movd            [p_dst - 4], xmm0
    movd            [p_dst + i_dststride - 4], xmm1
    lea             p_dst, [p_dst + 2 * i_dststride]
    movd            [p_dst - 4], xmm2
    movd            [p_dst + i_dststride - 4], xmm3
    movlps          [p_dst + 2 * i_dststride - 8], xmm0
.unalign_done:
    pop             p_dst
    pop             p_src
    mov             i_height, [r7]
    sub             i_width, 1
.width_loop:
    push            p_src
    push            p_dst
    movdqa          xmm0, [p_src]
    movdqa          xmm1, [p_src + i_srcstride]
    movdqa          xmm2, [p_src + 2 * i_srcstride]
    movdqa          xmm3, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    movdqa          xmm4, [p_src]
.height_loop:
    movdqa          xmm5, [p_src + i_srcstride]
    SSE2_FilterVerticalw_8px xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6
    movdqa          xmm6, [p_src + 2 * i_srcstride]
    SSE2_FilterVerticalw_8px xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7
    movdqa          xmm7, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    packuswb        xmm0, xmm1
    movlps          [p_dst], xmm0
    movhps          [p_dst + i_dststride], xmm0
    lea             p_dst, [p_dst + 2 * i_dststride]
    SSE2_FilterVerticalw_8px xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm0
    movdqa          xmm0, [p_src]
    SSE2_FilterVerticalw_8px xmm3, xmm4, xmm5, xmm6, xmm7, xmm0, xmm1
    packuswb        xmm2, xmm3
    movlps          [p_dst], xmm2
    movhps          [p_dst + i_dststride], xmm2
    cmp             i_height, 4
    jl              .x_loop_dec
    lea             p_dst, [p_dst + 2 * i_dststride]
    movdqa          xmm1, [p_src + i_srcstride]
    SSE2_FilterVerticalw_8px xmm4, xmm5, xmm6, xmm7, xmm0, xmm1, xmm2
    je              .store_xmm4_exit
    movdqa          xmm2, [p_src + 2 * i_srcstride]
    SSE2_FilterVerticalw_8px xmm5, xmm6, xmm7, xmm0, xmm1, xmm2, xmm3
    movdqa          xmm3, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    packuswb        xmm4, xmm5
    movlps          [p_dst], xmm4
    movhps          [p_dst + i_dststride], xmm4
    lea             p_dst, [p_dst + 2 * i_dststride]
    SSE2_FilterVerticalw_8px xmm6, xmm7, xmm0, xmm1, xmm2, xmm3, xmm4
    movdqa          xmm4, [p_src]
    SSE2_FilterVerticalw_8px xmm7, xmm0, xmm1, xmm2, xmm3, xmm4, xmm5
    packuswb        xmm6, xmm7
    movlps          [p_dst], xmm6
    movhps          [p_dst + i_dststride], xmm6
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_height, 8
    jg              .height_loop
    jl              .x_loop_dec
    movdqa          xmm5, [p_src + i_srcstride]
    SSE2_FilterVerticalw_8px xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6
    packuswb        xmm0, xmm0
    movlps          [p_dst], xmm0
.x_loop_dec:
    pop             p_dst
    pop             p_src
    sub             i_width, 8
    jle             .done
    mov             i_height, [r7]
    add             p_src, 16
    add             p_dst, 8
    jmp             .width_loop
.store_xmm4_exit:
    packuswb        xmm4, xmm4
    movlps          [p_dst], xmm4
    pop             p_dst
    pop             p_src
.done:
    pop             i_height
    POP_XMM
    LOAD_6_PARA_POP
%ifdef X86_32
    pop             r6
%endif
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_dststride
%undef i_width
%undef i_height
%undef i_srcstride3


%ifdef HAVE_AVX2

; pixels=%1 shufb_32435465768798A9=%2 shufb_011267784556ABBC=%3 maddubsw_p1m5_p1m5_m5p1_m5p1=%4 tmp=%5,%6
%macro AVX2_FilterHorizontalbw_16px 6
    vpshufb         %5, %1, %3
    vpshufb         %1, %1, %2
    vpshufd         %6, %1, 10110001b
%ifdef X86_32_PICASM
    push            r0
    mov             r0, esp
    and             esp, 0xffffffe0
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    vpmaddubsw      %1, %1, [esp]
    mov             esp, r0
    pop             r0
%else
    vpmaddubsw      %1, %1, [db20_256]
%endif
    vpmaddubsw      %5, %5, %4
    vpmaddubsw      %6, %6, %4
    vpaddw          %1, %1, %5
    vpaddw          %1, %1, %6
%endmacro

; pixels=%1 shufb_32435465768798A9=%2 shufb_011267784556ABBC=%3 db20=%4 tmp=%5,%6
%macro AVX2_FilterHorizontal_16px 6
    AVX2_FilterHorizontalbw_16px %1, %2, %3, %4, %5, %6
%ifdef X86_32_PICASM
    vpcmpeqw        %6, %6, %6
    vpsrlw          %6, %6, 15
    vpsllw          %6, %6, 4
    vpaddw          %1, %1, %6
%else
    vpaddw          %1, %1, [h264_w0x10_256]
%endif
    vpsraw          %1, %1, 5
%endmacro

; px0=%1 px1=%2 shufb_32435465768798A9=%3 shufb_011267784556ABBC=%4 maddubsw_p1m5_p1m5_m5p1_m5p1=%5 tmp=%6,%7
%macro AVX2_FilterHorizontalbw_4x4px 7
    vpshufb         %6, %1, %4
    vpshufb         %7, %2, %4
    vpshufb         %1, %1, %3
    vpshufb         %2, %2, %3
    vpunpcklqdq     %1, %1, %2
    vpunpcklqdq     %6, %6, %7
    vpshufd         %7, %1, 10110001b
%ifdef X86_32_PICASM
    push            r0
    mov             r0, esp
    and             esp, 0xffffffe0
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    vpmaddubsw      %1, %1, [esp]
    mov             esp, r0
    pop             r0
%else
    vpmaddubsw      %1, %1, [db20_256]
%endif
    vpmaddubsw      %6, %6, %5
    vpmaddubsw      %7, %7, %5
    vpaddw          %1, %1, %6
    vpaddw          %1, %1, %7
%endmacro

; px0=%1 px1=%2 shufb_32435465768798A9=%3 shufb_011267784556ABBC=%4 db20=%5 tmp=%6,%7
%macro AVX2_FilterHorizontal_4x4px 7
    AVX2_FilterHorizontalbw_4x4px %1, %2, %3, %4, %5, %6, %7
%ifdef X86_32_PICASM
    vpcmpeqw        %7, %7, %7
    vpsrlw          %7, %7, 15
    vpsllw          %7, %7, 4
    vpaddw          %1, %1, %7
%else
    vpaddw          %1, %1, [h264_w0x10_256]
%endif
    vpsraw          %1, %1, 5
%endmacro

; pixels=%1 -32768>>scale=%2 tmp=%3
%macro AVX2_FilterHorizontalbw_4px 3
    vpmaddubsw      %1, %1, [maddubsw_m2p10_m40m40_p10m2_p0p0_256]
    vpmaddwd        %1, %1, %2
    vpshufd         %3, %1, 10110001b
    vpaddd          %1, %1, %3
%endmacro

; pixels=%1 tmp=%2
%macro AVX2_FilterHorizontal_4px 2
%ifdef X86_32_PICASM
    push            r0
    mov             r0, esp
    and             esp, 0xffffffe0
    push            0x0000fe0a    ;maddubsw_m2p10_m40m40_p10m2_p0p0_256
    push            0xd8d80afe
    push            0x0000fe0a
    push            0xd8d80afe
    push            0x0000fe0a
    push            0xd8d80afe
    push            0x0000fe0a
    push            0xd8d80afe
    push            0xfc00fc00    ;dwm1024_256
    push            0xfc00fc00
    push            0xfc00fc00
    push            0xfc00fc00
    push            0xfc00fc00
    push            0xfc00fc00
    push            0xfc00fc00
    push            0xfc00fc00
    push            0x00008000    ;dd32768_256
    push            0x00008000
    push            0x00008000
    push            0x00008000
    push            0x00008000
    push            0x00008000
    push            0x00008000
    push            0x00008000
    vpmaddubsw      %1, %1, [esp+64]
    vpmaddwd        %1, %1, [esp+32]
    vpshufd         %2, %1, 10110001b
    vpaddd          %1, %1, %2
    vpaddd          %1, %1, [esp]
    mov             esp, r0
    pop             r0
%else
    AVX2_FilterHorizontalbw_4px %1, [dwm1024_256], %2
    vpaddd          %1, %1, [dd32768_256]
%endif
%endmacro

; px_ab=%1 px_cd=%2 px_ef=%3 maddubsw_ab=%4 maddubsw_cd=%5 maddubsw_ef=%6 tmp=%7
%macro AVX2_FilterVertical_16px 7
    vpmaddubsw      %1, %1, %4
    vpmaddubsw      %7, %2, %5
    vpaddw          %1, %1, %7
    vpmaddubsw      %7, %3, %6
    vpaddw          %1, %1, %7
%ifdef X86_32_PICASM
    vpcmpeqw        %7, %7, %7
    vpsrlw          %7, %7, 15
    vpsllw          %7, %7, 4
    vpaddw          %1, %1, %7
%else
    vpaddw          %1, %1, [h264_w0x10_256]
%endif
    vpsraw          %1, %1, 5
%endmacro

; px_a=%1 px_f=%2 px_bc=%3 px_de=%4 maddubsw_bc=%5 maddubsw_de=%6 tmp=%7,%8
%macro AVX2_FilterVertical2_16px 8
    vpxor           %7, %7, %7
    vpunpcklbw      %1, %1, %7
    vpunpcklbw      %8, %2, %7
    vpaddw          %1, %1, %8
    vpmaddubsw      %7, %3, %5
    vpaddw          %1, %1, %7
    vpmaddubsw      %7, %4, %6
    vpaddw          %1, %1, %7
%ifdef X86_32_PICASM
    vpcmpeqw        %7, %7, %7
    vpsrlw          %7, %7, 15
    vpsllw          %7, %7, 4
    vpaddw          %1, %1, %7
%else
    vpaddw          %1, %1, [h264_w0x10_256]
%endif
    vpsraw          %1, %1, 5
%endmacro

; px0=%1 px1=%2 px2=%3 px3=%4 px4=%5 px5=%6 tmp=%7
%macro AVX2_FilterVerticalw_16px 7
    vpaddw          %1, %1, %6
    vpaddw          %7, %2, %5
    vpsubw          %1, %1, %7
    vpsraw          %1, %1, 2
    vpsubw          %1, %1, %7
    vpaddw          %7, %3, %4
    vpaddw          %1, %1, %7
    vpsraw          %1, %1, 2
%ifdef X86_32_PICASM
    push            r0
    mov             r0, esp
    and             esp, 0xffffffe0
    push            0x00200020
    push            0x00200020
    push            0x00200020
    push            0x00200020
    push            0x00200020
    push            0x00200020
    push            0x00200020
    push            0x00200020
    vpaddw          %7, %7, [esp]
    mov             esp, r0
    pop             r0
%else
    vpaddw          %7, %7, [dw32_256]
%endif
    vpaddw          %1, %1, %7
    vpsraw          %1, %1, 6
%endmacro

;***********************************************************************
; void McHorVer02_avx2(const uint8_t *pSrc,
;                      int32_t iSrcStride,
;                      uint8_t *pDst,
;                      int32_t iDstStride,
;                      int32_t iWidth,
;                      int32_t iHeight)
;***********************************************************************

WELS_EXTERN McHorVer02_avx2
%define p_src         r0
%define i_srcstride   r1
%define p_dst         r2
%define i_dststride   r3
%define i_width       r4
%define i_height      r5
%define i_srcstride3  r6
    %assign push_num 0
%ifdef X86_32
    push            r6
    %assign push_num 1
%endif
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
    sub             p_src, i_srcstride
    sub             p_src, i_srcstride
    lea             i_srcstride3, [3 * i_srcstride]
    cmp             i_width, 8
    je              .width8
    jg              .width16
; .width4:
%ifdef X86_32_PICASM
    push            i_width
    mov             i_width, esp
    and             esp, 0xffffffe0
    sub             esp, 16
    push            0x14141414    ;db20_128
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0xfb01fb01    ;maddubsw_p1m5_256
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0x01fb01fb    ;maddubsw_m5p1_256
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
%endif
    vmovd           xmm0, [p_src]
    vpbroadcastd    xmm5, [p_src + i_srcstride]
    vpunpcklbw      xmm0, xmm0, xmm5
    vpbroadcastd    ymm1, [p_src + 2 * i_srcstride]
    vpunpcklbw      xmm5, xmm5, xmm1
    vpblendd        xmm0, xmm0, xmm5, 1100b
    vpbroadcastd    ymm5, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    vpunpcklbw      ymm1, ymm1, ymm5
    vpbroadcastd    ymm2, [p_src]
    vpunpcklbw      ymm5, ymm5, ymm2
    vpblendd        ymm1, ymm1, ymm5, 11001100b
    vpblendd        ymm0, ymm0, ymm1, 11110000b
    vpbroadcastd    ymm5, [p_src + i_srcstride]
    lea             p_src, [p_src + 2 * i_srcstride]
    vpunpcklbw      ymm2, ymm2, ymm5
    vpbroadcastd    ymm3, [p_src]
    vpunpcklbw      ymm5, ymm5, ymm3
    vpblendd        ymm2, ymm2, ymm5, 11001100b
    vpblendd        ymm1, ymm1, ymm2, 11110000b
    vpbroadcastd    ymm5, [p_src + i_srcstride]
    vpunpcklbw      ymm3, ymm3, ymm5
    vpbroadcastd    ymm4, [p_src + 2 * i_srcstride]
    vpunpcklbw      ymm5, ymm5, ymm4
    vpblendd        ymm3, ymm3, ymm5, 11001100b
    vpblendd        ymm2, ymm2, ymm3, 11110000b
%ifdef X86_32_PICASM
    vbroadcasti128  ymm6, [esp+64]
    AVX2_FilterVertical_16px ymm0, ymm1, ymm2, [esp+32], ymm6, [esp], ymm5
%else
    vbroadcasti128  ymm6, [db20_128]
    AVX2_FilterVertical_16px ymm0, ymm1, ymm2, [maddubsw_p1m5_256], ymm6, [maddubsw_m5p1_256], ymm5
%endif
    vpackuswb       ymm0, ymm0, ymm0
    vmovd           [p_dst], xmm0
    vpsrlq          xmm5, xmm0, 32
    vmovd           [p_dst + i_dststride], xmm5
    lea             p_dst, [p_dst + 2 * i_dststride]
    vextracti128    xmm0, ymm0, 1
    vmovd           [p_dst], xmm0
    vpsrlq          xmm5, xmm0, 32
    vmovd           [p_dst + i_dststride], xmm5
    cmp             i_height, 5
    jl              .width4_done
    lea             p_dst, [p_dst + 2 * i_dststride]
    vpbroadcastd    ymm5, [p_src + i_srcstride3]
    vpunpcklbw      ymm4, ymm4, ymm5
    jg              .width4_height_ge8
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px xmm2, xmm3, xmm4, [esp+32], xmm6, [esp], xmm5
%else
    AVX2_FilterVertical_16px xmm2, xmm3, xmm4, [maddubsw_p1m5_256], xmm6, [maddubsw_m5p1_256], xmm5
%endif
    vpackuswb       xmm2, xmm2, xmm2
    vmovd           [p_dst], xmm2
    jmp             .width4_done
.width4_height_ge8:
    lea             p_src, [p_src + 4 * i_srcstride]
    vpbroadcastd    ymm1, [p_src]
    vpunpcklbw      ymm5, ymm5, ymm1
    vpblendd        ymm4, ymm4, ymm5, 11001100b
    vpblendd        ymm3, ymm3, ymm4, 11110000b
    vpbroadcastd    ymm5, [p_src + i_srcstride]
    vpunpcklbw      ymm1, ymm5
    vpbroadcastd    ymm0, [p_src + 2 * i_srcstride]
    vpunpcklbw      ymm5, ymm5, ymm0
    vpblendd        ymm1, ymm1, ymm5, 11001100b
    vpblendd        ymm4, ymm4, ymm1, 11110000b
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px ymm2, ymm3, ymm4, [esp+32], ymm6, [esp], ymm5
%else
    AVX2_FilterVertical_16px ymm2, ymm3, ymm4, [maddubsw_p1m5_256], ymm6, [maddubsw_m5p1_256], ymm5
%endif
    vpackuswb       ymm2, ymm2, ymm2
    vmovd           [p_dst], xmm2
    vpsrlq          xmm5, xmm2, 32
    vmovd           [p_dst + i_dststride], xmm5
    lea             p_dst, [p_dst + 2 * i_dststride]
    vextracti128    xmm2, ymm2, 1
    vmovd           [p_dst], xmm2
    vpsrlq          xmm5, xmm2, 32
    vmovd           [p_dst + i_dststride], xmm5
    cmp             i_height, 9
    jl              .width4_done
    lea             p_dst, [p_dst + 2 * i_dststride]
    vmovd           xmm5, [p_src + i_srcstride3]
    vpunpcklbw      xmm0, xmm0, xmm5
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px xmm4, xmm1, xmm0, [esp+32], xmm6, [esp], xmm5
%else
    AVX2_FilterVertical_16px xmm4, xmm1, xmm0, [maddubsw_p1m5_256], xmm6, [maddubsw_m5p1_256], xmm5
%endif
    vpackuswb       xmm4, xmm4, xmm4
    vmovd           [p_dst], xmm4
.width4_done:
%ifdef X86_32_PICASM
    mov             esp, i_width
    pop             i_width
%endif
    vzeroupper
    POP_XMM
    LOAD_6_PARA_POP
%ifdef X86_32
    pop             r6
%endif
    ret

.width8:
%ifdef X86_32_PICASM
    push            i_width
    mov             i_width, esp
    and             esp, 0xffffffe0
    sub             esp, 16
    push            0x14141414    ;db20_128
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0xfb01fb01    ;maddubsw_p1m5_256
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0x01fb01fb    ;maddubsw_m5p1_256
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
%endif
    sub             i_height, 1
    vmovq           xmm0, [p_src]
    vmovq           xmm4, [p_src + i_srcstride]
    vpunpcklbw      xmm0, xmm0, xmm4
    vmovq           xmm1, [p_src + 2 * i_srcstride]
    vpunpcklbw      xmm4, xmm4, xmm1
    vinserti128     ymm0, ymm0, xmm4, 1
    vmovq           xmm4, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    vpunpcklbw      xmm1, xmm1, xmm4
    vmovq           xmm6, [p_src]
    vpunpcklbw      xmm4, xmm4, xmm6
    vinserti128     ymm1, ymm1, xmm4, 1
.width8_yloop:
    vmovq           xmm4, [p_src + i_srcstride]
    vpunpcklbw      xmm2, xmm6, xmm4
    vmovq           xmm3, [p_src + 2 * i_srcstride]
    vpunpcklbw      xmm4, xmm4, xmm3
    vinserti128     ymm2, ymm2, xmm4, 1
%ifdef X86_32_PICASM
    vbroadcasti128  ymm5, [esp+64]
    AVX2_FilterVertical_16px ymm0, ymm1, ymm2, [esp+32], ymm5, [esp], ymm4
%else
    vbroadcasti128  ymm5, [db20_128]
    AVX2_FilterVertical_16px ymm0, ymm1, ymm2, [maddubsw_p1m5_256], ymm5, [maddubsw_m5p1_256], ymm4
%endif
    vmovq           xmm4, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    vpunpcklbw      xmm3, xmm3, xmm4
    vmovq           xmm6, [p_src]
    vpunpcklbw      xmm4, xmm4, xmm6
    vinserti128     ymm3, ymm3, xmm4, 1
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px ymm1, ymm2, ymm3, [esp+32], ymm5, [esp], ymm4
%else
    AVX2_FilterVertical_16px ymm1, ymm2, ymm3, [maddubsw_p1m5_256], ymm5, [maddubsw_m5p1_256], ymm4
%endif
    vpackuswb       ymm0, ymm0, ymm1
    vmovlps         [p_dst], xmm0
    vextracti128    xmm1, ymm0, 1
    vmovlps         [p_dst + i_dststride], xmm1
    lea             p_dst, [p_dst + 2 * i_dststride]
    vmovhps         [p_dst], xmm0
    vmovhps         [p_dst + i_dststride], xmm1
    cmp             i_height, 4
    jl              .width8_done
    lea             p_dst, [p_dst + 2 * i_dststride]
    vmovq           xmm4, [p_src + i_srcstride]
    vpunpcklbw      xmm0, xmm6, xmm4
    jg              .width8_height_ge8
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px xmm2, xmm3, xmm0, [esp+32], xmm5, [esp], xmm4
%else
    AVX2_FilterVertical_16px xmm2, xmm3, xmm0, [maddubsw_p1m5_256], xmm5, [maddubsw_m5p1_256], xmm4
%endif
    vpackuswb       xmm2, xmm2, xmm2
    vmovlps         [p_dst], xmm2
    jmp             .width8_done
.width8_height_ge8:
    vmovq           xmm1, [p_src + 2 * i_srcstride]
    vpunpcklbw      xmm4, xmm4, xmm1
    vinserti128     ymm0, ymm0, xmm4, 1
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px ymm2, ymm3, ymm0, [esp+32], ymm5, [esp], ymm4
%else
    AVX2_FilterVertical_16px ymm2, ymm3, ymm0, [maddubsw_p1m5_256], ymm5, [maddubsw_m5p1_256], ymm4
%endif
    vmovq           xmm4, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    vpunpcklbw      xmm1, xmm1, xmm4
    vmovq           xmm6, [p_src]
    vpunpcklbw      xmm4, xmm4, xmm6
    vinserti128     ymm1, ymm1, xmm4, 1
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px ymm3, ymm0, ymm1, [esp+32], ymm5, [esp], ymm4
%else
    AVX2_FilterVertical_16px ymm3, ymm0, ymm1, [maddubsw_p1m5_256], ymm5, [maddubsw_m5p1_256], ymm4
%endif
    vpackuswb       ymm2, ymm2, ymm3
    vmovlps         [p_dst], xmm2
    vextracti128    xmm3, ymm2, 1
    vmovlps         [p_dst + i_dststride], xmm3
    lea             p_dst, [p_dst + 2 * i_dststride]
    vmovhps         [p_dst], xmm2
    vmovhps         [p_dst + i_dststride], xmm3
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_height, 8
    jg              .width8_yloop
    jl              .width8_done
    vmovq           xmm4, [p_src + i_srcstride]
    vpunpcklbw      xmm2, xmm6, xmm4
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px xmm0, xmm1, xmm2, [esp+32], xmm5, [esp], xmm4
%else
    AVX2_FilterVertical_16px xmm0, xmm1, xmm2, [maddubsw_p1m5_256], xmm5, [maddubsw_m5p1_256], xmm4
%endif
    vpackuswb       xmm0, xmm0, xmm0
    vmovlps         [p_dst], xmm0
.width8_done:
%ifdef X86_32_PICASM
    mov             esp, i_width
    pop             i_width
%endif
    vzeroupper
    POP_XMM
    LOAD_6_PARA_POP
%ifdef X86_32
    pop             r6
%endif
    ret

.width16:
%ifdef X86_32_PICASM
    push            i_width
    mov             i_width, esp
    and             esp, 0xffffffe0
    push            0x14141414    ;db20_128
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0x14141414
    push            0xfb01fb01    ;maddubsw_p1m5_256
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0xfb01fb01
    push            0x01fb01fb    ;maddubsw_m5p1_256
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x01fb01fb
    push            0x14fb14fb    ;maddubsw_m5p20_256
    push            0x14fb14fb
    push            0x14fb14fb
    push            0x14fb14fb
    push            0x14fb14fb
    push            0x14fb14fb
    push            0x14fb14fb
    push            0x14fb14fb
    push            0xfb14fb14    ;maddubsw_p20m5_256
    push            0xfb14fb14
    push            0xfb14fb14
    push            0xfb14fb14
    push            0xfb14fb14
    push            0xfb14fb14
    push            0xfb14fb14
    push            0xfb14fb14
%endif
    sub             i_height, 1
    test            i_height, 1
    jnz             .width16_yloop_begin_even
    vmovq           xmm0, [p_src]
    vpbroadcastq    ymm1, [p_src + 8]
    vpblendd        ymm0, ymm0, ymm1, 11110000b
    vmovq           xmm1, [p_src + i_srcstride]
    vpbroadcastq    ymm2, [p_src + i_srcstride + 8]
    vpblendd        ymm1, ymm1, ymm2, 11110000b
    vpunpcklbw      ymm0, ymm0, ymm1
    vmovq           xmm2, [p_src + 2 * i_srcstride]
    vpbroadcastq    ymm3, [p_src + 2 * i_srcstride + 8]
    vpblendd        ymm2, ymm2, ymm3, 11110000b
    vmovq           xmm3, [p_src + i_srcstride3]
    vpbroadcastq    ymm4, [p_src + i_srcstride3 + 8]
    lea             p_src, [p_src + 4 * i_srcstride]
    vpblendd        ymm3, ymm3, ymm4, 11110000b
    vpunpcklbw      ymm2, ymm2, ymm3
    vmovq           xmm4, [p_src]
    vpbroadcastq    ymm5, [p_src + 8]
    vpblendd        ymm4, ymm4, ymm5, 11110000b
    vmovq           xmm5, [p_src + i_srcstride]
    vpbroadcastq    ymm6, [p_src + i_srcstride + 8]
    lea             p_src, [p_src + 2 * i_srcstride]
    vpblendd        ymm5, ymm5, ymm6, 11110000b
    vpunpcklbw      ymm4, ymm4, ymm5
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px ymm0, ymm2, ymm4, [esp+96], [esp+128], [esp+64], ymm7
%else
    AVX2_FilterVertical_16px ymm0, ymm2, ymm4, [maddubsw_p1m5_256], [db20_256], [maddubsw_m5p1_256], ymm7
%endif
    vpackuswb       ymm0, ymm0, ymm0
    vpermq          ymm0, ymm0, 1000b
    vmovdqa         [p_dst], xmm0
    add             p_dst, i_dststride
    jmp             .width16_yloop
.width16_yloop_begin_even:
    vmovq           xmm1, [p_src]
    vpbroadcastq    ymm2, [p_src + 8]
    vpblendd        ymm1, ymm1, ymm2, 11110000b
    vmovq           xmm2, [p_src + i_srcstride]
    vpbroadcastq    ymm3, [p_src + i_srcstride + 8]
    vpblendd        ymm2, ymm2, ymm3, 11110000b
    vmovq           xmm3, [p_src + 2 * i_srcstride]
    vpbroadcastq    ymm4, [p_src + 2 * i_srcstride + 8]
    add             p_src, i_srcstride3
    vpblendd        ymm3, ymm3, ymm4, 11110000b
    vpunpcklbw      ymm2, ymm2, ymm3
    vmovq           xmm4, [p_src]
    vpbroadcastq    ymm5, [p_src + 8]
    vpblendd        ymm4, ymm4, ymm5, 11110000b
    vmovq           xmm5, [p_src + i_srcstride]
    vpbroadcastq    ymm6, [p_src + i_srcstride + 8]
    lea             p_src, [p_src + 2 * i_srcstride]
    vpblendd        ymm5, ymm5, ymm6, 11110000b
    vpunpcklbw      ymm4, ymm4, ymm5
.width16_yloop:
    vmovq           xmm6, [p_src]
    vpbroadcastq    ymm7, [p_src + 8]
    vpblendd        ymm6, ymm6, ymm7, 11110000b
%ifdef X86_32_PICASM
    AVX2_FilterVertical2_16px ymm1, ymm6, ymm2, ymm4, [esp+32], [esp], ymm0, ymm7
%else
    AVX2_FilterVertical2_16px ymm1, ymm6, ymm2, ymm4, [maddubsw_m5p20_256], [maddubsw_p20m5_256], ymm0, ymm7
%endif
    vmovq           xmm7, [p_src + i_srcstride]
    vpbroadcastq    ymm0, [p_src + i_srcstride + 8]
    vpblendd        ymm7, ymm7, ymm0, 11110000b
    vpunpcklbw      ymm6, ymm6, ymm7
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px ymm2, ymm4, ymm6, [esp+96], [esp+128], [esp+64], ymm0
%else
    AVX2_FilterVertical_16px ymm2, ymm4, ymm6, [maddubsw_p1m5_256], [db20_256], [maddubsw_m5p1_256], ymm0
%endif
    vpackuswb       ymm1, ymm1, ymm2
    vpermq          ymm1, ymm1, 11011000b
    vmovdqa         [p_dst], xmm1
    vextracti128    [p_dst + i_dststride], ymm1, 1
    lea             p_dst, [p_dst + 2 * i_dststride]
    vmovq           xmm0, [p_src + 2 * i_srcstride]
    vpbroadcastq    ymm1, [p_src + 2 * i_srcstride + 8]
    vpblendd        ymm0, ymm0, ymm1, 11110000b
%ifdef X86_32_PICASM
    AVX2_FilterVertical2_16px ymm3, ymm0, ymm4, ymm6, [esp+32], [esp], ymm2, ymm1
%else
    AVX2_FilterVertical2_16px ymm3, ymm0, ymm4, ymm6, [maddubsw_m5p20_256], [maddubsw_p20m5_256], ymm2, ymm1
%endif
    vmovq           xmm1, [p_src + i_srcstride3]
    vpbroadcastq    ymm2, [p_src + i_srcstride3 + 8]
    lea             p_src, [p_src + 4 * i_srcstride]
    vpblendd        ymm1, ymm1, ymm2, 11110000b
    vpunpcklbw      ymm0, ymm0, ymm1
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px ymm4, ymm6, ymm0, [esp+96], [esp+128], [esp+64], ymm2
%else
    AVX2_FilterVertical_16px ymm4, ymm6, ymm0, [maddubsw_p1m5_256], [db20_256], [maddubsw_m5p1_256], ymm2
%endif
    vpackuswb       ymm3, ymm3, ymm4
    vpermq          ymm3, ymm3, 11011000b
    vmovdqa         [p_dst], xmm3
    vextracti128    [p_dst + i_dststride], ymm3, 1
    lea             p_dst, [p_dst + 2 * i_dststride]
    vmovq           xmm2, [p_src]
    vpbroadcastq    ymm3, [p_src + 8]
    vpblendd        ymm2, ymm2, ymm3, 11110000b
%ifdef X86_32_PICASM
    AVX2_FilterVertical2_16px ymm5, ymm2, ymm6, ymm0, [esp+32], [esp], ymm4, ymm3
%else
    AVX2_FilterVertical2_16px ymm5, ymm2, ymm6, ymm0, [maddubsw_m5p20_256], [maddubsw_p20m5_256], ymm4, ymm3
%endif
    vmovq           xmm3, [p_src + i_srcstride]
    vpbroadcastq    ymm4, [p_src + i_srcstride + 8]
    vpblendd        ymm3, ymm3, ymm4, 11110000b
    vpunpcklbw      ymm2, ymm2, ymm3
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px ymm6, ymm0, ymm2, [esp+96], [esp+128], [esp+64], ymm4
%else
    AVX2_FilterVertical_16px ymm6, ymm0, ymm2, [maddubsw_p1m5_256], [db20_256], [maddubsw_m5p1_256], ymm4
%endif
    vpackuswb       ymm5, ymm5, ymm6
    vpermq          ymm5, ymm5, 11011000b
    vmovdqa         [p_dst], xmm5
    vextracti128    [p_dst + i_dststride], ymm5, 1
    lea             p_dst, [p_dst + 2 * i_dststride]
    vmovq           xmm4, [p_src + 2 * i_srcstride]
    vpbroadcastq    ymm5, [p_src + 2 * i_srcstride + 8]
    vpblendd        ymm4, ymm4, ymm5, 11110000b
%ifdef X86_32_PICASM
    AVX2_FilterVertical2_16px ymm7, ymm4, ymm0, ymm2, [esp+32], [esp], ymm6, ymm5
%else
    AVX2_FilterVertical2_16px ymm7, ymm4, ymm0, ymm2, [maddubsw_m5p20_256], [maddubsw_p20m5_256], ymm6, ymm5
%endif
    vmovq           xmm5, [p_src + i_srcstride3]
    vpbroadcastq    ymm6, [p_src + i_srcstride3 + 8]
    lea             p_src, [p_src + 4 * i_srcstride]
    vpblendd        ymm5, ymm5, ymm6, 11110000b
    vpunpcklbw      ymm4, ymm4, ymm5
%ifdef X86_32_PICASM
    AVX2_FilterVertical_16px ymm0, ymm2, ymm4, [esp+96], [esp+128], [esp+64], ymm6
%else
    AVX2_FilterVertical_16px ymm0, ymm2, ymm4, [maddubsw_p1m5_256], [db20_256], [maddubsw_m5p1_256], ymm6
%endif
    vpackuswb       ymm7, ymm7, ymm0
    vpermq          ymm7, ymm7, 11011000b
    vmovdqa         [p_dst], xmm7
    vextracti128    [p_dst + i_dststride], ymm7, 1
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_height, 8
    jg              .width16_yloop
%ifdef X86_32_PICASM
    mov             esp, i_width
    pop             i_width
%endif
    vzeroupper
    POP_XMM
    LOAD_6_PARA_POP
%ifdef X86_32
    pop             r6
%endif
    ret
%undef p_src
%undef i_srcstride
%undef i_srcstride3
%undef p_dst
%undef i_dststride
%undef i_width
%undef i_height
%undef i_ycnt


;*******************************************************************************
; void McHorVer20_avx2(const uint8_t *pSrc,
;                      int iSrcStride,
;                      uint8_t *pDst,
;                      int iDstStride,
;                      int iWidth,
;                      int iHeight);
;*******************************************************************************

WELS_EXTERN McHorVer20_avx2
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_dststride  r3
%define i_width      r4
%define i_height     r5
    %assign  push_num 0
    LOAD_6_PARA
    PUSH_XMM 7
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
%ifdef X86_32_PICASM
    push            r1
    mov             r1, esp
    and             esp, 0xfffffff0
    push            0x090a0809        ;shufb_32435465768798A9
    push            0x07080607
    push            0x05060405
    push            0x03040203
    vbroadcasti128  ymm4, [esp]
    push            0x0c0b0b0a
    push            0x06050504
    push            0x08070706
    push            0x02010100
    vbroadcasti128  ymm5, [esp]
    push            0x01fb01fb
    push            0xfb01fb01
    push            0x01fb01fb
    push            0xfb01fb01
    vbroadcasti128  ymm6, [esp]
    mov             esp, r1
    pop             r1
%else
    vbroadcasti128  ymm4, [shufb_32435465768798A9]
    vbroadcasti128  ymm5, [shufb_011267784556ABBC]
    vbroadcasti128  ymm6, [maddubsw_p1m5_p1m5_m5p1_m5p1_128]
%endif
    cmp             i_width, 8
    je              .width8
    jg              .width16_yloop
%xdefine i_srcstride3 i_width
%undef i_width
    lea             i_srcstride3, [3 * i_srcstride]
.width4_yloop:
    vmovdqu         xmm0, [p_src - 2]
    vmovdqu         xmm1, [p_src + i_srcstride - 2]
    vinserti128     ymm0, ymm0, [p_src + 2 * i_srcstride - 2], 1
    vinserti128     ymm1, ymm1, [p_src + i_srcstride3 - 2], 1
    lea             p_src, [p_src + 4 * i_srcstride]
    AVX2_FilterHorizontal_4x4px ymm0, ymm1, ymm4, ymm5, ymm6, ymm2, ymm3
    vpackuswb       ymm0, ymm0, ymm0
    vmovd           [p_dst], xmm0
    vpsrlq          xmm1, xmm0, 32
    vmovd           [p_dst + i_dststride], xmm1
    lea             p_dst, [p_dst + 2 * i_dststride]
    vextracti128    xmm0, ymm0, 1
    vmovd           [p_dst], xmm0
    vpsrlq          xmm1, xmm0, 32
    vmovd           [p_dst + i_dststride], xmm1
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_height, 4
    jg              .width4_yloop
    vzeroupper
    POP_XMM
    LOAD_6_PARA_POP
    ret
.width8:
    lea             i_srcstride3, [3 * i_srcstride]
.width8_yloop:
    vmovdqu         xmm0, [p_src - 2]
    vmovdqu         xmm1, [p_src + i_srcstride - 2]
    vinserti128     ymm0, ymm0, [p_src + 2 * i_srcstride - 2], 1
    vinserti128     ymm1, ymm1, [p_src + i_srcstride3 - 2], 1
    lea             p_src, [p_src + 4 * i_srcstride]
    AVX2_FilterHorizontal_16px ymm0, ymm4, ymm5, ymm6, ymm2, ymm3
    AVX2_FilterHorizontal_16px ymm1, ymm4, ymm5, ymm6, ymm2, ymm3
    vpackuswb       ymm0, ymm0, ymm1
    vmovlps         [p_dst], xmm0
    vmovhps         [p_dst + i_dststride], xmm0
    lea             p_dst, [p_dst + 2 * i_dststride]
    vextracti128    xmm0, ymm0, 1
    vmovlps         [p_dst], xmm0
    vmovhps         [p_dst + i_dststride], xmm0
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_height, 4
    jg              .width8_yloop
    vzeroupper
    POP_XMM
    LOAD_6_PARA_POP
    ret
%undef i_srcstride3
.width16_yloop:
    vmovdqu         xmm0, [p_src - 2]
    vmovdqu         xmm1, [p_src + 6]
    vinserti128     ymm0, ymm0, [p_src + i_srcstride - 2], 1
    vinserti128     ymm1, ymm1, [p_src + i_srcstride + 6], 1
    lea             p_src, [p_src + 2 * i_srcstride]
    AVX2_FilterHorizontal_16px ymm0, ymm4, ymm5, ymm6, ymm2, ymm3
    AVX2_FilterHorizontal_16px ymm1, ymm4, ymm5, ymm6, ymm2, ymm3
    vpackuswb       ymm0, ymm0, ymm1
    vmovdqa         [p_dst], xmm0
    vextracti128    [p_dst + i_dststride], ymm0, 1
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_height, 2
    jg              .width16_yloop
    vzeroupper
    POP_XMM
    LOAD_6_PARA_POP
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_dststride
%undef i_width
%undef i_height


;***********************************************************************
; void McHorVer20Width5Or9Or17_avx2(const uint8_t *pSrc,
;                                   int32_t iSrcStride,
;                                   uint8_t *pDst,
;                                   int32_t iDstStride,
;                                   int32_t iWidth,
;                                   int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer20Width5Or9Or17_avx2
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_dststride  r3
%define i_width      r4
%define i_height     r5
    %assign  push_num 0
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
%ifdef X86_32_PICASM
    push            r1
    mov             r1, esp
    and             esp, 0xfffffff0
    push            0x090a0809        ;shufb_32435465768798A9
    push            0x07080607
    push            0x05060405
    push            0x03040203
    vbroadcasti128  ymm5, [esp]
    push            0x0c0b0b0a
    push            0x06050504
    push            0x08070706
    push            0x02010100
    vbroadcasti128  ymm6, [esp]
    push            0x01fb01fb
    push            0xfb01fb01
    push            0x01fb01fb
    push            0xfb01fb01
    vbroadcasti128  ymm7, [esp]
    mov             esp, r1
    pop             r1
%else
    vbroadcasti128  ymm5, [shufb_32435465768798A9]
    vbroadcasti128  ymm6, [shufb_011267784556ABBC]
    vbroadcasti128  ymm7, [maddubsw_p1m5_p1m5_m5p1_m5p1_128]
%endif
    cmp             i_width, 9
    je              .width9
    jg              .width17
.width5_yloop:
    vmovdqu         xmm0, [p_src - 2]
    vinserti128     ymm0, ymm0, [p_src + i_srcstride - 2], 1
    lea             p_src, [p_src + 2 * i_srcstride]
    AVX2_FilterHorizontal_16px ymm0, ymm5, ymm6, ymm7, ymm1, ymm2
    vpackuswb       ymm0, ymm0, ymm0
    vpsrlq          xmm1, xmm0, 8
    vmovd           [p_dst + 1], xmm1
    vmovd           [p_dst], xmm0
    add             p_dst, i_dststride
    vextracti128    xmm0, ymm0, 1
    vpsrlq          xmm1, xmm0, 8
    vmovd           [p_dst + 1], xmm1
    vmovd           [p_dst], xmm0
    add             p_dst, i_dststride
    sub             i_height, 2
    jg              .width5_yloop
    vzeroupper
    POP_XMM
    LOAD_6_PARA_POP
    ret
.width9:
%xdefine i_srcstride3 i_width
%undef i_width
    lea             i_srcstride3, [3 * i_srcstride]
.width9_yloop:
    vmovdqu         xmm0, [p_src - 2]
    vmovdqu         xmm4, [p_src + i_srcstride - 2]
    vinserti128     ymm0, ymm0, [p_src + 2 * i_srcstride - 2], 1
    vinserti128     ymm4, ymm4, [p_src + i_srcstride3 - 2], 1
    lea             p_src, [p_src + 4 * i_srcstride]
    vpunpckhqdq     ymm3, ymm0, ymm4
    AVX2_FilterHorizontal_4px ymm3, ymm2
    AVX2_FilterHorizontal_16px ymm0, ymm5, ymm6, ymm7, ymm1, ymm2
    vpackuswb       ymm3, ymm3, ymm0
    vmovd           [p_dst + 5], xmm3
    vmovhps         [p_dst], xmm3
    add             p_dst, i_dststride
    AVX2_FilterHorizontal_16px ymm4, ymm5, ymm6, ymm7, ymm1, ymm2
    vpackuswb       ymm4, ymm4, ymm4
    vpsrlq          xmm2, xmm3, 32
    vmovd           [p_dst + 5], xmm2
    vmovlps         [p_dst], xmm4
    add             p_dst, i_dststride
    vextracti128    xmm3, ymm3, 1
    vextracti128    xmm4, ymm4, 1
    vmovd           [p_dst + 5], xmm3
    vmovhps         [p_dst], xmm3
    add             p_dst, i_dststride
    vpsrlq          xmm2, xmm3, 32
    vmovd           [p_dst + 5], xmm2
    vmovlps         [p_dst], xmm4
    add             p_dst, i_dststride
    sub             i_height, 4
    jg              .width9_yloop
    vzeroupper
    POP_XMM
    LOAD_6_PARA_POP
    ret
.width17:
    lea             i_srcstride3, [3 * i_srcstride]
.width17_yloop:
    vmovdqu         xmm0, [p_src - 2]
    vmovdqu         xmm3, [p_src + 6]
    vinserti128     ymm0, ymm0, [p_src + i_srcstride - 2], 1
    vinserti128     ymm3, ymm3, [p_src + i_srcstride + 6], 1
    vmovdqa         ymm4, ymm3
    AVX2_FilterHorizontal_16px ymm0, ymm5, ymm6, ymm7, ymm1, ymm2
    AVX2_FilterHorizontal_16px ymm3, ymm5, ymm6, ymm7, ymm1, ymm2
    vpackuswb       ymm0, ymm0, ymm3
    vmovdqu         xmm1, [p_src + 2 * i_srcstride - 2]
    vmovdqu         xmm3, [p_src + 2 * i_srcstride + 6]
    vinserti128     ymm1, ymm1, [p_src + i_srcstride3 - 2], 1
    vinserti128     ymm3, ymm3, [p_src + i_srcstride3 + 6], 1
    lea             p_src, [p_src + 4 * i_srcstride]
    vpunpckhqdq     ymm4, ymm4, ymm3
    AVX2_FilterHorizontal_4px ymm4, ymm2
    vpackuswb       ymm4, ymm4, ymm4
    vmovd           [p_dst + 13], xmm4
    vmovdqa         [p_dst], xmm0
    add             p_dst, i_dststride
    vextracti128    xmm2, ymm4, 1
    vmovd           [p_dst + 13], xmm2
    vextracti128    [p_dst], ymm0, 1
    add             p_dst, i_dststride
    vpsrlq          xmm4, xmm4, 32
    vmovd           [p_dst + 13], xmm4
    AVX2_FilterHorizontal_16px ymm1, ymm5, ymm6, ymm7, ymm0, ymm4
    AVX2_FilterHorizontal_16px ymm3, ymm5, ymm6, ymm7, ymm0, ymm4
    vpackuswb       ymm1, ymm1, ymm3
    vmovdqa         [p_dst], xmm1
    add             p_dst, i_dststride
    vpsrlq          xmm2, xmm2, 32
    vmovd           [p_dst + 13], xmm2
    vextracti128    [p_dst], ymm1, 1
    add             p_dst, i_dststride
    sub             i_height, 4
    jg              .width17_yloop
    vzeroupper
    POP_XMM
    LOAD_6_PARA_POP
    ret
%undef i_srcstride3
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_dststride
%undef i_width
%undef i_height


;*******************************************************************************
; void McHorVer20Width4U8ToS16_avx2(const uint8_t *pSrc,
;                                   int iSrcStride,
;                                   int16_t *pDst,
;                                   int iHeight);
;*******************************************************************************

WELS_EXTERN McHorVer20Width4U8ToS16_avx2
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_height     r3
%define i_srcstride3 r4
%define i_dststride   8
    %assign  push_num 0
%ifdef X86_32
    push            r4
    %assign  push_num 1
%endif
    LOAD_4_PARA
    PUSH_XMM 7
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    sub             p_src, i_srcstride
    sub             p_src, i_srcstride
    lea             i_srcstride3, [3 * i_srcstride]
%ifdef X86_32_PICASM
    push            r1
    mov             r1, esp
    and             esp, 0xfffffff0
    push            0x090a0809        ;shufb_32435465768798A9
    push            0x07080607
    push            0x05060405
    push            0x03040203
    vbroadcasti128  ymm4, [esp]
    push            0x0c0b0b0a
    push            0x06050504
    push            0x08070706
    push            0x02010100
    vbroadcasti128  ymm5, [esp]
    push            0x01fb01fb
    push            0xfb01fb01
    push            0x01fb01fb
    push            0xfb01fb01
    vbroadcasti128  ymm6, [esp]
    mov             esp, r1
    pop             r1
%else
    vbroadcasti128  ymm4, [shufb_32435465768798A9]
    vbroadcasti128  ymm5, [shufb_011267784556ABBC]
    vbroadcasti128  ymm6, [maddubsw_p1m5_p1m5_m5p1_m5p1_128]
%endif
    sub             i_height, 3
.yloop:
    vmovdqu         xmm0, [p_src - 2]
    vmovdqu         xmm1, [p_src + i_srcstride - 2]
    vinserti128     ymm0, ymm0, [p_src + 2 * i_srcstride - 2], 1
    vinserti128     ymm1, ymm1, [p_src + i_srcstride3 - 2], 1
    lea             p_src, [p_src + 4 * i_srcstride]
    AVX2_FilterHorizontalbw_4x4px ymm0, ymm1, ymm4, ymm5, ymm6, ymm2, ymm3
    vmovdqa         [p_dst], ymm0
    add             p_dst, 4 * i_dststride
    sub             i_height, 4
    jg              .yloop
    ; Height % 4 remaining single.
    vmovdqu         xmm0, [p_src - 2]
    AVX2_FilterHorizontalbw_16px xmm0, xmm4, xmm5, xmm6, xmm2, xmm3
    vmovlps         [p_dst], xmm0
    vzeroupper
    POP_XMM
    LOAD_4_PARA_POP
%ifdef X86_32
    pop             r4
%endif
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_height
%undef i_srcstride3
%undef i_dststride


;***********************************************************************
; void McHorVer02Width4S16ToU8_avx2(const int16_t *pSrc,
;                                   uint8_t *pDst,
;                                   int32_t iDstStride,
;                                   int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer02Width4S16ToU8_avx2
%define p_src        r0
%define p_dst        r1
%define i_dststride  r2
%define i_height     r3
%define i_dststride3 r4
%define i_srcstride  8
    %assign  push_num 0
%ifdef X86_32
    push            r4
    %assign  push_num 1
%endif
    LOAD_4_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r2, r2d
    SIGN_EXTENSION  r3, r3d
    lea             i_dststride3, [3 * i_dststride]
    vmovdqu         ymm0, [p_src +  0 * i_srcstride]
    vmovdqu         ymm1, [p_src +  1 * i_srcstride]
    vmovdqu         ymm2, [p_src +  2 * i_srcstride]
    vmovdqu         ymm3, [p_src +  3 * i_srcstride]
    vmovdqu         ymm4, [p_src +  4 * i_srcstride]
    vmovdqu         ymm5, [p_src +  5 * i_srcstride]
    vmovdqu         ymm6, [p_src +  6 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm0, ymm1, ymm2, ymm3, ymm4, ymm5, ymm7
    vpackuswb       ymm0, ymm0, ymm0
    vmovd           [p_dst], xmm0
    vpsrlq          xmm7, xmm0, 32
    vmovd           [p_dst + i_dststride], xmm7
    vextracti128    xmm0, ymm0, 1
    vmovd           [p_dst + 2 * i_dststride], xmm0
    vpsrlq          xmm7, xmm0, 32
    vmovd           [p_dst + i_dststride3], xmm7
    cmp             i_height, 4
    jle             .done
    lea             p_dst, [p_dst + 4 * i_dststride]
    vmovdqu         ymm7, [p_src +  7 * i_srcstride]
    vmovdqu         ymm0, [p_src +  8 * i_srcstride]
    vmovdqu         ymm1, [p_src +  9 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm4, ymm5, ymm6, ymm7, ymm0, ymm1, ymm3
    vpackuswb       ymm4, ymm4, ymm4
    vmovd           [p_dst], xmm4
    vpsrlq          xmm3, xmm4, 32
    vmovd           [p_dst + i_dststride], xmm3
    vextracti128    xmm4, ymm4, 1
    vmovd           [p_dst + 2 * i_dststride], xmm4
    vpsrlq          xmm3, xmm4, 32
    vmovd           [p_dst + i_dststride3], xmm3
.done:
    vzeroupper
    POP_XMM
    LOAD_4_PARA_POP
%ifdef X86_32
    pop             r4
%endif
    ret
%undef p_src
%undef p_dst
%undef i_dststride
%undef i_height
%undef i_srcstride
%undef i_dststride3


;*******************************************************************************
; void McHorVer20Width8U8ToS16_avx2(const uint8_t *pSrc,
;                                   int iSrcStride,
;                                   int16_t *pDst,
;                                   int iHeight);
;*******************************************************************************

WELS_EXTERN McHorVer20Width8U8ToS16_avx2
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_height     r3
%define i_dststride  16
    %assign  push_num 0
    LOAD_4_PARA
    PUSH_XMM 6
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    sub             p_src, i_srcstride
    sub             p_src, i_srcstride
%ifdef X86_32_PICASM
    push            r1
    mov             r1, esp
    and             esp, 0xfffffff0
    push            0x090a0809        ;shufb_32435465768798A9
    push            0x07080607
    push            0x05060405
    push            0x03040203
    vbroadcasti128  ymm3, [esp]
    push            0x0c0b0b0a
    push            0x06050504
    push            0x08070706
    push            0x02010100
    vbroadcasti128  ymm4, [esp]
    push            0x01fb01fb
    push            0xfb01fb01
    push            0x01fb01fb
    push            0xfb01fb01
    vbroadcasti128  ymm5, [esp]
    mov             esp, r1
    pop             r1
%else
    vbroadcasti128  ymm3, [shufb_32435465768798A9]
    vbroadcasti128  ymm4, [shufb_011267784556ABBC]
    vbroadcasti128  ymm5, [maddubsw_p1m5_p1m5_m5p1_m5p1_128]
%endif
    sub             i_height, 1
.yloop:
    vmovdqu         xmm0, [p_src - 2]
    vinserti128     ymm0, ymm0, [p_src + i_srcstride - 2], 1
    lea             p_src, [p_src + 2 * i_srcstride]
    AVX2_FilterHorizontalbw_16px ymm0, ymm3, ymm4, ymm5, ymm1, ymm2
    vmovdqu         [p_dst], ymm0
    add             p_dst, 2 * i_dststride
    sub             i_height, 2
    jg              .yloop
    jl              .done
    vmovdqu         xmm0, [p_src - 2]
    AVX2_FilterHorizontalbw_16px xmm0, xmm3, xmm4, xmm5, xmm1, xmm2
    vmovdqa         [p_dst], xmm0
.done:
    vzeroupper
    POP_XMM
    LOAD_4_PARA_POP
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_height
%undef i_dststride


;***********************************************************************
; void McHorVer02Width5S16ToU8_avx2(const int16_t *pSrc,
;                                   uint8_t *pDst,
;                                   int32_t iDstStride,
;                                   int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer02Width5S16ToU8_avx2
%define p_src        r0
%define p_dst        r1
%define i_dststride  r2
%define i_height     r3
%define i_srcstride  16
    %assign  push_num 0
    LOAD_4_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r2, r2d
    SIGN_EXTENSION  r3, r3d
    vmovdqu         ymm0, [p_src +  0 * i_srcstride]
    vmovdqu         ymm2, [p_src +  2 * i_srcstride]
    vmovdqu         ymm4, [p_src +  4 * i_srcstride]
    vmovdqu         ymm6, [p_src +  6 * i_srcstride]
    vperm2i128      ymm1, ymm0, ymm2, 00100001b
    vperm2i128      ymm3, ymm2, ymm4, 00100001b
    vperm2i128      ymm5, ymm4, ymm6, 00100001b
    AVX2_FilterVerticalw_16px ymm0, ymm1, ymm2, ymm3, ymm4, ymm5, ymm7
    vpackuswb       ymm0, ymm0, ymm0
    vpsrlq          xmm7, xmm0, 8
    vmovd           [p_dst + 1], xmm7
    vmovd           [p_dst], xmm0
    add             p_dst, i_dststride
    vextracti128    xmm0, ymm0, 1
    vpsrlq          xmm7, xmm0, 8
    vmovd           [p_dst + 1], xmm7
    vmovd           [p_dst], xmm0
    add             p_dst, i_dststride
    vmovdqu         ymm7, [p_src +  7 * i_srcstride]
    vmovdqu         ymm0, [p_src +  8 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm2, ymm3, ymm4, ymm5, ymm6, ymm7, ymm1
    vpackuswb       ymm2, ymm2, ymm2
    vpsrlq          xmm1, xmm2, 8
    vmovd           [p_dst + 1], xmm1
    vmovd           [p_dst], xmm2
    add             p_dst, i_dststride
    vextracti128    xmm2, ymm2, 1
    vpsrlq          xmm1, xmm2, 8
    vmovd           [p_dst + 1], xmm1
    vmovd           [p_dst], xmm2
    add             p_dst, i_dststride
    vmovdqu         ymm1, [p_src +  9 * i_srcstride]
    vmovdqu         ymm2, [p_src + 10 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm4, ymm5, ymm6, ymm7, ymm0, ymm1, ymm3
    vpackuswb       ymm4, ymm4, ymm4
    vpsrlq          xmm3, xmm4, 8
    vmovd           [p_dst + 1], xmm3
    vmovd           [p_dst], xmm4
    cmp             i_height, 5
    jle             .done
    add             p_dst, i_dststride
    vextracti128    xmm4, ymm4, 1
    vpsrlq          xmm3, xmm4, 8
    vmovd           [p_dst + 1], xmm3
    vmovd           [p_dst], xmm4
    add             p_dst, i_dststride
    vmovdqu         ymm3, [p_src + 11 * i_srcstride]
    vmovdqu         xmm4, [p_src + 12 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm6, ymm7, ymm0, ymm1, ymm2, ymm3, ymm5
    vpackuswb       ymm6, ymm6, ymm6
    vpsrlq          xmm5, xmm6, 8
    vmovd           [p_dst + 1], xmm5
    vmovd           [p_dst], xmm6
    add             p_dst, i_dststride
    vextracti128    xmm6, ymm6, 1
    vpsrlq          xmm5, xmm6, 8
    vmovd           [p_dst + 1], xmm5
    vmovd           [p_dst], xmm6
    add             p_dst, i_dststride
    vmovdqu         xmm5, [p_src + 13 * i_srcstride]
    AVX2_FilterVerticalw_16px xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm7
    vpackuswb       xmm0, xmm0, xmm0
    vpsrlq          xmm7, xmm0, 8
    vmovd           [p_dst + 1], xmm7
    vmovd           [p_dst], xmm0
.done:
    vzeroupper
    POP_XMM
    LOAD_4_PARA_POP
    ret
%undef p_src
%undef p_dst
%undef i_dststride
%undef i_height
%undef i_srcstride


;***********************************************************************
; void McHorVer02Width8S16ToU8_avx2(const int16_t *pSrc,
;                                   uint8_t *pDst,
;                                   int32_t iDstStride,
;                                   int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer02Width8S16ToU8_avx2
%define p_src        r0
%define p_dst        r1
%define i_dststride  r2
%define i_height     r3
%define i_dststride3 r4
%define i_srcstride  16
    %assign  push_num 0
%ifdef X86_32
    push            r4
    %assign  push_num 1
%endif
    LOAD_4_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r2, r2d
    SIGN_EXTENSION  r3, r3d
    lea             i_dststride3, [3 * i_dststride]
    vmovdqa         ymm0, [p_src +  0 * i_srcstride]
    vmovdqa         ymm2, [p_src +  2 * i_srcstride]
    vmovdqa         ymm4, [p_src +  4 * i_srcstride]
    vperm2i128      ymm1, ymm0, ymm2, 00100001b
    vperm2i128      ymm3, ymm2, ymm4, 00100001b
.yloop:
    vmovdqa         ymm6, [p_src +  6 * i_srcstride]
    vperm2i128      ymm5, ymm4, ymm6, 00100001b
    AVX2_FilterVerticalw_16px ymm0, ymm1, ymm2, ymm3, ymm4, ymm5, ymm7
    vmovdqu         ymm7, [p_src +  7 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm2, ymm3, ymm4, ymm5, ymm6, ymm7, ymm1
    vpackuswb       ymm1, ymm0, ymm2
    vmovdqa         ymm0, [p_src +  8 * i_srcstride]
    vextracti128    xmm2, ymm1, 1
    vmovlps         [p_dst], xmm1
    vmovlps         [p_dst + i_dststride], xmm2
    vmovhps         [p_dst + 2 * i_dststride], xmm1
    vmovhps         [p_dst + i_dststride3], xmm2
    cmp             i_height, 4
    jle             .done
    lea             p_dst, [p_dst + 4 * i_dststride]
    vmovdqu         ymm1, [p_src +  9 * i_srcstride]
    vmovdqa         ymm2, [p_src + 10 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm4, ymm5, ymm6, ymm7, ymm0, ymm1, ymm3
    vmovdqu         ymm3, [p_src + 11 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm6, ymm7, ymm0, ymm1, ymm2, ymm3, ymm5
    vpackuswb       ymm5, ymm4, ymm6
    vmovdqa         ymm4, [p_src + 12 * i_srcstride]
    add             p_src, 8 * i_srcstride
    vextracti128    xmm6, ymm5, 1
    vmovlps         [p_dst], xmm5
    vmovlps         [p_dst + i_dststride], xmm6
    vmovhps         [p_dst + 2 * i_dststride], xmm5
    vmovhps         [p_dst + i_dststride3], xmm6
    lea             p_dst, [p_dst + 4 * i_dststride]
    sub             i_height, 8
    jg              .yloop
.done:
    vzeroupper
    POP_XMM
    LOAD_4_PARA_POP
%ifdef X86_32
    pop             r4
%endif
    ret
%undef p_src
%undef p_dst
%undef i_dststride
%undef i_height
%undef i_dststride3
%undef i_srcstride


;*******************************************************************************
; void McHorVer20Width16U8ToS16_avx2(const uint8_t *pSrc,
;                                    int32_t iSrcStride,
;                                    int16_t *pDst,
;                                    int32_t iHeight);
;*******************************************************************************

WELS_EXTERN McHorVer20Width16U8ToS16_avx2
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_height     r3
%define i_dststride  32
    %assign  push_num 0
    LOAD_4_PARA
    PUSH_XMM 7
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    sub             p_src, i_srcstride
    sub             p_src, i_srcstride
%ifdef X86_32_PICASM
    push            r1
    mov             r1, esp
    and             esp, 0xfffffff0
    push            0x090a0809        ;shufb_32435465768798A9
    push            0x07080607
    push            0x05060405
    push            0x03040203
    vbroadcasti128  ymm4, [esp]
    push            0x0c0b0b0a
    push            0x06050504
    push            0x08070706
    push            0x02010100
    vbroadcasti128  ymm5, [esp]
    push            0x01fb01fb
    push            0xfb01fb01
    push            0x01fb01fb
    push            0xfb01fb01
    vbroadcasti128  ymm6, [esp]
    mov             esp, r1
    pop             r1
%else
    vbroadcasti128  ymm4, [shufb_32435465768798A9]
    vbroadcasti128  ymm5, [shufb_011267784556ABBC]
    vbroadcasti128  ymm6, [maddubsw_p1m5_p1m5_m5p1_m5p1_128]
%endif
    sub             i_height, 1
.yloop:
    vmovdqu         xmm0, [p_src - 2]
    vinserti128     ymm0, ymm0, [p_src + 6], 1
    vmovdqu         xmm1, [p_src + i_srcstride - 2]
    vinserti128     ymm1, ymm1, [p_src + i_srcstride + 6], 1
    lea             p_src, [p_src + 2 * i_srcstride]
    AVX2_FilterHorizontalbw_16px ymm0, ymm4, ymm5, ymm6, ymm2, ymm3
    vmovdqa         [p_dst], ymm0
    AVX2_FilterHorizontalbw_16px ymm1, ymm4, ymm5, ymm6, ymm2, ymm3
    vmovdqa         [p_dst + i_dststride], ymm1
    add             p_dst, 2 * i_dststride
    sub             i_height, 2
    jg              .yloop
    jl              .done
    vmovdqu         xmm0, [p_src - 2]
    vinserti128     ymm0, ymm0, [p_src + 6], 1
    AVX2_FilterHorizontalbw_16px ymm0, ymm4, ymm5, ymm6, ymm1, ymm2
    vmovdqa         [p_dst], ymm0
.done:
    vzeroupper
    POP_XMM
    LOAD_4_PARA_POP
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_height
%undef i_dststride


;***********************************************************************
; void McHorVer02Width9S16ToU8_avx2(const int16_t *pSrc,
;                                   uint8_t *pDst,
;                                   int32_t iDstStride,
;                                   int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer02Width9S16ToU8_avx2
%define p_src        r0
%define p_dst        r1
%define i_dststride  r2
%define i_height     r3
%define i_srcstride  32
    %assign  push_num 0
    LOAD_4_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r2, r2d
    SIGN_EXTENSION  r3, r3d
    vmovdqa         ymm0, [p_src + 0 * i_srcstride]
    vmovdqa         ymm1, [p_src + 1 * i_srcstride]
    vmovdqa         ymm2, [p_src + 2 * i_srcstride]
    vmovdqa         ymm3, [p_src + 3 * i_srcstride]
    vmovdqa         ymm4, [p_src + 4 * i_srcstride]
    sub             i_height, 1
.height_loop:
    vmovdqa         ymm5, [p_src + 5 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm0, ymm1, ymm2, ymm3, ymm4, ymm5, ymm6
    vmovdqa         ymm6, [p_src + 6 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm1, ymm2, ymm3, ymm4, ymm5, ymm6, ymm7
    vmovdqa         ymm7, [p_src + 7 * i_srcstride]
    vpackuswb       ymm0, ymm0, ymm1
    vextracti128    xmm1, ymm0, 1
    vpsllq          xmm1, xmm1, 56
    vmovlps         [p_dst + 1], xmm1
    vmovlps         [p_dst], xmm0
    add             p_dst, i_dststride
    vmovhps         [p_dst + 1], xmm1
    vmovhps         [p_dst], xmm0
    add             p_dst, i_dststride
    AVX2_FilterVerticalw_16px ymm2, ymm3, ymm4, ymm5, ymm6, ymm7, ymm0
    vmovdqa         ymm0, [p_src + 8 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm3, ymm4, ymm5, ymm6, ymm7, ymm0, ymm1
    vpackuswb       ymm2, ymm2, ymm3
    vextracti128    xmm3, ymm2, 1
    vpsllq          xmm3, xmm3, 56
    vmovlps         [p_dst + 1], xmm3
    vmovlps         [p_dst], xmm2
    add             p_dst, i_dststride
    vmovhps         [p_dst + 1], xmm3
    vmovhps         [p_dst], xmm2
    add             p_dst, i_dststride
    vmovdqa         ymm1, [p_src + 9 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm4, ymm5, ymm6, ymm7, ymm0, ymm1, ymm2
    vmovdqa         ymm2, [p_src + 10 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm5, ymm6, ymm7, ymm0, ymm1, ymm2, ymm3
    vmovdqa         ymm3, [p_src + 11 * i_srcstride]
    vpackuswb       ymm4, ymm4, ymm5
    vextracti128    xmm5, ymm4, 1
    vpsllq          xmm5, xmm5, 56
    vmovlps         [p_dst + 1], xmm5
    vmovlps         [p_dst], xmm4
    cmp             i_height, 4
    jle             .done
    add             p_dst, i_dststride
    vmovhps         [p_dst + 1], xmm5
    vmovhps         [p_dst], xmm4
    add             p_dst, i_dststride
    AVX2_FilterVerticalw_16px ymm6, ymm7, ymm0, ymm1, ymm2, ymm3, ymm4
    vmovdqa         ymm4, [p_src + 12 * i_srcstride]
    add             p_src, 8 * i_srcstride
    AVX2_FilterVerticalw_16px ymm7, ymm0, ymm1, ymm2, ymm3, ymm4, ymm5
    vpackuswb       ymm6, ymm6, ymm7
    vextracti128    xmm7, ymm6, 1
    vpsllq          xmm7, xmm7, 56
    vmovlps         [p_dst + 1], xmm7
    vmovlps         [p_dst], xmm6
    add             p_dst, i_dststride
    vmovhps         [p_dst + 1], xmm7
    vmovhps         [p_dst], xmm6
    add             p_dst, i_dststride
    sub             i_height, 8
    jg              .height_loop
    vmovdqa         ymm5, [p_src + 5 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm0, ymm1, ymm2, ymm3, ymm4, ymm5, ymm6
    vpackuswb       ymm0, ymm0, ymm0
    vextracti128    xmm1, ymm0, 1
    vpsllq          xmm1, xmm1, 56
    vmovlps         [p_dst + 1], xmm1
    vmovlps         [p_dst], xmm0
.done:
    vzeroupper
    POP_XMM
    LOAD_4_PARA_POP
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_dststride
%undef i_height


;*******************************************************************************
; void McHorVer20Width17U8ToS16_avx2(const uint8_t *pSrc,
;                                    int32_t iSrcStride,
;                                    int16_t *pDst,
;                                    int32_t iHeight);
;*******************************************************************************

WELS_EXTERN McHorVer20Width17U8ToS16_avx2
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_height     r3
%define i_srcstride3 r4
%define i_dststride  64
    %assign  push_num 0
%ifdef X86_32
    push            r4
    %assign  push_num 1
%endif
    LOAD_4_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    sub             p_src, i_srcstride
    sub             p_src, i_srcstride
    lea             i_srcstride3, [3 * i_srcstride]
%ifdef X86_32_PICASM
    push            r5
    mov             r5, esp
    and             esp, 0xffffffe0
    push            0x090a0809        ;shufb_32435465768798A9
    push            0x07080607
    push            0x05060405
    push            0x03040203
    vbroadcasti128  ymm5, [esp]
    push            0x0c0b0b0a
    push            0x06050504
    push            0x08070706
    push            0x02010100
    vbroadcasti128  ymm6, [esp]
    push            0x01fb01fb
    push            0xfb01fb01
    push            0x01fb01fb
    push            0xfb01fb01
    vbroadcasti128  ymm7, [esp]
    sub             esp, 16
    push            0x0000fe0a    ;maddubsw_m2p10_m40m40_p10m2_p0p0_256
    push            0xd8d80afe
    push            0x0000fe0a
    push            0xd8d80afe
    push            0x0000fe0a
    push            0xd8d80afe
    push            0x0000fe0a
    push            0xd8d80afe
    push            0x80008000    ;dwm32768_256
    push            0x80008000
    push            0x80008000
    push            0x80008000
    push            0x80008000
    push            0x80008000
    push            0x80008000
    push            0x80008000
%else
    vbroadcasti128  ymm5, [shufb_32435465768798A9]
    vbroadcasti128  ymm6, [shufb_011267784556ABBC]
    vbroadcasti128  ymm7, [maddubsw_p1m5_p1m5_m5p1_m5p1_128]
%endif
    sub             i_height, 3
.yloop:
    vmovdqu         xmm0, [p_src - 2]
    vmovdqu         xmm3, [p_src + 6]
    vinserti128     ymm0, ymm0, [p_src + i_srcstride - 2], 1
    vinserti128     ymm3, ymm3, [p_src + i_srcstride + 6], 1
    vmovdqa         ymm4, ymm3
    AVX2_FilterHorizontalbw_16px ymm0, ymm5, ymm6, ymm7, ymm1, ymm2
    vmovdqa         [p_dst], xmm0
    vextracti128    [p_dst + i_dststride], ymm0, 1
    AVX2_FilterHorizontalbw_16px ymm3, ymm5, ymm6, ymm7, ymm1, ymm2
    vmovdqu         xmm1, [p_src + 2 * i_srcstride - 2]
    vmovdqu         xmm0, [p_src + 2 * i_srcstride + 6]
    vinserti128     ymm1, ymm1, [p_src + i_srcstride3 - 2], 1
    vinserti128     ymm0, ymm0, [p_src + i_srcstride3 + 6], 1
    lea             p_src, [p_src + 4 * i_srcstride]
    vpunpckhqdq     ymm4, ymm4, ymm0
%ifdef X86_32_PICASM
    vpmaddubsw      ymm4, ymm4, [esp+32]
    vpmaddwd        ymm4, ymm4, [esp]
    vpshufd         ymm2, ymm4, 10110001b
    vpaddd          ymm4, ymm4, ymm2
%else
    AVX2_FilterHorizontalbw_4px ymm4, [dwm32768_256], ymm2
%endif
    vmovlps         [p_dst + 26], xmm4
    vmovdqa         [p_dst + 16], xmm3
    vextracti128    xmm2, ymm4, 1
    vmovlps         [p_dst + i_dststride + 26], xmm2
    vextracti128    [p_dst + i_dststride + 16], ymm3, 1
    vmovhps         [p_dst + 2 * i_dststride + 26], xmm4
    AVX2_FilterHorizontalbw_16px ymm1, ymm5, ymm6, ymm7, ymm3, ymm4
    vmovdqa         [p_dst + 2 * i_dststride], xmm1
    AVX2_FilterHorizontalbw_16px ymm0, ymm5, ymm6, ymm7, ymm3, ymm4
    vmovdqa         [p_dst + 2 * i_dststride + 16], xmm0
    vextracti128    [p_dst + 3 * i_dststride], ymm1, 1
    vmovhps         [p_dst + 3 * i_dststride + 26], xmm2
    vextracti128    [p_dst + 3 * i_dststride + 16], ymm0, 1
    add             p_dst, 4 * i_dststride
    sub             i_height, 4
    jg              .yloop
    ; Handle remaining 2 lines after 4x unrolled loop.
    vmovdqu         xmm0, [p_src - 2]
    vinserti128     ymm0, ymm0, [p_src + 6], 1
    vmovdqu         xmm3, [p_src + i_srcstride - 2]
    vinserti128     ymm3, ymm3, [p_src + i_srcstride + 6], 1
    vpunpckhqdq     ymm4, ymm0, ymm3
%ifdef X86_32_PICASM
    vpmaddubsw      ymm4, ymm4, [esp+32]
    vpmaddwd        ymm4, ymm4, [esp]
    vpshufd         ymm2, ymm4, 10110001b
    vpaddd          ymm4, ymm4, ymm2
    mov             esp, r5
    pop             r5
%else
    AVX2_FilterHorizontalbw_4px ymm4, [dwm32768_256], ymm2
%endif
    AVX2_FilterHorizontalbw_16px ymm0, ymm5, ymm6, ymm7, ymm1, ymm2
    AVX2_FilterHorizontalbw_16px ymm3, ymm5, ymm6, ymm7, ymm1, ymm2
    vextracti128    xmm4, ymm4, 1
    vmovlps         [p_dst + 26], xmm4
    vmovdqa         [p_dst], ymm0
    vmovhps         [p_dst + i_dststride + 26], xmm4
    vmovdqa         [p_dst + i_dststride], ymm3
    vzeroupper
    POP_XMM
    LOAD_4_PARA_POP
%ifdef X86_32
    pop             r4
%endif
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_dststride
%undef i_height
%undef i_srcstride3


;***********************************************************************
; void McHorVer02Width16Or17S16ToU8_avx2(const int16_t *pSrc,
;                                        int32_t iSrcStride,
;                                        uint8_t *pDst,
;                                        int32_t iDstStride,
;                                        int32_t iWidth,
;                                        int32_t iHeight);
;***********************************************************************

WELS_EXTERN McHorVer02Width16Or17S16ToU8_avx2
%define p_src        r0
%define i_srcstride  r1
%define p_dst        r2
%define i_dststride  r3
%define i_width      r4
%define i_height     r5
%define i_srcstride3 r6
    %assign  push_num 0
%ifdef X86_32
    push            r6
    %assign  push_num 1
%endif
    LOAD_6_PARA
    PUSH_XMM 8
    SIGN_EXTENSION  r1, r1d
    SIGN_EXTENSION  r3, r3d
    SIGN_EXTENSION  r4, r4d
    SIGN_EXTENSION  r5, r5d
    sub             i_height, 1
    lea             i_srcstride3, [3 * i_srcstride]
    test            i_width, 1
    jz              .align_begin
    push            i_height
    push            p_src
    push            p_dst
    lea             p_src, [p_src + 2 * i_width - 2]
    add             p_dst, i_width
    vmovd           xmm0, [p_src]
    vpunpcklwd      xmm0, xmm0, [p_src + i_srcstride]
    vmovd           xmm1, [p_src + 2 * i_srcstride]
    add             p_src, i_srcstride3
    vpunpcklwd      xmm1, xmm1, [p_src]
    vpunpckldq      xmm0, xmm0, xmm1
    vmovd           xmm1, [p_src + i_srcstride]
    vpunpcklwd      xmm1, xmm1, [p_src + 2 * i_srcstride]
    vmovd           xmm2, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    vpunpcklwd      xmm2, xmm2, [p_src]
    vpunpckldq      xmm1, xmm1, xmm2
    vpunpcklqdq     xmm0, xmm0, xmm1
.height_loop_unalign:
    vmovd           xmm1, [p_src + i_srcstride]
    vpalignr        xmm1, xmm1, xmm0, 2
    vmovd           xmm2, [p_src + 2 * i_srcstride]
    vpalignr        xmm2, xmm2, xmm1, 2
    vmovd           xmm3, [p_src + i_srcstride3]
    vpalignr        xmm3, xmm3, xmm2, 2
    lea             p_src, [p_src + 4 * i_srcstride]
    vmovd           xmm4, [p_src]
    vpalignr        xmm4, xmm4, xmm3, 2
    vmovd           xmm5, [p_src + i_srcstride]
    vpalignr        xmm5, xmm5, xmm4, 2
    AVX2_FilterVerticalw_16px xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm7
    vpackuswb       xmm0, xmm0, xmm0
    vpslld          xmm6, xmm0, 24
    vmovd           [p_dst - 4], xmm6
    vmovlps         [p_dst + 4 * i_dststride - 8], xmm6
    add             p_dst, i_dststride
    vpslld          xmm6, xmm0, 16
    vmovd           [p_dst - 4], xmm6
    vmovlps         [p_dst + 4 * i_dststride - 8], xmm6
    add             p_dst, i_dststride
    vpslld          xmm6, xmm0, 8
    vmovd           [p_dst - 4], xmm6
    vmovd           [p_dst + i_dststride - 4], xmm0
    lea             p_dst, [p_dst + 4 * i_dststride]
    vmovlps         [p_dst - 8], xmm6
    vmovlps         [p_dst + i_dststride - 8], xmm0
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_height, 8
    jle             .height_loop_unalign_exit
    vmovd           xmm1, [p_src + 2 * i_srcstride]
    vpalignr        xmm1, xmm1, xmm5, 2
    vmovd           xmm0, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    vpunpcklwd      xmm0, xmm0, [p_src]
    vpalignr        xmm0, xmm0, xmm1, 4
    jmp             .height_loop_unalign
.height_loop_unalign_exit:
    vpbroadcastq    xmm6, [p_src + 2 * i_srcstride - 6]
    AVX2_FilterVerticalw_16px xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7
    vpackuswb       xmm1, xmm1, xmm1
    vmovlps         [p_dst - 8], xmm1
    pop             p_dst
    pop             p_src
    pop             i_height
.align_begin:
    vmovdqa         ymm0, [p_src]
    vmovdqa         ymm1, [p_src + i_srcstride]
    vmovdqa         ymm2, [p_src + 2 * i_srcstride]
    vmovdqa         ymm3, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    vmovdqa         ymm4, [p_src]
.height_loop:
    vmovdqa         ymm5, [p_src + i_srcstride]
    AVX2_FilterVerticalw_16px ymm0, ymm1, ymm2, ymm3, ymm4, ymm5, ymm6
    vmovdqa         ymm6, [p_src + 2 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm1, ymm2, ymm3, ymm4, ymm5, ymm6, ymm7
    vmovdqa         ymm7, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    vpackuswb       ymm0, ymm0, ymm1
    vpermq          ymm0, ymm0, 11011000b
    vmovdqa         [p_dst], xmm0
    vextracti128    [p_dst + i_dststride], ymm0, 1
    lea             p_dst, [p_dst + 2 * i_dststride]
    AVX2_FilterVerticalw_16px ymm2, ymm3, ymm4, ymm5, ymm6, ymm7, ymm0
    vmovdqa         ymm0, [p_src]
    AVX2_FilterVerticalw_16px ymm3, ymm4, ymm5, ymm6, ymm7, ymm0, ymm1
    vpackuswb       ymm2, ymm2, ymm3
    vpermq          ymm2, ymm2, 11011000b
    vmovdqa         [p_dst], xmm2
    vextracti128    [p_dst + i_dststride], ymm2, 1
    lea             p_dst, [p_dst + 2 * i_dststride]
    vmovdqa         ymm1, [p_src + i_srcstride]
    AVX2_FilterVerticalw_16px ymm4, ymm5, ymm6, ymm7, ymm0, ymm1, ymm2
    vmovdqa         ymm2, [p_src + 2 * i_srcstride]
    AVX2_FilterVerticalw_16px ymm5, ymm6, ymm7, ymm0, ymm1, ymm2, ymm3
    vmovdqa         ymm3, [p_src + i_srcstride3]
    lea             p_src, [p_src + 4 * i_srcstride]
    vpackuswb       ymm4, ymm4, ymm5
    vpermq          ymm4, ymm4, 11011000b
    vmovdqa        [p_dst], xmm4
    vextracti128   [p_dst + i_dststride], ymm4, 1
    lea             p_dst, [p_dst + 2 * i_dststride]
    AVX2_FilterVerticalw_16px ymm6, ymm7, ymm0, ymm1, ymm2, ymm3, ymm4
    vmovdqa         ymm4, [p_src]
    AVX2_FilterVerticalw_16px ymm7, ymm0, ymm1, ymm2, ymm3, ymm4, ymm5
    vpackuswb       ymm6, ymm6, ymm7
    vpermq          ymm6, ymm6, 11011000b
    vmovdqa         [p_dst], xmm6
    vextracti128    [p_dst + i_dststride], ymm6, 1
    lea             p_dst, [p_dst + 2 * i_dststride]
    sub             i_height, 8
    jg              .height_loop
    jl              .done
    vmovdqa         ymm5, [p_src + i_srcstride]
    AVX2_FilterVerticalw_16px ymm0, ymm1, ymm2, ymm3, ymm4, ymm5, ymm6
    vpackuswb       ymm0, ymm0, ymm0
    vpermq          ymm0, ymm0, 11011000b
    vmovdqa         [p_dst], xmm0
.done:
    vzeroupper
    POP_XMM
    LOAD_6_PARA_POP
%ifdef X86_32
    pop             r6
%endif
    ret
%undef p_src
%undef i_srcstride
%undef p_dst
%undef i_dststride
%undef i_width
%undef i_height
%undef i_srcstride3

%endif ; HAVE_AVX2
