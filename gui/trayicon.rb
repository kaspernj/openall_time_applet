#This class controls the behaviour around the trayicon.
class Openall_time_applet::Gui::Trayicon
  attr_reader :args
  
  def initialize(args)
    @args = args
    @debug = @args[:oata].debug
    @mutex_update_icon = Mutex.new
    
    @ti = Gtk::StatusIcon.new
    @ti.icon_name = "OpenAll Timelogging"
    @ti.tooltip = "OpenAll Timelogging"
    @ti.signal_connect("popup-menu", &self.method(:on_statusicon_rightclick))
    @ti.signal_connect("activate", &self.method(:on_statusicon_leftclick))
    self.update_icon
    
    #Start icon-updater-thread.
    self.icon_updater
  end
  
  #This methods starts the thread that updates the tray-icon.
  def icon_updater
    Gtk.timeout_add(30000) do
      self.update_icon
      true
    end
  end
  
  #This updates the icon in the system-tray. It draws seconds on the icon, if a timelog is being tracked.
  def update_icon
    @mutex_update_icon.synchronize do
      print "Updating icon.\n" if @debug
      
      color = Knj::Opts.get("tray_text_color")
      color = "black" if color.to_s.strip.length <= 0
      
      if !@args[:oata].timelog_active
        @ti.file = "../gfx/icon_time_#{color}.png"
        return nil
      end
      
      #Calculate minutes tracked and generate variables.
      secs = Time.now.to_i - @args[:oata].timelog_active_time.to_i + @args[:oata].timelog_active.time_total
      text = Knj::Strings.secs_to_human_short_time(secs, :secs => false)
      
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
      canvas = Magick::Image.new(53, 53) do
        self.background_color = "transparent"
        self.format = "png"
      end
      
      color = "#a1a80a" if color == "green_casalogic"
      
      gc = Magick::Draw.new
      gc.fill(color)
      gc.pointsize = 23
      gc.text(padding_left, 35, text)
      gc.draw(canvas)
      
      tmp_path = "#{Knj::Os.tmpdir}/openall_time_applet_icon.png"
      canvas.write(tmp_path)
      canvas.destroy!
      
      
=begin
      Ruby_process::Cproxy.run do |data|
        subproc = data[:subproc]
        subproc.static("Object", "require", "rubygems")
        subproc.static("Object", "require", "RMagick")
        
        canvas = subproc.new("Magick::Image", 53, 53)
          puts "Setting bgcolor to transparent."
          canvas.background_color = "transparent"
          canvas.format = "png"
        
        puts "Wee"
        
        color = "#a1a80a" if color == "green_casalogic"
      
        gc = subproc.new("Magick::Draw")
        gc.fill(color)
        gc.pointsize = 23
        gc.text(padding_left, 35, text)
        gc.draw(canvas)
        
        canvas.write(tmp_path)
        canvas.destroy!
      end
=end
      
      #Set icon for tray.
      @ti.file = tmp_path
      
      
      return nil
    end
  end
  
  def on_statusicon_rightclick(tray, button, time)
    menu = Gtk::Menu.new
    @args[:oata].trayicon_timelogs do |timelog|
      label = timelog.descr_short
      
      #If this is the active timelog, make the label bold, by getting the label-child and using HTML-markup on it.
      if @args[:oata].timelog_active and @args[:oata].timelog_active[:task_id] == timelog[:task_id] and @args[:oata].timelog_active[:descr] == timelog[:descr]
        mi = Gtk::ImageMenuItem.new(Gtk::Stock::MEDIA_STOP)
        
        secs = Time.now.to_i - @args[:oata].timelog_active_time.to_i + timelog.time_total
        mins = (secs.to_f / 60.0).round(0)
        
        mi.children[0].markup = "<b>#{_("Stop")} #{Knj::Web.html(label)}</b>"
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
    
    
    #Start-menu-item. Opens main-window, expands treeview and calls the plus-button which adds a new timelog and focuses treeview.
    start = Gtk::ImageMenuItem.new(Gtk::Stock::NEW)
    start.children[0].label = "#{_("Start new")}..."
    start.signal_connect(:activate, &self.method(:on_startNew_activate))
    
    menu.append(Gtk::SeparatorMenuItem.new)
    menu.append(start)
    
    
    #Show the menu and position it correctly (bug with Gnome Shell where popup would be placed under bottom panel, if it isnt done this way by calling 'position_menu').
    menu.show_all
    
    menu.popup(nil, nil, button, time) do |menu, x, y|
      @ti.position_menu(menu)
    end
  end
  
  def on_startNew_activate(*args)
    #Stop tracking current timelog (if tracking).
    @args[:oata].timelog_stop_tracking
    
    #Open main-window and focus it.
    @args[:oata].show_main
    
    #Get main-window-object.
    win_main = Knj::Gtk2::Window.get("main")
    win_main.gui["txtDescr"].grab_focus
  end
  
  def on_statusicon_leftclick(*args)
    @args[:oata].show_main
  end
  
  def on_stopTracking_activate(*args)
    @args[:oata].timelog_stop_tracking
  end
end