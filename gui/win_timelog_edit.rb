class Openall_time_applet::Gui::Win_timelog_edit
  attr_reader :args, :gui
  
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_timelog_edit.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    
    tasks_opts = [_("None")] + @args[:oata].ob.list(:Task, {"orderby" => "openall_uid"})
    @gui["cbTask"].init(tasks_opts)
    
    #We are editting a timelog - set widget-values.
    @timelog = @args[:timelog]
    
    if @timelog
      @gui["txtDescr"].text = @timelog[:descr]
      @gui["txtTime"].text = @timelog.time_as_human
      @gui["txtTimeTransport"].text = @timelog.time_transport_as_human
      @gui["cbTask"].sel = @timelog.task if @timelog.task
      @gui["cbShouldSync"].active = Knj::Strings.yn_str(@timelog[:sync_need], true, false)
    else
      @gui["btnRemove"].visible = false
    end
    
    #Show the window.
    @gui["window"].show_all
  end
  
  def on_btnSave_clicked(*args)
    #Generate task-ID based on widget-value.
    task = @gui["cbTask"].sel
    if task.respond_to?(:is_knj?)
      task_id = task.id
    else
      task_id = 0
    end
    
    #Get times as integers based on widget-values.
    if @gui["txtTime"].text == ""
      time_secs = 0
    else
      begin
        time_secs = Knj::Strings.human_time_str_to_secs(@gui["txtTime"].text)
      rescue => e
        Knj::Gtk2.msgbox(_("You have entered an invalid time-format.") + "\n\n" + Knj::Errors.error_str(e))
        return nil
      end
    end
    
    if @gui["txtTimeTransport"].text == ""
      time_transport_secs = 0
    else
      begin
        time_transport_secs = Knj::Strings.human_time_str_to_secs(@gui["txtTimeTransport"].text)
      rescue => e
        Knj::Gtk2.msgbox(_("You have entered an invalid transport-time-format.") + "\n\n" + Knj::Errors.error_str(e))
        return nil
      end
    end
    
    #Generate hash for updating dataabase.
    save_hash = {
      :descr => @gui["txtDescr"].text,
      :time => time_secs,
      :time_transport => time_transport_secs,
      :task_id => task_id,
      :sync_need => Knj::Strings.yn_str(@gui["cbShouldSync"].active?, 1, 0)
    }
    
    #Update or add the timelog.
    if @timelog
      @timelog.update(save_hash)
    else
      @timelog = @args[:oata].ob.add(:Timelog, save_hash)
    end
    
    #Start tracking the current timelog if the checkbox has been checked.
    if @gui["cbStartTracking"].active?
      @args[:oata].timelog_active = @timelog
    end
    
    @gui["window"].destroy
  end
  
  def on_btnRemove_clicked(*args)
    if Knj::Gtk2.msgbox(_("Do you want to remove this timelog? This will not delete the timelog on OpenAll."), "yesno") != "yes"
      return nil
    end
    
    @args[:oata].ob.delete(@timelog)
    @gui["window"].destroy
  end
end