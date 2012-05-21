class Openall_time_applet::Models::Task < Knj::Datarow
  has_one [
    :Organisation
  ]
  
  has_many [
    [:Timelog, :task_id, :timelogs]
  ]
  
  def self.update_cache(d, args)
    res = nil
    args[:oata].oa_conn do |conn|
      res = conn.request(:getAllTasksForUser)
    end
    
    res.each do |task_data|
      task = self.ob.get_by(:Task, {"openall_uid" => task_data["uid"]})
      data_hash = {
        :openall_uid => task_data["uid"],
        :title => task_data["title"]
      }
      
      org = self.ob.get_by(:Organisation, {"openall_uid" => task_data["organisation_uid"]})
      data_hash[:organisation_id] = org.id if org
      
      if task
        task.update(data_hash)
      else
        task = self.ob.add(:Task, data_hash)
      end
    end
  end
end