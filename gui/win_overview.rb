class Openall_time_applet::Gui::Win_overview
  attr_reader :args, :gui
  
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_overview.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    
    @gui["tvTimelogs"].init([_("ID"), _("Description"), _("Time"), _("Transport"), _("Needs sync"), _("Task")])
    @gui["tvTimelogs"].columns[0].visible = false
    self.reload_timelogs
    
    #Reload the treeview if something happened to a timelog.
    @reload_id = @args[:oata].ob.connect("object" => :Timelog, "signals" => ["add", "update", "delete"], &self.method(:reload_timelogs))
    
    @gui["window"].show_all
  end
  
  def reload_timelogs
    @gui["tvTimelogs"].model.clear
    @args[:oata].ob.list(:Timelog, {"orderby" => "id"}) do |timelog|
      @gui["tvTimelogs"].append([
        timelog.id,
        timelog.descr_short,
        timelog.time_as_human,
        timelog.time_transport_as_human,
        Knj::Strings.yn_str(timelog[:sync_need], _("Yes"), _("No")),
        timelog.task_name
      ])
    end
  end
  
  def on_tvTimelogs_row_activated(*args)
    row = @gui["tvTimelogs"].sel
    return nil if !row
    
    timelog = @args[:oata].ob.get(:Timelog, row[0])
    win_timelog_edit = @args[:oata].show_timelog_edit(timelog)
    win_timelog_edit.gui["window"].modal = @gui["window"]
    win_timelog_edit.gui["window"].transient_for = @gui["window"]
  end
  
  def on_window_destroy
    #Unconnect reload-event. Else it will crash on call to destroyed object. Also frees up various ressources.
    @args[:oata].ob.unconnect("object" => :Timelog, "conn_id" => @reload_id)
  end
end