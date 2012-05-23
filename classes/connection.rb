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
    
    #Verify login by reading dashboard HTML.
    res = @http.get("index.php?c=Dashboard")
    raise _("Could not log in.") if !res.body.match(/<ul id="webticker" >/)
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