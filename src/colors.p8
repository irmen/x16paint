%import textio

colors {
    const ubyte PALETTE_BOX_ROW = 15
    const ubyte PALETTE_BOX_COL = 3
    bool active = false

    sub show() {
        active = true
        draw()
        main.enable_text_layer()
        cx16.VERA_L1_CONFIG |= %00001000     ; enable T256C mode for the text layer so we can show all 256 colors
    }

    sub hide() {
        active = false
        main.disable_text_layer()
        cx16.VERA_L1_CONFIG &= %11110111     ; disable T256C mode again
        txt.color2(1,0)
        txt.clear_screen()
    }

    sub mouse(ubyte buttons, uword mx, uword my) {
        if buttons==0 or not active
            return
        if mx>=(PALETTE_BOX_COL+1)*8 and mx<(PALETTE_BOX_COL+33)*8 and my>=(PALETTE_BOX_ROW+4)*8 and my<(PALETTE_BOX_ROW+12)*8 {
            ; palette clicked
            mx = (mx-(PALETTE_BOX_COL+1)*8)/8
            my = (my-(PALETTE_BOX_ROW+4)*8)/8
            ubyte color = lsb(my)*32+lsb(mx)
            when buttons {
                1 -> drawing.selected_color1 = color
                2 -> drawing.selected_color2 = color
            }
            draw_selected_colors()
        }
    }
    
    sub draw() {
        txt.color2(14,0)
        txt.clear_screen()
        menu.outline(PALETTE_BOX_COL, PALETTE_BOX_ROW, 33, 12, "Palette")
        txt.color2(14,0)
        txt.plot(PALETTE_BOX_COL+2, PALETTE_BOX_ROW+2)
        txt.print("Color1:")
        txt.plot(PALETTE_BOX_COL+15, PALETTE_BOX_ROW+2)
        txt.print("Color2:")
        draw_selected_colors()

        ubyte row
        ubyte col
        cx16.r0L = 0
        for row in PALETTE_BOX_ROW+4 to PALETTE_BOX_ROW+11 {
            for col in PALETTE_BOX_COL+1 to PALETTE_BOX_COL+32 {
                txt.setcc2(col, row, 160, cx16.r0L)
                cx16.r0L++
            }
        }
        txt.setcc2(PALETTE_BOX_COL+1, PALETTE_BOX_ROW+4, sc:'▒', 255)       ; the 'transparent' color zero
    }

    sub draw_selected_colors() {
        if drawing.selected_color1==0 {
            txt.setcc2(PALETTE_BOX_COL+9, PALETTE_BOX_ROW+2, sc:'▒', 255)
            txt.setcc2(PALETTE_BOX_COL+10, PALETTE_BOX_ROW+2, sc:'▒', 255)
        } else {
            txt.setcc2(PALETTE_BOX_COL+9, PALETTE_BOX_ROW+2, 160, drawing.selected_color1)
            txt.setcc2(PALETTE_BOX_COL+10, PALETTE_BOX_ROW+2, 160, drawing.selected_color1)
        }
        txt.plot(PALETTE_BOX_COL+11, PALETTE_BOX_ROW+2)
        txt.print_ub0(drawing.selected_color1)
        if drawing.selected_color2==0 {
            txt.setcc2(PALETTE_BOX_COL+22, PALETTE_BOX_ROW+2, sc:'▒', 255)
            txt.setcc2(PALETTE_BOX_COL+23, PALETTE_BOX_ROW+2, sc:'▒', 255)
        } else {
            txt.setcc2(PALETTE_BOX_COL+22, PALETTE_BOX_ROW+2, 160, drawing.selected_color2)
            txt.setcc2(PALETTE_BOX_COL+23, PALETTE_BOX_ROW+2, 160, drawing.selected_color2)
        }
        txt.plot(PALETTE_BOX_COL+24, PALETTE_BOX_ROW+2)
        txt.print_ub0(drawing.selected_color2)
    }
}