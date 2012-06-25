class Openall_time_applet::Gui::Win_main
  attr_reader :args, :gui
  
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_main.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    
    
    #Generate list-store containing tasks for the task-column.
    task_ls = Gtk::ListStore.new(String, String)
    iter = task_ls.append
    iter[0] = _("None")
    iter[1] = 0.to_s
    
    tasks = [_("Choose:")]
    @args[:oata].ob.list(:Task, {"orderby" => "title"}) do |task|
      iter = task_ls.append
      iter[0] = task[:title]
      iter[1] = task.id.to_s
      tasks << task
    end
    
    #Add the tasks to the combo-box.
    @gui["cbTask"].init(tasks)
    
    init_data = @gui["tvTimelogs"].init([
      _("ID"),
      _("Description"),
      _("Timestamp"),
      _("Time"),
      _("Transport"),
      _("Length"),
      _("Transport descr."),
      _("Transport costs"),
      {
        :title => _("Fixed travel"),
        :type => :toggle
      },
      {
        :title => _("Int. work"),
        :type => :toggle
      },
      {
        :title => _("Sync?"),
        :type => :toggle
      },
      {
        :title => _("Task"),
        :type => :combo,
        :model => task_ls,
        :has_entry => false
      }
    ])
    
    Knj::Gtk2::Tv.editable_text_renderers_to_model(
      :ob => @args[:oata].ob,
      :tv => @gui["tvTimelogs"],
      :model_class => :Timelog,
      :renderers => init_data[:renderers],
      :change_before => proc{ @dont_reload = true },
      :change_after => proc{ @dont_reload = false },
      :cols => {
        1 => :descr,
        2 => {:col => :timestamp, :type => :datetime},
        3 => {:col => :time, :type => :time_as_sec},
        4 => {:col => :time_transport, :type => :time_as_sec},
        5 => {:col => :transportlength, :type => :int},
        6 => {:col => :transportdescription},
        7 => {:col => :transportcosts, :type => :human_number, :decimals => 2},
        8 => {:col => :travelfixed},
        9 => {:col => :workinternal},
        10 => {:col => :sync_need},
        11 => {
          :col => :task_id,
          :value_callback => lambda{ |data|
            task = @args[:oata].ob.get_by(:Task, {"title" => data[:value]})
            
            if !task
              return 0
            else
              return task.id
            end
          },
          :value_set_callback => proc{ |data| data[:model].task_name }
        }
      }
    )
    
    @gui["tvTimelogs"].columns[0].visible = false
    self.reload_timelogs
    
    #Reload the treeview if something happened to a timelog.
    @reload_id = @args[:oata].ob.connect("object" => :Timelog, "signals" => ["add", "update", "delete"], &self.method(:reload_timelogs))
    
    @gui["window"].show_all
  end
  
  def dont_reload
    @dont_reload = true
    begin
      yield
    ensure
      @dont_reload = false
    end
  end
  
  def reload_timelogs
    return nil if @dont_reload or @gui["tvTimelogs"].destroyed?
    @gui["tvTimelogs"].model.clear
    @args[:oata].ob.list(:Timelog, {"orderby" => "id"}) do |timelog|
      @gui["tvTimelogs"].append([
        timelog.id,
        timelog[:descr],
        timelog.timestamp_str,
        timelog.time_as_human,
        timelog.time_transport_as_human,
        Knj::Locales.number_out(timelog[:transportlength], 0),
        timelog.transport_descr_short,
        Knj::Locales.number_out(timelog[:transportcosts], 2),
        Knj::Strings.yn_str(timelog[:travelfixed], true, false),
        Knj::Strings.yn_str(timelog[:workinternal], true, false),
        Knj::Strings.yn_str(timelog[:sync_need], true, false),
        timelog.task_name
      ])
    end
  end
  
  def on_imiQuit_activate
    @gui["window"].destroy
  end
  
  def on_imiPreferences_activate
    @args[:oata].show_preferences
  end
  
  def on_imiWeekview_activate
    @args[:oata].show_worktime_overview
  end
  
  def on_window_destroy
    #Unconnect reload-event. Else it will crash on call to destroyed object. Also frees up various ressources.
    @args[:oata].ob.unconnect("object" => :Timelog, "conn_id" => @reload_id)
  end
  
  def on_expOverview_activate(expander)
    if !expander.expanded?
      @gui["window"].set_size_request(-1, 480)
    else
      @gui["window"].set_size_request(-1, -1)
    end
  end
  
  def on_btnSwitch_clicked
    task = @gui["cbTask"].sel
    if !task.is_a?(Knj::Datarow)
      Knj::Gtk2.msgbox(_("Please choose a task."), "warning")
      return nil
    end
    
    @timelog = @args[:oata].ob.add(:Timelog, {
      :task_id => task.id,
      :descr => @gui["txtDescr"].text
    })
    @args[:oata].timelog_active = @timelog
    @gui["txtDescr"].text = ""
    @gui["cbTask"].sel = _("Choose:")
  end
  
  def on_btnSync_clicked
    @args[:oata].sync_static("transient_for" => @gui["window"]) do
      @args[:oata].sync
    end
  end
  
  def on_btnMinus_clicked
    sel = @gui["tvTimelogs"].sel
    tlog = @args[:oata].ob.get(:Timelog, sel[0]) if sel
    
    if !sel or !tlog
      Knj::Gtk2.msgbox(_("Please choose a timelog to delete."), "warning")
      return nil
    end
    
    return nil if Knj::Gtk2.msgbox(_("Do you want to remove this timelog?"), "yesno") != "yes"
    @args[:oata].ob.delete(tlog)
  end
  
  def on_btnPlus_clicked
    @args[:oata].ob.add(:Timelog)
  end
  
  #Redirects 'enter'-events to 'switch'-click-event.
  def on_txtDescr_activate(*args)
    self.on_btnSwitch_clicked
  end
end