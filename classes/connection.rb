require "json"

#This class handels various operations with the Openall-installation. It uses HTTP and JSON.
class Openall_time_applet::Connection
  def initialize(args)
    @args = args
    @http = Knj::Http2.new(
      :host => @args[:host],
      :port => @args[:port],
      :follow_redirects => false,
      :ssl => @args[:ssl],
      :debug => false
    )
    
    self.login
  end
  
  def login
    #For some weird reason OpenAll seems to only accept multipart-post-requests??
    @http.post_multipart("index.php?c=Auth&m=validateLogin", {"username" => @args[:username], "password" => @args[:password]})
    
    #Verify login by reading dashboard HTML.
    res = @http.get("index.php?c=Dashboard")
    
    if !res.body.match(/<ul\s*id="webticker"\s*>/)
      tmp_path = "#{Knj::Os.tmpdir}/openall_login_debug.txt"
      File.open(tmp_path, "w") do |fp|
        fp.write(res.body)
      end
      
      #Raise custom wrong-username error if login-form is still shown.
      if res.body.index("<div id=\"loginform\"") != nil
        raise _("Wrong username and/or password.")
      end
      
      raise sprintf(_("Could not log in because of unknown reason. Please check debug-output in '%s'."), tmp_path)
    end
  end
  
  def request(args)
    #Possible to give a string instead of hash to do it simple.
    args = {:url => "?c=Jsonapi&m=#{args}"} if args.is_a?(String) or args.is_a?(Symbol)
    args[:url] = "?c=Jsonapi&m=#{args[:method]}" if args[:method] and !args[:url]
    
    #Send request to OpenAll via HTTP.
    if args[:post]
      res = @http.post_multipart(args[:url], args[:post])
    else
      res = @http.get(args[:url])
    end
    
    raise _("Empty body returned from OpenAll.") if res.body.to_s.strip.length <= 0
    
    #Parse result as JSON.
    begin
      parsed = JSON.parse(res.body)
    rescue
      raise sprintf(_("Could not parse JSON from: %s"), res.body)
    end
    
    #An error occurred in OpenAll. Make it look like an error here as well.
    if parsed.is_a?(Hash) and parsed["type"] == "error"
      #Hack the backtrace to include code-lines from PHP.
      begin
        raise "(PHP-#{parsed["class"]}) #{parsed["msg"]}"
      rescue => e
        newbt = parsed["bt"]
        e.backtrace.each do |bt|
          newbt << bt
        end
        
        e.set_backtrace(newbt)
        
        raise e
      end
    end
    
    return parsed
  end
  
  def task_list
    return self.request("getAllTasksForUser")
  end
  
  def destroy
    @http.destroy if @http
  end
end