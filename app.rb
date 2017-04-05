require 'bundler'
Bundler.require
require 'tilt/erb'
require 'will_paginate'
require 'will_paginate/data_mapper'
require './model'
require 'json'

class EzrAds < Sinatra::Base
  enable :sessions
  register Sinatra::Flash
  set :session_secret, 'very very secret'

  use Warden::Manager do |config|
    config.serialize_into_session{ |user| user.id }
    config.serialize_from_session{ |id| User.get(id) }

    config.scope_defaults :default, strategies: [:password], action: 'auth/unauthenticated'
    config.failure_app = self
  end

  Warden::Manager.before_failure do |env,opts|
    env['REQUEST_METHOD'] = 'POST'
    env.each do |key,value|
      env[key]['_method'] = 'post' if key == 'rack.request.form_hash'
    end
  end

  Warden::Strategies.add(:password) do
    def valid?
      params['user'] && params['user']['username'] && params['user']['password']
    end

    def authenticate!
      user = User.first(username: params['user']['username'].downcase)
      if user.nil?
        throw(:warden, message: "The username you entered does not exist")
      elsif user.authenticate(params['user']['password'])
        success!(user)
      else
        throw(:warden, message: "The username and password combination was incorrect")
      end
    end
  end
  #end of Warden config

  require_relative 'routes/customers'
  require_relative 'routes/users'
  require_relative 'routes/tasks'
  require_relative 'routes/papers'
  require_relative 'routes/publications'
  require_relative 'routes/features'
  require_relative 'routes/ads'
  require_relative 'routes/runons'

  register Sinatra::EzrAds::Routing::Customers
  register Sinatra::EzrAds::Routing::Users
  register Sinatra::EzrAds::Routing::Tasks
  register Sinatra::EzrAds::Routing::Papers
  register Sinatra::EzrAds::Routing::Publications
  register Sinatra::EzrAds::Routing::Features
  register Sinatra::EzrAds::Routing::Ads
  register Sinatra::EzrAds::Routing::Runons



