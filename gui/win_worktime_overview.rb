class Openall_time_applet::Gui::Win_worktime_overview
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_worktime_overview.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    
    self.build_week(Knj::Datet.new)
    
    @gui["window"].show_all
  end
  
  def build_week(date)
    stats = {
      :task_total => {},
      :days_total => {}
    }
    
    @args[:oata].ob.list(:Worktime, {"timestamp_month" => date}) do |wt|
      task = wt.task
      date = wt.timestamp
      
      stats[:task_total][task.id] = {:secs => 0} if !stats[:task_total].key?(task.id)
      stats[:task_total][task.id][:secs] += wt[:worktime].to_i
      
      stats[:days_total][date.date] = {:secs => 0, :tasks => {}} if !stats[:days_total].key?(date.date)
      stats[:days_total][date.date][:secs] += wt[:worktime].to_i
      stats[:days_total][date.date][:tasks][task.id] = task
    end
    
    table = Gtk::Table.new(4, 4)
    row = 0
    
    stats[:days_total].keys.sort.each do |day_no|
      date = Knj::Datet.in(Time.new(date.year, date.month, day_no))
      day_title = Gtk::Label.new
      day_title.markup = "<b>#{date.out(:time => false)}</b>"
      day_title.xalign = 0
      
      day_sum_float = stats[:days_total][day_no][:secs].to_f / 3600.to_f
      day_sum = Gtk::Label.new
      day_sum.markup = "<b>#{Knj::Locales.number_out(day_sum_float, 2)}</b>"
      day_sum.xalign = 1
      
      table.attach(day_title, 0, 2, row, row + 1)
      table.attach(day_sum, 3, 4, row, row + 1)
      row += 1
      
      stats[:days_total][day_no][:tasks].each do |task_id, task|
        task_title = Gtk::Label.new(task.title)
        task_title.xalign = 0
        
        task_sum_float = stats[:task_total][task_id][:secs].to_f / 3600.to_f
        task_sum = Gtk::Label.new(Knj::Locales.number_out(task_sum_float, 2))
        task_sum.xalign = 1
        
        table.attach(Gtk::Label.new(""), 0, 1, row, row + 1)
        table.attach(task_title, 1, 2, row, row + 1)
        table.attach(Gtk::Label.new("Company"), 2, 3, row, row + 1)
        table.attach(task_sum, 3, 4, row, row + 1)
        row += 1
      end
    end
    
    @gui["boxContent"].pack_start(table)
  end
  
  def on_btnNext_clicked
    print "Next.\n"
  end
  
  def on_btnPrevious_clicked
    print "Previous.\n"
  end
end