#This class handels the window that will be shown before the actual sync takes place.
class Openall_time_applet::Gui::Win_sync_overview
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_sync_overview.glade")
    @gui.translate
    @gui.connect_signals{|h|method(h)}
    @gui["btnSync"].label = _("Transfer")
    
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
    
    #Initialize timelog treeview.
    init_data = Knj::Gtk2::Tv.init(@gui["tvTimelogs"], [
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
      },
      _("Sync time")
    ])
    
    #Make columns editable.
    Knj::Gtk2::Tv.editable_text_renderers_to_model(
      :ob => @args[:oata].ob,
      :tv => @gui["tvTimelogs"],
      :model_class => :Timelog,
      :renderers => init_data[:renderers],
      :change_before => proc{ @dont_reload = true },
      :change_after => proc{ @dont_reload = false; self.update_totals },
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
        },
        12 => {:col => :time_sync, :type => :time_as_sec}
      }
    )
    @gui["tvTimelogs"].columns[0].visible = false
    
    
=begin
    rowc = 1
    @args[:oata].ob.list(:Timelog, {"sync_need" => 1, "task_id_not" => 0}) do |timelog|
      
      
      #Spawn widgets.
      timelog_label = Gtk::Label.new(timelog[:descr])
      timelog_label.xalign = 0
      timelog_label.selectable = true
      
      logged_time_label = Gtk::Label.new(Knj::Strings.secs_to_human_time_str(timelog[:time]))
      logged_time_label.xalign = 0
      logged_time_label.selectable = true
      
      sync_time_text = Gtk::Entry.new
      sync_time_text.text = Knj::Strings.secs_to_human_time_str(count_rounded_time)
      sync_time_text.signal_connect(:changed, &self.method(:on_syncTimeText_changed))
      @sync_time_text_widgets[timelog.id] = sync_time_text
      
      #Attach widgets in table.
      @gui["tableTimelogs"].attach(timelog_label, 0, 1, rowc, rowc + 1)
      @gui["tableTimelogs"].attach(logged_time_label, 1, 2, rowc, rowc + 1)
      @gui["tableTimelogs"].attach(sync_time_text, 2, 3, rowc, rowc + 1)
      
      rowc += 1
    end
=end
    
    self.reload_timelogs
    self.update_totals
    
    @reload_id = @args[:oata].ob.connect("object" => :Timelog, "signals" => ["add", "update", "delete"], &self.method(:reload_timelogs))
    
    if @timelogs_count <= 0
      #Show error-message and destroy the window, if no timelogs was to be synced.
      Knj::Gtk2.msgbox("msg" => _("There is nothing to sync at this time."), "run" => false)
      @gui["window"].destroy
    else
      #...else show the window.
      @gui["window"].show_all
    end
  end
  
  def reload_timelogs
    return nil if @dont_reload or @gui["tvTimelogs"].destroyed?
    @gui["tvTimelogs"].model.clear
    @timelogs_count = 0
    @args[:oata].ob.list(:Timelog, {"sync_need" => 1, "task_id_not" => 0, "task_id_not" => "", "orderby" => "timestamp"}) do |timelog|
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
      
      Knj::Gtk2::Tv.append(@gui["tvTimelogs"], [
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
        timelog.task_name,
        Knj::Strings.secs_to_human_time_str(count_rounded_time)
      ])
      @timelogs_count += 1
    end
  end
  
  def on_btnSync_clicked
    begin
      #Destroy this window and start syncing for real.
      @gui["window"].destroy
      @args[:oata].sync_real
    rescue => e
      Knj::Gtk2.msgbox(Knj::Errors.error_str(e))
    end
  end
  
  def update_totals
    total_secs = 0
    
    @gui["tvTimelogs"].model.each do |model, path, iter|
      time_val = @gui["tvTimelogs"].model.get_value(iter, 12)
      
      begin
        total_secs += Knj::Strings.human_time_str_to_secs(time_val)
      rescue
        #ignore - user is properly entering stuff.
      end
    end
    
    @gui["labTotal"].markup = "<b>#{_("Total hours:")}</b> #{Knj::Strings.secs_to_human_time_str(total_secs)}"
  end
  
  def on_window_destroy
    #Unconnect reload-event. Else it will crash on call to destroyed object. Also frees up various ressources.
    @args[:oata].ob.unconnect("object" => :Timelog, "conn_id" => @reload_id)
  end
end