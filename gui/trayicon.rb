#This class controls the behaviour around the trayicon.
class Openall_time_applet::Gui::Trayicon
  attr_reader :args
  
  def initialize(args)
    @args = args
    @debug = @args[:oata].debug
    
    @ti = Gtk::StatusIcon.new
    @ti.signal_connect("popup-menu", &self.method(:on_statusicon_rightclick))
    @ti.signal_connect("activate", &self.method(:on_statusicon_leftclick))
    self.update_icon
    
    #Start icon-updater-thread.
    self.icon_updater
  end
  
  #This methods starts the thread that updates the tray-icon.
  def icon_updater
    Knj::Thread.new do
      loop do
        self.update_icon
        sleep 60
      end
    end
  end
  
  #This updates the icon in the system-tray. It draws seconds on the icon, if a timelog is being tracked.
  def update_icon
    print "Updating icon.\n" if @debug
    
    color = Knj::Opts.get("tray_text_color")
    color = "black" if color.to_s.strip.length <= 0
    
    if !@args[:oata].timelog_active
      @ti.file = "../gfx/icon_time_#{color}.png"
      return nil
    end
    
    #Calculate minutes tracked and generate variables.
    secs = Time.now.to_i - @args[:oata].timelog_active_time.to_i
    mins = (secs.to_f / 60.0)
    
    if mins >= 60
      hours = mins / 60
      text = "#{Knj::Locales.number_out(hours, 1)}t"
    else
      text = "#{Knj::Locales.number_out(mins, 0)}m"
    end
    
    if text.length <= 2
      padding_left = 9
    elsif text.length <= 3
      padding_left = 4
    elsif text.length <= 4
      padding_left = 2
    else
      padding_left = 0
    end
    
    #Generate image.
    require "RMagick"
    canvas = Magick::Image.new(53, 53){
      self.background_color = "transparent"
      self.format = "png"
    }
    
    color = "#a1a80a" if color == "green_casalogic"
    
    gc = Magick::Draw.new
    gc.fill(color)
    gc.pointsize = 23
    gc.text(padding_left, 35, text)
    gc.draw(canvas)
    
    tmp_path = "#{Knj::Os.tmpdir}/openall_time_applet_icon.png"
    canvas.write(tmp_path)
    canvas.destroy!
    
    #Set icon for tray.
    @ti.file = tmp_path
    
    
    return nil
  end
  
  def on_statusicon_rightclick(tray, button, time)
    menu = Gtk::Menu.new
    
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
      mins = (secs.to_f / 60.0).round(0)
      label = Gtk::MenuItem.new(sprintf(_("%s minutes"), mins))
      menu.append(label)
    end
    
    menu.show_all
    
    menu.popup(nil, nil, button, time) do |menu, x, y|
      @ti.position_menu(menu)
    end
  end
  
  def on_statusicon_leftclick(*args)
    @args[:oata].show_main
  end
  
  def on_stopTracking_activate(*args)
    @args[:oata].timelog_stop_tracking
  end
end