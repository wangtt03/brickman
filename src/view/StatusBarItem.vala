/*
 * brickman -- Brick Manager for LEGO Mindstorms EV3/ev3dev
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
 * StatusBarItem.vala:
 *
 * Base class for items shown in StatusBar
 */

using U8g;

namespace BrickManager {
    public abstract class StatusBarItem : Object {
        public const ushort HEIGHT = 9;

        public virtual bool dirty { get; set; default = true; }
        public abstract ushort draw(Graphics u8g, ushort x, StatusBar.Align align);
    }
}
