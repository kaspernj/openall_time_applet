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
    
    
    #Set up completion for description entry.
    ec = Gtk::EntryCompletion.new
    ec.model = Gtk::ListStore.new(String)
    ec.text_column = 0
    @gui["txtDescr"].completion = ec
    
    added = {}
    @args[:oata].ob.list(:Worktime, {"orderby" => "timestamp"}) do |worktime|
      next if added.key?(worktime[:comment])
      added[worktime[:comment]] = true
      ec.model.append[0] = worktime[:comment]
    end
    
    @args[:oata].ob.list(:Timelog, {"orderby" => "descr"}) do |timelog|
      next if added.key?(timelog[:descr])
      added[timelog[:descr]] = true
      ec.model.append[0] = timelog[:descr]
    end
    
    ec.signal_connect("match-selected") do |me, model, iter|
      text = model.get_value(iter, 0)
      me.entry.text = text
      true
    end
    
    
    
    #Add the tasks to the combo-box.
    @gui["cbTask"].init(tasks)
    
    init_data = @gui["tvTimelogs"].init([
      _("ID"),
      {
        :title => _("Description"),
        :type => :string,
        :markup => true
      },
      {
        :title => _("Timestamp"),
        :type => :string,
        :markup => true
      },
      {
        :title => _("Time"),
        :type => :string,
        :markup => true
      },
      {
        :title => _("Transport"),
        :type => :string,
        :markup => true
      },
      {
        :title => _("Length"),
        :type => :string,
        :markup => true
      },
      {
        :title => _("Descr."),
        :type => :string,
        :markup => true
      },
      {
        :title => _("Costs"),
        :type => :string,
        :markup => true
      },
      {
        :title => _("Fixed"),
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
        :has_entry => false,
        :markup => true
      }
    ])
    
    Knj::Gtk2::Tv.editable_text_renderers_to_model(
      :ob => @args[:oata].ob,
      :tv => @gui["tvTimelogs"],
      :model_class => :Timelog,
      :renderers => init_data[:renderers],
      :change_before => proc{|d|
        if (d[:col_no] == 11 or d[:col_no] == 3 or d[:col_no] == 2) and @args[:oata].timelog_active and @args[:oata].timelog_active.id == d[:model].id
          raise _("You cannot edit the time for the active timelog.")
        end
        
        @dont_reload = true
      },
      :change_after => proc{
        @dont_reload = false
      },
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
    
    
    #The ID column should not be visible (it is only used to identify which timelog the row represents).
    @gui["tvTimelogs"].columns[0].visible = false
    
    
    #Connect certain column renderers to the editingStarted-method, so editing can be canceled, if the user tries to edit forbidden data on the active timelog.
    init_data[:renderers][1].signal_connect_after("editing-started", :descr, &self.method(:on_cell_editingStarted))
    init_data[:renderers][2].signal_connect_after("editing-started", :timestamp, &self.method(:on_cell_editingStarted))
    init_data[:renderers][3].signal_connect_after("editing-started", :time, &self.method(:on_cell_editingStarted))
    init_data[:renderers][11].signal_connect_after("editing-started", :task, &self.method(:on_cell_editingStarted))
    
    
    #Fills the timelogs-treeview with data.
    self.reload_timelogs
    
    
    #Reload the treeview if something happened to a timelog.
    @reload_id = @args[:oata].ob.connect("object" => :Timelog, "signals" => ["add", "update", "delete"], &self.method(:reload_timelogs))
    
    
    #Update switch-button.
    self.update_switch_button
    
    
    #Update switch-button when active timelog is changed.
    @event_timelog_active_changed = @args[:oata].events.connect(:timelog_active_changed) do
      self.update_switch_button
      self.check_rows
      self.timelog_info_trigger
    end
    
    
    #This timeout controls the updating of the timelog-info-frame and the time-counter for the active timelog in the treeview.
    @timeout_id = Gtk.timeout_add(1000) do
      self.check_rows
      self.timelog_info_trigger
      true
    end
    
    
    #Show the window.
    @gui["window"].show_all
    self.timelog_info_trigger
    width = @gui["window"].size[0]
    @gui["window"].resize(width, 1)
  end
  
  #This method is called, when editting starts in a description-, time- or task-cell. If it is the active timelog, then editting is canceled.
  def on_cell_editingStarted(renderer, editable, path, col_title)
    iter = @gui["tvTimelogs"].model.get_iter(path)
    timelog_id = @gui["tvTimelogs"].model.get_value(iter, 0).to_i
    
    if tlog = @args[:oata].timelog_active and tlog.id.to_i == timelog_id
      renderer.stop_editing(true)
      Knj::Gtk2.msgbox(_("You cannot edit this on the active timelog."))
    end
  end
  
  #This method is used to do stuff without having the treeview reloading. It executes the given block and then makes the treeview reloadable again.
  def dont_reload
    @dont_reload = true
    begin
      yield
    ensure
      @dont_reload = false
    end
  end
  
  #Removes all timelogs from the treeview and adds them again. Does nothing if the 'dont_reload'-variable is set.
  def reload_timelogs
    return nil if @dont_reload or @gui["tvTimelogs"].destroyed?
    @gui["tvTimelogs"].model.clear
    @args[:oata].ob.list(:Timelog, "parent_timelog_id" => 0, "orderby" => [["timestamp", "desc"]]) do |timelog|
      begin
        tstamp_str = timelog.timestamp_str
      rescue => e
        tstamp_str = "[#{_("error")}: #{e.message}"
      end
      
      @gui["tvTimelogs"].append([
        timelog.id,
        Knj::Web.html(timelog[:descr]),
        tstamp_str,
        timelog.time_as_human,
        timelog.time_transport_as_human,
        Knj::Locales.number_out(timelog[:transportlength], 0),
        Knj::Web.html(timelog[:transportdescription]),
        Knj::Locales.number_out(timelog[:transportcosts], 2),
        Knj::Strings.yn_str(timelog[:travelfixed], true, false),
        Knj::Strings.yn_str(timelog[:workinternal], true, false),
        Knj::Strings.yn_str(timelog[:sync_need], true, false),
        timelog.task_name
      ])
    end
    
    #Reset cache of which rows are set to bold.
    @bold_rows = {}
  end
  
  def on_imiQuit_activate
    #Check if a timelog needs to be synced. If so the user needs to confirm he really wants to quit.
    timelog_found = nil
    do_destroy = true
    
    @args[:oata].ob.list(:Timelog, "task_id_not" => ["", 0]) do |timelog|
      if timelog.time_total > 0 or timelog.time_total(:transport => true) > 0 or timelog[:sync_need].to_i == 1
        timelog_found = timelog
        break
      end
    end
    
    if timelog_found
      if Knj::Gtk2.msgbox(sprintf(_("The timelog '%s' has not been synced. Are you sure you want to quit?"), timelog_found[:descr]), "yesno") != "yes"
        do_destroy = false
      end
    end
    
    @args[:oata].destroy if do_destroy
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
    @args[:oata].events.disconnect(:timelog_active_changed, @event_timelog_active_changed) if @event_timelog_active_changed
    @event_timelog_active_changed = nil
    Gtk.timeout_remove(@timeout_id)
  end
  
  def on_expOverview_activate(expander)
    if expander.expanded?
      @gui["window"].resize(@gui["window"].size[0], 480)
      self.timelog_info_trigger
    else
      Gtk.timeout_add(200) do
        self.timelog_info_trigger
        @gui["window"].resize(@gui["window"].size[0], 1)
        false
      end
    end
  end
  
  #This method handles the "Timelog info"-frame. Hides, shows and updates the info in it.
  def timelog_info_trigger
    if tlog = @args[:oata].timelog_active
      task = tlog.task
      if !task
        task_text = "[#{_("no task sat on the timelog")}]"
      else
        task_text = task.name
      end
      
      @gui["labRunningTimelog"].label = tlog[:descr]
      @gui["labRunningTask"].label = task_text
      
      time_tracked = Knj::Strings.secs_to_human_time_str(@args[:oata].timelog_active_time_tracked + tlog.time_total)
      
      @gui["labRunningTime"].label = time_tracked
      
      @gui["txtDescr"].hide
      @gui["cbTask"].hide
      @gui["tableRunning"].show_all
    else
      @gui["txtDescr"].show
      @gui["cbTask"].show
      @gui["tableRunning"].hide
    end
  end
  
  def on_btnSwitch_clicked
    if @args[:oata].timelog_active
      @args[:oata].timelog_stop_tracking
      @gui["txtDescr"].grab_focus
    else
      task = @gui["cbTask"].sel
      if !task.is_a?(Knj::Datarow)
        task_id = 0
      else
        task_id = task.id
      end
      
      @timelog = @args[:oata].ob.add(:Timelog, {
        :task_id => task_id,
        :descr => @gui["txtDescr"].text
      })
      @args[:oata].timelog_active = @timelog
      @gui["txtDescr"].text = ""
      @gui["cbTask"].sel = _("Choose:")
    end
    
    self.update_switch_button
  end
  
  #This method updates the switch button to start or stop, based on the if a timelog is tracked or not.
  def update_switch_button
    but = @gui["btnSwitch"]
    tlog_act = @args[:oata].timelog_active
    
    if tlog_act
      but.image = Gtk::Image.new(Gtk::Stock::MEDIA_STOP, Gtk::IconSize::BUTTON)
      but.label = _("Stop")
    else
      but.image = Gtk::Image.new(Gtk::Stock::MEDIA_RECORD, Gtk::IconSize::BUTTON)
      but.label = _("Start")
    end
  end
  
  #This method runs through all rows in the treeview and checks if a row should be marked with bold. It also increases the time in the time-column for the tracked timelog.
  def check_rows
    act_timelog = @args[:oata].timelog_active
    
    if act_timelog
      act_timelog_id = act_timelog.id
    else
      act_timelog_id = nil
    end
    
    rows_bold = [1, 2, 3, 4, 5, 6, 7, 11]
    
    @gui["tvTimelogs"].model.each do |model, path, iter|
      timelog_id = model.get_value(iter, 0).to_i
      bold = false
      iter_id = iter.to_s.to_i
      
      #Update time tracked.
      if timelog_id == act_timelog_id
        secs = act_timelog.time_total + @args[:oata].timelog_active_time_tracked
        iter[3] = "<b>#{Knj::Strings.secs_to_human_time_str(secs)}</b>"
        bold = true
      end
      
      #Set all columns to bold if not already set.
      if bold and !@bold_rows.key?(iter_id)
        rows_bold.each do |row_no|
          iter[row_no] = "<b>#{model.get_value(iter, row_no)}</b>"
        end
        
        @bold_rows[iter_id] = true
      end
    end
  end
  
  def on_btnSync_clicked
    @args[:oata].show_prepare_sync
  end
  
  def on_miSyncStatic_activate
    @args[:oata].sync_static("transient_for" => @gui["window"])
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
    #Add new timelog to database.
    timelog = @args[:oata].ob.add(:Timelog)
    
    #Focus new timelog in treeview and open the in-line-editting for the description.
    added_id = timelog.id.to_i
    
    @gui["tvTimelogs"].model.each do |model, path, iter|
      timelog_id = model.get_value(iter, 0).to_i
      
      if timelog_id == added_id
        col = @gui["tvTimelogs"].columns[1]
        @gui["tvTimelogs"].set_cursor(path, col, true)
        break
      end
    end
  end
  
  #Redirects 'enter'-events to 'switch'-click-event.
  def on_txtDescr_activate(*args)
    self.on_btnSwitch_clicked
  end
end