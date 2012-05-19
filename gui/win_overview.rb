class Openall_time_applet::Gui::Win_overview
  attr_reader :args, :gui
  
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_overview.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    
    @gui["tvTimelogs"].init([_("ID"), _("Description"), _("Time"), _("Transport"), _("Needs sync")])
    @gui["tvTimelogs"].columns[0].visible = false
    self.reload_timelogs
    
    @gui["window"].show_all
  end
  
  def reload_timelogs
    @args[:oata].ob.list(:Timelog, {"orderby" => "id"}) do |timelog|
      descr = timelog[:descr].to_s.gsub("\n", " ").gsub(/\s{2,}/, " ")
      descr = Knj::Strings.shorten(descr, 20)
      
      sync_need = Knj::Strings.yn_str(timelog[:sync_need], _("Yes"), _("No"))
      
      @gui["tvTimelogs"].append([timelog.id, descr, timelog[:time], timelog[:time_transport], sync_need])
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
end