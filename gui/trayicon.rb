class Openall_time_applet::Gui::Trayicon
  attr_reader :args
  
  def initialize(args)
    @args = args
    
    @ti = Gtk::StatusIcon.new
    @ti.file = "../gfx/icon_time.png"
    @ti.signal_connect("popup-menu", &self.method(:on_statusicon_rightclick))
  end
  
  def on_statusicon_rightclick(tray, button, time)
    #Build rightclick-menu for tray-icon.
    timelog_new = Gtk::ImageMenuItem.new(Gtk::Stock::NEW)
    timelog_new.label = _("New timelog")
    timelog_new.signal_connect("activate", &self.method(:on_timelogNew_activate))
    
    overview = Gtk::ImageMenuItem.new(Gtk::Stock::EDIT)
    overview.label = _("Overview")
    overview.signal_connect("activate", &self.method(:on_overview_activate))
    
    worktime_overview = Gtk::ImageMenuItem.new(Gtk::Stock::HOME)
    worktime_overview.label = _("Time overview")
    worktime_overview.signal_connect("activate", &self.method(:on_worktimeOverview_activate))
    
    pref = Gtk::ImageMenuItem.new(Gtk::Stock::PREFERENCES)
    pref.signal_connect("activate", &self.method(:on_preferences_activate))
    
    quit = Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)
    quit.signal_connect("activate", &self.method(:on_quit_activate))
    
    sync = Gtk::ImageMenuItem.new(Gtk::Stock::HARDDISK)
    sync.label = _("Synchronize with OpenAll")
    sync.signal_connect("activate", &self.method(:on_sync_activate))
    
    menu = Gtk::Menu.new
    menu.append(timelog_new)
    menu.append(overview)
    menu.append(worktime_overview)
    menu.append(Gtk::SeparatorMenuItem.new)
    menu.append(pref)
    menu.append(Gtk::SeparatorMenuItem.new)
    
    #Make a list of all timelogs in the menu.
    @args[:oata].ob.list(:Timelog, {"orderby" => "id"}) do |timelog|
      label = sprintf(_("Track: %s"), timelog.descr_short)
      
      #If this is the active timelog, make the label bold, by getting the label-child and using HTML-markup on it.
      if @args[:oata].timelog_active and @args[:oata].timelog_active.id == timelog.id
        mi = Gtk::ImageMenuItem.new(Gtk::Stock::MEDIA_RECORD)
        mi.children[0].markup = "<b>#{label}</b>"
        mi.signal_connect("activate", &self.method(:on_stopTracking_activate))
      else
        mi = Gtk::MenuItem.new(label)
        #Change the active timelog, when the timelog is clicked.
        mi.signal_connect("activate") do
          @args[:oata].timelog_active = timelog
        end
      end
      
      menu.append(mi)
    end
    
    if @args[:oata].timelog_active
      menu.append(Gtk::SeparatorMenuItem.new)
      
      #If tracking is active, then show how many seconds has been tracked until now in menu as an item.
      secs = Time.now.to_i - @args[:oata].timelog_active_time.to_i
      label = Gtk::MenuItem.new(sprintf(_("%s seconds"), secs))
      menu.append(label)
    end
    
    menu.append(Gtk::SeparatorMenuItem.new)
    menu.append(sync)
    menu.append(quit)
    menu.show_all
    
    menu.popup(nil, nil, button, time)
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
  
  def on_worktimeOverview_activate(*args)
    @args[:oata].show_worktime_overview
  end
  
  def on_quit_activate(*args)
    @args[:oata].destroy
  end
  
  def on_sync_activate(*args)
    @args[:oata].sync
  end
  
  def on_stopTracking_activate(*args)
    @args[:oata].timelog_stop_tracking
  end
end