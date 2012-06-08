class Openall_time_applet::Gui::Win_overview
  attr_reader :args, :gui
  
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_overview.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    
    
    #Generate list-store containing tasks for the task-column.
    task_ls = Gtk::ListStore.new(String, String)
    iter = task_ls.append
    iter[0] = _("None")
    iter[1] = 0.to_s
    
    task_ls_to_id = []
    
    @args[:oata].ob.list(:Task, {"orderby" => "title"}) do |task|
      iter = task_ls.append
      iter[0] = task[:title]
      iter[1] = task.id.to_s
      task_ls_to_id << task.id
    end
    
    init_data = @gui["tvTimelogs"].init([
      _("ID"),
      _("Description"),
      _("Time"),
      _("Transport"),
      {
        :title => _("Needs sync"),
        :type => :toggle
      },
      {
        :title => _("Task"),
        :type => :combo,
        :model => task_ls
      }
    ])
    
    
    #Set description to be editable.
    init_data[:renderers][1].editable = true
    init_data[:renderers][1].signal_connect("edited") do |renderer, row, var|
      sel = @gui["tvTimelogs"].sel
      timelog = @args[:oata].ob.get(:Timelog, sel[0])
      
      begin
        timelog[:descr] = var
      rescue => e
        Knj::Gtk2.msgbox(e.message, "warning")
      end
    end
    
    #Set time to be editable.
    init_data[:renderers][2].editable = true
    init_data[:renderers][2].signal_connect("edited") do |renderer, row, var|
      sel = @gui["tvTimelogs"].sel
      timelog = @args[:oata].ob.get(:Timelog, sel[0])
      
      begin
        time_secs = Knj::Strings.human_time_str_to_secs(var)
      rescue
        Knj::Gtk2.msgbox(_("Invalid time entered."))
        return nil
      end
      
      begin
        timelog[:time] = time_secs
      rescue => e
        Knj::Gtk2.msgbox(e.message, "warning")
      end
    end
    
    #Set transport to be editable.
    init_data[:renderers][3].editable = true
    init_data[:renderers][3].signal_connect("edited") do |renderer, row, var|
      sel = @gui["tvTimelogs"].sel
      timelog = @args[:oata].ob.get(:Timelog, sel[0])
      
      begin
        time_secs = Knj::Strings.human_time_str_to_secs(var)
      rescue
        Knj::Gtk2.msgbox(_("Invalid time entered."))
        return nil
      end
      
      begin
        timelog[:time_transport] = time_secs
      rescue => e
        Knj::Gtk2.msgbox(e.message, "warning")
      end
    end
    
    #Set sync flag to be activateable.
    init_data[:renderers][4].activatable = true
    init_data[:renderers][4].signal_connect("toggled") do |renderer, path, val|
      iter = @gui["tvTimelogs"].model.get_iter(path)
      id = @gui["tvTimelogs"].model.get_value(iter, 0)
      timelog = @args[:oata].ob.get(:Timelog, id)
      
      if timelog[:sync_need].to_i == 1
        timelog[:sync_need] = 0
      else
        timelog[:sync_need] = 1
      end
    end
    
    #Make task select-able.
    init_data[:renderers][5].editable = true
    init_data[:renderers][5].has_entry = false
    init_data[:renderers][5].signal_connect("edited") do |renderer, row_no, val|
      iter = @gui["tvTimelogs"].model.get_iter(row_no)
      id = @gui["tvTimelogs"].model.get_value(iter, 0) 
      timelog = @args[:oata].ob.get(:Timelog, id)
      
      task = @args[:oata].ob.get_by(:Task, {"title" => val})
      if !task
        timelog[:task_id] = 0
      else
        timelog[:task_id] = task.id
      end
    end
    
    
    @gui["tvTimelogs"].columns[0].visible = false
    self.reload_timelogs
    
    #Reload the treeview if something happened to a timelog.
    @reload_id = @args[:oata].ob.connect("object" => :Timelog, "signals" => ["add", "update", "delete"], &self.method(:reload_timelogs))
    
    @gui["window"].show_all
  end
  
  def on_cell_edited(*args)
    print "Cell edit!\n"
    Knj::Php.print_r(args)
  end
  
  def reload_timelogs
    @gui["tvTimelogs"].model.clear
    @args[:oata].ob.list(:Timelog, {"orderby" => "id"}) do |timelog|
      @gui["tvTimelogs"].append([
        timelog.id,
        timelog.descr_short,
        timelog.time_as_human,
        timelog.time_transport_as_human,
        Knj::Strings.yn_str(timelog[:sync_need], true, false),
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