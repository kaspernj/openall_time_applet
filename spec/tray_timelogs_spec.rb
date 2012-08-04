require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "OpenallTimeApplet" do
  it "should be able to start" do
    $tmp_path = "/tmp/openall_spec.sqlite3"
    File.unlink($tmp_path) if File.exists?($tmp_path)
    Openall_time_applet::CONFIG[:db_path] = $tmp_path
    $oata = Openall_time_applet.new
  end
  
  it "should only return a specific amount of timelogs for tray-icon" do
    task1 = $oata.ob.add(:Task, :title => "Task 1")
    task2 = $oata.ob.add(:Task, :title => "Task 2")
    
    tlog1 = $oata.ob.add(:Timelog, :descr => "Tlog 1", :task_id => task1.id)
    tlog2 = $oata.ob.add(:Timelog, :descr => "Tlog 1", :task_id => task1.id)
    tlog3 = $oata.ob.add(:Timelog, :descr => "Tlog 1", :task_id => task2.id)
    tlog4 = $oata.ob.add(:Timelog, :descr => "Tlog 4", :task_id => task2.id)
    
    count = 0
    $oata.trayicon_timelogs do |timelog|
      count += 1
    end
    
    raise "Expected count 3 but got #{count}." if count != 3
  end
  
  it "should remove the temp db" do
    File.unlink($tmp_path) if File.exists?($tmp_path)
  end
end
