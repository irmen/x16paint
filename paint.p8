%import syslib
%import gfx2
%import textio
%import string

main {
    bool mouse_button_pressed
    uword mouse_prev_x
    uword mouse_prev_y

    sub start() {
        ; screen mode
        void cx16.screen_mode(128, false)
        cx16.VERA_L1_CONFIG |= %00001000     ; enable T256C mode for the text layer
        cx16.GRAPH_set_colors(1,2,0)
        cx16.GRAPH_clear()
        gfx2.init_mode(1)

        ; mouse
        cx16.mouse_config2(1)
        ; select a different palette offset for the mouse pointer to make it visible on black:
        cx16.vpoke_mask(1, $fc00+7, %11110000, %1011)         ; TODO better mouse pointer?

        ; instructions
        txt.lowercase()
        txt.color(14)
        txt.clear_screen()
        txt.print("\n\n    Commander X16 PAINT\n\n")
        txt.color(11)
        txt.print("    DesertFish ▒ Prog8")
        txt.color(14)
        txt.print("\n\n\n\n    Instructions:\n\n\n")
        txt.print("    - Use the mouse to paint stuff.\n")
        txt.print("      left/right=draw, middle=fill.\n\n")
        txt.print("    - TAB toggles the menus on/off.\n\n\n")
        txt.print("    Click any mouse button to start.")
        while not cx16.mouse_pos() { }
        while cx16.mouse_pos() { }
        menu.toggle()
        menu.draw()

        ; main loop
        repeat {
            handle_mouse()
            handle_keypress()
        }
    }

    sub handle_mouse() {
        ubyte buttons = cx16.mouse_pos()
        if menu.active {
            mouse_button_pressed = false
            menu.mouse(buttons, cx16.r0, cx16.r1)
            return
        }
        if buttons {
            ; handle mouse clicks in draw mode
            if buttons==4 {
                gfx2.fill(cx16.r0, cx16.r1, drawing.selected_color1)
            }
            else if mouse_button_pressed {
                ; draw line to new position
                uword from_x = mouse_prev_x
                uword from_y = mouse_prev_y
                mouse_prev_x = cx16.r0
                mouse_prev_y = cx16.r1
                cx16.GRAPH_set_colors(color_for_button(), 0, 0)
                cx16.GRAPH_draw_line(from_x, from_y, mouse_prev_x, mouse_prev_y)
            } else {
                ; start new position
                mouse_prev_x = cx16.r0
                mouse_prev_y = cx16.r1
                cx16.FB_cursor_position(cx16.r0, cx16.r1)
                cx16.FB_set_pixel(color_for_button())
                mouse_button_pressed = true
            }
        } else {
            mouse_button_pressed = false
        }

        sub color_for_button() -> ubyte {
            when buttons {
                1 -> return drawing.selected_color1
                2 -> return drawing.selected_color2
                else -> return 0
            }
        }
    }

    sub handle_keypress() {
        when cbm.GETIN() {
            9 -> {
                ; TAB = show/hide menus overlay
                menu.toggle()
            }
        }
    }

}

drawing {
    ubyte selected_color1 = 5
    ubyte selected_color2 = 2

    sub clear() {
        cx16.GRAPH_set_colors(selected_color1,0,selected_color2)
        cx16.GRAPH_clear()
    }
}

