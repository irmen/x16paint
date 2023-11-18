; routines to load and save "BMX" files (commander X16 bitmap format)
; TODO: move this into prog8 cx16 library itself

%import diskio

bmx {

    ubyte[32] header
    str FILEID = petscii:"bmx"

    ubyte bitsperpixel          ; consider using set_bpp() when setting this
    ubyte vera_colordepth       ; consider using set_vera_colordepth() when setting this
    uword width
    uword height
    ubyte border
    ubyte palette_entries
    ubyte palette_start

    uword error_message         ; pointer to error message, or 0 if all ok
    uword max_width = 0         ; should you want load() to check for this
    uword max_height = 0        ; should you want load() to check for this

    sub set_bpp(ubyte bpp) {
        bitsperpixel = bpp
        vera_colordepth = 0
        when bpp {
            2 -> vera_colordepth = 1
            4 -> vera_colordepth = 2
            8 -> vera_colordepth = 3
        }
    }

    sub set_vera_colordepth(ubyte depth) {
        vera_colordepth = depth
        bitsperpixel = 1 << depth
    }

    sub load(ubyte drivenumber, str filename, ubyte vbank, uword vaddr, uword screen_width) -> bool {
        ; Loads a BMX bitmap image and palette into vram.
        ; Parameters:
        ; the drive number and filename to load,
        ; the vram bank and address where the bitmap data should go,
        ; and the width of the current screen mode (can be 0 if you know no padding is needed).
        ; You can set the max_width and max_height variables first, if you want this routine to check those.
        ; Returns: success status, if false, error_message points to the error message string.
        error_message = 0
        ubyte old_drivenumber = diskio.drivenumber
        diskio.drivenumber = drivenumber
        if diskio.f_open(filename) {
            diskio.reset_read_channel()
            if load_header() {
                if parse_header() {
                    if max_width and width>max_width {
                        error_message = "image too large"
                        goto load_end
                    }
                    if screen_width and width>screen_width {
                        error_message = "image too large"
                        goto load_end
                    }
                    if max_height and height>max_height {
                        error_message = "image too large"
                        goto load_end
                    }
                    if load_palette() {
                        if load_bitmap(vbank, vaddr, screen_width)
                            goto load_end
                        else
                            error_message = "bitmap error"
                    } else
                        error_message = "palette error"
                } else
                    error_message = "invalid bmx file"
            } else
                error_message = "invalid bmx file"
        } else
            error_message = diskio.status()

load_end:
        diskio.f_close()
        diskio.drivenumber = old_drivenumber
        return error_message==0
    }

    ; TODO supply image width & height too!!! And drive number, and file name!
    sub save(ubyte vbank, uword vaddr, uword screen_width) -> bool {
        ; Save bitmap and palette data from vram into a BMX file. Returns success t
        ; You supply vram bank and address to read the bitmap data from, and the width of the current screen mode.
        ; Returns: success status, if false, error_message points to the error message string.
        width = min(width, screen_width)
        error_message = 0
        if save_header() {
            if save_palette() {
                if save_bitmap(vbank, vaddr, screen_width) {
                    return true
                } else
                    error_message = "bitmap error"
            } else
                error_message = "palette error"
        } else
            error_message = "header error"
        return false
    }

; ------------------- helper routines -------------------------

    sub load_header() -> bool {
        ; load a BMX header from the currently active input file
        for cx16.r0L in 0 to sizeof(header)-1 {
            header[cx16.r0L] = cbm.CHRIN()
        }
        return not cbm.READST()
    }

    sub parse_header() -> bool {
        if header[0]==FILEID[0] and header[1]==FILEID[1] and header[2]==FILEID[2] {
            if header[3]==1 {       ; only version 1 supported for now
                bitsperpixel = header[4]
                vera_colordepth = header[5]
                width = peekw(&header+6)
                height = peekw(&header+8)
                border = header[10]
                palette_entries = header[11]
                palette_start = header[12]
                return true
            }
        }
        return false
    }

    sub load_palette() -> bool {
        ; load palette data from the currently active input file
        uword palette_addr = $fa00
        repeat palette_start {
            void cbm.CHRIN()
            void cbm.CHRIN()
            palette_addr += 2
        }
        cx16.r0L = palette_entries
        cx16.vaddr(1, palette_addr, 0, 1)
        do {
            cx16.VERA_DATA0 = cbm.CHRIN()
            cx16.VERA_DATA0 = cbm.CHRIN()
            cx16.r0L--
        } until cx16.r0L==0
        return not cbm.READST()
    }

    sub load_bitmap(ubyte vbank, uword vaddr, uword screenwidth) -> bool {
        ; load contiguous bitmap into vram from the currently active input file
        cx16.vaddr(vbank, vaddr, 0, 1)
        cx16.r1 = bytes_per_scanline()
        cx16.r2 = pad_bytes_per_scanline(screenwidth)
        ; TODO use MACPTR
        repeat height {
            repeat cx16.r1 {
                cx16.VERA_DATA0  = cbm.CHRIN()
            }
            repeat cx16.r2 {
                cx16.VERA_DATA0 = 0     ; pad out if image width < screen width
            }
        }
        return cbm.READST() & $40    ; eof?
    }

    sub save_header() -> bool {
        ; save out the BMX header to the currently active output file
        build_header()
        for cx16.r0L in 0 to sizeof(header)-1 {
            cbm.CHROUT(header[cx16.r0L])
        }
        return not cbm.READST()
    }

    sub save_palette() -> bool {
        ; save full palette straight out of vram to the currently active output file
        cx16.vaddr(1, $fa00, 0, 1)
        ; TODO use MCIOUT
        repeat 512
            cbm.CHROUT(cx16.VERA_DATA0)
        return not cbm.READST()
    }

    sub save_bitmap(ubyte vbank, uword vaddr, uword screenwidth) -> bool {
        ; save contiguous bitmap from vram to the currently active output file
        cx16.vaddr(vbank, vaddr, 0, 1)
        ; TODO use MCIOUT
        cx16.r1 = bytes_per_scanline()
        cx16.r2 = pad_bytes_per_scanline(screenwidth)
        repeat height {
            repeat cx16.r1
                cbm.CHROUT(cx16.VERA_DATA0)
            repeat cx16.r2 {
                %asm {{
                    lda  cx16.VERA_DATA0        ; just read away padding bytes
                }}
            }
        }
        return not cbm.READST()
    }

    sub bytes_per_scanline() -> uword {
        when bitsperpixel {
            1 -> return width/8
            2 -> return width/4
            4 -> return width/2
            8 -> return width
            else -> return 0
        }
    }

    sub pad_bytes_per_scanline(uword screenwidth) -> uword {
        if width<screenwidth {
            screenwidth-=width
            when bitsperpixel {
                1 -> return screenwidth/8
                2 -> return screenwidth/4
                4 -> return screenwidth/2
                8 -> return screenwidth
            }
        }
        return 0
    }

    sub build_header() {
        ; build the internal BMX header structure
        ; normally you don't have to call this yourself
        sys.memset(header, sizeof(header), 0)
        header[0] = FILEID[0]
        header[1] = FILEID[1]
        header[2] = FILEID[2]
        header[3] = 1        ; version 1
        header[4] = bitsperpixel
        header[5] = vera_colordepth
        header[6] = lsb(width)
        header[7] = msb(width)
        header[8] = lsb(height)
        header[9] = msb(height)
        header[10] = border
        header[11] = palette_entries
        header[12] = palette_start
    }
}