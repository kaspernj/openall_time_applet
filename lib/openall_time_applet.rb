require "rubygems"
require "knjrbfw"
require "gtk2"
require "sqlite3"
require "gettext"
require "base64"

require "knj/gtk2"
require "knj/gtk2_tv"
require "knj/gtk2_statuswindow"

class Openall_time_applet
  def self.exec
    require "#{File.dirname(__FILE__)}/../bin/openall_time_applet"
  end
  
  #Subclass controlling autoloading of models.
  class Models
    def self.const_missing(name)
      require "../models/#{name.to_s.downcase}.rb"
      return Openall_time_applet::Models.const_get(name)
    end
  end
  
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
  attr_reader :db, :ob
  
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
      :return_keys => "symbols"
    )
    
    #Models-handeler.
    @ob = Knj::Objects.new(
      :datarow => true,
      :db => @db,
      :class_path => "../models",
      :class_pre => "",
      :module => Openall_time_applet::Models
    )
    
    #Options used to save various information (Openall-username and such).
    Knj::Opts.init("knjdb" => @db, "table" => "Option")
  end
  
  #Updates the database according to the db-schema.
  def update_db
    require "../conf/db_schema.rb"
    rev = Knj::Db::Revision.new.init_db("db" => @db, "schema" => Openall_time_applet::DB_SCHEMA)
  end
  
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
end

#Gettext support.
def _(*args, &block)
  return GetText._(*args, &block)
end