menu {
    bool active = true
    const ubyte PALETTE_BOX_ROW = 17
    const ubyte PALETTE_BOX_COL = 3

    str[4] commands_names = ["Clear", "Save", "Load", "Quit"]
    uword[4] commands_handlers = [&commands.clear, &commands.save, &commands.load, &commands.quit]
    ubyte[4] commands_x = [26, 26, 26, 26]
    ubyte[4] commands_y = [4, 6, 8, 10]

    str[9] tools_names = ["Draw", "Rectangle", "Circle", "Erase", "Magnify", "Line", "Box", "Disc", "Fill"]
    ubyte[9] tools_x = [6, 6, 6, 6, 6, 17, 18, 17, 17]
    ubyte[9] tools_y = [4, 6, 8, 10, 12, 4, 6, 8, 10]

    sub draw() {
        txt.color(14)
        txt.clear_screen()
        draw_tools()
        draw_commands()
        draw_palette()
    }

    sub draw_tools() {
        outline(3, 2, 20, 14, "Tools")
        txt.color(3)
        for cx16.r0L in 0 to len(tools_names)-1 {
            txt.plot(tools_x[cx16.r0L], tools_y[cx16.r0L])
            txt.print(tools_names[cx16.r0L])
        }
        txt.setcc2(5,4,sc:'✓',7)
    }

    sub draw_commands() {
        outline(24, 2, 12, 14, "Commands")
        txt.color(3)
        for cx16.r0L in 0 to len(commands_names)-1 {
            txt.plot(commands_x[cx16.r0L], commands_y[cx16.r0L])
            txt.print(commands_names[cx16.r0L])
        }
        txt.color(6)
        txt.plot(26,14)
        txt.print("TAB=back")
        txt.plot(27,15)
        txt.print("to image")
    }

    sub draw_palette() {
        outline(PALETTE_BOX_COL, PALETTE_BOX_ROW, 33, 10, "Palette")
        txt.plot(PALETTE_BOX_COL+1, PALETTE_BOX_ROW+1)
        txt.print("Col1:")
        txt.plot(PALETTE_BOX_COL+12, PALETTE_BOX_ROW+1)
        txt.print("Col2:")
        print_selected_colors()

        ubyte row
        ubyte col
        cx16.r0L = 0
        for row in PALETTE_BOX_ROW+2 to PALETTE_BOX_ROW+9 {
            for col in PALETTE_BOX_COL+1 to PALETTE_BOX_COL+32 {
                txt.setcc2(col, row, 160, cx16.r0L)
                cx16.r0L++
            }
        }
        txt.setcc2(PALETTE_BOX_COL+1, PALETTE_BOX_ROW+2, sc:'▒', 255)
    }

    sub outline(ubyte x, ubyte y, ubyte w, ubyte h, str caption) {
        for cx16.r0L in x+1 to x+w-1 {
            txt.setcc2(cx16.r0L, y, sc:'─', 14)
            txt.setcc2(cx16.r0L, y+h, sc:'─', 14)
            for cx16.r1L in y+1 to y+h-1
                txt.setchr(cx16.r0L, cx16.r1L, ' ')
        }
        for cx16.r0L in y+1 to y+h-1 {
            txt.setcc2(x, cx16.r0L, sc:'|', 14)
            txt.setcc2(x+w, cx16.r0L, sc:'|', 14)
        }
        txt.setcc2(x, y, sc:'┌', 14)
        txt.setcc2(x+w, y, sc:'┐', 14)
        txt.setcc2(x, y+h, sc:'└', 14)
        txt.setcc2(x+w, y+h, sc:'┘', 14)
        txt.plot(x+3, y)
        txt.color(15)
        txt.print(caption)
    }

    sub message(str text) {
        cx16.r0L = string.length(text)
        ubyte xpos = 20 - cx16.r0L/2 -3
        outline(xpos, 8, cx16.r0L+3, 6, "Message")
        txt.plot(xpos+2,11)
        txt.color(7)
        txt.print(text)
    }

    sub confirm(str text) -> bool {
        message(text)
        while cbm.GETIN() { }
        repeat {
            when cbm.GETIN() {
                0 -> { }
                'y' -> return true
                else -> return false
            }
        }
    }

    sub print_selected_colors() {
        if drawing.selected_color1==0 {
            txt.setcc2(PALETTE_BOX_COL+6, PALETTE_BOX_ROW+1, sc:'▒', 255)
            txt.setcc2(PALETTE_BOX_COL+7, PALETTE_BOX_ROW+1, sc:'▒', 255)
        } else {
            txt.setcc2(PALETTE_BOX_COL+6, PALETTE_BOX_ROW+1, 160, drawing.selected_color1)
            txt.setcc2(PALETTE_BOX_COL+7, PALETTE_BOX_ROW+1, 160, drawing.selected_color1)
        }
        txt.plot(PALETTE_BOX_COL+8, PALETTE_BOX_ROW+1)
        txt.print_ub0(drawing.selected_color1)
        if drawing.selected_color2==0 {
            txt.setcc2(PALETTE_BOX_COL+17, PALETTE_BOX_ROW+1, sc:'▒', 255)
            txt.setcc2(PALETTE_BOX_COL+18, PALETTE_BOX_ROW+1, sc:'▒', 255)
        } else {
            txt.setcc2(PALETTE_BOX_COL+17, PALETTE_BOX_ROW+1, 160, drawing.selected_color2)
            txt.setcc2(PALETTE_BOX_COL+18, PALETTE_BOX_ROW+1, 160, drawing.selected_color2)
        }
        txt.plot(PALETTE_BOX_COL+19, PALETTE_BOX_ROW+1)
        txt.print_ub0(drawing.selected_color2)
    }

    sub toggle() {
        if active {
            active = false
            cx16.VERA_CTRL = 0
            cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11001111) | %00010000
        } else {
            active = true
            draw()
            cx16.VERA_CTRL = 0
            cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11001111) | %00100000
        }
    }

    sub mouse(ubyte buttons, uword mx, uword my) {
        if buttons==0
            return

        if mx>=(PALETTE_BOX_COL+1)*8 and mx<(PALETTE_BOX_COL+33)*8 and my>=(PALETTE_BOX_ROW+2)*8 and my<(PALETTE_BOX_ROW+10)*8 {
            ; palette clicked
            mx = (mx-(PALETTE_BOX_COL+1)*8)/8
            my = (my-(PALETTE_BOX_ROW+2)*8)/8
            ubyte color = lsb(my)*32+lsb(mx)
            when buttons {
                1 -> drawing.selected_color1 = color
                2 -> drawing.selected_color2 = color
                3 -> {
                    outline(10, 10, 10, 10, "Popup")
                    sys.wait(60)
                }
            }
            print_selected_colors()
            return
        }

        if buttons!=1
            return      ; only support left mouse button to click menu entries

        if mx >= commands_x[0]*8 {
            ; possibly command clicked
            for cx16.r0L in 0 to len(commands_names)-1 {
                cx16.r1 = commands_x[cx16.r0L]*8
                cx16.r2 = commands_y[cx16.r0L]*8
                cx16.r3 = cx16.r1 + string.length(commands_names[cx16.r0L])*8
                if mx>=cx16.r1 and my>=cx16.r2 and mx<cx16.r3 and my<(cx16.r2+8) {
                    void callfar(cx16.getrambank(), commands_handlers[cx16.r0L], 0)       ; indirect JSR
                    return
                }
            }
        } else if mx >= tools_x[0]*8 {
            ; possibly tool clicked
        }
    }
}

commands {
    sub clear() {
        if menu.confirm("Clear image. Sure Y/N?") {
            drawing.clear()
            menu.message("Cleared with Col.2")
            sys.wait(60)
        }
        menu.draw()
    }

    sub save() {
        menu.message("SAVE not yet implemented")     ; TODO
        sys.wait(100)
        menu.draw()
    }

    sub load() {
        menu.message("LOAD not yet implemented")     ; TODO
        sys.wait(100)
        menu.draw()
    }

    sub quit() {
        if menu.confirm("Quit program. Sure Y/N?") {
            void cx16.screen_mode(0, false)
            cx16.VERA_L1_CONFIG &= %11110111     ; disable T256C mode for the text layer
            sys.exit(0)
        } else {
            menu.draw()
        }
    }
}
