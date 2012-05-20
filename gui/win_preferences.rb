class Openall_time_applet::Gui::Win_preferences
  attr_reader :args, :gui
  
  def initialize(args)
    @args = args
    
    @gui = Gtk::Builder.new.add("../glade/win_preferences.glade")
    @gui.translate
    @gui.connect_signals{|h| method(h)}
    
    self.load_values
    
    @gui["window"].show_all
  end
  
  #Loads values from database into widgets.
  def load_values
    @gui["txtHost"].text = Knj::Opts.get("openall_host")
    @gui["txtPort"].text = Knj::Opts.get("openall_port")
    @gui["txtUsername"].text = Knj::Opts.get("openall_username")
    @gui["txtPassword"].text = Base64.strict_decode64(Knj::Opts.get("openall_password"))
    
    if Knj::Opts.get("openall_ssl") == "1"
      @gui["cbSSL"].active = true
    else
      @gui["cbSSL"].active = false
    end
  end
  
  #Saves values from widgets into database.
  def on_btnSave_clicked
    Knj::Opts.set("openall_host", @gui["txtHost"].text)
    Knj::Opts.set("openall_port", @gui["txtPort"].text)
    Knj::Opts.set("openall_ssl", Knj::Strings.yn_str(@gui["cbSSL"].active?, 1, 0))
    Knj::Opts.set("openall_username", @gui["txtUsername"].text)
    Knj::Opts.set("openall_password", Base64.strict_encode64(@gui["txtPassword"].text))
    @gui["window"].destroy
  end
  
  #Tries to connect to OpenAll with the given information and receive a task-list as well to validate information and connectivity.
  def on_btnTest_clicked
    ws = Knj::Gtk2::StatusWindow.new("transient_for" => @gui["window"])
    ws.label = _("Connecting and logging in...")
    
    #Do the stuff in thread so GUI wont lock.
    Knj::Thread.new do
      begin
        #Connect to OpenAll, log in, get a list of tasks to test the information and connection.
        @args[:oata].oa_conn do |conn|
          ws.percent = 0.3
          ws.label = _("Getting task-list.")
          task_list = conn.task_list
          
          ws.label = sprintf(_("Got %s tasks."), task_list.length)
          ws.percent = 1
        end
      rescue => e
        #Show error for user if error occurrs.
        Knj::Gtk2.msgbox(
          "msg" => Knj::Errors.error_str(e),
          "type" => "warning",
          "title" => _("Error"),
          "run" => false,
          "transient_for" => @gui["window"]
        )
      ensure
        #Be sure that the status-window will be closed.
        Knj::Thread.new do
          sleep 1.5
          ws.destroy if ws
        end
      end
    end
  end
end