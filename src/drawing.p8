; These are the actual drawing routines.

%import gfxroutines

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
        gfx.eor_mode = false
        ubyte circle_radius

        if dragging_with_button {
            eor_color += 17
            if buttons {
                ; user is dragging the mouse with button(s) pressed
                ; this usually means whatever is drawn is still temporary
                when active_tool {
                    TOOL_DRAW, TOOL_ERASE -> {
                        ; immediately draw the line while dragging
                        ; TODO: allow user to pick a brush size
                        gfx.line(mouse_drag_start_x, mouse_drag_start_y, mx, my, color_for_button(buttons))
                        mouse_drag_start_x=mx
                        mouse_drag_start_y=my
                    }
                    TOOL_LINE -> {
                        gfx.eor_mode = true
                        gfx.line(mouse_drag_start_x, mouse_drag_start_y, mx, my, eor_color)
                        sys.waitvsync()
                        sys.waitvsync()
                        gfx.line(mouse_drag_start_x, mouse_drag_start_y, mx, my, eor_color)
                        gfx.eor_mode = false
                    }
                    TOOL_RECT -> {
                        gfx.eor_mode = true
                        drawrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, eor_color)
                        sys.waitvsync()
                        sys.waitvsync()
                        drawrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, eor_color)
                        gfx.eor_mode = false
                    }
                    TOOL_BOX -> {
                        gfx.eor_mode = true
                        drawfillrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, eor_color)
                        sys.waitvsync()
                        sys.waitvsync()
                        drawfillrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, eor_color)
                        gfx.eor_mode = false
                    }
                    TOOL_CIRCLE -> {
                        gfx.eor_mode = true
                        circle_radius = radius(mouse_drag_start_x, mouse_drag_start_y, mx, my)
                        gfx.safe_circle(mouse_drag_start_x, mouse_drag_start_y, circle_radius, eor_color)
                        sys.waitvsync()
                        sys.waitvsync()
                        gfx.safe_circle(mouse_drag_start_x, mouse_drag_start_y, circle_radius, eor_color)
                        gfx.eor_mode = false
                    }
                    TOOL_DISC -> {
                        gfx.eor_mode = true
                        circle_radius = radius(mouse_drag_start_x, mouse_drag_start_y, mx, my)
                        gfx.safe_disc(mouse_drag_start_x, mouse_drag_start_y, circle_radius, eor_color)
                        sys.waitvsync()
                        sys.waitvsync()
                        gfx.safe_disc(mouse_drag_start_x, mouse_drag_start_y, circle_radius, eor_color)
                        gfx.eor_mode = false
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
                        gfx.line(mouse_drag_start_x, mouse_drag_start_y, mx, my, color)
                    }
                    TOOL_RECT -> {
                        drawrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, color)
                    }
                    TOOL_BOX -> {
                        drawfillrect(mouse_drag_start_x, mouse_drag_start_y, mx, my, color)
                    }
                    TOOL_CIRCLE -> {
                        gfx.safe_circle(mouse_drag_start_x, mouse_drag_start_y, radius(mouse_drag_start_x, mouse_drag_start_y, mx, my), color)
                    }
                    TOOL_DISC -> {
                        gfx.safe_disc(mouse_drag_start_x, mouse_drag_start_y, radius(mouse_drag_start_x, mouse_drag_start_y, mx, my), color)
                    }
                    TOOL_FILL -> {
                        gfx.fill(cx16.r0, cx16.r1L, color)
                    }
                }
                dragging_with_button = 0
            }
        } else {
            if buttons {
                ; user starts pressing a button, drawing starts
                dragging_with_button = buttons
                mouse_drag_start_x = mx
                mouse_drag_start_y = my
            }
        }
    }

    sub drawrect(uword x1, uword y1, uword x2, uword y2, ubyte color) {
        gfx.rect(min(x1, x2), lsb(min(y1, y2)),
                 1+abs(x2-x1 as word) as uword, 1+abs(y2-y1 as word) as ubyte,
                 color)
    }

    sub drawfillrect(uword x1, uword y1, uword x2, uword y2, ubyte color) {
        gfx.fillrect(min(x1, x2), lsb(min(y1, y2)),
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
            notification.show("Undo not available")
        else {
            notification.show("Undo")
            next_undo_buffer--
            restore_buffer(next_undo_buffer)
            ; TODO cycle multiple buffers
        }
    }

    sub redo() {
        if undo_buffers_amount==0 or next_undo_buffer==stored_undo_buffers
            notification.show("Redo not available")
        else {
            notification.show("Redo")
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
}
