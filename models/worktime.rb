class Openall_time_applet::Models::Worktime < Knj::Datarow
  has_one [
    :Task
  ]
  
  def self.update_cache(d, args)
    res = nil
    args[:oata].oa_conn do |conn|
      res = conn.request(:getLatestWorktimes)
    end
    
    #Update all worktimes.
    found = []
    res.each do |wt_d|
      found << wt_d["uid"]
      task = self.ob.get_by(:Task, {"openall_uid" => wt_d["task_uid"]})
      
      if !task
        $stderr.puts sprintf(_("Task with UID '%s' was not found."), wt_d["task_uid"]) + " - " + sprintf(_("Skipping worktime with UID %s"), wt_d["uid"])
        next
      end
      
      save_hash = {
        :openall_uid => wt_d["uid"],
        :task_id => task.id,
        :timestamp => Datet.in(wt_d["timestamp"]),
        :worktime => Knj::Strings.human_time_str_to_secs(wt_d["worktime"]),
        :transporttime => Knj::Strings.human_time_str_to_secs(wt_d["transporttime"]),
        :comment => wt_d["comment"]
      }
      
      wt = self.ob.get_by(:Worktime, {"openall_uid" => wt_d["uid"]})
      if wt
        wt.update(save_hash)
      else
        wt = self.ob.add(:Worktime, save_hash)
      end
    end
    
    #Delete the ones not given.
    list = self.ob.list(:Worktime, {"openall_uid_not" => found})
    self.ob.deletes(list)
  end
end