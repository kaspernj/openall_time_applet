require "socket"
require "json"

#This class handels various operations with the Openall-installation. It uses HTTP and JSON.
class Openall_time_applet::Connection
  def initialize(args)
    @args = args
    @http = Knj::Http2.new(
      :host => @args[:host],
      :port => @args[:port],
      :follow_redirects => false,
      :ssl => Knj::Strings.yn_str(@args[:ssl], true, false),
      :debug => false,
      :encoding_gzip => false
    )
    
    self.login
  end
  
  def login
    #For some weird reason OpenAll seems to only accept multipart-post-requests??
    @http.post_multipart("index.php?c=Auth&m=validateLogin", {"username" => @args[:username], "password" => @args[:password]})
    @http.reconnect
    
    #Verify login by reading dashboard HTML.
    res = @http.get("index.php?c=Dashboard")
    raise _("Could not log in.") if !res.body.match(/<ul id="webticker" >/)
  end
  
  def request(args)
    args = {:url => args} if args.is_a?(String)
    res = @http.get(args[:url])
    parsed = JSON.parse(res.body)
    
    return parsed
  end
  
  def task_list
    return self.request("index.php?c=Jsonapi&m=task_list")
  end
  
  def destroy
    @http.destroy if @http
  end
end