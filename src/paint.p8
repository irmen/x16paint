; Paint program for the Commander X16.
; BMX file format: see https://cx16forum.com/forum/viewtopic.php?t=6945

; This is the main program and menu logic.

; TODO: undo+redo
; TODO: 1-8 and shifted 1-8 = select color 0-15 ? but what about all the other colors?
; TODO: file picker for load, file list before save?
; TODO: add Help command (use 80x30 screen mode for the help text?)
; TODO: increase/decrease brush size for erasing and drawing
; TODO: implement zoom, could be a sprite that magnifies whats under cursor and follows? Or use vera scaling? (but needs scrolling the bitmap layer, is this possible at all?)
; TODO: palette editing, or rely on an external tool/plugin for this?
; TODO: ellipse (squashed circles)
; TODO: tool-specific mouse pointer?
; TODO: grid toggle?
; TODO: text tool?


%import syslib
%import textio
%import diskio
%import strings
%import bmx
%import palette
%import drawing
%import sprites
%import colors
%option no_sysinit

main {
    sub start() {
        ;; diskio.fastmode(3)      ; fast loads+saves
        gfx_init()
        drawing.init()
        drawing.reset_undo()

        ; mouse
        cx16.mouse_config2(1)
        set_mousepointer_hand()
        ; select a different palette offset for the mouse pointer to make it visible on black:
        ; cx16.vpoke_mask(1, $fc00+7, %11110000, %1011)

        ; instructions
        txt.lowercase()
        txt.clear_screen()
        txt.print("\n\n    \x9aCommander X16 PAINT\n\n"+
            "    \x97DesertFish ▒ Prog8 ▒ version 1.4dev\x9f" +
            "\n\n\n\n    Instructions:\n\n\n"+
            "   - Use the mouse to paint stuff.\n"+
            "     Left/right button = color 1/2.\n"+
            "     Middle button = erase.\n\n" +
            "   - Resolution 320*240, 256 colors.\n\n")
        txt.print("   - Tools have hotkeys (capitalized).\n\n"+
            "   - TAB toggles the menus on/off.\n\n"+
            "   - Type lowercase filenames.\n\n\n\n"+
            "    \x99Click any mouse button to start.")
        do {
            cx16.r0L, void, void, void = cx16.mouse_pos()
        } until cx16.r0L!=0
        menu.wait_release_mousebuttons()
        menu.show()

        repeat {
            handle_mouse()
            handle_keypress()
        }
    }

    sub gfx_init() {
        gfx_lores.eor_mode = false
        void cx16.screen_mode(128, false)
        gfx_lores.clear_screen(0)
    }

    sub handle_mouse() {
        cx16.r3L, cx16.r0, cx16.r1, void = cx16.mouse_pos()
        if menu.active {
            drawing.stop()
            menu.mouse(cx16.r3L, cx16.r0, cx16.r1)
            return
        }
        else if colors.active {
            drawing.stop()
            colors.mouse(cx16.r3L, cx16.r0, cx16.r1)
            return
        }
        else
            drawing.mouse(cx16.r3L, cx16.r0, cx16.r1)
    }

    sub handle_keypress() {
        ; check if left CTRL is held down to show the position
        cx16.r0, void = cx16.joystick_get(0)
        drawing.show_coordinates(cx16.r0&$8000 == 0)

        when cbm.GETIN2() {
            0 -> { /* do nothing */ }
            9 -> {
                ; TAB = show/hide menus overlay
                if menu.active {
                    menu.hide()
                }
                else {
                    colors.hide()
                    menu.show()
                }
            }
            'w' -> {
                menu.notification("Draw")
                tools.draw()
            }
            'l' -> {
                menu.notification("Line")
                tools.line()
            }
            'r' -> {
                menu.notification("Rectangle")
                tools.rect()
            }
            'b' -> {
                menu.notification("Box")
                tools.box()
            }
            'c' -> {
                menu.notification("Circle")
                tools.circle()
            }
            'd' -> {
                menu.notification("Disc")
                tools.disc()
            }
            'e' -> {
                menu.notification("Erase")
                tools.erase()
            }
            'f' -> {
                menu.notification("Fill")
                tools.fill()
            }
            'p' -> {
                ; toggle color palette
                if colors.active {
                    colors.hide()
                }
                else {
                    menu.hide()
                    colors.show()
                }
            }
            'u' -> {
                menu.notification("Undo is T.B.D.")     ; TODO
                ; drawing.undo()
            }
            'y' -> {
                menu.notification("Redo is T.B.D.")     ; TODO
                ; drawing.redo()
            }
            'z' -> {
                menu.notification("Zoom (TODO)")
                tools.zoom()
            }
        }

    }

    sub enable_text_layer() {
        cx16.VERA_CTRL = 0
        cx16.VERA_DC_VIDEO = cx16.VERA_DC_VIDEO | %00100000
    }

    sub disable_text_layer() {
        cx16.VERA_CTRL = 0
        cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11001111) | %00010000
    }

    sub set_mousepointer_crosshair() {
        ; the array below is the compressed form of this sprite image:
        ;    00, 00, 00, 00, 00, 00, 00, 00, 14, 00, 00, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 00, 00, 14, 00, 00, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 00, 00, 14, 00, 00, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 00, 00, 14, 00, 00, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 00, 00, 03, 00, 00, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 00, 00, 14, 00, 00, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 06, 05, 03, 05, 06, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 05, 01, 00, 01, 05, 00, 00, 00, 00, 00,
        ;    14, 14, 14, 14, 03, 14, 03, 00, 00, 00, 03, 14, 03, 14, 14, 14,
        ;    00, 00, 00, 00, 00, 00, 05, 01, 00, 01, 05, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 06, 05, 03, 05, 06, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 00, 00, 14, 00, 00, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 00, 00, 03, 00, 00, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 00, 00, 14, 00, 00, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 00, 00, 14, 00, 00, 00, 00, 00, 00, 00,
        ;    00, 00, 00, 00, 00, 00, 00, 00, 14, 00, 00, 00, 00, 00, 00, 00        
        ubyte[] crosshair_image_lzsa = [
            $0d, $00, $fb, $0d, $0e, $27, $8f, $20, $2f, $03, $0f, $05, $ff, $22, $06, $05,
            $03, $05, $06, $5c, $2f, $05, $01, $00, $01, $05, $88, $01, $52, $03, $0e, $c2,
            $21, $da, $21, $27, $02, $47, $c0, $ee, $47, $80, $47, $40, $ff, $1f, $e7, $e8 ]
        sprites.set_mousepointer_image(crosshair_image_lzsa, true)
        cx16.r0s = -8
        cx16.r1s = -8
        sys.clear_carry()
        cx16.extapi(cx16.EXTAPI_mouse_sprite_offset)
    }

    sub set_mousepointer_hand() {
        sprites.set_mousepointer_hand()
        cx16.r0s = -1
        cx16.r1s = -1
        sys.clear_carry()
        cx16.extapi(cx16.EXTAPI_mouse_sprite_offset)
    }
}

