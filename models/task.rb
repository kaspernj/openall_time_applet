class Openall_time_applet::Models::Task < Knj::Datarow
  has_one [
    :Organisation
  ]
  
  has_many [
    [:Timelog, :task_id, :timelogs]
  ]
  
  def initialize(*args, &block)
    super(*args, &block)
    
    #Fix default values.
    self[:active] = 1 if self[:active].to_s == ""
  end
  
  def self.update_cache(d, args)
    res = nil
    args[:oata].oa_conn do |conn|
      res = conn.request(:getAllTasksForUser)
    end
    
    #Update all tasks for current user.
    found_ids = []
    res.each do |task_data|
      task = self.ob.get_by(:Task, "openall_uid" => task_data["uid"])
      data_hash = {
        :openall_uid => task_data["uid"],
        :title => task_data["title"],
        :status => task_data["status"]
      }
      
      org = self.ob.get_by(:Organisation, "openall_uid" => task_data["organisation_uid"])
      data_hash[:organisation_id] = org.id if org
      
      if task
        task.update(data_hash)
      else
        task = self.ob.add(:Task, data_hash)
      end
      
      found_ids << task.id
    end
    
    #Mark all tasks not given as not-active.
    d.ob.list(:Task, "id_not" => found_ids) do |task|
      task[:active] = 0
    end
  end
  
  #Returns all open tasks or tasks that are attached to timelogs.
  def self.tasks_to_show(d)
    tasks = {}
    
    #Get lists of tasks that are not closed.
    self.ob.list(:Task, "status_not" => "Closed", "active" => 1) do |task|
      tasks[task.id] = task
    end
    
    #Get missing tasks that have attached timelogs.
    self.ob.list(:Task, [:Timelog, "task_id_not"] => tasks.keys) do |task|
      tasks[task.id] = task
    end
    
    #Sort the found tasks
    Knj::ArrayExt.hash_sort(tasks) do |task1, task2|
      task1[1][:title].to_s.downcase <=> task2[1][:title].to_s.downcase
    end
    
    #Return the found tasks.
    if block_given?
      tasks.each do |task_id, task|
        yield(task)
      end
    else
      return tasks.values
    end
  end
  
  #Returns the name of the task (and the organisation).
  def name
    str = self[:title].to_s.strip
    str = "[#{_("no name")}]" if str.empty?
    
    if org = self.organisation
      str << " (#{Knj::Strings.shorten(org.name, 15)})"
    end
    
    return str
  end
end