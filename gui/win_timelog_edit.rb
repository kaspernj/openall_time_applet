class Openall_time_applet::Gui::Win_timelog_edit
  attr_reader :args, :gui
  
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_timelog_edit.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    
    @gui["window"].show_all
  end
  
  def on_btnSave_clicked(*args)
    save_hash = {
      :descr => @gui["txtDescr"].text,
      :time => @gui["txtTime"].text,
      :time_transport => @gui["txtTimeTransport"].text
    }
    
    if @timelog
      @timelog.update(save_hash)
    else
      @timelog = @args[:oata].ob.add(:Timelog, save_hash)
    end
    
    @gui["window"].destroy
  end
end