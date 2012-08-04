require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require "timeout"

describe "OpenallTimeApplet" do
  it "should be able to start" do
    $tmp_path = "/tmp/openall_spec.sqlite3"
    File.unlink($tmp_path) if File.exists?($tmp_path)
    Openall_time_applet::CONFIG[:db_path] = $tmp_path
    $oata = Openall_time_applet.new
  end
  
  it "should be able to clone timelogs" do
    debug = false
    
    date = Datet.new
    date.days - 1
    
    timelog = $oata.ob.add(:Timelog, {
      :descr => "Test 1",
      :timestamp => date
    })
    
    $oata.timelog_active = timelog
    sleep 0.5
    $oata.timelog_stop_tracking
    
    timelogs = $oata.ob.list(:Timelog, "orderby" => "timestamp").to_a
    raise "Expected amount of timelogs to be 2 but it wasnt: #{timelogs.length}" if timelogs.length != 2
    
    cloned = timelogs.last
    raise "Expected date to be today but it wasnt: #{cloned.timestamp}" if cloned.timestamp.time.strftime("%Y-%m-%d") != Time.now.strftime("%Y-%m-%d")
    
    $oata.timelog_active = timelog
    sleep 0.5
    $oata.timelog_stop_tracking
    
    timelogs = $oata.ob.list(:Timelog, "orderby" => "timestamp").to_a
    raise "Expected amount of timelogs to be 2 but it wasnt: #{timelogs.length}" if timelogs.length != 2
    
    #Try to delete a timelog that has a sub-timelog with logged time. It should show an error message-box.
    $oata.show_main
    main = Knj::Gtk2::Window.get("main")
    main.gui["expOverview"].expanded = true
    main.gui["tvTimelogs"].selection.select_iter(main.gui["tvTimelogs"].model.iter_first)
    
    #Click the minus.
    t = Thread.new do
      main.gui["btnMinus"].clicked
    end
    
    #Answer 'yes' to delete timelog.
    print "Passing until msgbox is shown.\n" if debug
    Thread.pass while !Knj::Gtk2::Msgbox.shown?
    raise "Unexpected label: '#{Knj::Gtk2::Msgbox.cur_label}'." if Knj::Gtk2::Msgbox.cur_label.to_s != _("Do you want to remove this timelog?")
    Knj::Gtk2::Msgbox.cur_respond(Gtk::Dialog::RESPONSE_YES)
    
    #Wait for the 'could not delete timelog' to be shown.
    Thread.pass while !Knj::Gtk2::Msgbox.shown?
    
    #Could-not-delete-timelog was shown - press ok to that.
    raise "Unexpected msgbox-label: #{Knj::Gtk2::Msgbox.cur_label}." if Knj::Gtk2::Msgbox.cur_label.index("Could not delete the timelog") == nil
    
    Knj::Gtk2::Msgbox.cur_respond(Gtk::Dialog::RESPONSE_OK)
    raise "Didnt expect the timelog to be deleted." if timelog.deleted?
    
    #Reset the sub-timelogs time and try to delete again. This time it should actually be deleted.
    #Or else it wont be possible to delete main timelog.
    timelog.child_timelogs do |child_timelog|
      child_timelog[:time] = 0
    end
    
    #Mark timelog.
    main.gui["tvTimelogs"].selection.select_iter(main.gui["tvTimelogs"].model.iter_first)
    
    #Click the minus.
    t = Thread.new do
      main.gui["btnMinus"].clicked
    end
    
    #Answer 'yes' to delete timelog.
    print "Passing until msgbox is shown.\n" if debug
    Thread.pass while !Knj::Gtk2::Msgbox.shown?
    raise "Unexpected label: '#{Knj::Gtk2::Msgbox.cur_label}'." if Knj::Gtk2::Msgbox.cur_label.to_s != _("Do you want to remove this timelog?")
    
    print "Doing yes-response to last.\n" if debug
    Knj::Gtk2::Msgbox.cur_respond(Gtk::Dialog::RESPONSE_YES)
    
    #Wait for timelog to be deleted or another msgbox to be shown.
    print "Passing until msgbox is shown or timelog deleted.\n" if debug
    Timeout.timeout(2) do
      Thread.pass while !Knj::Gtk2::Msgbox.shown? and !timelog.deleted?
    end
    sleep 0.1
    
    print "Done with passing.\n" if debug
    
    if Knj::Gtk2::Msgbox.shown?
      raise "A new message box was shown: '#{Knj::Gtk2::Msgbox.cur_label}'."
      Knj::Gtk2::Msgbox.cur_respond(Gtk::Dialog::RESPONSE_OK)
    end
    
    raise "Timelog was not deleted." if !timelog.deleted?
  end
  
  it "should only return a specific amount of timelogs for tray-icon" do
    count = 0
    $oata.trayicon_timelogs do |timelog|
      count += 1
    end
    
    print "Count: #{count}\n"
  end
  
  it "should remove the temp db" do
    File.unlink($tmp_path) if File.exists?($tmp_path)
  end
end
