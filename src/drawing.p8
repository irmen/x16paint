; These are the actual drawing routines.

%import gfx2

drawing {
    const ubyte TOOL_DRAW = 0
    const ubyte TOOL_RECT = 1
    const ubyte TOOL_CIRCLE = 2
    const ubyte TOOL_ERASE = 3         ; keep this, even though middle mouse button is the same. Usability / key shortcut reasons.
    const ubyte TOOL_LINE = 4
    const ubyte TOOL_BOX = 5
    const ubyte TOOL_DISC = 6
    const ubyte TOOL_FILL = 7

    ubyte active_tool = TOOL_DRAW
    ubyte selected_color1 = 5
    ubyte selected_color2 = 2
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

        when active_tool {
            TOOL_DRAW, TOOL_ERASE -> {
                ; TODO: allow user to pick a brush size
                if mouse_button_pressed {
                    ; draw line to new position
                    uword from_x = mouse_prev_x
                    uword from_y = mouse_prev_y
                    mouse_prev_x = cx16.r0
                    mouse_prev_y = cx16.r1
                    ubyte color = 0     ; erase
                    if active_tool==TOOL_DRAW
                        color = color_for_button(buttons)
                    cx16.GRAPH_set_colors(color, 0, 0)
                    cx16.GRAPH_draw_line(from_x, from_y, mouse_prev_x, mouse_prev_y)
                } else {
                    ; start new position
                    mouse_prev_x = cx16.r0
                    mouse_prev_y = cx16.r1
                    cx16.FB_cursor_position(cx16.r0, cx16.r1)
                    cx16.FB_set_pixel(color_for_button(buttons))
                    mouse_button_pressed = true
                }
            }
            TOOL_RECT -> { /* todo */ }
            TOOL_CIRCLE -> { /* todo */ }
            TOOL_LINE -> { /* todo */ }
            TOOL_BOX -> { /* todo */ }
            TOOL_DISC -> { /* todo */ }
            TOOL_FILL -> {
                gfx2.fill(cx16.r0, cx16.r1, color_for_button(buttons))
            }
        }
    }
}
