#Support for libs loaded through RubyGems.
require "rubygems"

#For secs-to-human-string (MySQL-format), model-framework, database-framework, options-framework, date-framework and more.
if ENV["HOME"] == "/home/kaspernj" and File.exists?("/home/kaspernj/Dev/Ruby/knjrbfw")
  #For development.
  require "/home/kaspernj/Dev/Ruby/knjrbfw/lib/knjrbfw"
else
  require "knjrbfw"
end

require "sqlite3"
require "gettext"
require "base64"

#The base class of the applet. Spawns all windows, holds subclasses for models and gui, holds models objects and holds database-objects.
class Openall_time_applet
  #Shortcut to start the application. Used by the Ubuntu-package.
  def self.exec
    require "#{File.dirname(__FILE__)}/../bin/openall_time_applet"
  end
  
  #Subclass controlling autoloading of models.
  class Models
    #Autoloader for subclasses.
    def self.const_missing(name)
      require "../models/#{name.to_s.downcase}.rb"
      return Openall_time_applet::Models.const_get(name)
    end
  end
  
  #Subclass holding all GUI-subclasses and autoloading of them.
  class Gui
    #Autoloader for subclasses.
    def self.const_missing(name)
      require "../gui/#{name.to_s.downcase}.rb"
      return Openall_time_applet::Gui.const_get(name)
    end
  end
  
  #Autoloader for subclasses.
  def self.const_missing(name)
    namel = name.to_s.downcase
    tries = [
      "../classes/#{namel}.rb"
    ]
    tries.each do |try|
      if File.exists?(try)
        require try
        return Openall_time_applet.const_get(name)
      end
    end
    
    raise "Could not load constant: '#{name}'."
  end
  
  #Various readable variables.
  attr_reader :db, :debug, :events, :ob, :ti, :timelog_active, :timelog_active_time
  attr_accessor :reminder_next
  
  #Config controlling paths and more.
  CONFIG = {
    :settings_path => "#{Knj::Os.homedir}/.openall_time_applet",
    :run_path => "#{Knj::Os.homedir}/.openall_time_applet/run",
    :db_path => "#{Knj::Os.homedir}/.openall_time_applet/openall_time_applet.sqlite3",
    :sock_path => "#{Knj::Os.homedir}/.openall_time_applet/sock"
  }
  
  #Initializes config-dir and database.
  def initialize(args = {})
    self.check_runfile_and_cmds
    self.require_gtk2
    
    @debug = args[:debug]
    Dir.mkdir(CONFIG[:settings_path]) if !File.exists?(CONFIG[:settings_path])
    
    #Database-connection.
    @db = Knj::Db.new(
      :type => "sqlite3",
      :path => CONFIG[:db_path],
      :return_keys => "symbols",
      :index_append_table_name => true
    )
    
    #Update to latest db-revision.
    self.update_db
    
    #Models-handeler.
    @ob = Knj::Objects.new(
      :datarow => true,
      :db => @db,
      :class_path => "../models",
      :class_pre => "",
      :module => Openall_time_applet::Models
    )
    @ob.events.connect(:no_name) do |event, classname|
      _("not set")
    end
    
    @events = Knj::Event_handler.new
    @events.add_event(:name => :timelog_active_changed)
    
    #Options used to save various information (Openall-username and such).
    Knj::Opts.init("knjdb" => @db, "table" => "Option")
    
    #Set crash-operation to save tracked time instead of loosing it.
    Kernel.at_exit(&self.method(:destroy))
    
    #Set default-color to "green_casalogic".
    Knj::Opts.set("tray_text_color", "green_casalogic") if Knj::Opts.get("tray_text_color").to_s.strip.length <= 0
    
    #Spawn tray-icon.
    self.spawn_trayicon
    
    #Start reminder.
    self.reminding
    
    #Start unix-socket that listens for remote control.
    @unix_socket = Openall_time_applet::Unix_socket.new(:oata => self)
    
    #Start autosync-timeout.
    self.restart_autosync
  end
  
  #Creates a runfile or sending a command to the running OpenAll-Time-Applet through the Unix-socket.
  def check_runfile_and_cmds
    #If run-file exists and the PID within is still running, then send command (if given) and exit.
    if File.exists?(CONFIG[:run_path]) and Knj::Unix_proc.pid_running?(File.read(CONFIG[:run_path]).to_i)
      cmd = nil
      ARGV.each do |val|
        if match = val.match(/^--cmd=(.+)$/)
          cmd = match[1]
          break
        end
      end
      
      if cmd
        print "Executing command through sock: #{cmd}\n"
        
        require "socket"
        UNIXSocket.open(CONFIG[:sock_path]) do |sock|
          sock.puts(cmd)
        end
      end
      
      puts "Already running"
      exit
    end
    
    File.open(CONFIG[:run_path], "w") do |fp|
      fp.write(Process.pid)
    end
    
    Kernel.at_exit do
      File.unlink(CONFIG[:run_path]) if File.exists?(CONFIG[:run_path]) and File.read(CONFIG[:run_path]).to_i == Process.pid
    end
  end
  
  #Requires the heavy Gtk-stuff.
  def require_gtk2
    require "gtk2"
    
    #For msgbox and translation of windows.
    require "knj/gtk2"
    
    #For easy initialization, getting and settings of values on comboboxes.
    require "knj/gtk2_cb"
    
    #For easy initialization, getting and settings of values on treeviews.
    require "knj/gtk2_tv"
    
    #For easy making status-windows with progressbar.
    require "knj/gtk2_statuswindow"
  end
  
  #Updates the database according to the db-schema.
  def update_db
    require "../conf/db_schema.rb"
    Knj::Db::Revision.new.init_db("debug" => false, "db" => @db, "schema" => Openall_time_applet::DB_SCHEMA)
  end
  
  #This method starts the reminder-thread, that checks if a reminder should be shown.
  def reminding
    Knj::Thread.new do
      loop do
        enabled = Knj::Strings.yn_str(Knj::Opts.get("reminder_enabled"), true, false)
        if enabled and !@reminder_next
          @reminder_next = Knj::Datet.new
          @reminder_next.mins + Knj::Opts.get("reminder_every_minute").to_i
        elsif enabled and @reminder_next and Time.now >= @reminder_next
          self.reminding_exec
          @reminder_next = nil
        end
        
        sleep 30
      end
    end
    
    return nil
  end
  
  #This executes the notification that notifies if a timelog is being tracked.
  def reminding_exec
    return nil unless @timelog_active
    Knj::Notify.send("time" => 5, "msg" => sprintf(_("Tracking task: %s"), @timelog_active[:descr]))
  end
  
  #Creates a connection to OpenAll, logs in, yields the connection and destroys it again.
  #===Examples
  # oata.oa_conn do |conn|
  #   task_list = conn.task_list
  # end
  def oa_conn
    begin
      conn = Openall_time_applet::Connection.new(
        :oata => self,
        :host => Knj::Opts.get("openall_host"),
        :port => Knj::Opts.get("openall_port"),
        :username => Knj::Opts.get("openall_username"),
        :password => Base64.strict_decode64(Knj::Opts.get("openall_password")),
        :ssl => Knj::Strings.yn_str(Knj::Opts.get("openall_ssl"), true, false)
      )
      yield(conn)
    ensure
      conn.destroy if conn
    end
  end
  
  #Spawns the trayicon in systray.
  def spawn_trayicon
    return nil if @ti
    @ti = Openall_time_applet::Gui::Trayicon.new(:oata => self)
  end
  
  def show_main
    Knj::Gtk2::Window.unique!("main") do
      Openall_time_applet::Gui::Win_main.new(:oata => self)
    end
  end
  
  #Spawns the preference-window.
  def show_preferences
    Knj::Gtk2::Window.unique!("preferences") do
      Openall_time_applet::Gui::Win_preferences.new(:oata => self)
    end
  end
  
  def show_overview
    Knj::Gtk2::Window.unique!("overview") do
      Openall_time_applet::Gui::Win_overview.new(:oata => self)
    end
  end
  
  def show_worktime_overview
    Knj::Gtk2::Window.unique!("worktime_overview") do
      Openall_time_applet::Gui::Win_worktime_overview.new(:oata => self)
    end
  end
  
  #Updates the task-cache.
  def update_task_cache
    @ob.static(:Task, :update_cache, {:oata => self})
  end
  
  #Updates the worktime-cache.
  def update_worktime_cache
    @ob.static(:Worktime, :update_cache, {:oata => self})
  end
  
  def update_organisation_cache
    @ob.static(:Organisation, :update_cache, {:oata => self})
  end
  
  #Pushes time-updates to OpenAll.
  def push_time_updates
    @ob.static(:Timelog, :push_time_updates, {:oata => self})
  end
  
  #Synchronizes organisations, tasks and worktimes.
  def sync_static(args = nil)
    sw = Knj::Gtk2::StatusWindow.new("transient_for" => args["transient_for"])
    
    return Knj::Thread.new do
      begin
        sw.label = _("Updating organisation-cache.")
        self.update_organisation_cache
        sw.percent = 0.33
        
        sw.label = _("Updating task-cache.")
        self.update_task_cache
        sw.percent = 0.66
        
        sw.label = _("Updating worktime-cache.")
        self.update_worktime_cache
        sw.percent = 1
        
        sleep 1 if !block_given?
        sw.destroy if sw
        sw = nil
        yield if block_given?
      rescue => e
        sw.destroy if sw
        sw = nil
        Knj::Gtk2.msgbox("msg" => Knj::Errors.error_str(e), "type" => "warning", "title" => _("Error"), "run" => false)
      ensure
        sw.destroy if sw
      end
    end
  end
  
  #Shows the sync overview, which must be seen before the actual sync.
  def show_prepare_sync
    Openall_time_applet::Gui::Win_sync_overview.new(:oata => self)
  end
  
  #Refreshes task-cache, create missing worktime from timelogs and push tracked time to timelogs. Shows a status-window while doing so.
  def sync_real
    sw = Knj::Gtk2::StatusWindow.new
    self.timelog_stop_tracking if @timelog_active
    
    Knj::Thread.new do
      begin
        sw.label = _("Pushing time-updates.")
        self.push_time_updates
        sw.percent = 0.5
        
        sw.label = _("Updating worktime-cache.")
        self.update_worktime_cache
        sw.percent = 1
        
        sw.label = _("Done")
        
        sleep 1
      rescue => e
        Knj::Gtk2.msgbox("msg" => Knj::Errors.error_str(e), "type" => "warning", "title" => _("Error"), "run" => false)
      ensure
        sw.destroy if sw
      end
    end
  end
  
  #Stops tracking a timelog. Saves time tracked and sets sync-flag.
  def timelog_stop_tracking
    if @timelog_active
      secs_passed = Time.now.to_i - @timelog_active_time.to_i
      @timelog_active.update(
        :time => @timelog_active[:time].to_i + secs_passed,
        :sync_need => 1
      )
      @timelog_logged_time[:timestamp_end] = Time.now
    end
    
    @timelog_active = nil
    @timelog_active_time = nil
    @ti.update_icon if @ti
    @events.call(:timelog_active_changed)
  end
  
  #Sets a new timelog to track. Stops tracking of previous timelog if already tracking.
  def timelog_active=(timelog)
    begin
      #Check if there has been logged time another day - if so, clone it and begin logging on the clone instead.
      tlt = @ob.list(:Timelog_logged_time, {
        "timelog" => timelog,
        "timestamp_start_day_not" => Time.now,
        "limit" => 1
      })
      if !tlt.empty?
        timelog = @ob.add(:Timelog, {
          :task_id => timelog[:task_id],
          :timestamp => Time.now,
          :descr => timelog[:descr],
          :transportdescription => timelog[:transportdescription],
          :workinternal => timelog[:workinternal],
          :timetype => timelog[:timetype]
        })
        #raise sprintf(_("You have already logged on this timelog on %s"), tlt.first.timestamp_start.out)
      end
      
      self.timelog_stop_tracking
      @timelog_logged_time = @ob.add(:Timelog_logged_time, {:timelog_id => timelog.id})
      @timelog_active = timelog
      @timelog_active_time = Time.new
      
      @events.call(:timelog_active_changed)
    rescue => e
      Knj::Gtk2.msgbox("msg" => Knj::Errors.error_str(e), "type" => "warning", "title" => _("Error"), "run" => false)
    end
    
    @ti.update_icon if @ti
  end
  
  #Returns the amount of seconds tracked.
  def timelog_active_time_tracked
    return 0 if !@timelog_active_time
    return Time.now.to_i - @timelog_active_time.to_i
  end
  
  #Saves tracking-status if tracking. Stops Gtks main loop.
  def destroy
    self.timelog_stop_tracking
    
    #Use quit-variable to avoid Gtk-warnings.
    Gtk.main_quit if @quit != true
    @quit = true
  end
  
  #Restarts the auto-syncing timeout.
  def restart_autosync
    #Remove current timeout.
    Gtk.timeout_remove(@autosync_timeout) if @autosync_timeout
    @autosync_timeout = nil
    
    #Get various info from db.
    enabled = Knj::Strings.yn_str(Knj::Opts.get("autosync_enabled"), true, false)
    interval = Knj::Opts.get("autosync_interval").to_i
    interval_msecs = interval * 60 * 1000
    
    if !enabled #dont continue if autosync isnt enabled.
      self.status = _("Disabled automatic synchronization.")
      return nil
    end
    
    self.status = sprintf(_("Restarted automatic sync. to run every %s minutes."), Knj::Locales.number_out(interval, 1))
    
    #Start new timeout.
    @autosync_timeout = Gtk.timeout_add(interval_msecs) do
      if !@sync_thread
        @sync_thread = Knj::Thread.new(&self.method(:run_autosync))
      end
      
      true
    end
  end
  
  #This method is executing the automatic synchronization.
  def run_autosync
    begin
      self.status = _("Synchronizing organisations.")
      self.update_organisation_cache
      
      self.status = _("Synchronizing worktime.")
      self.update_worktime_cache
      
      self.status = _("Automatic synchronization done.")
    rescue => e
      self.status = sprintf(_("Error while auto-syncing: %s"), e.message)
      puts Knj::Errors.error_str(e)
    ensure
      @sync_thread = nil
    end
  end
  
  #Prints status to the command line and the statusbar in the main window (if the main window is open).
  def status=(newstatus)
    puts "Status: '#{newstatus}'."
    win_main = Knj::Gtk2::Window.get("main")
    
    if win_main
      win_main.gui["statusbar"].push(0, newstatus)
    end
  end
end

#Gettext support.
def _(*args, &block)
  return GetText._(*args, &block)
end