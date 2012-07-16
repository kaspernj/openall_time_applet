class Openall_time_applet::Gui::Win_worktime_overview
  #For Knj::Gtk2::Window#unique!
  attr_reader :gui
  
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_worktime_overview.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    
    @date = Datet.new
    self.build_week
    
    @gui["window"].show_all
  end
  
  def build_week
    date = @date
    
    stats = {
      :task_total => {},
      :days_total => {},
      :week_total => 0
    }
    
    @gui["labWeek"].label = sprintf(_("Week %s"), date.time.strftime("%W"))
    
    @args[:oata].ob.list(:Worktime, {"timestamp_week" => date}) do |wt|
      task = wt.task
      date = wt.timestamp
      
      stats[:task_total][task.id] = {:secs => 0} if !stats[:task_total].key?(task.id)
      stats[:task_total][task.id][:secs] += wt[:worktime].to_i
      
      stats[:days_total][date.date] = {:secs => 0, :tasks => {}} if !stats[:days_total].key?(date.date)
      stats[:days_total][date.date][:secs] += wt[:worktime].to_i
      stats[:days_total][date.date][:tasks][task.id] = task
      
      #Generate first worktime of that date.
      if !stats[:days_total][date.date].key?(:first_time) or stats[:days_total][date.date][:first_time].to_i > wt.timestamp.to_i
        stats[:days_total][date.date][:first_time] = wt.timestamp
      end
      
      stats[:week_total] += wt[:worktime].to_i
    end
    
    table = Gtk::Table.new(5, 5)
    table.row_spacings = 3
    table.column_spacings = 3
    row = 0
    
    
    #Draw top total-row.
    week_total_title = Gtk::Label.new
    week_total_title.markup = "<b>#{sprintf(_("Week total: %s hours"), Knj::Locales.number_out(stats[:week_total].to_f / 3600.0, 2))}</b>"
    week_total_title.selectable = true
    table.attach(week_total_title, 0, 5, row, row + 1)
    row += 1
    
    
    #Make empty label to make space between total row and days.
    table.attach(Gtk::Label.new(" "), 0, 5, row, row + 1)
    row += 1
    
    
    #Draw all the days.
    stats[:days_total].keys.sort.each do |day_no|
      date = Datet.in(Time.new(date.year, date.month, day_no))
      
      day_title = Gtk::Label.new
      day_title.markup = "<b>#{date.day_str(:short => true)} #{date.time.strftime("%d/%m")} - #{stats[:days_total][day_no][:first_time].time.strftime("%H:%M")}</b>"
      day_title.xalign = 0
      day_title.selectable = true
      
      day_sum_float = stats[:days_total][day_no][:secs].to_f / 3600.to_f
      day_sum = Gtk::Label.new
      day_sum.markup = "<b>#{Knj::Locales.number_out(day_sum_float, 2)}</b>"
      day_sum.xalign = 1
      day_sum.selectable = true
      
      table.attach(day_title, 0, 3, row, row + 1)
      table.attach(day_sum, 4, 5, row, row + 1)
      row += 1
      
      stats[:days_total][day_no][:tasks].each do |task_id, task|
        uid_title = Gtk::Label.new(task[:openall_uid].to_s)
        uid_title.xalign = 0
        uid_title.selectable = true
        
        task_title = Gtk::Label.new(task.title)
        task_title.xalign = 0
        task_title.selectable = true
        
        task_sum_float = stats[:task_total][task_id][:secs].to_f / 3600.to_f
        task_sum = Gtk::Label.new(Knj::Locales.number_out(task_sum_float, 2))
        task_sum.xalign = 1
        task_sum.selectable = true
        
        company_title = Gtk::Label.new(task.organisation_name)
        company_title.xalign = 0
        company_title.selectable = true
        
        table.attach(Gtk::Label.new(""), 0, 1, row, row + 1)
        table.attach(uid_title, 1, 2, row, row + 1)
        table.attach(task_title, 2, 3, row, row + 1)
        table.attach(company_title, 3, 4, row, row + 1)
        table.attach(task_sum, 4, 5, row, row + 1)
        row += 1
      end
      
      #Make empty label to devide the days with one row.
      table.attach(Gtk::Label.new(" "), 0, 5, row, row + 1)
      row += 1
    end
    
    if stats[:days_total].empty?
      table = Gtk::Label.new(_("No worktimes was found that week."))
    end
    
    #Remove previous table.
    if @table
      @gui["boxContent"].remove(@table)
      @table.destroy
    end
    
    #Attach and set new table.
    @gui["boxContent"].pack_start(table)
    @gui["window"].show_all
    @table = table
  end
  
  def on_btnNext_clicked
    @date.days + 7
    self.build_week
  end
  
  def on_btnPrevious_clicked
    @date.days - 7
    self.build_week
  end
end