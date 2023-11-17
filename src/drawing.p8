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
    uword mouse_prev_x
    uword mouse_prev_y
    bool mouse_button_pressed
    ubyte undo_buffers_amount
    ubyte next_undo_buffer = 0
    ubyte stored_undo_buffers = 0

    sub init() {
        undo_buffers_amount = (cx16.numbanks()-1)/10 as ubyte       ; each undo buffer requires 10 banks
    }

    sub color_for_button(ubyte buttons) -> ubyte {
        when buttons {
            1 -> return selected_color1
            2 -> return selected_color2
            else -> return 0
        }
    }

    sub mouse(ubyte buttons, uword mx, uword my) {
        if buttons==0
            return

        ubyte color
        uword from_x
        uword from_y

        when active_tool {
            TOOL_DRAW, TOOL_ERASE -> {
                ; TODO: allow user to pick a brush size
                if mouse_button_pressed {
                    ; draw to new position
                    from_x = mouse_prev_x
                    from_y = mouse_prev_y
                    mouse_prev_x = mx
                    mouse_prev_y = my
                    color = 0     ; erase
                    if active_tool==TOOL_DRAW
                        color = color_for_button(buttons)
                    gfx.line(from_x, from_y, mouse_prev_x, mouse_prev_y, color)
                    ;cx16.GRAPH_set_colors(color, 0, 0)
                    ;cx16.GRAPH_draw_line(from_x, from_y, mouse_prev_x, mouse_prev_y)
                } else {
                    ; start new position
                    mouse_prev_x = mx
                    mouse_prev_y = my
                    ;cx16.FB_cursor_position(mx, my)
                    ;cx16.FB_set_pixel(color_for_button(buttons))
                }
            }
            TOOL_LINE -> {
                ; TODO: this is not how lines are supposed to work, but just a first example implementation
                if mouse_button_pressed {
                    ; draw line to current position
                    gfx.line(mouse_prev_x, mouse_prev_y, mx, my, color_for_button(buttons))
                    ; cx16.GRAPH_set_colors(color_for_button(buttons), 0, 0)
                    ; cx16.GRAPH_draw_line(mouse_prev_x, mouse_prev_y, mx, my)
                } else {
                    ; start new position
                    mouse_prev_x = mx
                    mouse_prev_y = my
                }
            }
            TOOL_RECT -> {
                ; TODO: this is not how rectangles are supposed to work, but just a first example implementation
                if mouse_button_pressed {
                    ; draw rectangle to current position
                    gfx.rect(min(mouse_prev_x, mx), min(mouse_prev_y, my),
                             1+abs(mouse_prev_x - mx as word) as uword, 1+abs(mouse_prev_y - my as word) as uword,
                             color_for_button(buttons))
                    ;cx16.GRAPH_set_colors(color_for_button(buttons), 0, 0)
                    ;cx16.GRAPH_draw_rect(min(mouse_prev_x, mx), min(mouse_prev_y, my),
                    ;                     1+abs(mouse_prev_x - mx as word) as uword, 1+abs(mouse_prev_y - my as word) as uword,
                    ;                     0, false)
                } else {
                    ; start new position
                    mouse_prev_x = mx
                    mouse_prev_y = my
                }
            }
            TOOL_BOX -> {
                ; TODO: is this how filled rectangles are supposed to work?
                if mouse_button_pressed {
                    ; draw box to current position
                    gfx.fillrect(min(mouse_prev_x, mx), min(mouse_prev_y, my),
                                 1+abs(mouse_prev_x - mx as word) as uword, 1+abs(mouse_prev_y - my as word) as uword,
                                 color_for_button(buttons))
                    ; color = color_for_button(buttons)
                    ; cx16.GRAPH_set_colors(color, color, 0)
                    ; cx16.GRAPH_draw_rect(min(mouse_prev_x, mx), min(mouse_prev_y, my),
                    ;                      1+abs(mouse_prev_x - mx as word) as uword, 1+abs(mouse_prev_y - my as word) as uword,
                    ;                      0, true)
                } else {
                    ; start new position
                    mouse_prev_x = mx
                    mouse_prev_y = my
                }
            }
            TOOL_CIRCLE -> {
                ; TODO: this is not how circles are supposed to work, but just a first example implementation
                if mouse_button_pressed {
                    ; draw disc to current position
                    color = color_for_button(buttons)
                    gfx.safe_circle(mouse_prev_x, mouse_prev_y, radius(mouse_prev_x, mouse_prev_y, mx, my), color_for_button(buttons))
                } else {
                    ; start new position
                    mouse_prev_x = mx
                    mouse_prev_y = my
                }
            }
            TOOL_DISC -> {
                ; TODO: is this how filled circles are supposed to work?
                if mouse_button_pressed {
                    ; draw disc to current position
                    color = color_for_button(buttons)
                    gfx.safe_disc(mouse_prev_x, mouse_prev_y, radius(mouse_prev_x, mouse_prev_y, mx, my), color_for_button(buttons))
                } else {
                    ; start new position
                    mouse_prev_x = mx
                    mouse_prev_y = my
                }
            }
            TOOL_FILL -> {
                gfx.fill(cx16.r0, cx16.r1, color_for_button(buttons))
            }
        }
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
