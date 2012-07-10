class Openall_time_applet::Models::Timelog_logged_time < Knj::Datarow
  has_one [
    {:class => :Timelog, :col => :timelog_id, :method => :timelog, :required => true}
  ]
  
  def self.add(d)
    d.data[:timestamp_start] = Time.now if !d.data[:timestamp_start]
  end
end