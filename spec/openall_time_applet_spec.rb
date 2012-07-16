require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "OpenallTimeApplet" do
  it "should be able to start" do
    $tmp_path = "/tmp/openall_spec.sqlite3"
    Openall_time_applet::CONFIG[:db_path] = $tmp_path
    $oata = Openall_time_applet.new
  end
  
  it "should be able to clone timelogs" do
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
    
    #Or else it wont be possible to delete main timelog.
    timelog.child_timelogs do |child_timelog|
      child_timelog[:time] = 0
    end
  end
  
  it "should automatically delete sub-timelogs" do
    main = $oata.ob.get_by(:Timelog, "parent_timelog_id" => 0)
    $oata.ob.delete(main)
    timelogs = $oata.ob.list(:Timelog, "orderby" => "timestamp").to_a
    raise "Expected amount of timelogs to be 0 but it wasnt: #{timelogs.length}" if timelogs.length != 0
  end
  
  it "should remove the temp db" do
    File.unlink($tmp_path) if File.exists?($tmp_path)
  end
end
