require 'bundler'
Bundler.require
require 'tilt/erb'

require './model'



class EzrAds < Sinatra::Base
  enable :sessions
  register Sinatra::Flash
  set :session_secret, "change-me-to-environment-variable"

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

  get '/' do
    env['warden'].authenticate!
    user_publication = env['warden'].user[:publication]


    @role = env['warden'].user[:role]
    @title = "Home"

    @ads = Ad.all

    erb :view_ads
  end

  get '/view/users' do
    env['warden'].authenticate!
    @title = "Users"
    @user = User.all
    @role = env['warden'].user[:role]

    erb :view_users
  end

  get '/create/user' do
    env['warden'].authenticate!
    @title = "Create user"

    erb :create_user
  end

  post '/create/user' do
    user = User.new(created_at: Time.now, username: params['user']['username'].downcase, role: params['user']['role'], publication: params['user']['publication'], phone: params['user']['phone'], email: params['user']['email'], password: params['user']['password'])
    if user.save
      flash[:success] = "User created"
      redirect '/view/users'
    else
      flash[:error] = "User creation failed"
      redirect '/create/user'
    end
  end

  get '/edit/user/:id' do
    env['warden'].authenticate!
    @user = User.first(id: params['id'])
    @title = "Edit User"

    erb :edit_user
  end

  post '/edit/user/:id' do
    user = User.first(id: params['id'])
    if user.update(username: params['user']['username'], role: params['user']['role'], publication: params['user']['publication'], phone: params['user']['phone'], email: params['user']['email'], password: params['user']['password'])
      flash[:success] = "User updated"
      redirect '/view/users'
    else
      flash[:error] = "Update failed"
      redirect back
    end
  end

  get '/delete/user/:id' do
    env['warden'].authenticate!
    user = User.get params['id']
    if user.destroy
      flash[:success] = "User deleted"
      redirect back
    else
      flash[:error] = "Deletion failed"
      redirect back
    end
  end

  get '/view/customers' do
    env['warden'].authenticate!
    @customers = Customer.all
    @title = "View customers"

    erb :view_customers
  end

  get '/view/customer/:id' do
    env['warden'].authenticate!
    @customer = Customer.get(params['id'])
    @title = "Editing #{@customer.business_name}"

    erb :view_customer
  end

  get '/create/customer' do
    env['warden'].authenticate!

    erb :create_customer
  end

  get '/edit/customer/:id' do
    env['warden'].authenticate!
    @customer = Customer.get params['id']
    @title = "Edit Customer"

    erb :edit_customer
  end

  post '/edit/customer/:id' do
    customer = Customer.get params['id']
    if customer.update(contact_name: params['customer']['contact_name'], business_name: params['customer']['business_name'], billing_address: params['customer']['billing_address'], phone: params['customer']['phone'], mobile: params['customer']['mobile'], email: params['customer']['email'])
      flash[:success] = "Customer updated"
      redirect '/view/customers'
    else
      flash[:error] = "Update failed"
      redirect back
    end
  end

  get '/delete/customer/:id' do
    env['warden'].authenticate!
    customer = Customer.get params['id']
    if customer.destroy
      flash[:success] = "User deleted"
      redirect back
    else
      flash[:error] = "Deletion failed"
      redirect back
    end
  end

  post '/create/customer' do
    customer = Customer.new(created_at: Time.now, contact_name: params['customer']['contact_name'], business_name: params['customer']['business_name'], billing_address: params['customer']['billing_address'], phone: params['customer']['phone'], mobile: params['customer']['mobile'], email: params['customer']['email'])
    if customer.save
      flash[:success] = "Customer created"
      redirect '/view/customers'
    else
      flash[:error] = "Customer creation failed"
      redirect back
    end
  end

  get '/create/ad' do
    env['warden'].authenticate!
    @customers = Customer.all
    @title = "Create ad"
    today = Date.today
    @features = Features.all

    user_pub = env['warden'].user[:publication]
    if user_pub != 1
      @publications = Publication.all(:publication_id => user_pub, :date.gt => today)
    else
      @publications = Publication.all(:date.gt => today)
    end

    erb :create_ad
  end

  post '/create/ad' do
    ad_user = env['warden'].user[:id]

    ad = Ad.new(created_at: Time.now, publication_id: params['ad']['publication'], height: params['ad']['height'], columns: params['ad']['columns'], position: params['ad']['position'], price: params['ad']['price'], user_id: ad_user, customer_id: params['ad']['customer'], note: params['ad']['note'])
    if ad.save
      flash[:success] = "Ad booked"
      redirect '/'
    else
      flash[:error] = "Something went wrong #{ad.errors.inspect}"
      redirect back
    end
  end

  get '/edit/ad/:id' do
    env['warden'].authenticate!
    @title = "Edit ad"
    @ad = Ad.get params['id']
    @customers = Customer.all

    erb :edit_ad

  end

  post '/edit/ad/:id' do
    ad = Ad.get params['id']
    user = ad.user[:id]

    params['ad']['publication_date'].each do |p|
      if p[1] != ""
        ad.update(publication_date: p[1], publication: params['ad']['publication'], size: params['ad']['size'], position: params['ad']['position'], price: params['ad']['price'], customer_id: params['ad']['customer'], note: params['ad']['note'], updated_at: Time.now, updated_by: user)
        ad.save
      end
    end
    redirect '/'
    flash[:success] = "Ad updated"

  end

  get '/view/ad/:id' do
    env['warden'].authenticate!
    @ad = Ad.get params['id']
    @title = "Viewing ad"

    erb :view_ad
  end

  post '/view/ads-by-date' do
    env['warden'].authenticate!
    @role = env['warden'].user[:role]
    user_publication = env['warden'].user[:publication]
    if @role != 1
      @ads = Ad.all(:publication_date => (params['ad']['viewdate']), :publication => user_publication)
    else
      @ads = Ad.all(:publication_date => (params['ad']['viewdate']))
    end

    @title = "Viewing ads"
    erb :view_ads_by_date
  end

  get '/ad/completed/:id' do
    ad = Ad.get params['id']
    ad.completed = true
    if ad.save
      flash[:success] = "Ad completed"
      redirect '/'
    else
      flash[:error] = "Something went wrong"
      redirect back
    end
  end
  get '/ad/incomplete/:id' do
    ad = Ad.get params['id']
    ad.completed = false
    if ad.save
      flash[:success] = "Ad still needs work eh?"
      redirect '/'
    else
      flash[:error] = "Something went wrong"
      redirect back
    end
  end
  get '/ad/place/:id' do
    ad = Ad.get params['id']
    ad.placed = true
    if ad.save
      flash[:success] = "Ad placed"
      redirect '/'
    else
      flash[:error] = "Something went wrong"
      redirect back
    end
  end
  get '/ad/unplace/:id' do
    ad = Ad.get params['id']
    ad.placed = false
    if ad.save
      flash[:success] = "Ad not placed"
      redirect '/'
    else
      flash[:error] = "Something went wrong"
      redirect back
    end
  end

  get '/view/tasks' do
    env['warden'].authenticate!
    @title = "Tasks"
    @user_id = env['warden'].user[:id]
    @tasks = Task.all(:user_id => @user_id)

    erb :view_tasks
  end

  get '/view/task/:id' do
    env['warden'].authenticate!
    @task = Task.get params['id']
    @title = @task.title

    erb :view_task
  end
  get '/task/completed/:id' do
    t = Task.get params['id']
    t.completed = true
    if t.save
      flash[:success] = "Task completed"
      redirect '/view/tasks'
    else
      flash[:error] = "Something went wrong"
      redirect back
    end
  end
  get '/task/incomplete/:id' do
    t = Task.get params['id']
    t.completed = false
    if t.save
      flash[:success] = "Keep working on it"
      redirect '/view/tasks'
    else
      flash[:error] = "Something went wrong"
      redirect back
    end
  end

  get '/create/task' do
    env['warden'].authenticate!
    @title = "Create task"
    @users = User.all

    erb :create_task
  end

  post '/create/task' do
    uid = env['warden'].user[:id]
    t = Task.new(title: params['task']['title'], created_by: uid, created_at: Time.now, deadline: params['task']['deadline'], user_id: params['task']['user_id'], priority: params['task']['priority'], body: params['task']['body'], completed: false)

    if t.save
      flash[:success] = "Task successfully created..."
      redirect '/view/tasks'
    else
      flash[:error] = "Something went wrong.."
      redirect back
    end
  end

  get '/view/publications' do
    env['warden'].authenticate!

    @title = "Viewing publications"
    user_pub = env['warden'].user[:publication]
    if user_pub != 1
      @publications = Publication.all(:publication_id => user_pub, :order => [:date.asc])
    else
      @publications = Publication.all(:order => [:date.asc])
    end
    erb :view_publications
  end

  get '/create/publication' do
    env['warden'].authenticate!

    @title = "Create publication"

    erb :create_publication
  end

  post '/create/single_publication' do
    p = Publication.new(name: params['publication']['name'], date: params['publication']['date'], publication_id: params['publication']['publication_id'])
    if p.save
      flash[:success] = "Successfully created publication"
      redirect '/view/publications'
    else
      flash[:error] = "Something went wrong"
      redirect back
    end
  end

  post '/create/multiple_publications' do
    sd = Date.parse(params['publication']['start_date'])
    ed = Date.parse(params['publication']['end_date'])

    (sd..ed).each do |d|
      if d.wday == sd.wday
        p = Publication.new(name: params['publication']['name'], date: d, publication_id: params['publication']['publication_id'])
        p.save
      end
    end
    flash[:success] = "Successfully created publications"
    redirect '/view/publications'
  end

#Authentication
  get '/auth/login' do
    erb :login
  end

  post '/auth/login' do
    env['warden'].authenticate!
    @title = "Login"
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
    @search = params['search']['query']

    dbsearch(Customer, @search)
  end

  helpers do
    def dbsearch(dbmodel, query)
      if c = dbmodel.first(:business_name => query)
        redirect "/view/customer/#{c.id}"
      else
        flash[:error] = "No record found..."
        redirect back
      end
    end

    def dblist()
      arr = []
      m = Customer.all
      m.each do |n|
        arr << n.business_name

      end
      return arr
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

    def display_user(i)
      if i != nil
        u = User.get i
        username = u.username.capitalize
        return username
      end
    end

    def display_time(i)
      if i
        return i.strftime('%l:%M%P %d %b %Y')
      end
    end

    def display_date(i)
      if i
        return i.strftime('%A %d %b %Y')
      end
    end

    def display_task_number
      if env['warden'].user
        uid = env['warden'].user[:id]
        return Task.count(:user_id => uid, :completed => false)
      end
    end
  end

end
