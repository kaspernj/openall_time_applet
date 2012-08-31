class Openall_time_applet::Gui::Win_preferences
  attr_reader :args, :gui
  
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_preferences.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    @gui["window"].icon = "#{File.dirname(__FILE__)}/../gfx/icon_time_black.png"
    
    self.load_values
    
    @gui["window"].show_all
  end
  
  #Loads values from database into widgets.
  def load_values
    #OpenAll settings.
    @gui["txtHost"].text = Knj::Opts.get("openall_host")
    @gui["txtPort"].text = Knj::Opts.get("openall_port")
    @gui["txtUsername"].text = Knj::Opts.get("openall_username")
    @gui["txtPassword"].text = Base64.strict_decode64(Knj::Opts.get("openall_password"))
    @gui["cbSSL"].active = Knj::Strings.yn_str(Knj::Opts.get("openall_ssl"), true, false)
    
    #Reminder settings.
    @gui["cbReminderEnabled"].active = Knj::Strings.yn_str(Knj::Opts.get("reminder_enabled"), true, false)
    @gui["txtReminderEveryMinute"].text = Knj::Opts.get("reminder_every_minute")
    
    #Tray settings.
    @tray_colors = {"black" => _("Black"), "green_casalogic" => _("Green (Casalogic)"), "white" => _("White")}
    @gui["cbTrayTextColor"].init(@tray_colors.values)
    @gui["cbTrayTextColor"].sel = @tray_colors[Knj::Opts.get("tray_text_color")] if Knj::Opts.get("tray_text_color").to_s.strip.length > 0
    
    #Autosync settings.
    @gui["cbAutoSync"].active = Knj::Strings.yn_str(Knj::Opts.get("autosync_enabled"), true, false)
    @gui["txtAutoSyncInterval"].text = Knj::Opts.get("autosync_interval")
  end
  
  #Saves values from widgets into database.
  def on_btnSave_clicked
    Knj::Opts.set("openall_host", @gui["txtHost"].text)
    Knj::Opts.set("openall_port", @gui["txtPort"].text)
    Knj::Opts.set("openall_ssl", Knj::Strings.yn_str(@gui["cbSSL"].active?, 1, 0))
    Knj::Opts.set("openall_username", @gui["txtUsername"].text)
    Knj::Opts.set("openall_password", Base64.strict_encode64(@gui["txtPassword"].text))
    Knj::Gtk2.msgbox(_("The OpenAll-settings was saved."), "info")
  end
  
  def on_btnReminderSave_clicked
    if !(Float(@gui["txtReminderEveryMinute"].text) rescue false)
      Knj::Gtk2.msgbox(_("Reminder-minute was not numeric."))
      return nil
    end
    
    Knj::Opts.set("reminder_enabled", Knj::Strings.yn_str(@gui["cbReminderEnabled"].active?, 1, 0))
    Knj::Opts.set("reminder_every_minute", @gui["txtReminderEveryMinute"].text)
    
    #Reset reminder.
    @args[:oata].reminder_next = nil
    
    Knj::Gtk2.msgbox(_("The reminder-settings was saved."), "info")
  end
  
  def on_btnTraySave_clicked
    color_key = @tray_colors.keys[@gui["cbTrayTextColor"].sel["active"]]
    Knj::Opts.set("tray_text_color", color_key)
    @args[:oata].ti.update_icon if @args[:oata].ti
    Knj::Gtk2.msgbox(_("The tray-settings was saved."), "info")
  end
  
  #Tries to connect to OpenAll with the given information and receive a task-list as well to validate information and connectivity.
  def on_btnTest_clicked
    ws = Knj::Gtk2::StatusWindow.new("transient_for" => @gui["window"])
    ws.label = _("Connecting and logging in...")
    
    #Do the stuff in thread so GUI wont lock.
    Knj::Thread.new do
      begin
        args_oa_conn = {
          :host => @gui["txtHost"].text,
          :port => @gui["txtPort"].text.to_i,
          :ssl => @gui["cbSSL"].active?,
          :username => @gui["txtUsername"].text,
          :password => @gui["txtPassword"].text
        }
        
        #Connect to OpenAll, log in, get a list of tasks to test the information and connection.
        @args[:oata].oa_conn(args_oa_conn) do |conn|
          ws.percent = 0.3
          ws.label = _("Getting task-list.")
          task_list = conn.task_list
          
          ws.label = sprintf(_("Got %s tasks."), task_list.length)
          ws.percent = 1
        end
      rescue => e
        #Show error for user if error occurrs.
        Knj::Gtk2.msgbox(
          "msg" => Knj::Errors.error_str(e),
          "type" => "warning",
          "title" => _("Error"),
          "run" => false,
          "transient_for" => @gui["window"]
        )
      ensure
        #Be sure that the status-window will be closed.
        Knj::Thread.new do
          sleep 1.5
          ws.destroy if ws
        end
      end
    end
  end
  
  def on_btnAutoSyncSave_clicked
    interval = @gui["txtAutoSyncInterval"].text
    if !(Float(interval) rescue false) or interval.to_i <= 0
      Knj::Gtk2.msgbox(_("The interval was not numeric or above zero."))
      return false
    end
    
    Knj::Opts.set("autosync_enabled", Knj::Strings.yn_str(@gui["cbAutoSync"].active?, 1, 0))
    Knj::Opts.set("autosync_interval", interval)
    
    @args[:oata].restart_autosync
    
    Knj::Gtk2.msgbox("msg" => _("The auto. sync. preferences was saved."), "type" => "info")
  end
end