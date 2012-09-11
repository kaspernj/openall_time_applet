class Openall_time_applet::Gui::Win_main
  ROWS_BOLD = [:timestamp, :time, :descr, :ttime, :tkm, :ttype, :tdescr, :cost, :task]
  
  attr_reader :args, :gui
  
  def initialize(args)
    @args = args
    @oata = @args[:oata]
    @ob = @oata.ob
    @log = @oata.log
    
    @gui = Gtk::Builder.new.add("#{File.dirname(__FILE__)}/../glade/win_main.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    
    #Shortcut-variables to very used widgets.
    @window = @gui["window"]
    @expander = @gui["expOverview"]
    @tv = @gui["tvTimelogs"]
    @tvpt = @gui["tvTimelogsPrepareTransfer"]
    
    
    #Set icon for window.
    @window.icon = "#{File.dirname(__FILE__)}/../gfx/icon_time_black.png"
    
    
    #Settings for various widgets.
    Gtk2_expander_settings.new(:expander => @expander, :name => "main_expander", :db => @oata.db)
    Gtk2_window_settings.new(:window => @window, :name => "main_window", :db => @oata.db)
    
    #Trigger max. height stuff.
    self.on_expOverview_activate(@expander)
    
    #Generate list-store containing tasks for the task-column.
    @task_ls = Gtk::ListStore.new(String, String)
    
    iter = @task_ls.append
    iter[0] = _("None")
    iter[1] = "0"
    
    tasks = [_("Choose:")]
    @ob.static(:Task, :tasks_to_show) do |task|
      iter = @task_ls.append
      iter[0] = task.name
      iter[1] = task.id.to_s
      tasks << task
    end
    
    self.task_ls_resort
    @gui["cbTask"].init(tasks)
    
    
    #Generate list-store containing time-types.
    @time_types = Openall_time_applet::Models::Timelog.time_types
    time_types_ls = Gtk::ListStore.new(String, String)
    @time_types.each do |key, val|
      iter = time_types_ls.append
      iter[0] = val
      iter[1] = key
    end
    
    
    #Set up completion for description entry.
    @descr_ec = Gtk::EntryCompletion.new
    @descr_ec.model = Gtk::ListStore.new(String)
    @descr_ec.text_column = 0
    @gui["txtDescr"].completion = @descr_ec
    self.reload_descr_completion
    @descr_ec.signal_connect("match-selected", &self.method(:on_descr_entrycompletion_selected))
    
    
    
    init_data = @tv.init(
      :type => :treestore,
      :reorderable => false,
      :sortable => false,
      :cols => [
        _("ID"),
        {
          :title => _("Stamp"),
          :type => :string,
          :markup => true,
          :expand => false
        },
        {
          :title => _("Time"),
          :type => :string,
          :markup => true,
          :expand => false
        },
        {
          :title => _("Description"),
          :type => :string,
          :markup => true,
          :expand => true,
          :fixed_width => 160
        },
        {
          :title => _("T-time"),
          :type => :string,
          :markup => true,
          :expand => false
        },
        {
          :title => _("T-km"),
          :type => :string,
          :markup => true
        },
        {
          :title => _("T-Descr."),
          :type => :string,
          :markup => true,
          :expand => true,
          :fixed_width => 160
        },
        {
          :title => _("T-type"),
          :type => :combo,
          :model => time_types_ls,
          :has_entry => false,
          :fixed_width => 120,
          :markup => true
        },
        {
          :title => _("Cost"),
          :type => :string,
          :markup => true
        },
        {
          :title => _("Fixed"),
          :type => :toggle,
          :expand => false
        },
        {
          :title => _("Internal")[0, 3] + ".",
          :type => :toggle,
          :expand => false
        },
        {
          :title => _("Task"),
          :type => :combo,
          :model => @task_ls,
          :has_entry => false,
          :markup => true,
          :expand => true,
          :fixed_width => 160
        },
        {
          :title => _("Track"),
          :type => :toggle,
          :expand => false
        }
      ]
    )
    
    @tv_settings = Gtk2_treeview_settings.new(
      :tv => @tv,
      :col_ids => {
        0 => :id,
        1 => :timestamp,
        2 => :time,
        3 => :descr,
        4 => :ttime,
        5 => :tkm,
        6 => :tdescr,
        7 => :ttype,
        8 => :cost,
        9 => :fixed,
        10 => :int,
        11 => :task,
        12 => :track
      }
    )
    
    Knj::Gtk2::Tv.editable_text_renderers_to_model(
      :ob => @oata.ob,
      :tv => @tv,
      :model_class => :Timelog,
      :renderers => init_data[:renderers],
      :change_before => proc{|d|
        if d[:col_no] == 2 and @oata.timelog_active and @oata.timelog_active.id == d[:model].id
          raise _("You cannot edit the time for the active timelog.")
        end
        
        @dont_reload = true
      },
      :change_after => proc{
        @dont_reload = false
      },
      :on_edit => proc{|d|
        @tv_editting = true
      },
      :on_edit_done => proc{|d|
        @tv_editting = nil
      },
      :cols => {
        @tv_settings.col_orig_no_for_id(:timestamp) => {
          :col => :timestamp,
          :value_callback => self.method(:tv_editable_timestamp_callback),
          :value_set_callback => self.method(:tv_editable_timestamp_set_callback)
        },
        @tv_settings.col_orig_no_for_id(:time) => {
          :col => :time,
          :value_callback => proc{ |data| Knj::Strings.human_time_str_to_secs(data[:value]) },
          :value_set_callback => proc{ |data| Knj::Strings.secs_to_human_time_str(data[:value], :secs => false) }
        },
        @tv_settings.col_orig_no_for_id(:descr) => :descr,
        @tv_settings.col_orig_no_for_id(:ttime) => {
          :col => :time_transport,
          :value_callback => proc{ |data| Knj::Strings.human_time_str_to_secs(data[:value]) },
          :value_set_callback => proc{ |data| Knj::Strings.secs_to_human_time_str(data[:value], :secs => false) }
        },
        @tv_settings.col_orig_no_for_id(:tkm) => {:col => :transportlength, :type => :int},
        @tv_settings.col_orig_no_for_id(:tdescr) => {:col => :transportdescription},
        @tv_settings.col_orig_no_for_id(:ttype) => {
          :col => :timetype,
          :value_callback => lambda{|data|
            @time_types.key(data[:value])
          },
          :value_set_callback => proc{|data|
            Knj::Web.html(@time_types.fetch(data[:value]))
          }
        },
        @tv_settings.col_orig_no_for_id(:cost) => {:col => :transportcosts, :type => :human_number, :decimals => 2},
        @tv_settings.col_orig_no_for_id(:fixed) => {:col => :travelfixed},
        @tv_settings.col_orig_no_for_id(:int) => {:col => :workinternal},
        @tv_settings.col_orig_no_for_id(:task) => {
          :col => :task_id,
          :value_callback => lambda{|data|
            #Return ID of the found task or 0 if none was found.
            @ob.list(:Task) do |task|
              return task.id if task.name == data[:value]
            end
            
            return 0
          },
          :value_set_callback => proc{|data|
            #Return the task-name for the current rows timelog.
            data[:model].task_name
          }
        },
        @tv_settings.col_orig_no_for_id(:track) => {
          :value_callback => lambda{|data|
            if !data[:model]
              Knj::Gtk2.msgbox(_("You cannot track a date. Please track a timelog instead."))
              return false
            else
              if data[:value]
                @oata.timelog_active = data[:model]
              elsif data[:model] == @oata.timelog_active
                @oata.timelog_stop_tracking
              end
              
              return data[:model] == @oata.timelog_active
            end
          }
        }
      }
    )
    
    
    #The ID column should not be visible (it is only used to identify which timelog the row represents).
    @tv.columns[0].visible = false
    
    
    #Move the columns around to the right order (the way Jacob wanted them).
    @tv.move_column_after(@tv.columns[10], @tv.columns[3])
    @tv.move_column_after(@tv.columns[11], @tv.columns[3])
    @tv.move_column_after(@tv.columns[11], @tv.columns[5])
    @tv.move_column_after(@tv.columns[9], @tv.columns[6])
    @tv.move_column_after(@tv.columns[11], @tv.columns[8])
    @tv.move_column_after(@tv.columns[12], @tv.columns[0])
    
    
    #When a new row is selected, is should be evaluated if the minus-button should be active or not.
    @tv.selection.signal_connect("changed", &self.method(:validate_minus_active))
    self.validate_minus_active
    
    
    #Connect certain column renderers to the editingStarted-method, so editing can be canceled, if the user tries to edit forbidden data on the active timelog.
    init_data[:renderers][2].signal_connect_after("editing-started", :time, &self.method(:on_cell_editingStarted))
    
    
    #Fills the timelogs-treeview with data.
    self.reload_timelogs
    
    
    #Reload the treeview if something happened to a timelog.
    @reload_id = @ob.connect("object" => :Timelog, "signals" => ["add", "update"], &self.method(:reload_timelogs))
    @reload_id_delete = @ob.connect("object" => :Timelog, "signals" => ["delete"], &self.method(:on_timelog_delete))
    @reload_id_update = @ob.connect("object" => :Timelog, "signals" => ["update"], &self.method(:on_timelog_update))
    @reload_tasks_id = @ob.connect("object" => :Task, "signals" => ["add"], &self.method(:on_task_added))
    
    
    #Update switch-button.
    self.update_switch_button
    
    
    #Update switch-button when active timelog is changed.
    @event_timelog_active_changed = @oata.events.connect(:timelog_active_changed, &self.method(:on_timelog_active_changed))
    
    
    #This timeout controls the updating of the timelog-info-frame and the time-counter for the active timelog in the treeview.
    @timeout_id = Gtk.timeout_add(1000, &self.method(:timeout_update_sec))
    self.timeout_update_sec if @oata.timelog_active
    
    
    #Initializes sync-box.
    lab_transfer = _("Transfer")
    lab_transfer = "#{lab_transfer[0, 1]}_#{lab_transfer[1, 99]}" #For 'r'-shortcut.
    @gui["btnSyncPrepareTransfer"].label = lab_transfer
    
    
    #Generate list-store containing tasks for the task-column.
    @task_ls = Gtk::ListStore.new(String, String)
    iter = @task_ls.append
    iter[0] = _("None")
    iter[1] = 0.to_s
    
    tasks = [_("Choose:")]
    @ob.static(:Task, :tasks_to_show) do |task|
      iter = @task_ls.append
      iter[0] = task.name
      iter[1] = task.id.to_s
      tasks << task
    end
    
    #Initialize timelog treeview.
    init_data = Knj::Gtk2::Tv.init(@tvpt, [
      _("ID"),
      {
        :title => _("Description"),
        :type => :string,
        :expand => true
      },
      _("Stamp"),
      _("Time"),
      _("T-time"),
      _("T-km"),
      {
        :title => _("T-Descr."),
        :type => :string,
        :expand => true
      },
      _("Cost"),
      {
        :title => _("Fixed"),
        :type => :toggle
      },
      {
        :title => _("Internal")[0, 3] + ".",
        :type => :toggle
      },
      {
        :title => _("Skip"),
        :type => :toggle
      },
      {
        :title => _("Task"),
        :type => :combo,
        :model => @task_ls,
        :has_entry => false,
        :expand => true,
        :markup => true
      },
      _("Sync time")
    ])
    
    @tv_settings_pt = Gtk2_treeview_settings.new(
      :id => "win_main_tvTimelogsPrepareTransfer",
      :tv => @tvpt,
      :col_ids => {
        0 => :id,
        1 => :descr,
        2 => :timestamp,
        3 => :time,
        4 => :ttime,
        5 => :tkm,
        6 => :tdescr,
        7 => :cost,
        8 => :fixed,
        9 => :internal,
        10 => :skip,
        11 => :task,
        12 => :sync_time
      }
    )
    
    @tvpt.move_column_after(@tvpt.columns[1], @tvpt.columns[3])
    @tvpt.move_column_after(@tvpt.columns[11], @tvpt.columns[3])
    @tvpt.move_column_after(@tvpt.columns[9], @tvpt.columns[4])
    @tvpt.move_column_after(@tvpt.columns[10], @tvpt.columns[5])
    @tvpt.move_column_after(@tvpt.columns[9], @tvpt.columns[6])
    
    #Make columns editable.
    Knj::Gtk2::Tv.editable_text_renderers_to_model(
      :ob => @oata.ob,
      :tv => @tvpt,
      :model_class => :Timelog,
      :renderers => init_data[:renderers],
      :change_before => proc{ @dont_reload_sync = true },
      :change_after => proc{ @dont_reload_sync = false; self.update_sync_totals },
      :cols => {
        10 => {:col => :sync_need, :type => :toggle_rev},
        12 => {
          :col => :time_sync,
          :value_callback => proc{ |data| Knj::Strings.human_time_str_to_secs(data[:value]) },
          :value_set_callback => proc{ |data| Knj::Strings.secs_to_human_time_str(data[:value], :secs => false) }
        }
      }
    )
    @tvpt.columns[0].visible = false
    @gui["vboxPrepareTransfer"].hide
    @reload_preparetransfer_id = @ob.connect("object" => :Timelog, "signals" => ["add", "update"], &self.method(:reload_timelogs_preparetransfer))
    
    
    
    #Show the window.
    @window.show
    self.timelog_info_trigger
    width = @window.size[0]
    @window.resize(width, 1)
  end
  
  def window_resize_height_disable
    hints = Gdk::Geometry.new
    
    hints.min_width = 1
    hints.max_width = 9999
    
    hints.min_height = 1
    hints.max_height = 1
    
    @window.set_geometry_hints(@expander, hints, Gdk::Window::HINT_MAX_SIZE)
  end
  
  def window_resize_height_enable
    hints = Gdk::Geometry.new
    
    hints.min_width = 1
    hints.max_width = 9999
    
    hints.min_height = 1
    hints.max_height = 9999
    
    @window.set_geometry_hints(@expander, hints, Gdk::Window::HINT_MAX_SIZE)
  end
  
  def task_ls_resort
    @task_ls.set_sort_column_id(0)
    @task_ls.set_sort_func(0, &lambda{|iter1, iter2|
      task_id_1 = iter1[1].to_i
      task_id_2 = iter2[1].to_i
      
      task_name_1 = iter1[0].to_s.downcase
      task_name_2 = iter2[0].to_s.downcase
      
      if task_id_1 == 0
        return -1
      elsif task_id_2 == 0
        return 1
      else
        return task_name_1 <=> task_name_2
      end
    })
  end
  
  #Called after a new task has been added.
  def on_task_added(task)
    puts "New task added: #{task.to_hash}"
    
    #Add the new task to the treeview rows.
    iter = @task_ls.append
    iter[0] = task.name
    iter[1] = task.id.to_s
    
    self.task_ls_resort
    
    renderer = @tv_settings.cellrenderer_for_id(:task)
    renderer.model = @task_ls
    
    #Add the new task to the combobox in the top.
    @gui["cbTask"].append_model(:model => task)
    @gui["cbTask"].resort
  end
  
  #This is called when an item from the description-entry-completion-menu is selected. This method sets the selected text in the description-entry.
  def on_descr_entrycompletion_selected(me, model, iter)
    text = model.get_value(iter, 0)
    me.entry.text = text
    return true
  end
  
  #This method is called when the active timelog is changed. It calls various events to update the switch-button, update information in treeview and more instantly (instead of waiting for the 1-sec timeout which will seem like a delay).
  def on_timelog_active_changed(*args)
    self.update_switch_button
    self.check_rows
    self.timelog_info_trigger
  end
  
  #This method is called every second in order to update various information when tracking timelogs (stop-button-time, treeview-time and more).
  def timeout_update_sec
    #Update various information in the main treeview (time-counter).
    self.check_rows
    self.timelog_info_trigger
    
    #Returns true in order to continue calling this method every second.
    return true
  end
  
  #This is called when updating a timelogs timestamp through the treeview.
  def tv_editable_timestamp_callback(data)
    begin
      return data[:model].timestamp.update_from_str(data[:value])
    rescue => e
      Knj::Gtk2.msgbox(e.message)
      return data[:model].timestamp
    end
  end
  
  #This is called when a timelogs timestamp should be shown.
  def tv_editable_timestamp_set_callback(data)
    return Datet.in(data[:value]).strftime("%H:%M")
  end
  
  #Reloads the suggestions for the description-entry-completion.
  def reload_descr_completion
    added = {}
    @descr_ec.model.clear
    
    @ob.list(:Worktime, "orderby" => [["timestamp", "desc"]]) do |worktime|
      next if added.key?(worktime[:comment])
      added[worktime[:comment]] = true
      @descr_ec.model.append[0] = worktime[:comment]
    end
    
    @ob.list(:Timelog, "orderby" => [["timestamp", "desc"]]) do |timelog|
      next if added.key?(timelog[:descr])
      added[timelog[:descr]] = true
      @descr_ec.model.append[0] = timelog[:descr]
    end
  end
  
  def reload_timelogs_preparetransfer
    return nil if @dont_reload_sync or @tvpt.destroyed?
    @dont_reload_sync = true
    
    begin
      @tvpt.model.clear
      @timelogs_sync_count = 0
      tnow_str = Time.now.strftime("%Y %m %d")
      
      @ob.list(:Timelog, "task_id_not" => ["", 0], "orderby" => [["timestamp", "desc"]]) do |timelog|
        #Read time and transport from timelog.
        time = timelog[:time].to_i
        transport = timelog[:time_transport].to_i
        
        #If transport is logged, then the work if offsite. It should be rounded up by 30 min. Else 15 min. round up.
        if transport > 0
          roundup = 1800
        else
          roundup = 900
        end
        
        #Do the actual counting.
        count_rounded_time = 0
        loop do
          break if count_rounded_time >= time
          count_rounded_time += roundup
        end
        
        #Set sync-time on timelog.
        timelog[:time_sync] = count_rounded_time
        
        tstamp = timelog.timestamp
        
        if tstamp.strftime("%Y %m %d") == tnow_str
          tstamp_str = tstamp.strftime("%H:%M")
        else
          tstamp_str = tstamp.strftime("%d/%m")
        end
        
        @tv_settings_pt.append(
          :id => timelog.id,
          :descr => timelog[:descr],
          :timestamp => tstamp_str,
          :time => timelog.time_as_human,
          :ttime => timelog.time_transport_as_human,
          :tkm => Knj::Locales.number_out(timelog[:transportlength], 0),
          :tdescr => timelog.transport_descr_short,
          :cost => Knj::Locales.number_out(timelog[:transportcosts], 2),
          :fixed => Knj::Strings.yn_str(timelog[:travelfixed], true, false),
          :internal => Knj::Strings.yn_str(timelog[:workinternal], true, false),
          :skip => Knj::Strings.yn_str(timelog[:sync_need], false, true),
          :task => timelog.task_name,
          :sync_time => Knj::Strings.secs_to_human_time_str(count_rounded_time, :secs => false)
        )
        @timelogs_sync_count += 1
      end
    ensure
      @dont_reload_sync = nil
    end
  end
  
  def on_btnSync_clicked
    self.reload_timelogs_preparetransfer
    
    if @timelogs_sync_count <= 0
      #Show error-message and destroy the window, if no timelogs was to be synced.
      Knj::Gtk2.msgbox("msg" => _("There is nothing to sync at this time."), "run" => false)
    else
      #...else show the window.
      @expander.hide
      self.update_sync_totals
      @gui["vboxPrepareTransfer"].show
    end
  end
  
  def update_sync_totals
    total_secs = 0
    
    @tvpt.model.each do |model, path, iter|
      time_val = @tvpt.model.get_value(iter, 12)
      
      col_no_skip = @tv_settings_pt.col_orig_no_for_id(:skip)
      skip_val = @tvpt.model.get_value(iter, col_no_skip)
      
      if skip_val != 1
        begin
          total_secs += Knj::Strings.human_time_str_to_secs(time_val)
        rescue
          #ignore - user is properly entering stuff.
        end
      end
    end
    
    @gui["labTotal"].markup = "<b>#{_("Total hours:")}</b> #{Knj::Strings.secs_to_human_time_str(total_secs, :secs => false)}"
  end
  
  def on_btnCancelPrepareTransfer_clicked
    @expander.show
    @gui["vboxPrepareTransfer"].hide
  end
  
  #This method is called, when editting starts in a description-, time- or task-cell. If it is the active timelog, then editting is canceled.
  def on_cell_editingStarted(renderer, editable, path, col_title)
    iter = @tv.model.get_iter(path)
    timelog_id = @tv.model.get_value(iter, 0).to_i
    
    if tlog = @oata.timelog_active and tlog.id.to_i == timelog_id
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
    self.reload_descr_completion
    
    return nil if @dont_reload or @tv.destroyed?
    @log.debug("Reloading main treeview.")
    
    tnow_str = Time.now.strftime("%Y %m %d")
    @tv.model.clear
    
    #Create date-parent elements that the timelogs will be appended under.
    dates = {}
    now_year = Time.now.year
    
    @ob.list(:Timelog, "orderby" => [["timestamp", "desc"]]) do |tlog|
      tstamp = Datet.in(tlog[:timestamp])
      next if !tstamp
      str = tstamp.out(:time => false)
      
      if !dates.key?(str)
        tstamp_year = tstamp.year
        
        if tstamp_year != now_year
          date_str = str
        else
          date_str = tstamp.out(:time => false, :year => false)
        end
        
        iter = @tv_settings.tv.model.append(nil)
        iter[1] = "<b>#{Knj::Web.html(date_str)}</b>"
        
        dates[str] = {
          :iter => iter,
          :tlogs => []
        }
      end
    end
    
    #Append the timelogs to the parent dates.
    @ob.list(:Timelog, "orderby" => ["task_id", "descr", "timestamp"]) do |timelog|
      begin
        tstamp_str = timelog.timestamp_str
      rescue => e
        tstamp_str = "[#{_("error")}: #{e.message}"
      end
      
      if tstamp = timelog.timestamp
        tstamp_str = tstamp.strftime("%H:%M")
        parent = dates[tstamp.out(:time => false)][:iter]
      else
        parent = nil
      end
      
      @tv_settings.append_adv(
        :parent => parent,
        :data => {
          :id => timelog.id,
          :timestamp => tstamp_str,
          :time => timelog.time_as_human,
          :descr => Knj::Web.html(timelog[:descr]),
          :ttime => timelog.time_transport_as_human,
          :tkm => Knj::Locales.number_out(timelog[:transportlength], 0),
          :ttype => @time_types[timelog[:timetype]],
          :tdescr => Knj::Web.html(timelog[:transportdescription]),
          :cost => Knj::Locales.number_out(timelog[:transportcosts], 2),
          :fixed => Knj::Strings.yn_str(timelog[:travelfixed], true, false),
          :int => Knj::Strings.yn_str(timelog[:workinternal], true, false),
          :task => timelog.task_name
        }
      )
    end
    
    #Make all dates expand their content (timelogs).
    @tv.expand_all
    
    #Reset cache of which rows are set to bold.
    @bold_rows = {}
  end
  
  def timelog_tv_data_by_timelog(timelog)
    @tv.model.each do |model, path, iter|
      timelog_i_id = iter[0].to_i
      
      if timelog.id.to_i == timelog_i_id
        return {
          :timelog => timelog,
          :iter => iter,
          :path => path
        }
      end
    end
    
    raise Errno::ENOENT, sprintf(_("Could not find timelog in treeview: '%s'."), timelog.id)
  end
  
  def date_tv_data_by_datet(datet, args = nil)
    datet_str = datet.out(:time => false)
    add_after = nil
    
    @tv.model.each do |model, path, iter|
      #Skip the iter's that are timelogs (we look for a parent-date).
      timelog_id = iter[0].to_i
      next if timelog_id != 0
      
      date_i_str = Php4r.strip_tags(iter[1])
      
      if date_i_str == datet_str
        return {
          :iter => iter,
          :path => path
        }
      end
      
      datet_i = Datet.in(date_i_str)
      
      if datet_i < datet
        add_after = iter
      end
    end
    
    if args and args[:add]
      iter = @tv.insert_after(nil, add_after)
      iter[1] = "<b>#{Knj::Web.html(datet.out(:time => false))}</b>"
      
      return {
        :iter => iter
      }
    end
    
    raise sprintf(_("Could not find iter from that date: '%s'."), datet)
  end
  
  #This method is called every time a timelog is updated (changed). This is needed to move timelogs around under the right dates, when the date is changed for a timelog.
  def on_timelog_update(timelog)
    #Get the treeview-data for the selected timelog.
    tlog_data = self.timelog_tv_data_by_timelog(timelog)
    
    #Get the date from the parent treeview-iter.
    parent_iter = tlog_data[:iter].parent
    parent_date = Php4r.strip_tags(parent_iter[1])
    
    #Get the date from the selected timelog.
    tlog_date_str = timelog.timestamp.out(:time => false, :year => false)
    
    #The date of the timelog has been updated, and the timelog has to be moved elsewhere in the treeview.
    if parent_date != tlog_date_str
      #Wait 5 miliseconds so the 'dont_reload' variable wont be 'true' any more.
      Gtk.timeout_add(5) do
        @log.debug("Timestamps wasnt the same - reload treeview (parent: #{parent_date} vs tlog: #{tlog_date_str}).")
        
        #Reload timelogs to make the changed timelog appear under the right date.
        self.reload_timelogs
        
        #Re-select the timelog in the treeview.
        begin
          if !timelog.deleted?
            tlog_data = self.timelog_tv_data_by_timelog(timelog)
            @tv.selection.select_iter(tlog_data[:iter])
          end
        rescue Errno::ENOENT
          #Ignore - it has been deleted.
        end
        
        #Return false for the timeout, so it wont be called again.
        false
      end
    end
  end
  
  #This method handels events for when a timelog is deleted. It removes the timelog from various treeviews, so it isnt necessary to do a complete reload of them, which takes a lot longer.
  def on_timelog_delete(timelog)
    del_id = timelog.id.to_i
    
    @tv.model.each do |model, path, iter|
      timelog_id = model.get_value(iter, 0).to_i
      next if timelog_id <= 0
      
      if timelog_id == del_id
        model.remove(iter)
        break
      end
    end
    
    @tvpt.model.each do |model, path, iter|
      timelog_id = model.get_value(iter, 0).to_i
      next if timelog_id <= 0
      
      if timelog_id == del_id
        model.remove(iter)
        break
      end
    end
  end
  
  #Called when the quit-menu-item is activated.
  def on_imiQuit_activate
    #Check if a timelog needs to be synced. If so the user needs to confirm he really wants to quit.
    timelog_found = nil
    do_destroy = true
    
    @ob.list(:Timelog, "task_id_not" => ["", 0]) do |timelog|
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
    
    @oata.destroy if do_destroy
  end
  
  def on_imiPreferences_activate
    @oata.show_preferences
  end
  
  def on_imiWeekview_activate
    @oata.show_worktime_overview
  end
  
  def on_window_destroy
    #Unconnect reload-event. Else it will crash on call to destroyed object. Also frees up various ressources.
    @ob.unconnect("object" => :Timelog, "conn_ids" => [@reload_id, @reload_id_update, @reload_id_delete, @reload_preparetransfer_id])
    @ob.unconnect("object" => :Task, "conn_ids" => [@reload_tasks_id])
    
    @oata.events.disconnect(:timelog_active_changed, @event_timelog_active_changed) if @event_timelog_active_changed
    @event_timelog_active_changed = nil
    Gtk.timeout_remove(@timeout_id)
  end
  
  def on_expOverview_activate(expander)
    if expander.expanded?
      self.window_resize_height_enable
      @log.debug("Current window-size: #{@window.size}")
      size = @window.size
      @window.resize(size[0], 480) if size[1] < 480
      self.timelog_info_trigger
    else
      self.window_resize_height_disable
      self.timelog_info_trigger
    end
  end
  
  #This method handles the "Timelog info"-frame. Hides, shows and updates the info in it.
  def timelog_info_trigger
    if tlog = @oata.timelog_active
      time_tracked = @oata.timelog_active_time_tracked + tlog.time_total
      @gui["btnSwitch"].label = "#{_("Stop")} (#{Knj::Strings.secs_to_human_short_time(time_tracked)})"
      
      #Update icon every second while showing main-window, so it looks like stop-button and tray-icon-time is in sync (else tray will only update every 30 sec. which will make it look out of sync, even though it wont be).
      @oata.ti.update_icon
    end
  end
  
  def on_btnSwitch_clicked
    if @oata.timelog_active
      @oata.timelog_stop_tracking
      @gui["txtDescr"].grab_focus
    else
      descr = @gui["txtDescr"].text.to_s.strip
      
      task = @gui["cbTask"].sel
      if !task.is_a?(Knj::Datarow)
        task_id = 0
      else
        task_id = task.id
      end
      
      timelog = @ob.get_by(:Timelog, {
        "task_id" => task_id,
        "descr_lower" => descr,
        "timestamp_day" => Time.now
      })
      
      if !timelog
        timelog = @ob.add(:Timelog, {
          :task_id => task_id,
          :descr => descr
        })
      end
      
      @oata.timelog_active = timelog
      @gui["txtDescr"].text = ""
      @gui["cbTask"].sel = _("Choose:")
    end
    
    self.update_switch_button
  end
  
  #This method updates the switch button to start or stop, based on the if a timelog is tracked or not.
  def update_switch_button
    but = @gui["btnSwitch"]
    tlog_act = @oata.timelog_active
    
    if tlog_act
      but.image = Gtk::Image.new(Gtk::Stock::MEDIA_STOP, Gtk::IconSize::BUTTON)
      
      @gui["txtDescr"].text = tlog_act[:descr]
      
      if task = tlog_act.task
        @gui["cbTask"].sel = task.name
      else
        @gui["cbTask"].sel = _("Choose:")
      end
      
      @gui["txtDescr"].sensitive = false
      @gui["cbTask"].sensitive = false
    else
      but.image = Gtk::Image.new(Gtk::Stock::MEDIA_RECORD, Gtk::IconSize::BUTTON)
      but.label = _("Start")
      
      @gui["txtDescr"].text = ""
      @gui["cbTask"].sel = _("Choose:")
      @gui["txtDescr"].sensitive = true
      @gui["cbTask"].sensitive = true
    end
  end
  
  #This method runs through all rows in the treeview and checks if a row should be marked with bold. It also increases the time in the time-column for the tracked timelog.
  def check_rows
    return nil if @tv_editting
    act_timelog = @oata.timelog_active
    
    if act_timelog
      act_timelog_id = act_timelog.id
    else
      act_timelog_id = nil
    end
    
    col_no_track = @tv_settings.col_orig_no_for_id(:track)
    
    @tv.model.each do |model, path, iter|
      timelog_id = model.get_value(iter, 0).to_i
      bold = false
      
      #Update time tracked.
      if timelog_id == act_timelog_id
        secs = act_timelog.time_total + @oata.timelog_active_time_tracked
        col_no = @tv_settings.col_orig_no_for_id(:time)
        iter[col_no] = "<b>#{Knj::Strings.secs_to_human_time_str(secs, :secs => false)}</b>"
        bold = true
        
        @log.debug("Setting track-check for timelog '#{timelog_id}'.")
        iter[col_no_track] = 1
      else
        if iter[col_no_track] == 1
          #Track-check-value is set for a timelog that isnt being tracked - remove it.
          @log.debug("Remove track-check for timelog '#{timelog_id}'.")
          iter[col_no_track] = 0
        end
        
        if @bold_rows[timelog_id] == true
          #Remove bold text if timelog is not being tracked.
          ROWS_BOLD.each do |row_no|
            col_no = @tv_settings.col_orig_no_for_id(row_no)
            cur_val = model.get_value(iter, col_no)
            iter[col_no] = cur_val.gsub(/^<b>/i, "").gsub(/<\/b>$/i, "")
          end
          
          @bold_rows.delete(timelog_id)
        end
      end
      
      #Set all columns to bold if not already set.
      if bold and !@bold_rows.key?(timelog_id)
        ROWS_BOLD.each do |row_no|
          col_no = @tv_settings.col_orig_no_for_id(row_no)
          iter[col_no] = "<b>#{model.get_value(iter, col_no)}</b>"
        end
        
        @bold_rows[timelog_id] = true
      end
    end
  end
  
  def on_miSyncStatic_activate
    @oata.sync_static("transient_for" => @window)
  end
  
  def on_btnMinus_clicked
    sel = @tv.sel
    tlog = @ob.get(:Timelog, sel[0]) if sel
    
    if !sel or !tlog
      Knj::Gtk2.msgbox(_("Please choose a timelog to delete."), "warning")
      return nil
    end
    
    return nil if Knj::Gtk2.msgbox(_("Do you want to remove this timelog?"), "yesno") != "yes"
    begin
      @log.debug("Deleting timelog from pressing minus and confirming: '#{tlog.id}'.")
      @ob.delete(tlog)
    rescue => e
      Knj::Gtk2.msgbox(sprintf(_("Could not delete the timelog: %s"), e.message))
    end
  end
  
  def on_btnPlus_clicked
    #Add new timelog to database.
    timelog = @ob.add(:Timelog)
    @log.debug("Timelog added from pressing plus-button: '#{timelog.to_hash}'.")
    
    #Focus new timelog in treeview and open the in-line-editting for the description.
    added_id = timelog.id.to_i
    
    @tv.model.each do |model, path, iter|
      col_no = @tv_settings.col_no_for_id(:id)
      timelog_id = model.get_value(iter, col_no).to_i
      
      if timelog_id == added_id
        @log.debug("Setting focus to added timelog.")
        col = @tv.columns[1]
        @tv.set_cursor(path, col, true)
        break
      end
    end
  end
  
  #Redirects 'enter'-events to 'switch'-click-event.
  def on_txtDescr_activate(*args)
    self.on_btnSwitch_clicked
  end
  
  def on_btnSyncPrepareTransfer_clicked
    begin
      #Destroy this window and start syncing for real.
      @window.destroy
      @oata.sync_real
    rescue => e
      Knj::Gtk2.msgbox(Knj::Errors.error_str(e))
    end
  end
  
  #Enables or disables the minus-button based on what is selected in the treeview.
  def validate_minus_active(*args)
    sel = @tv.sel
    
    if sel and sel[0].to_i > 0
      @gui["btnMinus"].sensitive = true
    else
      @gui["btnMinus"].sensitive = false
    end
  end
end