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

  Warden::Manager.before_failure do |env, opts|
    env['REQUEST_METHOD'] = 'POST'
    env.each do |key, value|
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
        throw(:warden, message: 'The username and password combination was incorrect')
      elsif user.authenticate(params['user']['password'])
        success!(user)
      else
        throw(:warden, message: 'The username and password combination was incorrect')
      end
    end
  end
  # end of Warden config

  require_relative 'helpers'

  require_relative 'routes/customers'
  require_relative 'routes/users'
  require_relative 'routes/tasks'
  require_relative 'routes/papers'
  require_relative 'routes/publications'
  require_relative 'routes/features'
  require_relative 'routes/ads'
  require_relative 'routes/runons'
  require_relative 'routes/api'

  register Sinatra::EzrAds::Helpers

  register Sinatra::EzrAds::Routing::Customers
  register Sinatra::EzrAds::Routing::Users
  register Sinatra::EzrAds::Routing::Tasks
  register Sinatra::EzrAds::Routing::Papers
  register Sinatra::EzrAds::Routing::Publications
  register Sinatra::EzrAds::Routing::Features
  register Sinatra::EzrAds::Routing::Ads
  register Sinatra::EzrAds::Routing::Runons
  register Sinatra::EzrAds::Routing::Api

  register Sinatra::CrossOrigin

  options "*" do
    response.headers["Allow"] = "HEAD,GET,PUT,POST,DELETE,OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Overide, Content-Type, Cache-Control, Accept"
    200
  end

  # Authentication
  get '/auth/login' do
    erb :login
  end

  post '/auth/login' do
    env['warden'].authenticate!
    @title = "Login"
    session[:ad] = {}
    flash[:success] = 'Successfully logged in'

    if session[:return_to].nil?
      redirect '/'
    else
      redirect session[:return_to]
    end
  end

  get '/auth/logout' do
    env['warden'].raw_session.inspect
    env['warden'].logout
    flash[:success] = 'Successfully logged out'
    redirect '/'
  end

  post '/auth/unauthenticated' do
    session[:return_to] = env['warden.options'][:attempted_path] if session[:return_to].nil?
    flash[:error] = env['warden.options'][:message] || 'You must log in'
    redirect '/auth/login'
  end

  #search
  get '/search' do
    env['warden'].authenticate!
    @title = 'Search'
    @features = Feature.all(:paper_id => env['warden'].user.paper_id)
    @users = User.all
    @customers = Customer.all
    @paper = env['warden'].user.paper_id
    if params['customer-search']
      if params['customer-search']['query']
        @customer = Customer.all(:business_name.like => "%#{params['customer-search']['query']}%") + Customer.all(:contact_name.like => "%#{params['customer-search']['query']}%")
        if @customer.count == 1
          @results = '1 record found'
        else
          @results = "#{@customer.count} records found"
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

      if @ads.nil?
        @results = 'You gotta enter a search term for a search to work...'
      elsif @ads.count > 1
        @results = "#{@ads.count} records found"
      elsif @ads.count == 1
        @results = '1 record found'
      end
    end

    erb :search
  end
end
