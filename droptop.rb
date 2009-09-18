require 'rubygems'
require 'sinatra'
require 'logger'
require 'digest/md5'
require 'tempfile'

$LOAD_PATH.unshift File.dirname(__FILE__) + "/lib/dropio/lib"
require 'dropio'
include Dropio

configure do
  logger = Logger.new("log/#{Sinatra::Application.environment}.log")
  set :logging, false
  set :logger, logger
  use Rack::CommonLogger, logger

  Dropio::Config.api_key = "46f2d0f95744b94ec30ab86fb3dcae1882663179"
    
  set :public, 'public'
  set :views, 'views'
end

helpers do 
  
  def request_for_static?
    /(\/images|\/javascripts|\/stylesheets)/.match(request.path_info)
  end
  
  def redirect_to(url)
    redirect url
  end
  
  def find_or_create_drop(url, hashed_url)
    drop = nil
    begin
      drop = Dropio::Drop.find(hashed_url)
    rescue Dropio::MissingResourceError
    end
    
    if drop.nil?
      p = {:name => hashed_url, :description => "Collaborating, in real-time, about #{@url}"}
      drop = Dropio::Drop.create(p)
      drop.create_link(@url,@url)
    end
    return drop
  end
  
  def hash(url)
    return "droptop" + Digest::MD5.hexdigest(url)
  end
  
  def check_and_parse(url)
    real_url = URI.parse(url) rescue nil
    if real_url.class == URI::HTTP
      url.gsub!(":/","://") if url =~ /:\/[a-zA-Z0-9]+/
      return true, url
    end
    return false, nil
  end

end

get '/note/posted' do
  erb :posted
end

get '/note/*' do
  @url = params[:splat][0]
  valid, @url = check_and_parse(@url)
  erb :note
end

post '/note/*' do
  @url = params[:splat][0]
  valid, @url = check_and_parse(@url)
  if valid
    @hashed_url = hash(@url)
    @drop = find_or_create_drop(@url, @hashed_url)
    
    begin
      @drop.create_note(params[:contents])
    rescue Dropio::RequestError
    end
  end
  redirect_to '/note/posted'
end

get '/' do
  erb :home
end

post '/' do
  redirect_to '/' + params["url"]
end

get '/*' do
  @url = params[:splat][0]
  valid, @url = check_and_parse(@url)
  options.logger.info "Found: #{@url}"
  if valid
    @hashed_url = hash(@url)
    @drop = find_or_create_drop(@url, @hashed_url)
  else
    redirect_to '/'
  end

  erb :page
end

post '/screenshot/*' do
  @url = params[:splat][0]
  valid, @url = check_and_parse(@url)
  if valid
    @hashed_url = hash(@url)
    @drop = find_or_create_drop(@url, @hashed_url)
    fname = "dropTop#{rand(1000)}.jpeg"
    File.open("tmp/#{fname}","w") do |file|
      Net::HTTP.start("www.websitethumbnail.de") { |http|
        resp = http.get("/shots/artviperx.php?&w=800&h=600&q=80&url=" + @url)
        file.write(resp.body)
      }
    end
    @drop.add_file("tmp/#{fname}")
    File.delete("tmp/#{fname}")
    erb "SUCCESS"
  else
    erb "FAILURE"
  end
end