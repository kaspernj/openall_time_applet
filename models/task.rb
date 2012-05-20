class Openall_time_applet::Models::Task < Knj::Datarow
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
      task_data = {
        :openall_uid => task_data["uid"],
        :title => task_data["title"]
      }
      
      if task
        task.update(task_data)
      else
        task = self.ob.add(:Task, task_data)
      end
    end
  end
end