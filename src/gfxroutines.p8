; 320*240 256C bitmap graphics routines, based on gfx2 library module.

; NOTE: can't really use the kernal graphics routines because we need to be able
;       to draw non-destructively by EORing the color.

gfx {
    ; read-only control variables:
    ; fixed screen mode 320x240x256C
    const uword width = 320
    const uword height = 240
    const ubyte bpp = 8

    bool eor_mode

    sub init() {
        eor_mode = false
        void cx16.screen_mode(128, false)
        clear_screen(1, 0)
    }

    sub clear_screen(ubyte col1, ubyte col2) {
        cx16.GRAPH_set_colors(col1,0,col2)
        cx16.GRAPH_clear()
    }

    sub rect(uword xx, ubyte yy, uword rwidth, ubyte rheight, ubyte color) {
        if rwidth==0 or rheight==0
            return
        horizontal_line(xx, yy, rwidth, color)
        if rheight==1
            return
        horizontal_line(xx, yy+rheight-1, rwidth, color)
        vertical_line(xx, yy+1, rheight-2, color)
        if rwidth==1
            return
        vertical_line(xx+rwidth-1, yy+1, rheight-2, color)
    }

    sub fillrect(uword xx, ubyte yy, uword rwidth, ubyte rheight, ubyte color) {
        ; Draw a filled rectangle of the given size and color.
        ; To fill the whole screen, use clear_screen(color) instead - it is much faster.
        if rwidth==0
            return
        repeat rheight {
            horizontal_line(xx, yy, rwidth, color)
            yy++
        }
    }

    sub horizontal_line(uword xx, ubyte yy, uword length, ubyte color) {
        if length==0
            return
        position(xx, yy)
        if eor_mode {
            cx16.vaddr_clone(0)      ; also setup port 1, for reading
            %asm {{
                ldx  p8v_length+1
                beq  +
                ldy  #0
-               lda  p8v_color
                eor  cx16.VERA_DATA1
                sta  cx16.VERA_DATA0
                iny
                bne  -
                dex
                bne  -
+               ldy  p8v_length     ; remaining
                beq  +
-               lda  p8v_color
                eor  cx16.VERA_DATA1
                sta  cx16.VERA_DATA0
                dey
                bne  -
+
            }}
        } else {
            %asm {{
                lda  p8v_color
                ldx  p8v_length+1
                beq  +
                ldy  #0
-               sta  cx16.VERA_DATA0
                iny
                bne  -
                dex
                bne  -
+               ldy  p8v_length     ; remaining
                beq  +
-               sta  cx16.VERA_DATA0
                dey
                bne  -
+
            }}
        }
    }

    sub safe_horizontal_line(uword xx, uword yy, uword length, ubyte color) {
        ; does bounds checking and clipping
        if msb(yy)&$80!=0 or yy>=height
            return
        if msb(xx)&$80!=0 {
            length += xx
            xx = 0
        }
        if xx>=width
            return
        if xx+length>width
            length = width-xx
        if length>width
            return

        horizontal_line(xx, lsb(yy), length, color)
    }

    sub vertical_line(uword xx, ubyte yy, uword lheight, ubyte color) {
        ; set vera auto-increment to 320 pixel increment (=next line)
        position(xx,yy)
        cx16.VERA_ADDR_H = cx16.VERA_ADDR_H & %00000111 | (14<<4)
        if eor_mode {
            cx16.vaddr_clone(0)      ; also setup port 1, for reading
            %asm {{
                ldy  p8v_lheight
                beq  +
-               lda  p8v_color
                eor  cx16.VERA_DATA1
                sta  cx16.VERA_DATA0
                dey
                bne  -
+
            }}
        } else {
            %asm {{
                ldy  p8v_lheight
                beq  +
                lda  p8v_color
-               sta  cx16.VERA_DATA0
                dey
                bne  -
+
            }}
        }
    }

    sub line(uword @zp x1, uword @zp y1, uword @zp x2, uword @zp y2, ubyte color) {
        ; Bresenham algorithm.
        ; This code special-cases various quadrant loops to allow simple ++ and -- operations.
        if y1>y2 {
            ; make sure dy is always positive to have only 4 instead of 8 special cases
            cx16.r0 = x1
            x1 = x2
            x2 = cx16.r0
            cx16.r0 = y1
            y1 = y2
            y2 = cx16.r0
        }
        word @zp dx = (x2 as word)-x1
        word @zp dy = (y2 as word)-y1

        if dx==0 {
            vertical_line(x1, lsb(y1), abs(dy) as uword +1, color)
            return
        }
        if dy==0 {
            if x1>x2
                x1=x2
            horizontal_line(x1, lsb(y1), abs(dx) as uword +1, color)
            return
        }

        word @zp d = 0
        cx16.r1L = 1 ;; true      ; 'positive_ix'
        if dx < 0 {
            dx = -dx
            cx16.r1L = 0 ;; false
        }
        word @zp dx2 = dx*2
        word @zp dy2 = dy*2
        cx16.r14 = x1       ; internal plot X

        if dx >= dy {
            if cx16.r1L!=0 {
                repeat {
                    plot(cx16.r14, lsb(y1), color)
                    if cx16.r14==x2
                        return
                    cx16.r14++
                    d += dy2
                    if d > dx {
                        y1++
                        d -= dx2
                    }
                }
            } else {
                repeat {
                    plot(cx16.r14, lsb(y1), color)
                    if cx16.r14==x2
                        return
                    cx16.r14--
                    d += dy2
                    if d > dx {
                        y1++
                        d -= dx2
                    }
                }
            }
        }
        else {
            if cx16.r1L!=0 {
                repeat {
                    plot(cx16.r14, lsb(y1), color)
                    if y1 == y2
                        return
                    y1++
                    d += dx2
                    if d > dy {
                        cx16.r14++
                        d -= dy2
                    }
                }
            } else {
                repeat {
                    plot(cx16.r14, lsb(y1), color)
                    if y1 == y2
                        return
                    y1++
                    d += dx2
                    if d > dy {
                        cx16.r14--
                        d -= dy2
                    }
                }
            }
        }
    }

    sub safe_circle(uword @zp xcenter, uword @zp ycenter, ubyte radius, ubyte color) {
        ; This version does bounds checks and clipping, but is a lot slower.
        ; Midpoint algorithm.
        if radius==0
            return

        ubyte @zp xx = radius
        ubyte @zp yy = 0
        word @zp decisionOver2 = (1 as word)-xx
        ; R14 = internal plot X
        ; R15 = internal plot Y

        while xx>=yy {
            cx16.r14 = xcenter + xx
            cx16.r15 = ycenter + yy
            plotq()
            cx16.r14 = xcenter - xx
            plotq()
            cx16.r14 = xcenter + xx
            cx16.r15 = ycenter - yy
            plotq()
            cx16.r14 = xcenter - xx
            plotq()
            cx16.r14 = xcenter + yy
            cx16.r15 = ycenter + xx
            plotq()
            cx16.r14 = xcenter - yy
            plotq()
            cx16.r14 = xcenter + yy
            cx16.r15 = ycenter - xx
            plotq()
            cx16.r14 = xcenter - yy
            plotq()

            yy++
            if decisionOver2>=0 {
                xx--
                decisionOver2 -= xx*$0002
            }
            decisionOver2 += yy*$0002
            decisionOver2++
        }

        sub plotq() {
            ; cx16.r14 = x, cx16.r15 = y, color=color.
            safe_plot(cx16.r14, cx16.r15, color)
        }
    }

    sub safe_disc(uword @zp xcenter, uword @zp ycenter, ubyte @zp radius, ubyte color) {
        ; This version does bounds checks and clipping, but is a lot slower.
        ; Midpoint algorithm, filled
        if radius==0
            return
        ubyte @zp yy = 0
        word @zp decisionOver2 = (1 as word)-radius

        while radius>=yy {
            safe_horizontal_line(xcenter-radius, ycenter+yy, radius*$0002+1, color)
            safe_horizontal_line(xcenter-radius, ycenter-yy, radius*$0002+1, color)
            safe_horizontal_line(xcenter-yy, ycenter+radius, yy*$0002+1, color)
            safe_horizontal_line(xcenter-yy, ycenter-radius, yy*$0002+1, color)
            yy++
            if decisionOver2>=0 {
                radius--
                decisionOver2 -= radius*$0002
            }
            decisionOver2 += yy*$0002
            decisionOver2++
        }
    }

    sub plot(uword @zp xx, ubyte @zp yy, ubyte @zp color) {
        void addr_mul_24_for_lores_256c(yy, xx)      ; 24 bits result is in r0 and r1L (highest byte)
        %asm {{
            stz  cx16.VERA_CTRL
            lda  cx16.r1
            sta  cx16.VERA_ADDR_H
            lda  cx16.r0+1
            sta  cx16.VERA_ADDR_M
            lda  cx16.r0
            sta  cx16.VERA_ADDR_L
            lda  p8v_eor_mode
            bne  +
            lda  p8v_color
            sta  cx16.VERA_DATA0
            rts
+           lda  p8v_color
            eor  cx16.VERA_DATA0
            sta  cx16.VERA_DATA0
            rts
        }}
    }

    sub safe_plot(uword xx, uword yy, ubyte color) {
        ; A plot that does bounds checks to see if the pixel is inside the screen.
        if msb(xx)&$80!=0 or msb(yy)&$80!=0
            return
        if xx >= width or yy >= height
            return
        plot(xx, lsb(yy), color)
    }

    sub pget(uword @zp xx, ubyte yy) -> ubyte {
        void addr_mul_24_for_lores_256c(yy, xx)      ; 24 bits result is in r0 and r1L (highest byte)
        %asm {{
            stz  cx16.VERA_CTRL
            lda  cx16.r1
            sta  cx16.VERA_ADDR_H
            lda  cx16.r0+1
            sta  cx16.VERA_ADDR_M
            lda  cx16.r0
            sta  cx16.VERA_ADDR_L
            lda  cx16.VERA_DATA0
            sta  cx16.r0L
        }}
        return cx16.r0L
    }

    sub fill(uword x, ubyte y, ubyte new_color) {
        ; Non-recursive scanline flood fill.
        ; based loosely on code found here https://www.codeproject.com/Articles/6017/QuickFill-An-efficient-flood-fill-algorithm
        ; with the fixes applied to the seedfill_4 routine as mentioned in the comments.
        const ubyte MAXDEPTH = 64
        word @zp xx = x as word
        word @zp yy = y as word
        word[MAXDEPTH] @split @shared stack_xl
        word[MAXDEPTH] @split @shared stack_xr
        word[MAXDEPTH] @split @shared stack_y
        byte[MAXDEPTH] @shared stack_dy
        cx16.r12L = 0       ; stack pointer
        word x1
        word x2
        byte dy
        cx16.r10L = new_color
        sub push_stack(word sxl, word sxr, word sy, byte sdy) {
            if cx16.r12L==MAXDEPTH
                return
            cx16.r0s = sy+sdy
            if cx16.r0s>=0 and cx16.r0s<=height-1 {
;;                stack_xl[cx16.r12L] = sxl
;;                stack_xr[cx16.r12L] = sxr
;;                stack_y[cx16.r12L] = sy
;;                stack_dy[cx16.r12L] = sdy
;;                cx16.r12L++
                %asm {{
                    ldy  cx16.r12L
                    lda  p8v_sxl
                    sta  p8v_stack_xl_lsb,y
                    lda  p8v_sxl+1
                    sta  p8v_stack_xl_msb,y
                    lda  p8v_sxr
                    sta  p8v_stack_xr_lsb,y
                    lda  p8v_sxr+1
                    sta  p8v_stack_xr_msb,y
                    lda  p8v_sy
                    sta  p8v_stack_y_lsb,y
                    lda  p8v_sy+1
                    sta  p8v_stack_y_msb,y
                    ldy  cx16.r12L
                    lda  p8v_sdy
                    sta  p8v_stack_dy,y
                    inc  cx16.r12L
                }}
            }
        }
        sub pop_stack() {
;;            cx16.r12L--
;;            x1 = stack_xl[cx16.r12L]
;;            x2 = stack_xr[cx16.r12L]
;;            y = stack_y[cx16.r12L]
;;            dy = stack_dy[cx16.r12L]
            %asm {{
                dec  cx16.r12L
                ldy  cx16.r12L
                lda  p8v_stack_xl_lsb,y
                sta  p8v_x1
                lda  p8v_stack_xl_msb,y
                sta  p8v_x1+1
                lda  p8v_stack_xr_lsb,y
                sta  p8v_x2
                lda  p8v_stack_xr_msb,y
                sta  p8v_x2+1
                lda  p8v_stack_y_lsb,y
                sta  p8v_yy
                lda  p8v_stack_y_msb,y
                sta  p8v_yy+1
                ldy  cx16.r12L
                lda  p8v_stack_dy,y
                sta  p8v_dy
            }}
            yy+=dy
        }
        cx16.r11L = pget(xx as uword, lsb(yy))        ; old_color
        if cx16.r11L == cx16.r10L
            return
        if xx<0 or xx>width-1 or yy<0 or yy>height-1
            return
        push_stack(xx, xx, yy, 1)
        push_stack(xx, xx, yy + 1, -1)
        word left = 0
        while cx16.r12L!=0 {
            pop_stack()
            xx = x1
            ; TODO: if mode==1 (256c) use vera autodecrement instead of pget(), but code bloat not worth it?
            while xx >= 0 {
                if pget(xx as uword, lsb(yy)) != cx16.r11L
                    break
                xx--
            }
            if x1!=xx
                horizontal_line(xx as uword+1, lsb(yy), x1-xx as uword, cx16.r10L)
            else
                goto skip

            left = xx + 1
            if left < x1
                push_stack(left, x1 - 1, yy, -dy)
            xx = x1 + 1

            do {
                cx16.r9s = xx
                ; TODO: if mode==1 (256c) use vera autoincrement instead of pget(), but code bloat not worth it?
                while xx <= width-1 {
                    if pget(xx as uword, lsb(yy)) != cx16.r11L
                        break
                    xx++
                }
                if cx16.r9s!=xx
                    horizontal_line(cx16.r9, yy as ubyte, xx-cx16.r9s as uword, cx16.r10L)

                push_stack(left, xx - 1, yy, dy)
                if xx > x2 + 1
                    push_stack(x2 + 1, xx - 1, yy, -dy)
skip:
                xx++
                while xx <= x2 {
                    if pget(xx as uword, lsb(yy)) == cx16.r11L
                        break
                    xx++
                }
                left = xx
            } until xx>x2
        }
    }

    sub position(uword @zp xx, ubyte yy) {
        void addr_mul_24_for_lores_256c(yy, xx)      ; 24 bits result is in r0 and r1L (highest byte)
        cx16.r2L = cx16.r1L
        cx16.vaddr(cx16.r2L, cx16.r0, 0, 1)
    }

    asmsub addr_mul_24_for_lores_256c(ubyte yy @X, uword xx @AY) clobbers(A) -> uword @R0, ubyte @R1  {
        ; yy * 320 + xx (24 bits calculation)
        %asm {{
            sta  P8ZP_SCRATCH_W1
            sty  P8ZP_SCRATCH_W1+1
            stx  P8ZP_SCRATCH_B1
            stz  cx16.r1
            stz  P8ZP_SCRATCH_REG
            txa
            asl  a
            rol  P8ZP_SCRATCH_REG
            asl  a
            rol  P8ZP_SCRATCH_REG
            asl  a
            rol  P8ZP_SCRATCH_REG
            asl  a
            rol  P8ZP_SCRATCH_REG
            asl  a
            rol  P8ZP_SCRATCH_REG
            asl  a
            rol  P8ZP_SCRATCH_REG
            sta  cx16.r0
            lda  P8ZP_SCRATCH_B1
            clc
            adc  P8ZP_SCRATCH_REG
            sta  cx16.r0+1
            bcc  +
            inc  cx16.r1
+           ; now add the value to this 24-bits number
            lda  cx16.r0
            clc
            adc  P8ZP_SCRATCH_W1
            sta  cx16.r0
            lda  cx16.r0+1
            adc  P8ZP_SCRATCH_W1+1
            sta  cx16.r0+1
            bcc  +
            inc  cx16.r1
+           lda  cx16.r1
            rts
        }}
    }

}