menu {
    bool active = false

    str[] commands_names = ["Undo", "Clear", "Load image", "Save image", "Load pal.", "Save pal.", "Drive: ", "Quit"]
    uword[len(commands_names)] commands_handlers = [&commands.undo, &commands.clear, &commands.load, &commands.save, &commands.load_palette, &commands.save_palette, &commands.drive, &commands.quit]
    ubyte[len(commands_names)] commands_x = [27, 27, 27, 27, 27, 27, 27, 27]
    ubyte[len(commands_names)] commands_y = [4, 6, 8, 10, 12, 14, 16, 18]

    str[] tools_names = ["draW", "Rectangle", "Circle", "Erase", "Line", "Box", "Disc", "Fill", "Zoom", "Palette"]
    uword[len(tools_names)] tools_handlers = [&tools.draw, &tools.rect, &tools.circle, &tools.erase, &tools.line, &tools.box, &tools.disc, &tools.fill, &tools.zoom, &tools.palette]
    ubyte[len(tools_names)] tools_x = [6, 6, 6, 6, 17, 18, 17, 17, 6, 14]
    ubyte[len(tools_names)] tools_y = [4, 6, 8, 10, 4, 6, 8, 10, 12, 12]

    const ubyte MENU_BG_COL = 11

    sub draw() {
        txt.color2(1,0)
        txt.clear_screen()
        txt.color2(1, MENU_BG_COL)
        draw_tools()
        draw_commands()
        draw_info()
    }

    sub draw_tools() {
        outline(3, 2, 20, 12, "Tools")
        for cx16.r0L in 0 to len(tools_names)-1 {
            cx16.r2 = tools_names[cx16.r0L]
            txt.color(3)
            txt.plot(tools_x[cx16.r0L], tools_y[cx16.r0L])
            txt.print(cx16.r2)
            txt.color(12)
            txt.plot(tools_x[cx16.r0L] + hotkeyOffset(), tools_y[cx16.r0L]+1)
            txt.chrout('▔')
        }
        tools.draw_active_checkmark()

        sub hotkeyOffset() -> ubyte {
            for cx16.r5L in 0 to 100 {
                if @(cx16.r2+cx16.r5L)>96
                    return cx16.r5L
            }
            return 0
        }
    }

    sub draw_commands() {
        outline(25, 2, 12, 18, "Commands")
        txt.color(3)
        for cx16.r0L in 0 to len(commands_names)-1 {
            txt.plot(commands_x[cx16.r0L], commands_y[cx16.r0L])
            txt.print(commands_names[cx16.r0L])
        }
        commands.draw_drive()
    }

    sub draw_info() {
        const ubyte BOX_Y=23
        outline(3, BOX_Y, 31, 4, "Info")
        txt.color(12)
        txt.plot(4, BOX_Y+1)
        txt.print("Tool hotkeys are underlined.")
        txt.plot(4, BOX_Y+2)
        txt.print("Hold CTRL to show coordinates.")
        txt.plot(4, BOX_Y+3)
        txt.print("TAB to toggle menu.")
    }

    sub outline(ubyte x, ubyte y, ubyte w, ubyte h, str caption) {
        cbm.CLRCHN()
        for cx16.r0L in x+1 to x+w-1 {
            txt.setcc2(cx16.r0L, y, sc:'─', MENU_BG_COL<<4 | 14)
            txt.setcc2(cx16.r0L, y+h, sc:'─', MENU_BG_COL<<4 | 14)
            for cx16.r1L in y+1 to y+h-1
                txt.setcc2(cx16.r0L, cx16.r1L, ' ', MENU_BG_COL<<4 | 14)
        }
        for cx16.r0L in y+1 to y+h-1 {
            txt.setcc2(x, cx16.r0L, sc:'|', MENU_BG_COL<<4 | 14)
            txt.setcc2(x+w, cx16.r0L, sc:'|', MENU_BG_COL<<4 | 14)
        }
        txt.setcc2(x, y, sc:'┌', MENU_BG_COL<<4 | 14)
        txt.setcc2(x+w, y, sc:'┐', MENU_BG_COL<<4 | 14)
        txt.setcc2(x, y+h, sc:'└', MENU_BG_COL<<4 | 14)
        txt.setcc2(x+w, y+h, sc:'┘', MENU_BG_COL<<4 | 14)
        txt.plot(x+2, y)
        txt.color(13)
        txt.print(caption)
    }

    sub message(str title, str text) {
        const ubyte BOX_Y = 10
        cbm.CLRCHN()
        cx16.r0L = strings.length(text)
        ubyte xpos = 20 - cx16.r0L/2 -2
        outline(xpos, BOX_Y, cx16.r0L+3, 6, title)
        txt.plot(xpos+2,BOX_Y+3)
        txt.color(7)
        txt.print(text)
    }

    sub confirm(str text) -> bool {
        message("Confirm", text)
        while cbm.GETIN2()!=0 { }
        repeat {
            when cbm.GETIN2() {
                0 -> { }
                'y' -> return true
                else -> return false
            }
        }
    }

    sub input(ubyte maxlen, str title, str caption) -> str {
        const ubyte BOX_Y = 12
        str filename_buffer = "?" * 80
        ubyte entered_length = 0
        ubyte xpos = 20-(maxlen+5)/2
        cbm.CLRCHN()
        outline(xpos, BOX_Y, maxlen+4, 6, title)
        txt.plot(xpos+2,BOX_Y+2)
        txt.color(7)
        txt.print(caption)
        txt.plot(xpos+2,BOX_Y+4)
        filename_buffer[0] = 0
        cx16.set_chrin_keyhandler(0, &keystroke_handler)
        void txt.input_chars(filename_buffer)
        ; trim right crap and spaces
        filename_buffer[entered_length]=0
        while entered_length!=0 and filename_buffer[entered_length]!=' '
            entered_length--
        while entered_length!=0 {
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
                sys.save_prog8_internals()          ; because this routine is kinda called as an interrupt
                ubyte response=0
                if cx16.r0L==20 {
                    ; DEL/BACKSPACE
                    if entered_length>0 {
                        entered_length--
                        txt.chrout(157)
                        txt.chrout(' ')
                        response=157
                    }
                }
                sys.restore_prog8_internals()
                return response
            }
        }
    }

    uword[16] palette_backup

    sub backup_palette() {
        cx16.r2 = $fa00
        for cx16.r3L in 0 to 15 {
            cx16.r4L = cx16.vpeek(1,cx16.r2)
            cx16.r2++
            cx16.r4H = cx16.vpeek(1,cx16.r2)
            cx16.r2++
            palette_backup[cx16.r3L] = cx16.r4
        }
    }

    sub restore_palette() {
        palette.set_rgb(&palette_backup, len(palette_backup), 0)
    }

    sub show() {
        active = true
        draw()
        backup_palette()
        palette.set_default16()
        main.enable_text_layer()
        main.set_mousepointer_hand()
    }

    sub hide() {
        active = false
        main.disable_text_layer()
        restore_palette()
        txt.color2(1,0)
        txt.clear_screen()
        main.set_mousepointer_crosshair()
    }

    sub mouse(ubyte buttons, uword mx, uword my) {
        if buttons==0 or not active
            return

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
                cx16.r3 = cx16.r1 + strings.length(commands_names[cx16.r0L])*8
                if mx>=cx16.r1 and my>=cx16.r2 and mx<cx16.r3 and my<(cx16.r2+8) {
                    void call(commands_handlers[cx16.r0L])
                    wait_release_mousebuttons()
                    return
                }
            }
        } else if mx >= tools_x[0]*8 {
            ; possibly tool clicked
            for cx16.r0L in 0 to len(tools_names)-1 {
                cx16.r1 = tools_x[cx16.r0L]*8
                cx16.r2 = tools_y[cx16.r0L]*8
                cx16.r3 = cx16.r1 + strings.length(tools_names[cx16.r0L])*8
                if mx>=cx16.r1 and my>=cx16.r2 and mx<cx16.r3 and my<(cx16.r2+8) {
                    void call(tools_handlers[cx16.r0L])
                    wait_release_mousebuttons()
                    return
                }
            }
        }
    }

    sub wait_release_mousebuttons() {
        do {
            cx16.r0L, void, void, void = cx16.mouse_pos()
        } until cx16.r0L==0
    }

    sub notification(str text) {
        if menu.active or colors.active
            return
        txt.color2(1,2)
        txt.plot(14,2)
        txt.spc()
        txt.print(text)
        txt.spc()
        main.enable_text_layer()
        sys.wait(30)
        main.disable_text_layer()
        txt.plot(14,2)
        txt.color2(1,0)
        txt.print("                ")
    }
}

