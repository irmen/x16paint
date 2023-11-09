; Paint program for the Commander X16.
; This is the main program and menu logic.

%import syslib
%import textio
%import diskio
%import string
%import drawing

main {
    sub start() {
        ; screen mode
        void cx16.screen_mode(128, false)
        cx16.VERA_L1_CONFIG |= %00001000     ; enable T256C mode for the text layer
        cx16.GRAPH_set_colors(1,2,0)
        cx16.GRAPH_clear()
        drawing.init()

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
        txt.print("      Left/right button = color 1/2.\n")
        txt.print("      Middle button = erase.\n\n")
        txt.print("    - Only 320*240 with 256 colors.\n\n")
        txt.print("    - TAB toggles the menus on/off.\n\n\n\n")
        txt.print("    Click any mouse button to start.")
        while not cx16.mouse_pos() { }
        while cx16.mouse_pos() { }
        menu.toggle()   ; turn menu OFF

        repeat {
            handle_mouse()
            handle_keypress()
        }
    }

    sub handle_mouse() {
        cx16.r3L = cx16.mouse_pos()
        if menu.active {
            drawing.mouse_button_pressed = false
            menu.mouse(cx16.r3L, cx16.r0, cx16.r1)
            return
        }
        if cx16.r3L
            drawing.mouse(cx16.r3L, cx16.r0, cx16.r1)
        else
            drawing.mouse_button_pressed = false
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

menu {
    bool active = true
    const ubyte PALETTE_BOX_ROW = 17
    const ubyte PALETTE_BOX_COL = 3

    str[4] commands_names = ["Clear", "Save", "Load", "Quit"]
    uword[4] commands_handlers = [&commands.clear, &commands.save, &commands.load, &commands.quit]
    ubyte[4] commands_x = [26, 26, 26, 26]
    ubyte[4] commands_y = [4, 6, 8, 10]

    str[9] tools_names = ["Draw", "Rectangle", "Circle", "Erase", "Line", "Box", "Disc", "Fill", "Magnification"]
    uword[9] tools_handlers = [&tools.draw, &tools.rect, &tools.circle, &tools.erase, &tools.line, &tools.box, &tools.disc, &tools.fill, &tools.magnify]
    ubyte[9] tools_x = [6, 6, 6, 6, 17, 18, 17, 17, 6]
    ubyte[9] tools_y = [4, 6, 8, 10, 4, 6, 8, 10, 14]

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
        tools.draw_active_checkmark()
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
        txt.plot(PALETTE_BOX_COL+2, PALETTE_BOX_ROW+1)
        txt.print("Col1:")
        txt.plot(PALETTE_BOX_COL+13, PALETTE_BOX_ROW+1)
        txt.print("Col2:")
        draw_selected_colors()

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
        cbm.CLRCHN()
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

    sub message(str title, str text) {
        cbm.CLRCHN()
        cx16.r0L = string.length(text)
        ubyte xpos = 20 - cx16.r0L/2 -3
        outline(xpos, 8, cx16.r0L+3, 6, title)
        txt.plot(xpos+2,11)
        txt.color(7)
        txt.print(text)
    }

    sub confirm(str text) -> bool {
        message("Confirm", text)
        while cbm.GETIN() { }
        repeat {
            when cbm.GETIN() {
                0 -> { }
                'y' -> return true
                else -> return false
            }
        }
    }

    sub input(ubyte maxlen, str title, str caption) -> str {
        str filename_buffer = "?" * 80
        ubyte entered_length = 0
        ubyte xpos = 20-(maxlen+5)/2
        cbm.CLRCHN()
        outline(xpos, 8, maxlen+4, 6, title)
        txt.plot(xpos+2,10)
        txt.color(7)
        txt.print(caption)
        txt.plot(xpos+2,12)
        filename_buffer[0] = 0
        cx16.set_chrin_keyhandler(0, &keystroke_handler)
        void txt.input_chars(filename_buffer)
        ; trim right crap and spaces
        filename_buffer[entered_length]=0
        while entered_length and filename_buffer[entered_length]!=' '
            entered_length--
        while entered_length {
            if filename_buffer[entered_length]!=' '
                break
            filename_buffer[entered_length] = 0
            entered_length--
        }
        return filename_buffer

        sub keystroke_handler() -> ubyte {
            %asm {{
                sta  cx16.r0L
            }}
            if_cs {
                ; first entry, decide if we want to override
                if cx16.r0L==13 {
                    sys.set_carry()
                    return 0
                }
                if cx16.r0L<32 or (cx16.r0L>=128 and cx16.r0L<160) {
                    sys.clear_carry()   ; override
                    return 0
                }
                if entered_length<maxlen {
                    sys.set_carry()     ; regular printable char, don't override
                    entered_length++
                }
                else
                    sys.clear_carry()
                return 0
            } else {
                ; second entry, handle override
                if cx16.r0L==20 {
                    ; DEL/BACKSPACE
                    if entered_length>0 {
                        entered_length--
                        txt.chrout(157)
                        txt.chrout(' ')
                        return 157
                    }
                }
                return 0    ; eat all other characters
            }
        }
    }

    sub draw_selected_colors() {
        if drawing.selected_color1==0 {
            txt.setcc2(PALETTE_BOX_COL+7, PALETTE_BOX_ROW+1, sc:'▒', 255)
            txt.setcc2(PALETTE_BOX_COL+8, PALETTE_BOX_ROW+1, sc:'▒', 255)
        } else {
            txt.setcc2(PALETTE_BOX_COL+7, PALETTE_BOX_ROW+1, 160, drawing.selected_color1)
            txt.setcc2(PALETTE_BOX_COL+8, PALETTE_BOX_ROW+1, 160, drawing.selected_color1)
        }
        txt.plot(PALETTE_BOX_COL+9, PALETTE_BOX_ROW+1)
        txt.print_ub0(drawing.selected_color1)
        if drawing.selected_color2==0 {
            txt.setcc2(PALETTE_BOX_COL+18, PALETTE_BOX_ROW+1, sc:'▒', 255)
            txt.setcc2(PALETTE_BOX_COL+19, PALETTE_BOX_ROW+1, sc:'▒', 255)
        } else {
            txt.setcc2(PALETTE_BOX_COL+18, PALETTE_BOX_ROW+1, 160, drawing.selected_color2)
            txt.setcc2(PALETTE_BOX_COL+19, PALETTE_BOX_ROW+1, 160, drawing.selected_color2)
        }
        txt.plot(PALETTE_BOX_COL+20, PALETTE_BOX_ROW+1)
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
            draw_selected_colors()
            return
        }

        if buttons!=1 {
            ; only support left mouse button to click menu entries
            wait_release_mousebuttons()
            return
        }

        if mx >= commands_x[0]*8 {
            ; possibly command clicked
            for cx16.r0L in 0 to len(commands_names)-1 {
                cx16.r1 = commands_x[cx16.r0L]*8
                cx16.r2 = commands_y[cx16.r0L]*8
                cx16.r3 = cx16.r1 + string.length(commands_names[cx16.r0L])*8
                if mx>=cx16.r1 and my>=cx16.r2 and mx<cx16.r3 and my<(cx16.r2+8) {
                    void callfar(cx16.getrambank(), commands_handlers[cx16.r0L], 0)
                    wait_release_mousebuttons()
                    return
                }
            }
        } else if mx >= tools_x[0]*8 {
            ; possibly tool clicked
            for cx16.r0L in 0 to len(tools_names)-1 {
                cx16.r1 = tools_x[cx16.r0L]*8
                cx16.r2 = tools_y[cx16.r0L]*8
                cx16.r3 = cx16.r1 + string.length(tools_names[cx16.r0L])*8
                if mx>=cx16.r1 and my>=cx16.r2 and mx<cx16.r3 and my<(cx16.r2+8) {
                    void callfar(cx16.getrambank(), tools_handlers[cx16.r0L], 0)
                    wait_release_mousebuttons()
                    return
                }
            }
        }
    }

    sub wait_release_mousebuttons() {
        while cx16.mouse_pos() { }
    }
}

commands {
    sub clear() {
        if menu.confirm("Clear image. Sure Y/N?") {
            drawing.clear()
            menu.message("Info", "Cleared with Col.2")
            sys.wait(60)
        }
        menu.draw()
    }

    sub save() {
        uword filename = menu.input(26, "Save", "Enter filename, empty=abort")
        ubyte filename_len = string.length(filename)
        if filename==0 or filename_len==0 {
            menu.draw()
            return
        }

        menu.message("Info", "Saving...")
        bool success = false

        ; This uses the Golden Ram $0400-$07ff as buffer for VRAM.
        ; Save the image. The 320x240x256C image is exactly 75K data at vram $00000
        diskio.delete(filename)
        if diskio.f_open_w(filename) {
            cx16.vaddr(0,0,0,1)
            repeat 75 {
                cx16.r0 = $0400
                repeat 1024 {
                    @(cx16.r0) = cx16.VERA_DATA0
                    cx16.r0++
                }
                if not diskio.f_write($0400, 1024)
                    goto end_save
            }
            diskio.f_close_w()

            ; Save the palette. 2 pages at vram $1fa00
            if filename_len>4 {
                filename[filename_len-3] = 'p'
                filename[filename_len-2] = 'a'
                filename[filename_len-1] = 'l'
            } else {
                filename[filename_len] = '.'
                filename[filename_len+1] = 'p'
                filename[filename_len+2] = 'a'
                filename[filename_len+3] = 'l'
            }
            diskio.delete(filename)
            if diskio.f_open_w(filename) {
                cx16.vaddr(1,$fa00,0,1)
                cx16.r0 = $0400
                repeat 512 {
                    @(cx16.r0) = cx16.VERA_DATA0
                    cx16.r0++
                }
                success = diskio.f_write($0400, 512)
            }
        }

end_save:
        if not success {
            menu.message("Error", diskio.status())
            sys.wait(120)
        }
        diskio.f_close_w()
        menu.draw()
    }

    sub load() {
        uword filename = menu.input(26, "Load", "Enter filename, empty=abort")
        ubyte filename_len = string.length(filename)
        if filename==0 or filename_len==0 {
            menu.draw()
            return
        }

        menu.message("Info", "Loading...")
        if diskio.vload_raw(filename, 0, $0000) {
            if filename_len>4 {
                filename[filename_len-3] = 'p'
                filename[filename_len-2] = 'a'
                filename[filename_len-1] = 'l'
            } else {
                filename[filename_len] = '.'
                filename[filename_len+1] = 'p'
                filename[filename_len+2] = 'a'
                filename[filename_len+3] = 'l'
            }
            if diskio.vload_raw(filename, 1, $fa00) {
                menu.toggle()
                return
            }
        }

        menu.message("Error", diskio.status())
        sys.wait(120)
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

tools {
    sub clear_checkmarks() {
        ; clear all tool checkmarks (except magnifier)
        txt.setcc2(5,4,sc:' ',7)
        txt.setcc2(5,6,sc:' ',7)
        txt.setcc2(5,8,sc:' ',7)
        txt.setcc2(5,10,sc:' ',7)
        txt.setcc2(21,4,sc:' ',7)
        txt.setcc2(21,6,sc:' ',7)
        txt.setcc2(21,8,sc:' ',7)
        txt.setcc2(21,10,sc:' ',7)
    }

    sub draw_active_checkmark() {
        clear_checkmarks()
        when drawing.active_tool {
            drawing.TOOL_DRAW -> txt.setcc2(5,4,sc:'✓',7)
            drawing.TOOL_RECT -> txt.setcc2(5,6,$69,2)
            drawing.TOOL_CIRCLE -> txt.setcc2(5,8,$69,2)
            drawing.TOOL_ERASE -> txt.setcc2(5,10,sc:'✓',7)
            drawing.TOOL_LINE -> txt.setcc2(21,4,$69,2)
            drawing.TOOL_BOX -> txt.setcc2(21,6,$69,2)
            drawing.TOOL_DISC -> txt.setcc2(21,8,$69,2)
            drawing.TOOL_FILL -> txt.setcc2(21,10,sc:'✓',7)
        }

        if drawing.magnification
            txt.setcc2(5,14,$69,2)
        else
            txt.setcc2(5,14,sc:' ',7)
    }

    sub draw() {
        drawing.active_tool = drawing.TOOL_DRAW
        draw_active_checkmark()
    }

    sub circle() {
        drawing.active_tool = drawing.TOOL_CIRCLE
        draw_active_checkmark()
    }

    sub disc() {
        drawing.active_tool = drawing.TOOL_DISC
        draw_active_checkmark()
    }

    sub erase() {
        drawing.active_tool = drawing.TOOL_ERASE
        draw_active_checkmark()
    }

    sub line() {
        drawing.active_tool = drawing.TOOL_LINE
        draw_active_checkmark()
    }

    sub rect() {
        drawing.active_tool = drawing.TOOL_RECT
        draw_active_checkmark()
    }

    sub box() {
        drawing.active_tool = drawing.TOOL_BOX
        draw_active_checkmark()
    }

    sub fill() {
        drawing.active_tool = drawing.TOOL_FILL
        draw_active_checkmark()
    }

    sub magnify() {
        drawing.magnification = not drawing.magnification
        draw_active_checkmark()
    }
}