class Openall_time_applet::Models::Timelog < Knj::Datarow
  has_one [
    :Task
  ]
  
  #Treat data before inserting into database.
  def self.add(d)
    d.data[:time] = 0 if d.data[:time].to_s.strip.length <= 0
    d.data[:time_transport] = 0 if d.data[:time_transport].to_s.strip.length <= 0
  end
  
  #Pushes timelogs and time to OpenAll.
  def self.push_time_updates(d, args)
    args[:oata].oa_conn do |conn|
      #Go through timelogs that needs syncing and has a task set.
      self.ob.list(:Timelog, {"sync_need" => 1, "task_id_not" => 0}) do |timelog|
        secs_sum = timelog[:time].to_i + timelog[:time_transport].to_i
        next if secs_sum <= 0
        
        #The timelog has not yet been created in OpenAll - create it!
        res = conn.request(
          :method => :createWorktime,
          :post => {
            :task_uid => timelog.task[:openall_uid].to_i,
            :comment => timelog[:descr],
            :worktime => Knj::Strings.secs_to_human_time_str(timelog[:time]),
            :transporttime => Knj::Strings.secs_to_human_time_str(timelog[:time_transport])
          }
        )
        
        #Reset timelog.
        timelog.update(
          :time => 0,
          :time_transport => 0,
          :sync_need => 0,
          :sync_last => Time.now
        )
      end
    end
  end
  
  #Returns a short one-line short description.
  def descr_short
    descr = self[:descr].to_s.gsub("\n", " ").gsub(/\s{2,}/, " ")
    descr = Knj::Strings.shorten(descr, 20)
    descr = "[#{_("no description")}]" if descr.to_s.strip.length <= 0
    return descr
  end
  
  #Returns the time as a human readable format.
  def time_as_human
    return Knj::Strings.secs_to_human_time_str(self[:time])
  end
  
  #Returns the transport-time as a human readable format.
  def time_transport_as_human
    return Knj::Strings.secs_to_human_time_str(self[:time_transport])
  end
end