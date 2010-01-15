namespace Awn
{
  // entry-point prototypes
  public static delegate bool AppletInitFunc (Awn.Applet applet);
  public static delegate unowned Awn.Applet AppletInitPFunc (string canonical_name, string uid, int panel_id);
          
  public class Applet: Gtk.Plug, PanelConnector
  {
    private const string AWN_SETTINGS_APP = "awn-settings";

    private DBus.Connection _connection;

    private int origin_x;
    private int origin_y;
    private int pos_x;
    private int pos_y;
    private int panel_width;
    private int panel_height;
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
    
    public string display_name { get; set; }

    public bool show_all_on_embed { get; set; default = true; }

    public bool quit_on_delete { get; set; default = true; }

    public int panel_id { get; set construct; }

    private dynamic DBus.Object _panel_proxy;
    public DBus.Object panel_proxy { get { return _panel_proxy; } }

    public string uid { get; set construct; }

    private int64 _panel_xid;
    public int64 panel_xid { get { return this._panel_xid; } }

    private Gtk.PositionType _position;
    public new Gtk.PositionType position
    {
      get
      {
        return this._position;
      }
      set
      {
        this._position = value;
        this.position_changed (this._position);
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

    private int _offset;
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
      // FIXME!
      return this._offset;
    }

    private int _size;
    public int size
    {
      get
      {
        return this._size;
      }
      set
      {
        this._size = value;
        this.size_changed (this._size);
      }
    }

    public int max_size { get; set; }

    public PathType path_type { get; set; }

    public float offset_modifier { get; set; }

    public void set_behavior (AppletFlags behavior)
    {
      // FIXME!
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
    public signal void flags_changed (int flags);

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

      Utils.ensure_transparent_bg (this);
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
      Gtk.Widget item = new Gtk.ImageMenuItem.with_label ("Dock Preferences");

      return item;
    }

    public Gtk.Widget create_about_item (
      string copyright, int license, string version, string? comments,
      string? website, string? website_label, string? icon_name,
      string? translator_credits, [CCode (array_length = false, array_null_terminated = true)] string[]? authors, [CCode (array_length = false, array_null_terminated = true)] string[]? artists, [CCode (array_length = false, array_null_terminated = true)] string[]? documenters)
    {
      Gtk.AboutDialog dialog = new Gtk.AboutDialog ();

      return dialog;
    }

    public Gtk.Widget create_about_item_simple (string copyright,
                                                int license,
                                                string version)
    {
      return this.create_about_item (copyright, license, version, 
                                     null, null, null, null,
                                     null, null, null, null);
    }

    public Gtk.Widget create_default_menu ()
    {
      return new Gtk.Menu ();
    }

    public Gdk.NativeWindow docklet_request (int min_size,
                                             bool shrink, bool expand)
    {
      int64 window_id = this.bus_docklet_request (min_size, shrink, expand);

      return (Gdk.NativeWindow) window_id;
    }
  }
}