commands {
    sub undo() {
        menu.message("Info", "just press U = Undo, Y = Redo")
        sys.wait(100)
        menu.draw()
    }


    sub clear() {
        if menu.confirm("Clear image. Sure Y/N?") {
            ; TODO set palette to default?
            main.gfx_init()
            drawing.reset_undo()
            drawing.active_tool = drawing.TOOL_DRAW
            menu.hide()
            return
        }
        menu.draw()
    }

    sub load() {
        uword filename = menu.input(26, "Load image", "Enter filename, empty=abort")
        ubyte filename_len = strings.length(filename)
        if filename==0 or filename_len==0 {
            menu.draw()
            return
        }

        if not strings.endswith(filename, ".bmx")
            void strings.append(filename, ".bmx")

        menu.message("Info", "Loading...")
        uword error_message=0
        if bmx.open(diskio.drivenumber, filename) {
            if bmx.bitsperpixel in [1,2,4,8] {
                if bmx.width<=gfx_lores.WIDTH and bmx.height<=gfx_lores.HEIGHT {
                    if bmx.width<gfx_lores.WIDTH or bmx.height<gfx_lores.HEIGHT {
                        ; clear the screen with the border color
                        cx16.GRAPH_set_colors(0, 0, bmx.border)
                        cx16.GRAPH_clear()
                        ; need to use the slower load routine that does padding
                        ; center the image on the screen nicely
                        cx16.r0 = (gfx_lores.WIDTH-bmx.width)/2 + (gfx_lores.HEIGHT-bmx.height)/2*gfx_lores.WIDTH
                        when bmx.bitsperpixel {
                            1 -> load_1bpp_centered(cx16.r0)
                            2 -> load_2bpp_centered(cx16.r0)
                            4 -> load_4bpp_centered(cx16.r0)
                            else -> load_8bpp_centered(cx16.r0)
                        }
                        if error_message==0 {
                            drawing.reset_undo()
                            menu.backup_palette()
                            menu.hide()
                            return
                        }
                    }
                    else {
                        when bmx.bitsperpixel {
                            1 -> load_1bpp_centered(0)
                            2 -> load_2bpp_centered(0)
                            4 -> load_4bpp_centered(0)
                            else -> load_8bpp()
                        }
                        if error_message==0 {
                            if bmx.height<gfx_lores.HEIGHT {
                                ; fill the remaining bottom part of the screen
                                cx16.GRAPH_set_colors(bmx.border, bmx.border, 99)
                                cx16.GRAPH_draw_rect(0, bmx.height, gfx_lores.WIDTH, gfx_lores.HEIGHT-bmx.height, 0, true)
                            }
                            drawing.reset_undo()
                            menu.backup_palette()
                            menu.hide()
                            return
                        }
                    }
                } else
                    error_message = "image too large"
            } else
                error_message="invalid color depth"
        } else
            error_message = bmx.error_message

        menu.message("Error", error_message)
        txt.bell()
        sys.wait(120)
        menu.draw()
        return

        sub load_8bpp_centered(uword offset) {
            if bmx.continue_load_stamp(0, offset, gfx_lores.WIDTH)
                return
            error_message = bmx.error_message
        }

        sub load_8bpp() {
            if bmx.continue_load(0, 0)
                return
            error_message = bmx.error_message
        }

        sub load_4bpp_centered(uword offset) {
            const uword load_offset = (gfx_lores.WIDTH * (gfx_lores.HEIGHT-8)) & 65535
            const ubyte load_offset_bank = (gfx_lores.WIDTH * (gfx_lores.HEIGHT-8)) >> 16
            if not bmx.continue_load_stamp(load_offset_bank, load_offset, bmx.width) {
                error_message = bmx.error_message
                return
            }

            cx16.vaddr(load_offset_bank, load_offset, 1, 1)
            ubyte offset_bank = 0
            repeat bmx.height {
                cx16.vaddr(offset_bank, offset, 0, 1)
                repeat bmx.width/2 {
                    cx16.r0L = cx16.VERA_DATA1
                    cx16.VERA_DATA0 = cx16.r0L >> 4
                    cx16.VERA_DATA0 = cx16.r0L & 15
                }
                offset += gfx_lores.WIDTH
                if offset < gfx_lores.WIDTH
                    offset_bank++
            }

            ; fix up the bottom of the screen borders
            cx16.GRAPH_set_colors(bmx.border, bmx.border, 99)
            uword border_width = (gfx_lores.WIDTH-bmx.width)/2
            cx16.GRAPH_draw_rect(0, gfx_lores.HEIGHT-8, border_width, 8, 0, true)
            cx16.GRAPH_draw_rect(border_width+bmx.width, gfx_lores.HEIGHT-8, border_width, 8, 0, true)
        }

        sub load_2bpp_centered(uword offset) {
            const uword load_offset = (gfx_lores.WIDTH * gfx_lores.HEIGHT) & 65535
            const ubyte load_offset_bank = (gfx_lores.WIDTH * gfx_lores.HEIGHT) >> 16
            if not bmx.continue_load_stamp(load_offset_bank, load_offset, bmx.width) {
                error_message = bmx.error_message
                return
            }

            cx16.vaddr(load_offset_bank, load_offset, 1, 1)
            ubyte offset_bank = 0
            repeat bmx.height {
                cx16.vaddr(offset_bank, offset, 0, 1)
                repeat bmx.width/4 {
                    cx16.r0L = cx16.VERA_DATA1
                    cx16.VERA_DATA0 = cx16.r0L >> 6
                    cx16.VERA_DATA0 = (cx16.r0L >> 4) & 3
                    cx16.VERA_DATA0 = (cx16.r0L >> 2) & 3
                    cx16.VERA_DATA0 = cx16.r0L & 3
                }
                offset += gfx_lores.WIDTH
                if offset < gfx_lores.WIDTH
                    offset_bank++
            }
        }

        sub load_1bpp_centered(uword offset) {
            const uword load_offset = (gfx_lores.WIDTH * gfx_lores.HEIGHT) & 65535
            const ubyte load_offset_bank = (gfx_lores.WIDTH * gfx_lores.HEIGHT) >> 16
            if not bmx.continue_load_stamp(load_offset_bank, load_offset, bmx.width) {
                error_message = bmx.error_message
                return
            }

            cx16.vaddr(load_offset_bank, load_offset, 1, 1)
            ubyte offset_bank = 0
            repeat bmx.height {
                cx16.vaddr(offset_bank, offset, 0, 1)
                repeat bmx.width/8 {
                    cx16.r0L = cx16.VERA_DATA1
                    repeat 8 {
                        rol(cx16.r0L)
                        if_cs
                            cx16.VERA_DATA0 = 1
                        else
                            cx16.VERA_DATA0 = 0
                    }
                }
                offset += gfx_lores.WIDTH
                if offset < gfx_lores.WIDTH
                    offset_bank++
            }
        }
    }

    sub save() {
        uword filename = menu.input(26, "Save image", "Enter filename, empty=abort")
        ubyte filename_len = strings.length(filename)
        if filename==0 or filename_len==0 {
            menu.draw()
            return
        }

        if not strings.endswith(filename, ".bmx")
            void strings.append(filename, ".bmx")

        menu.message("Info", "Saving...")

        menu.restore_palette()   ; note: could also reconstruct the original palette in a buffer and let bmx.save() use that...
        bmx.set_bpp(8)
        bmx.width = gfx_lores.WIDTH
        bmx.height = gfx_lores.HEIGHT
        bmx.border = 0
        bmx.compression = 0
        bmx.palette_entries = 256
        bmx.palette_start = 0
        bool success = bmx.save(diskio.drivenumber, filename, 0, 0, gfx_lores.WIDTH)
        palette.set_default16()

        if not success {
            menu.message("Error", bmx.error_message)
            txt.bell()
            sys.wait(120)
        }
        menu.draw()
    }

    sub load_palette() {
        uword filename = menu.input(26, "Load palette", "Enter filename, empty=abort")
        ubyte filename_len = strings.length(filename)
        if filename==0 or filename_len==0 {
            menu.draw()
            return
        }

        if not strings.endswith(filename, ".bmx")
            void strings.append(filename, ".bmx")

        menu.message("Info", "Loading...")

        if bmx.open(diskio.drivenumber, filename) {
            if bmx.continue_load_only_palette() {
                menu.show()
                return
            }
        }

        menu.message("Error", bmx.error_message)
        txt.bell()
        sys.wait(120)
        menu.draw()
    }

    sub save_palette() {
        uword filename = menu.input(26, "Save palette", "Enter filename, empty=abort")
        ubyte filename_len = strings.length(filename)
        if filename==0 or filename_len==0 {
            menu.draw()
            return
        }

        if not strings.endswith(filename, ".bmx")
            void strings.append(filename, ".bmx")

        menu.message("Info", "Saving...")
        menu.restore_palette()   ; note: could also reconstruct the original palette in a buffer and let bmx.save() use that...
        bmx.set_bpp(0)
        bmx.width = 320
        bmx.height = 0
        bmx.border = 0
        bmx.compression = 0
        bmx.palette_entries = 256
        bmx.palette_start = 0
        bool success = bmx.save(diskio.drivenumber, filename, 0, 0, gfx_lores.WIDTH)
        palette.set_default16()

        if not success {
            menu.message("Error", bmx.error_message)
            txt.bell()
            sys.wait(120)
        }
        menu.draw()
    }

    sub drive() {
        diskio.drivenumber++
        if diskio.drivenumber==12
            diskio.drivenumber=8
        draw_drive()
    }

    sub draw_drive() {
        txt.plot(34, 16)
        txt.color(8)
        txt.print_ub(diskio.drivenumber)
        txt.spc()
    }

    sub quit() {
        if menu.confirm("Quit program. Sure Y/N?") {
            sys.reset_system()
            ;void cx16.screen_mode(0, false)
            ;cx16.VERA_L1_CONFIG &= %11110111     ; disable T256C mode for the text layer
            ;sys.exit(0)
        } else {
            menu.draw()
        }
    }
}

