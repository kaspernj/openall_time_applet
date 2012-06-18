class Openall_time_applet::Unix_socket
  def initialize(args)
    @args = args
    
    #Remove the sock-file if it already exists.
    File.unlink(Openall_time_applet::CONFIG[:sock_path]) if File.exists?(Openall_time_applet::CONFIG[:sock_path])
    
    #Start Unix-socket.
    require "socket"
    @usock = UNIXServer.new(Openall_time_applet::CONFIG[:sock_path])
    
    #Remove the sock-file after this process is done.
    Kernel.at_exit do
      File.unlink(Openall_time_applet::CONFIG[:sock_path]) if File.exists?(Openall_time_applet::CONFIG[:sock_path])
    end
    
    #Start thread that listens for connections through the Unix-socket.
    Knj::Thread.new do
      while client = @usock.accept
        client.each_line do |line|
          line = line.strip
          
          if line.strip == "open_main_window"
            @args[:oata].show_main
          else
            print "Unknown line: #{line}\n"
          end
        end
      end
    end
  end
end