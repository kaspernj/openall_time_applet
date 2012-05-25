#This class handels the window that will be shown before the actual sync takes place.
class Openall_time_applet::Gui::Win_sync_overview
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_sync_overview.glade")
    @gui.translate
    @gui.connect_signals{|h|method(h)}
    @gui["btnSync"].label = _("Synchronize")
    
    #This hash holds the text-widgets which time, which are used to update the timelogs later.
    @sync_time_text_widgets = {}
    
    rowc = 1
    @args[:oata].ob.list(:Timelog, {"sync_need" => 1, "task_id_not" => 0}) do |timelog|
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
      
      #Spawn widgets.
      timelog_label = Gtk::Label.new(timelog[:descr])
      timelog_label.xalign = 0
      timelog_label.selectable = true
      
      logged_time_label = Gtk::Label.new(Knj::Strings.secs_to_human_time_str(timelog[:time]))
      logged_time_label.xalign = 0
      logged_time_label.selectable = true
      
      sync_time_text = Gtk::Entry.new
      sync_time_text.text = Knj::Strings.secs_to_human_time_str(count_rounded_time)
      @sync_time_text_widgets[timelog.id] = sync_time_text
      
      #Attach widgets in table.
      @gui["tableTimelogs"].attach(timelog_label, 0, 1, rowc, rowc + 1)
      @gui["tableTimelogs"].attach(logged_time_label, 1, 2, rowc, rowc + 1)
      @gui["tableTimelogs"].attach(sync_time_text, 2, 3, rowc, rowc + 1)
      
      rowc += 1
    end
    
    if rowc == 1
      #Show error-message and destroy the window, if no timelogs was to be synced.
      Knj::Gtk2.msgbox(_("There is nothing to sync at this time."))
      @gui["window"].destroy
    else
      #...else show the window.
      @gui["window"].show_all
    end
  end
  
  def on_btnSync_clicked
    begin
      #Go through the shown timelogs and update their time to the entered and rounded time.
      @sync_time_text_widgets.each do |timelog_id, sync_time_text|
        timelog = @args[:oata].ob.get(:Timelog, timelog_id)
        secs = Knj::Strings.human_time_str_to_secs(sync_time_text.text)
        if !Knj::Php.is_numeric(secs)
          raise sprintf(_("Time was not numeric for: '%s'."), timelog[:descr])
        end
        
        #Update the time so that is what will be synchronized.
        timelog[:time] = secs
      end
      
      #Destroy this window and start syncing for real.
      @gui["window"].destroy
      @args[:oata].sync_real
    rescue => e
      Knj::Gtk2.msgbox(Knj::Errors.error_str(e))
    end
  end
end