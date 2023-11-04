%import syslib
%import gfx2
%import textio
%import palette
%option no_sysinit

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
}

menu {
    bool active = true

    sub draw() {
        txt.color2(14,0)
        txt.clear_screen()
        txt.plot(2,2)
        txt.print("Menu Layer")

        ubyte row
        ubyte col

        ; draw the palette box
        for col in 1 to 39 {
            txt.setchr(col, 20, sc:'─')
            txt.setchr(col, 29, sc:'─')
        }
        for row in 21 to 28 {
            txt.setchr(0, row, sc:'|')
            txt.setchr(39, row, sc:'|')
        }
        txt.setchr(0, 20, sc:'┌')
        txt.setchr(39, 20, sc:'┐')
        txt.setchr(0, 29, sc:'└')
        txt.setchr(39, 29, sc:'┘')
        txt.plot(3, 20)
        txt.print("Palette")
        txt.plot(34, 21)
        txt.print("Col1:")
        txt.plot(34, 23)
        txt.print("Col2:")
        print_selected_colors()

        cx16.r0L = 0
        for row in 21 to 28 {
            for col in 1 to 32 {
                txt.setcc2(col, row, 160, cx16.r0L)
                cx16.r0L++
            }
        }
        txt.setcc2(1, 21, sc:'▒', 255)
    }

    sub print_selected_colors() {
        if drawing.selected_color1==0 {
            txt.setcc2(34, 22, sc:'▒', 255)
            txt.setcc2(35, 22, sc:'▒', 255)
        } else {
            txt.setcc2(34, 22, 160, drawing.selected_color1)
            txt.setcc2(35, 22, 160, drawing.selected_color1)
        }
        txt.plot(36, 22)
        txt.print_ub0(drawing.selected_color1)
        if drawing.selected_color2==0 {
            txt.setcc2(34, 24, sc:'▒', 255)
            txt.setcc2(35, 24, sc:'▒', 255)
        } else {
            txt.setcc2(34, 24, 160, drawing.selected_color2)
            txt.setcc2(35, 24, 160, drawing.selected_color2)
        }
        txt.plot(36, 24)
        txt.print_ub0(drawing.selected_color2)
    }

    sub toggle() {
        if active {
            active = false
            cx16.VERA_CTRL = 0
            cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11001111) | %00010000
        } else {
            active = true
            cx16.VERA_CTRL = 0
            cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11001111) | %00110000
        }
    }

    sub mouse(ubyte buttons, uword mx, uword my) {
        if buttons==0
            return

        if mx>=1*8 and mx<33*8 and my>=21*8 and my<29*8 {
            ; palette clicked
            my = (my-21*8)/8
            mx = (mx-1*8)/8
            ubyte color = lsb(my)*32+lsb(mx)
            when buttons {
                1 -> drawing.selected_color1 = color
                2 -> drawing.selected_color2 = color
            }
            print_selected_colors()
        }
    }
}