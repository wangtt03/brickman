/*
 * brickdm -- Brick Display Manager for LEGO Mindstorms EV3/ev3dev
 *
 * Copyright (C) 2014 David Lechner <david@lechnology.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * brickdm.vala:
 *
 * This is the main program. Functions in this file include:
 *
 * - Grabbing a free console for displaying graphics
 * - Handling console switching
 * - Initializing library data structures
 * - Processing the main event loop
 */

using Gee;
using Posix;
using Linux.Console;
using Linux.VirtualTerminal;

errordomain ConsoleError {
    MODE
}

namespace BrickDisplayManager
{
    static MainLoop mainLoop;
    static int vtfd;
    static int vtnum;
    static bool dirty = true;
    static bool statusbar_visible = true;
    static U8g.Graphics u8g;
    static Deque<RootInfo> root_stack;

    const string DEFAULT_ROOT_ELEMENT_FORMAT = "-1|1W64H56";

    [Compact]
    public class RootInfo {
        public unowned M2tk.Element element;
        public uchar value;
        public const uchar MAX_VALUE = (uchar)(-1);
    }

    static bool HandleSIGTERM()
    {
        mainLoop.quit();
        return true;
    }

    /**
     * SIGHUP is used for console switching.
     *
     * Checking the result of the ioctl is important to make sure that
     * someone really has requested to switch consoles and that the
     * SIGHUP did not come from something else.
     */
    static bool HandleSIGHUP()
    {
        GLib.assert(mainLoop.get_context().is_owner());
        Linux.VirtualTerminal.Stat vtstat;
        if (Curses.isendwin()) {
            if (ioctl(vtfd, VT_GETSTATE, out vtstat) == 0) {
                if (vtstat.v_active == vtnum) {
                    // acquire console
                    ioctl(vtfd, VT_RELDISP, VT_ACKACQ);
                    Curses.refresh();
                    dirty = true;
                }
            }
        } else {
            // release console
            if (ioctl(vtfd, VT_RELDISP, 1) == 0)
              Curses.endwin();
        }
        return true;
    }

    static bool HandleDrawTimer()
    {
        if (!Curses.isendwin()) {
            M2tk.check_key();
            dirty |= M2tk.handle_key();
            if (dirty) {
               u8g.begin_draw();
               M2tk.draw();
               if (statusbar_visible) {
                  /* M2tk.draw() can change colors on us */
                  u8g.set_default_background_color();
                  u8g.set_default_forground_color();
                  //brickdm_power_draw_battery_status();
                  u8g.draw_line(0, 15, u8g.get_width(), 15);
             }
             u8g.end_draw();
             dirty = false;
         }
      }
      return true;
    }

    static int main (string[] args)
    {
        vtfd = open("/dev/tty0", O_RDWR, 0);
        if (vtfd < 0) {
            critical("could not open /dev/tty0 (error: %d)", -vtfd);
            return 1;
        }
        Linux.VirtualTerminal.Stat vtstat;
        if (ioctl(vtfd, VT_GETSTATE, out vtstat) < 0) {
            critical("tty is not virtual console");
            return 1;
        }
        if (ioctl(vtfd, VT_OPENQRY, out vtnum) < 0) {
            critical("no free virtual consoles");
            return 1;
        }
        var device = "/dev/tty" + vtnum.to_string();
        if (access(device, (W_OK|R_OK)) < 0) {
            critical("insufficient permission on tty");
            return 1;
        }
        ioctl(vtfd, KDSETMODE, TerminalMode.TEXT);
        ioctl(vtfd, VT_ACTIVATE, vtnum);
        ioctl(vtfd, VT_WAITACTIVE, vtnum);
        close(vtfd);

        vtfd = open(device, O_RDWR, 0);
        var vtIn = FileStream.fdopen(vtfd, "r");
        var vtOut = FileStream.fdopen(vtfd, "w");
        var term = new Curses.Screen("linux", vtIn, vtOut);

        int success = 0;
        var mode = Mode() {
            mode = (char)VT_PROCESS,
            relsig = (int16)SIGHUP,
            acqsig = (int16)SIGHUP
        };
        try {
            if (ioctl(vtfd, KDSETMODE, TerminalMode.GRAPHICS) < 0)
                  throw new ConsoleError.MODE("Could not set virtual console to KD_GRAPHICS mode.");
            debug("set to graphics mode");
            if (ioctl(vtfd, VT_SETMODE, ref mode) < 0)
                  throw new ConsoleError.MODE("Could not set virtual console to VT_PROCESS mode.");
            Unix.signal_add(SIGHUP, HandleSIGHUP);
            Unix.signal_add(SIGTERM, HandleSIGTERM);
            Unix.signal_add(SIGINT, HandleSIGTERM);

            u8g = new U8g.Graphics();
            u8g.init(U8g.Device.linux_framebuffer);
            var home = new Home();
            debug("root_element: %p", home.root_element);
            M2tk.init(home.root_element, M2tkEventSource, M2tkEventHandler,
                M2tk.U8gBoxShadowFrameGraphicsHandler);
            M2tk.set_u8g(u8g, M2tk.IconType.BOX);
            M2tk.set_font(M2tk.FontIndex.F0, U8g.Font.x11_7x13);
            M2tk.set_font(M2tk.FontIndex.F1, U8g.Font.m2tk_icon_9);
            M2tk.set_u8g_additional_text_x_border(3);

            mainLoop = new MainLoop();
            var drawTimer = new TimeoutSource(50);
            drawTimer.set_callback(HandleDrawTimer);
            drawTimer.attach(mainLoop.get_context());
            mainLoop.run();
            u8g.stop();
        } catch (ConsoleError e) {
            critical(e.message);
            success = 1;
        }

        ioctl(vtfd, KDSETMODE, TerminalMode.TEXT);
        mode.mode = (char)VT_AUTO;
        ioctl(vtfd, VT_SETMODE, ref mode);

        if (!Curses.isendwin()) {
            Curses.endwin();
            ioctl(vtfd, VT_ACTIVATE, vtstat.v_active);
            ioctl(vtfd, VT_WAITACTIVE, vtstat.v_active);
        }
        ioctl(vtfd, VT_DISALLOCATE, vtnum);

        close(vtfd);

        return success;
    }
}