tools {
    sub clear_checkmarks() {
        ; clear all tool checkmarks (except magnifier)
        txt.setcc2(5,4,sc:' ', menu.MENU_BG_COL<<4|7)
        txt.setcc2(5,6,sc:' ', menu.MENU_BG_COL<<4|7)
        txt.setcc2(5,8,sc:' ', menu.MENU_BG_COL<<4|7)
        txt.setcc2(5,10,sc:' ', menu.MENU_BG_COL<<4|7)
        txt.setcc2(21,4,sc:' ', menu.MENU_BG_COL<<4|7)
        txt.setcc2(21,6,sc:' ', menu.MENU_BG_COL<<4|7)
        txt.setcc2(21,8,sc:' ', menu.MENU_BG_COL<<4|7)
        txt.setcc2(21,10,sc:' ', menu.MENU_BG_COL<<4|7)
    }

    sub draw_active_checkmark() {
        if not menu.active
            return
        clear_checkmarks()
        when drawing.active_tool {
            drawing.TOOL_DRAW -> txt.setcc2(5,4,sc:'✓', menu.MENU_BG_COL<<4|7)
            drawing.TOOL_RECT -> txt.setcc2(5,6,sc:'✓', menu.MENU_BG_COL<<4|7)
            drawing.TOOL_CIRCLE -> txt.setcc2(5,8,sc:'✓', menu.MENU_BG_COL<<4|7)
            drawing.TOOL_ERASE -> txt.setcc2(5,10,sc:'✓', menu.MENU_BG_COL<<4|7)
            drawing.TOOL_LINE -> txt.setcc2(21,4,sc:'✓', menu.MENU_BG_COL<<4|7)
            drawing.TOOL_BOX -> txt.setcc2(21,6,sc:'✓', menu.MENU_BG_COL<<4|7)
            drawing.TOOL_DISC -> txt.setcc2(21,8,sc:'✓', menu.MENU_BG_COL<<4|7)
            drawing.TOOL_FILL -> txt.setcc2(21,10,sc:'✓', menu.MENU_BG_COL<<4|7)
        }

        if drawing.zooming
            txt.setcc2(5,12,$69, menu.MENU_BG_COL<<4|2)
        else
            txt.setcc2(5,12,sc:' ', menu.MENU_BG_COL<<4|7)
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

    sub zoom() {
        drawing.zooming = not drawing.zooming
        draw_active_checkmark()
    }

    sub palette() {
        menu.hide()
        colors.show()
    }
}