#Authentication
  get '/auth/login' do
    erb :login
  end

  post '/auth/login' do
    env['warden'].authenticate!
    @title = "Login"
    session[:ad] = {}
    flash[:success] = "Successfully logged in"

    if session[:return_to].nil?
      redirect '/'
    else
      redirect session[:return_to]
    end
  end

  get '/auth/logout' do
    env['warden'].raw_session.inspect
    env['warden'].logout
    flash[:success] = "Successfully logged out"
    redirect '/'
  end

  post '/auth/unauthenticated' do
    session[:return_to] = env['warden.options'][:attempted_path] if session[:return_to].nil?

    flash[:error] = env['warden.options'][:message] || "You must log in"
    redirect '/auth/login'
  end

  get '/protected' do
    env['warden'].authenticate!

    erb :protected
  end

  #search
  get '/search' do
    env['warden'].authenticate!
    @title = "Search"
    @features = Feature.all(:paper_id => env['warden'].user.paper_id)
    @users = User.all
    @customers = Customer.all
    @paper = env['warden'].user.paper_id
    if params['customer-search']
      if params['customer-search']['query']
        if @customer = Customer.all(:business_name.like => "%#{params['customer-search']['query']}%") + Customer.all(:contact_name.like => "%#{params['customer-search']['query']}%")
          if @customer.count == 1
            @results = "1 record found"
          else
            @results = "#{@customer.count} records found"
          end
        end
      end
    end

    if params['booking']
      id = params['booking']['number']
      ad = Ad.get id
      if ad && ad.publication.paper_id == env['warden'].user.paper_id
        redirect '/view/ad/' + id
      else
        @results = "No record found"
      end
    end

    if params['ad-search']
      if params['ad-search']['feature'] != ""
        feature = params['ad-search']['feature']
      end
      if params['ad-search']['width'] != ""
        width = params['ad-search']['width']
      end
      if params['ad-search']['height'] != ""
        height = params['ad-search']['height']
      end
      if params['ad-search']['user'] != ""
        user = params['ad-search']['user']
      end
      if params['ad-search']['customer'] != ""
        customer = params['ad-search']['customer']
      end

      if feature && width && height && user && customer
        @ads = Ad.all(:feature_id => feature) & Ad.all(:columns => width) & Ad.all(:height => height) & Ad.all(:user_id => user) & Ad.all(:customer_id => customer)
      elsif feature && width && height && user
        @ads = Ad.all(:feature_id => feature) & Ad.all(:columns => width) & Ad.all(:height => height) & Ad.all(:user_id => user)
      elsif feature && width && height && customer
        @ads = Ad.all(:feature_id => feature) & Ad.all(:columns => width) & Ad.all(:height => height) & Ad.all(:customer_id => customer)
      elsif feature && width && user && customer
        @ads = Ad.all(:feature_id => feature) & Ad.all(:columns => width) & Ad.all(:user_id => user) & Ad.all(:customer_id => customer)
      elsif width && height && user && customer
        @ads = Ad.all(:columns => width) & Ad.all(:height => height) & Ad.all(:user_id => user) & Ad.all(:customer_id => customer)
      elsif feature && height && user && customer
        @ads = Ad.all(:feature_id => feature) & Ad.all(:height => height) & Ad.all(:user_id => user) & Ad.all(:customer_id => customer)
      elsif feature && height && user
        @ads = Ad.all(:feature_id => feature) & Ad.all(:height => height) & Ad.all(:user_id => user)
      elsif feature && height && customer
        @ads = Ad.all(:feature_id => feature) & Ad.all(:height => height) & Ad.all(:customer_id => customer)
      elsif feature && height && width
        @ads = Ad.all(:feature_id => feature) & Ad.all(:height => height) & Ad.all(:columns => width)
      elsif feature && customer && user
        @ads = Ad.all(:feature_id => feature) & Ad.all(:customer_id => customer) & Ad.all(:user_id => user)
      elsif feature && customer && width
        @ads = Ad.all(:feature_id => feature) & Ad.all(:customer_id => customer) & Ad.all(:columns => width)
      elsif feature && user && width
        @ads = Ad.all(:feature_id => feature) & Ad.all(:user_id => user) & Ad.all(:columns => width)
      elsif height && user && width
        @ads = Ad.all(:height => height) & Ad.all(:user_id => user) & Ad.all(:columns => width)
      elsif height && customer && width
        @ads = Ad.all(:height => height) & Ad.all(:customer_id => customer) & Ad.all(:columns => width)
      elsif height && customer
        @ads = Ad.all(:height => height) & Ad.all(:customer_id => customer)
      elsif height && width
        @ads = Ad.all(:height => height) & Ad.all(:columns => width)
      elsif customer && width
        @ads = Ad.all(:customer_id => customer) & Ad.all(:columns => width)
      elsif customer && user
        @ads = Ad.all(:customer_id => customer) & Ad.all(:user_id => user)
      elsif customer && feature
        @ads = Ad.all(:customer_id => customer) & Ad.all(:feature_id => feature)
      elsif feature && width
        @ads = Ad.all(:feature_id => feature) & Ad.all(:columns => width)
      elsif feature && height
        @ads = Ad.all(:feature_id => feature) & Ad.all(:height => height)
      elsif feature && user
        @ads = Ad.all(:feature_id => feature) & Ad.all(:user_id => user)
      elsif width && user
        @ads = Ad.all(:columns => width) & Ad.all(:user_id => user)
      elsif height && user
        @ads = Ad.all(:height => height) & Ad.all(:user_id => user)
      elsif feature
        @ads = Ad.all(:feature_id => feature)
      elsif customer
        @ads = Ad.all(:customer_id => customer)
      elsif user
        @ads = Ad.all(:user_id => user)
      elsif width
        @ads = Ad.all(:columns => width)
      elsif height
        @ads = Ad.all(:height => height)
      end


      if @ads == nil
        @results = "You gotta enter a search term for a search to work..."
      elsif @ads.count > 1
        @results = "#{@ads.count} records found"
      elsif @ads.count == 1
        @results = "1 record found"
      end
    end

    erb :search
  end



  helpers do
    def format_price(i)
      return sprintf "%.2f", i
    end

    def display_role(i)
      if i == 1
        return "Admin"
      elsif i == 2
        return "Sales"
      elsif i == 3
        return "Production"
      elsif i == 4
        return "Accounts"
      else
        return "Role not found"
      end
    end

    def display_publication(i)
      if i == 1
        return "All"
      elsif i == 2
        return "Blenheim Sun"
      elsif i == 3
        return "Wellington..."
      else
        return "Publication not found"
      end
    end

    def display_payment(i)
      if i == 1
        return "Account"
      elsif i == 2
        return "Cash"
      elsif i == 3
        return "Eftpos"
      elsif i == 4
        return "Direct Credit"
      end
    end

    def display_user(i)
      if i != nil
        u = User.get i
        return u.username.capitalize
      end
    end

    def display_time(i)
      if i
        return i.strftime('%y%m%d %H:%M')
      end
    end

    def display_date(i)
      if i
        return i.strftime('%y%m%d')
      end
    end

    def display_task_number
      if env['warden'].user
        uid = env['warden'].user[:id]
        return Task.count(:user_id => uid, :completed => false)
      end
    end

    def display_price(h, w, r)
      return h * w * r
    end

    def display_papers
      @papers = Paper.all
    end

    def get_feature_id(f)
      k = Feature.first(:name => f)
      return k.id
    end

    def motd
      if env['warden'].user
        if k = Motd.last(:paper_id => env['warden'].user.paper_id)
          if k.enabled == true
            return k.message
          else
            return false
          end
        else
          return false
        end
      else
        return false
      end
    end

    def next_issue
      paper = Paper.all(:id => env['warden'].user.paper_id)
      pub = paper.publications(:date.gt => Date.today) & paper.publications(:order => [:date.desc])
      return pub.last
    end

    def paginate(resources)
      if !resources.next_page.nil? and !resources.previous_page.nil?
        html = "<a href='#{request.path_info}?page=#{resources.previous_page}'> Prev</a> "
        (1..resources.total_pages).each do |p|
          if params[:page].to_i == p
            html += "<a href='#{request.path_info}?page=#{p}' class='pagination-active'>#{p}</a> "
          else
            html += "<a href='#{request.path_info}?page=#{p}'>#{p}</a> "
          end
        end
        html += "<a href='#{request.path_info}?page=#{resources.next_page}'>Next </a> "
      elsif !resources.next_page.nil? and resources.previous_page.nil?
        html = "Prev "
        (1..resources.total_pages).each do |p|
          if params[:page].to_i == p
            html += "<a href='#{request.path_info}?page=#{p}' class='pagination-active'>#{p}</a> "
          else
            html += "<a href='#{request.path_info}?page=#{p}'>#{p}</a> "
          end
        end
        html += "<a href='#{request.path_info}?page=#{resources.next_page}'>Next </a> "
      elsif resources.next_page.nil? and !resources.previous_page.nil?
        html = "<a href='#{request.path_info}?page=#{resources.previous_page}'> Prev</a> "
        (1..resources.total_pages).each do |p|
          if params[:page].to_i == p
            html += "<a href='#{request.path_info}?page=#{p}' class='pagination-active'>#{p}</a> "
          else
            html += "<a href='#{request.path_info}?page=#{p}'>#{p}</a> "
          end
        end
        html += "Next "
      end
      return html
    end

  end

end
