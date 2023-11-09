; These are the actual drawing routines.

%import gfx2

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
    bool magnification = false
    uword mouse_prev_x
    uword mouse_prev_y
    bool mouse_button_pressed

    sub init() {
        gfx2.init_mode(1)
    }

    sub clear() {
        cx16.GRAPH_set_colors(selected_color1,0,selected_color2)
        cx16.GRAPH_clear()
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
                    cx16.GRAPH_set_colors(color, 0, 0)
                    cx16.GRAPH_draw_line(from_x, from_y, mouse_prev_x, mouse_prev_y)
                } else {
                    ; start new position
                    mouse_prev_x = mx
                    mouse_prev_y = my
                    cx16.FB_cursor_position(mx, my)
                    cx16.FB_set_pixel(color_for_button(buttons))
                }
            }
            TOOL_LINE -> {
                ; TODO: this is not how lines are supposed to work, but just a first example implementation
                if mouse_button_pressed {
                    ; draw line to current position
                    cx16.GRAPH_set_colors(color_for_button(buttons), 0, 0)
                    cx16.GRAPH_draw_line(mouse_prev_x, mouse_prev_y, mx, my)
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
                    cx16.GRAPH_set_colors(color_for_button(buttons), 0, 0)
                    cx16.GRAPH_draw_rect(min(mouse_prev_x, mx), min(mouse_prev_y, my),
                                         1+abs(mouse_prev_x - mx as word) as uword, 1+abs(mouse_prev_y - my as word) as uword,
                                         0, false)
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
                    color = color_for_button(buttons)
                    cx16.GRAPH_set_colors(color, color, 0)
                    cx16.GRAPH_draw_rect(min(mouse_prev_x, mx), min(mouse_prev_y, my),
                                         1+abs(mouse_prev_x - mx as word) as uword, 1+abs(mouse_prev_y - my as word) as uword,
                                         0, true)
                } else {
                    ; start new position
                    mouse_prev_x = mx
                    mouse_prev_y = my
                }
            }
            TOOL_CIRCLE -> {
                ; TODO circle
            }
            TOOL_DISC -> {
                ; TODO filled circle
            }
            TOOL_FILL -> {
                gfx2.fill(cx16.r0, cx16.r1, color_for_button(buttons))
            }
        }
    }
}
