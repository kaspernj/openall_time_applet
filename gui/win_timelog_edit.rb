class Openall_time_applet::Gui::Win_timelog_edit
  attr_reader :args, :gui
  
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_timelog_edit.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    
    tasks_opts = [_("None")] + @args[:oata].ob.list(:Task, {"orderby" => "openall_uid"})
    @gui["cbTask"].init(tasks_opts)
    
    Knj::Gtk2::Cb.init(
      "cb" => @gui["cbTimeType"],
      "items" => {
        "normal" => _("Normal"),
        "overtime150" => sprintf(_("Overtime %s"), 150),
        "overtime200" => sprintf(_("Overtime %s"), 200)
      }
    )
    
    
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
    
    
    #We are editting a timelog - set widget-values.
    @timelog = @args[:timelog]
    
    if @timelog
      @gui["txtDescr"].text = @timelog[:descr]
      @gui["txtTime"].text = @timelog.time_as_human
      @gui["txtTimeTransport"].text = @timelog.time_transport_as_human
      @gui["txtTransportLength"].text = Knj::Locales.number_out(@timelog[:transportlength], 0)
      @gui["txtTransportCosts"].text = Knj::Locales.number_out(@timelog[:transportcosts], 0)
      @gui["txtTransportDescr"].text = @timelog[:transportdescription]
      @gui["cbTask"].sel = @timelog.task if @timelog.task
      @gui["cbShouldSync"].active = Knj::Strings.yn_str(@timelog[:sync_need], true, false)
      @gui["cbTravelFixed"].active = Knj::Strings.yn_str(@timelog[:travelfixed], true, false)
      @gui["cbWorkInternal"].active = Knj::Strings.yn_str(@timelog[:workinternal], true, false)
      @gui["cbTimeType"].sel = @timelog[:timetype]
      @gui["txtTimestamp"].text = Knj::Datet.in(@timelog[:timestamp]).out
    else
      @gui["btnRemove"].visible = false
      @gui["txtTimestamp"].text = Knj::Datet.new.out
    end
    
    #Show the window.
    @gui["window"].show
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
    
    begin
      timestamp_dbstr = Knj::Datet.in(@gui["txtTimestamp"].text).dbstr
    rescue
      Knj::Gtk2.msgbox(_("You have entered an invalid timestamp."))
      return nil
    end
    
    #Generate hash for updating dataabase.
    save_hash = {
      :descr => @gui["txtDescr"].text,
      :timestamp => timestamp_dbstr,
      :time => time_secs,
      :timetype => @gui["cbTimeType"].sel,
      :time_transport => time_transport_secs,
      :transportdescription => @gui["txtTransportDescr"].text,
      :transportlength => Knj::Locales.number_in(@gui["txtTransportLength"].text),
      :transportcosts => Knj::Locales.number_in(@gui["txtTransportCosts"].text),
      :task_id => task_id,
      :sync_need => Knj::Strings.yn_str(@gui["cbShouldSync"].active?, 1, 0),
      :workinternal => Knj::Strings.yn_str(@gui["cbWorkInternal"].active?, 1, 0),
      :travelfixed => Knj::Strings.yn_str(@gui["cbTravelFixed"].active?, 1, 0)
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