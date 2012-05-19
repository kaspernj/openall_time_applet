class Openall_time_applet::Gui::Trayicon
  attr_reader :args
  
  def initialize(args)
    @args = args
    
    @ti = Gtk::StatusIcon.new
    @ti.file = "../gfx/icon_time.png"
    @ti.signal_connect("popup-menu", &self.method(:on_statusicon_rightclick))
    
    #Build rightclick-menu for tray-icon.
    timelog_new = Gtk::ImageMenuItem.new(Gtk::Stock::NEW)
    timelog_new.label = _("New timelog")
    timelog_new.signal_connect("activate", &self.method(:on_timelogNew_activate))
    
    overview = Gtk::ImageMenuItem.new(Gtk::Stock::EDIT)
    overview.label = _("Overview")
    overview.signal_connect("activate", &self.method(:on_overview_activate))
    
    pref = Gtk::ImageMenuItem.new(Gtk::Stock::PREFERENCES)
    pref.signal_connect("activate", &self.method(:on_preferences_activate))
    
    quit = Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)
    quit.signal_connect("activate", &self.method(:on_quit_activate))
    
    @menu = Gtk::Menu.new
    @menu.append(timelog_new)
    @menu.append(overview)
    @menu.append(Gtk::SeparatorMenuItem.new)
    @menu.append(pref)
    @menu.append(Gtk::SeparatorMenuItem.new)
    @menu.append(quit)
    @menu.show_all
  end
  
  def on_statusicon_rightclick(tray, button, time)
    @menu.popup(nil, nil, button, time)
  end
  
  def on_preferences_activate(*args)
    @args[:oata].show_preferences
  end
  
  def on_timelogNew_activate(*args)
    @args[:oata].show_timelog_new
  end
  
  def on_overview_activate(*args)
    @args[:oata].show_overview
  end
  
  def on_quit_activate(*args)
    Gtk.main_quit
  end
end