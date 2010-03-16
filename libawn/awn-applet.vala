/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Awn
{
  // entry-point prototypes
  public static delegate bool AppletInitFunc (Awn.Applet applet);
  public static delegate unowned Awn.Applet AppletInitPFunc (string canonical_name, string uid, int panel_id);
          
  public class Applet: Gtk.Plug, PanelConnector
  {
    private const string SETTINGS_APP = "awn-settings";

    private DBus.Connection _connection;

    private int origin_x = 0;
    private int origin_y = 0;
    private int pos_x = 0;
    private int pos_y = 0;
    private int panel_width = 0;
    private int panel_height = 0;
    private uint menu_inhibit_cookie = 0;
    private AppletFlags behavior_flags;

    private string _canonical_name;
    public string canonical_name
    {
      get
      {
        return this._canonical_name;
      }
      construct
      {
        string name = value.down ();
        name.canon ("abcdefghijklmnopqrstuvwxyz0123456789-", '-');
        this._canonical_name = (owned)name;
        warn_if_fail (_canonical_name.len () > 0);
      }
    }
    
    public string display_name { get; set; default = null; }

    public bool show_all_on_embed { get; set; default = true; }

    public bool quit_on_delete { get; set; default = true; }

    public int panel_id { get; set construct; }

    private dynamic DBus.Object _panel_proxy;
    public DBus.Object panel_proxy { get { return _panel_proxy; } }

    public string uid { get; set construct; }

    private int64 _panel_xid;
    public int64 panel_xid { get { return this._panel_xid; } }

    private Gtk.PositionType _position = Gtk.PositionType.BOTTOM;
    public new Gtk.PositionType position
    {
      get
      {
        return this._position;
      }
      set
      {
        if (this._position != value)
        {
          this._position = value;
          this.position_changed (this._position);
        }
      }
    }

    // compatibility methods
    public Gtk.PositionType get_pos_type ()
    {
      return this._position;
    }

    public void set_pos_type (Gtk.PositionType pos_type)
    {
      this.position = pos_type;
    }

    private int _offset = 0;
    public int offset
    {
      get
      {
        return this._offset;
      }
      set
      {
        if (this._offset != value)
        {
          this._offset = value;
          this.offset_changed (this._offset);
        }
      }
    }

    public int get_offset_at (int x, int y)
    {
      float temp = Utils.get_offset_modifier_by_path_type (this._path_type,
                                                           this._position,
                                                           this._offset,
                                                           this.offset_modifier,
                                                           this.pos_x + x,
                                                           this.pos_y + y,
                                                           this.panel_width,
                                                           this.panel_height);
      return (int)temp;
    }

    private int _size = 48;
    public int size
    {
      get
      {
        return this._size;
      }
      set
      {
        if (this._size != value)
        {
          this._size = value;
          this.size_changed (this._size);
        }
      }
    }

    public int max_size { get; set; }

    private PathType _path_type = PathType.LINEAR;
    public PathType path_type
    {
      get
      {
        return this._path_type;
      }
      set
      {
        if (this._path_type != value)
        {
          this._path_type = value;
          this.offset_changed (this._offset);
        }
      }
    }


    public float offset_modifier { get; set; default = 1.0f; }

    public void set_behavior (AppletFlags behavior)
    {
      this.behavior_flags = behavior;

      this.bus_set_behavior (behavior);
    }

    public int get_behavior ()
    {
      return this.behavior_flags;
    }

    /* signals */
    public signal void position_changed (Gtk.PositionType pos_type);
    public signal void offset_changed (int offset);
    public signal void size_changed (int size);
    public signal void origin_changed (Gdk.Rectangle rect);

    public Applet (string canonical_name, string uid, int panel_id)
    {
      Object (canonical_name: canonical_name, uid: uid, panel_id: panel_id);
    }

    private void on_embedded ()
    {
      if (this.show_all_on_embed)
      {
        this.show_all ();
      }
    }

    public override void constructed ()
    {
      //base.constructed (); // crashes

      this._connection = DBus.Bus.get (DBus.BusType.SESSION);
      this.connect (this._connection, out this._panel_proxy);

      this.set_app_paintable (true);

      unowned Gdk.Screen screen = this.get_screen ();
      unowned Gdk.Colormap? colormap = screen.get_rgba_colormap ();

      if (colormap == null) colormap = screen.get_rgb_colormap ();

      this.set_colormap (colormap);

      Signal.connect (this, "embedded", (Callback) this.on_embedded, null);
      this.delete_event.connect ( (w) =>
      {
        if (this.quit_on_delete)
        {
          Gtk.main_quit ();
          return true;
        }
        return false;
      });

      Utils.ensure_transparent_bg (this);

      Gdk.Atom atom = Gdk.Atom.intern_static_string ("_AWN_APPLET_POS_CHANGE");
      Gdk.add_client_message_filter (atom, this.on_client_message);
    }

    private Gdk.FilterReturn on_client_message (Gdk.XEvent gdk_xevent,
                                                Gdk.Event event)
    {
      unowned Gdk.Window? window = this.get_window ();

      if (window == null) return Gdk.FilterReturn.CONTINUE;

      // casting Gdk.Event to X.Event requires these incantations
      Gdk.XEvent* xe_ptr = &gdk_xevent;
      X.Event* xe = (X.Event*)xe_ptr;

      int pos_x = (int)xe->xclient.data.l[0];
      int pos_y = (int)xe->xclient.data.l[1];
      int panel_w = (int)xe->xclient.data.l[2];
      int panel_h = (int)xe->xclient.data.l[3];

      if (this.pos_x != pos_x || this.pos_y != pos_y ||
          this.panel_width != panel_w || this.panel_height != panel_h)
      {
        this.pos_x = pos_x;
        this.pos_y = pos_y;
        this.panel_width = panel_w;
        this.panel_height = panel_h;

        if (this.path_type != PathType.LINEAR)
        {
          this.offset_changed (this._offset);
        }
      }

      int x, y;
      window.get_origin (out x, out y);

      if (this.origin_x != x || this.origin_y != y)
      {
        this.origin_x = x;
        this.origin_y = y;

        Gdk.Rectangle rect = Gdk.Rectangle ();
        rect.x = x;
        rect.y = y;

        this.origin_changed (rect);
      }

      return Gdk.FilterReturn.REMOVE;
    }

    public void property_changed (string prop_name, Value value)
    {
      switch (prop_name)
      {
        case "Position":
          this.set_property ("position", value);
          break;
        case "Size":
          this.set_property ("size", value);
          break;
        case "Offset":
          this.set_property ("offset", value);
          break;
        case "MaxSize":
          this.set_property ("max-size", value);
          break;
        case "PanelXid":
          this._panel_xid = value.get_int64 ();
          break;
        case "PathType":
          this.set_property ("path-type", value);
          break;
        case "OffsetModifier":
          this.set_property ("offset-modifier", value);
          break;
        default:
          warning ("Unhandled property name: %s", prop_name);
          break;
      }
    }

    public static Gtk.Widget create_pref_item ()
    {
      Gtk.ImageMenuItem item;
      item = new Gtk.ImageMenuItem.with_label ("Dock Preferences"); // FIXME: i18n

      item.always_show_image = true;
      item.set_image (new Gtk.Image.from_icon_name ("avant-window-navigator",
                                                    Gtk.IconSize.MENU));
      item.show ();
      item.activate.connect ( (w) =>
      {
        Process.spawn_command_line_async (SETTINGS_APP);
      });

      return item;
    }

    public Gtk.Widget? create_about_item (
      string copyright, AppletLicense license, string version,
      string? comments, string? website, string? website_label,
      string? icon_name, string? translator_credits, [CCode (array_length = false, array_null_terminated = true)] string[]? authors, [CCode (array_length = false, array_null_terminated = true)] string[]? artists, [CCode (array_length = false, array_null_terminated = true)] string[]? documenters)
    {
      return_val_if_fail (copyright != null && copyright.length > 8, null);

      Gtk.AboutDialog dialog = new Gtk.AboutDialog ();

      unowned string applet_name;
      if (this.display_name != null)
      {
        applet_name = this.display_name;
      }
      else
      {
        applet_name = this.canonical_name;
      }

      dialog.set_copyright (copyright);

      switch (license)
      {
        case AppletLicense.GPLV2:
          dialog.set_license ("GPLv2");
          break;
        case AppletLicense.GPLV3:
          dialog.set_license ("GPLv3");
          break;
        case AppletLicense.LGPLV2_1:
          dialog.set_license ("LGPLv2.1");
          break;
        case AppletLicense.LGPLV3:
          dialog.set_license ("LGPLv3");
          break;
        default:
          warning ("License not set!");
          break;
      }

      dialog.set_program_name (applet_name);

      if (version != null)
      {
        dialog.set_version (version);
      }

      if (comments != null)
      {
        dialog.set_comments (comments);
      }

      if (website != null)
      {
        dialog.set_website (website);
      }

      if (website_label != null)
      {
        dialog.set_website_label (website_label);
      }

      if (icon_name == null)
      {
        icon_name = "stock_about";
      }

      dialog.set_logo_icon_name (icon_name);
      Gdk.Pixbuf pixbuf = Gtk.IconTheme.get_default ().load_icon (icon_name, 64, 0);
      if (pixbuf != null)
      {
        dialog.set_icon (pixbuf);
      }

      if (translator_credits != null)
      {
        dialog.set_translator_credits (translator_credits);
      }

      if (authors != null)
      {
        dialog.set_authors (authors);
      }

      if (artists != null)
      {
        dialog.set_artists (artists);
      }

      if (documenters != null)
      {
        dialog.set_documenters (documenters);
      }

      dialog.response.connect ( (d, response) =>
      {
        d.hide ();
      });
      Signal.connect (dialog, "delete-event", 
                      (Callback) Gtk.Widget.hide_on_delete, null);

      string item_text = "About %s".printf (applet_name);
      Gtk.ImageMenuItem item = new Gtk.ImageMenuItem.with_label (item_text);
      item.set_image (new Gtk.Image.from_stock (Gtk.STOCK_ABOUT,
                                                Gtk.IconSize.MENU));
      item.always_show_image = true;

      item.show ();
      item.activate.connect ( (i) =>
      {
        dialog.show_all ();
      });
      item.destroy_event.connect ( (i) =>
      {
        dialog.destroy ();
        return false;
      });

      return item;
    }

    public Gtk.Widget? create_about_item_simple (string copyright,
                                                 AppletLicense license,
                                                 string version)
    {
      return this.create_about_item (copyright, license, version, 
                                     null, null, null, null,
                                     null, null, null, null);
    }

    public Gtk.Widget create_default_menu ()
    {
      Gtk.Menu menu = new Gtk.Menu ();

      /* Inhibit autohide when the menu is shown */
      menu.show.connect ((m) =>
      {
        if (menu_inhibit_cookie == 0)
        {
          menu_inhibit_cookie = inhibit_autohide ("Displaying applet menu");
        }
      });
      menu.hide.connect ((m) =>
      {
        if (menu_inhibit_cookie != 0)
        {
          uninhibit_autohide (menu_inhibit_cookie);
          menu_inhibit_cookie = 0;
        }
      });

      menu.append (this.create_pref_item () as Gtk.MenuItem);

      Gtk.MenuItem separator = new Gtk.SeparatorMenuItem ();
      separator.show ();
      menu.append (separator);

      return menu;
    }

    public Gdk.NativeWindow docklet_request (int min_size,
                                             bool shrink, bool expand)
    {
      int64 window_id = this.bus_docklet_request (min_size, shrink, expand);

      return (Gdk.NativeWindow) window_id;
    }
  }
}
