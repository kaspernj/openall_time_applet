#Support for libs loaded through RubyGems.
require "rubygems"

#For secs-to-human-string (MySQL-format), model-framework, database-framework, options-framework, date-framework and more.
if ENV["HOME"] == "/home/kaspernj" and File.exists?("/home/kaspernj/Dev/Ruby/knjrbfw")
  #For development.
  require "/home/kaspernj/Dev/Ruby/knjrbfw/lib/knjrbfw"
else
  require "knjrbfw"
end

require "gtk2"
require "sqlite3"
require "gettext"
require "base64"

#For msgbox and translation of windows.
require "knj/gtk2"

#For easy initialization, getting and settings of values on comboboxes.
require "knj/gtk2_cb"

#For easy initialization, getting and settings of values on treeviews.
require "knj/gtk2_tv"

#For easy making status-windows with progressbar.
require "knj/gtk2_statuswindow"

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
  attr_reader :db, :ob, :ti, :timelog_active, :timelog_active_time
  attr_accessor :reminder_next
  
  #Config controlling paths and more.
  CONFIG = {
    :settings_path => "#{Knj::Os.homedir}/.openall_time_applet",
    :db_path => "#{Knj::Os.homedir}/.openall_time_applet/openall_time_applet.sqlite3"
  }
  
  #Initializes config-dir and database.
  def initialize(args = {})
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
    
    #Options used to save various information (Openall-username and such).
    Knj::Opts.init("knjdb" => @db, "table" => "Option")
    
    #Set crash-operation to save tracked time instead of loosing it.
    Kernel.at_exit(&self.method(:destroy))
    
    #Spawn tray-icon.
    self.spawn_trayicon
    
    #Start reminder.
    self.reminding
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
        :password => Base64.strict_decode64(Knj::Opts.get("openall_password"))
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
  
  #Spawns the preference-window.
  def show_preferences
    Openall_time_applet::Gui::Win_preferences.new(:oata => self)
  end
  
  def show_timelog_new
    Openall_time_applet::Gui::Win_timelog_edit.new(:oata => self)
  end
  
  def show_timelog_edit(timelog)
    Openall_time_applet::Gui::Win_timelog_edit.new(:oata => self, :timelog => timelog)
  end
  
  def show_overview
    Openall_time_applet::Gui::Win_overview.new(:oata => self)
  end
  
  def show_worktime_overview
    Openall_time_applet::Gui::Win_worktime_overview.new(:oata => self)
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
  def sync_static
    sw = Knj::Gtk2::StatusWindow.new
    
    Knj::Thread.new do
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
        
        sleep 1
      rescue => e
        Knj::Gtk2.msgbox("msg" => Knj::Errors.error_str(e), "type" => "warning", "title" => _("Error"), "run" => false)
      ensure
        sw.destroy if sw
      end
    end
  end
  
  #Shows the sync overview, which must be seen before the actual sync.
  def sync
    Openall_time_applet::Gui::Win_sync_overview.new(:oata => self)
  end
  
  #Refreshes task-cache, create missing worktime from timelogs and push tracked time to timelogs. Shows a status-window while doing so.
  def sync_real
    sw = Knj::Gtk2::StatusWindow.new
    
    if @timelog_active
      timelog_active = @timelog_active
      self.timelog_stop_tracking
    end
    
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
        self.timelog_active = timelog_active if timelog_active
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
    end
    
    @timelog_active = nil
    @timelog_active_time = nil
    @ti.update_icon if @ti
  end
  
  #Sets a new timelog to track. Stops tracking of previous timelog if already tracking.
  def timelog_active=(timelog)
    self.timelog_stop_tracking
    
    @timelog_active = timelog
    @timelog_active_time = Time.new
    @ti.update_icon if @ti
  end
  
  #Saves tracking-status if tracking. Stops Gtks main loop.
  def destroy
    self.timelog_stop_tracking
    
    #Use quit-variable to avoid Gtk-warnings.
    Gtk.main_quit if @quit != true
    @quit = true
  end
end

#Gettext support.
def _(*args, &block)
  return GetText._(*args, &block)
end