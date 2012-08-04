require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "OpenallTimeApplet" do
  it "should be able to start" do
    begin
      $tmp_path = "/tmp/openall_spec.sqlite3"
      File.unlink($tmp_path) if File.exists?($tmp_path)
      Openall_time_applet::CONFIG[:db_path] = $tmp_path
      $oata = Openall_time_applet.new
      
      Knj::Opts.set("openall_host", "192.168.56.54")
      Knj::Opts.set("openall_port", 80)
      Knj::Opts.set("openall_username", "kaspernj")
      Knj::Opts.set("openall_password", Base64.strict_encode64("123"))
      Knj::Opts.set("openall_ssl", 0)
    rescue Exception => e
      STDOUT.print Knj::Errors.error_str(e)
    end
  end
  
  it "should only return a specific amount of timelogs for tray-icon" do
    $oata.sync_static
    sleep 1
    raise "A new message box was shown: '#{Knj::Gtk2::Msgbox.cur_label}'." if Knj::Gtk2::Msgbox.shown?
    
    task = $oata.ob.get_by(:Task, "openall_uid_not" => ["", 0])
    raise "No task could be found?" if !task
    
    idstr = Digest::MD5.hexdigest(Time.now.to_f.to_s)
    titlestr = "Tlog test #{idstr}"
    
    tlog = $oata.ob.add(:Timelog,
      :descr => titlestr,
      :sync_need => 1,
      :task_id => task.id,
      :time => Knj::Strings.human_time_str_to_secs("01:30:15"),
      :time_sync => Knj::Strings.human_time_str_to_secs("01:30:30")
    )
    
    $oata.sync_real
    $oata.sync_static
    sleep 1
    
    worktime = $oata.ob.get_by(:Worktime, "comment" => titlestr)
    raise "Could not find synced worktime." if !worktime
    raise "Expected synced worktime to be '5430' but it was '#{worktime[:worktime]}'." if worktime[:worktime].to_i != 5430
  end
  
  it "should remove the temp db" do
    File.unlink($tmp_path) if File.exists?($tmp_path)
  end
end
