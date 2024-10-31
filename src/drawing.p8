; These are the actual drawing routines.

%import gfx_lores

drawing {
    const ubyte TOOL_DRAW = 1
    const ubyte TOOL_LINE = 2
    const ubyte TOOL_RECT = 3
    const ubyte TOOL_BOX = 4
    const ubyte TOOL_CIRCLE = 5
    const ubyte TOOL_DISC = 6
    const ubyte TOOL_ERASE = 7         ; keep this, even though middle mouse button is the same. Usability / key shortcut reasons.
    const ubyte TOOL_FILL = 8

    ubyte active_tool = TOOL_DRAW
    ubyte selected_color1 = 1
    ubyte selected_color2 = 6
    bool zooming = false
    uword mouse_drag_start_x
    uword mouse_drag_start_y
    ubyte undo_buffers_amount
    ubyte next_undo_buffer = 0
    ubyte stored_undo_buffers = 0
    ubyte dragging_with_button = 0
    ubyte eor_color
    uword mouse_x
    uword mouse_y

    sub init() {
        undo_buffers_amount = (cx16.numbanks()-1)/10 as ubyte       ; each undo buffer requires 10 banks
    }

    sub stop() {
        dragging_with_button = 0
    }

    sub color_for_button(ubyte buttons) -> ubyte {
        when buttons {
            1 -> return selected_color1
            2 -> return selected_color2
            else -> return 0
        }
    }

    sub mouse(ubyte buttons, uword mx, uword my) {
        gfx_lores.drawmode_eor(false)
        ubyte circle_radius
        mouse_x = mx
        mouse_y = my
        if coordinates_shown
            draw_coordinates()

        if dragging_with_button!=0 {
            eor_color += 17
            if buttons!=0 {
                ; user is dragging the mouse with button(s) pressed
                ; this usually means whatever is drawn is still temporary
                when active_tool {
                    TOOL_DRAW, TOOL_ERASE -> {
                        ; immediately draw the line while dragging
                        ; TODO: allow user to pick a brush size
                        gfx_lores.line(mouse_drag_start_x, lsb(mouse_drag_start_y), mx, lsb(my), color_for_button(buttons))
                        mouse_drag_start_x=mx
                        mouse_drag_start_y=my
                    }
                    TOOL_LINE -> {
                        gfx_lores.drawmode_eor(true)
                        gfx_lores.line(mouse_drag_start_x, lsb(mouse_drag_start_y), mx, lsb(my), eor_color)
                        sys.waitvsync()
                        sys.waitvsync()
                        gfx_lores.line(mouse_drag_start_x, lsb(mouse_drag_start_y), mx, lsb(my), eor_color)
                        gfx_lores.drawmode_eor(false)
                    }
                    TOOL_RECT -> {
                        gfx_lores.drawmode_eor(true)
                        drawrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, eor_color)
                        sys.waitvsync()
                        sys.waitvsync()
                        drawrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, eor_color)
                        gfx_lores.drawmode_eor(false)
                    }
                    TOOL_BOX -> {
                        gfx_lores.drawmode_eor(true)
                        drawfillrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, eor_color)
                        sys.waitvsync()
                        sys.waitvsync()
                        drawfillrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, eor_color)
                        gfx_lores.drawmode_eor(false)
                    }
                    TOOL_CIRCLE -> {
                        gfx_lores.drawmode_eor(true)
                        circle_radius = radius(mouse_drag_start_x, mouse_drag_start_y, mx, my)
                        uword mdx = mouse_drag_start_x
                        ubyte mdy = lsb(mouse_drag_start_y)
                        gfx_lores.safe_circle(mdx, mdy, circle_radius, eor_color)
                        sys.waitvsync()
                        sys.waitvsync()
                        gfx_lores.safe_circle(mdx, mdy, circle_radius, eor_color)
                        gfx_lores.drawmode_eor(false)
                    }
                    TOOL_DISC -> {
                        gfx_lores.drawmode_eor(true)
                        circle_radius = radius(mouse_drag_start_x, mouse_drag_start_y, mx, my)
                        gfx_lores.safe_disc(mouse_drag_start_x, mouse_drag_start_y, circle_radius, eor_color)
                        sys.waitvsync()
                        sys.waitvsync()
                        gfx_lores.safe_disc(mouse_drag_start_x, mouse_drag_start_y, circle_radius, eor_color)
                        gfx_lores.drawmode_eor(false)
                    }
                    TOOL_FILL -> {
                        ; no action on drag! Fill starts when button released.
                    }
                }
            } else {
                ; no buttons pressed anymore - end the dragging
                ; this usually means we actually draw the final shape now
                ubyte color = color_for_button(dragging_with_button)
                when active_tool {
                    TOOL_LINE -> {
                        gfx_lores.line(mouse_drag_start_x, lsb(mouse_drag_start_y), mx, lsb(my), color)
                    }
                    TOOL_RECT -> {
                        drawrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, color)
                    }
                    TOOL_BOX -> {
                        drawfillrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, color)
                    }
                    TOOL_CIRCLE -> {
                        gfx_lores.safe_circle(mouse_drag_start_x, mouse_drag_start_y, radius(mouse_drag_start_x, mouse_drag_start_y, mx, my), color)
                    }
                    TOOL_DISC -> {
                        gfx_lores.safe_disc(mouse_drag_start_x, mouse_drag_start_y, radius(mouse_drag_start_x, mouse_drag_start_y, mx, my), color)
                    }
                    TOOL_FILL -> {
                        gfx_lores.fill(cx16.r0, cx16.r1L, color)
                    }
                }
                dragging_with_button = 0
            }
        } else {
            if buttons!=0 {
                ; user starts pressing a button, drawing starts
                dragging_with_button = buttons
                mouse_drag_start_x = mx
                mouse_drag_start_y = my
            }
        }
    }

    sub drawrect(uword x1, uword y1, uword x2, uword y2, ubyte color) {
        gfx_lores.rect(min(x1, x2), lsb(min(y1, y2)),
                 1+abs(x2-x1 as word) as uword, 1+abs(y2-y1 as word) as ubyte,
                 color)
    }

    sub drawfillrect(uword x1, uword y1, uword x2, uword y2, ubyte color) {
        gfx_lores.fillrect(min(x1, x2), lsb(min(y1, y2)),
                 1+abs(x2-x1 as word) as uword, 1+abs(y2-y1 as word) as ubyte,
                 color)
    }

    sub radius(uword x1, uword y1, uword x2, uword y2) -> ubyte {
        x1 -= x2
        y1 -= y2
        return sqrt(x1*x1 + y1*y1)
    }

    sub remember_screen() {
        if undo_buffers_amount==0 or stored_undo_buffers==undo_buffers_amount
            return

        ; TODO cycle multiple buffers
        ; for now, we use just 1 buffer.
        ubyte prev_rambank = cx16.getrambank()
        cx16.FB_cursor_position(0, 0)
        ubyte bank
        for bank in 1 to 10 {
            ; copy 10 banks worth of pixels (10 times 24 rows)
            cx16.rambank(bank)
            cx16.FB_get_pixels($a000, 320*24)       ; TODO check that it doesn't overflow
        }
        cx16.rambank(prev_rambank)

        next_undo_buffer = 1
        stored_undo_buffers = 1
    }

    sub reset_undo() {
        if undo_buffers_amount==0
            return
        next_undo_buffer = 0
        stored_undo_buffers = 0
        remember_screen()
    }

    sub undo() {
        if undo_buffers_amount==0 or next_undo_buffer==0
            menu.notification("Undo not available")
        else {
            menu.notification("Undo")
            next_undo_buffer--
            restore_buffer(next_undo_buffer)
            ; TODO cycle multiple buffers
        }
    }

    sub redo() {
        if undo_buffers_amount==0 or next_undo_buffer==stored_undo_buffers
            menu.notification("Redo not available")
        else {
            menu.notification("Redo")
            restore_buffer(next_undo_buffer)
            next_undo_buffer++
            ; TODO cycle multiple buffers
        }
    }

    sub restore_buffer(ubyte buffer) {
        ubyte prev_rambank = cx16.getrambank()
        cx16.FB_cursor_position(0, 0)
        ubyte bank
        for bank in 1 to 10 {
            ; copy 10 banks worth of pixels (10 times 24 rows)
            cx16.rambank(bank)
            cx16.FB_set_pixels($a000, 320*24)       ; TODO this overflows the screen at the end!?
        }
        cx16.rambank(prev_rambank)
    }

    bool coordinates_shown = false

    sub draw_coordinates() {
        str[] tools = [0, "draw", "line", "rectangle", "box", "circle", "disc", "erase", "fill"]
        const ubyte COORDS_BG = 15
        const ubyte COLORS_X = 14
        if coordinates_shown {
            cx16.VERA_L1_CONFIG |= %00001000     ; enable T256C mode for the text layer so we can show all 256 colors
            txt.plot(3,27)
            txt.color(14)
            txt.chrout(18)      ; Reverse on
            txt.print("@ ")
            txt.print_uw(mouse_x)
            txt.chrout(',')
            txt.print_uw(mouse_y)
            repeat COLORS_X-txt.get_column()
                txt.chrout(' ')
            txt.print_ub0(selected_color1)
            txt.print("\x1d\x1d ")
            txt.print_ub0(selected_color2)
            txt.print("\x1d\x1d ")
            txt.print(tools[active_tool])
            repeat 36-txt.get_column()
                txt.chrout(' ')
            txt.chrout(146)      ; Reverse off

            txt.setcc2(COLORS_X+3, 27, 160, selected_color1)
            txt.setcc2(COLORS_X+4, 27, 160, selected_color1)
            txt.setcc2(COLORS_X+9, 27, 160, selected_color2)
            txt.setcc2(COLORS_X+10, 27, 160, selected_color2)
        } else {
            cx16.VERA_L1_CONFIG &= %11110111     ; disable T256C mode again
            txt.plot(3,27)
            repeat 33
                txt.chrout(' ')
        }
    }

    sub show_coordinates(bool show) {
        if menu.active or colors.active
            return
        if show {
            coordinates_shown = true
            draw_coordinates()
            main.enable_text_layer()
        } else {
            if coordinates_shown {
                coordinates_shown = false
                draw_coordinates()
                main.disable_text_layer()
            }
        }
    }
}
