require 'bundler'
Bundler.require
require 'tilt/erb'

require './model'



class EzrAds < Sinatra::Base
  enable :sessions
  register Sinatra::Flash
  set :session_secret, ENV['SECRET']

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
    today = Date.today
    user_publication = env['warden'].user.paper[:id]
    @role = env['warden'].user[:role]

    @title = "Home"

    paper = Paper.all(:id => user_publication)
    pub = paper.publications(:date.gt => today) & paper.publications(:order => [:date.desc])

    if @publications = paper.publications.count >= 1
      @publications = paper.publications(:order => [:date.asc])
      @ads = pub.last.ads
      @pub = pub.last
    else
      @pub = "No publications found - <a href='/create/publication'>Click here to create one</a>"
    end

    @features = @ads.features

    @gross = 0
    @count = 0
    if @ads.class != String
      @ads.each do |a|
        @gross += a.price
        @count += 1
      end
    end

    erb :view_ads
  end

  get '/view/publication/:pub/feature/:id' do
    env['warden'].authenticate!
    today = Date.today
    user_publication = env['warden'].user.paper[:id]
    @role = env['warden'].user[:role]
    feature = Feature.get(params['id'])

    @feature = feature.name
    @title = "Home"

    paper = Paper.all(:id => user_publication)
    pub = paper.publications.get params[:pub]

    if @publications = paper.publications.count >= 1
      @publications = paper.publications(:order => [:date.asc])
      @pub = pub
      @ads = Ad.all(:publication_id => @pub.id, :feature_id => params['id'])
    else
      @pub = "No publications found - <a href='/create/publication'>Click here to create one</a>"
    end

    @gross = 0
    @count = 0
    @paid = 0
    if @ads.class != String
      @ads.each do |a|
        @gross += a.price
        @count += 1
        if a.paid
          @paid += a.price
        end
      end
    end

    erb :view_publication_feature
  end

  get '/view/publication/:pub/:feat' do
    env['warden'].authenticate!
    today = Date.today
    user_publication = env['warden'].user.paper[:id]
    @role = env['warden'].user[:role]
    @title = "Home"
    #THIS NEEDS TO BE FIXED TO SHOW THE CORRECT ADS DEPENDING ON TYPE
    paper = Paper.all(:id => user_publication)
    pub = paper.publications.get params['pub']
    if params['feat'] == 'rop'
      @feature = "ROP"
      feature = paper.features(:type => 1)
    elsif params['feat'] == 'classie'
      @feature = "Classified"
      feature = paper.features(:type => 2) + paper.features(:type => 3)
    end


    if @publications = paper.publications.count >= 1
      @publications = paper.publications(:order => [:date.asc])
      @pub = pub
      @ads = feature.ads(:publication_id => pub.id)
    else
      @pub = "No publications found - <a href='/create/publication'>Click here to create one</a>"
    end

    @gross = 0
    @count = 0
    @paid = 0
    if @ads.class != String
      @ads.each do |a|
        @gross += a.price
        @count += 1
        if a.paid == true && a.payment != 1
          @paid += a.price
        end
      end
    end

    erb :view_publication_feature
  end

  get '/ads/publication/' do
    env['warden'].authenticate!
    today = Date.today
    user = env['warden'].user
    user_paper = user.paper_id
    @role = user.role

    @title = "Home"

    paper = Paper.all(:id => user_paper)
    pub = paper.publications(:id => params['view']['publication'])

    @publications = paper.publications(:order => [:date.asc])
    @ads = pub.ads
    @features = @ads.features
    @gross = 0
    @count = 0
    @ads.each do |a|
      @gross += a.price
      @count += 1
    end

    @pub = pub.last

    erb :view_ads
  end

  get '/view/users' do
    env['warden'].authenticate!
    @title = "Users"
    @users = User.all(:paper_id => env['warden'].user.paper_id)
    @roleArr = ['poo', 'Admin', 'Sales', 'Production', 'Accounts']
    @role = env['warden'].user[:role]

    @this_month = {}
    @last_month = {}

    @users.each do |u|
      this_month_total = 0
      last_month_total = 0
      u.ads.each do |a|
        present = Date.today.mon
        if present == 1
          last_month = 12
        else
          last_month = present - 1
        end

        if a.publication.date.mon == present
          this_month_total += a.price
        end
        @this_month.update(u.username.capitalize => this_month_total)

        if a.publication.date.mon == last_month
          last_month_total += a.price
        end
        @last_month.update(u.username.capitalize => last_month_total)
      end
    end

    erb :view_users
  end

  get '/view/user/:id' do
    env['warden'].authenticate!
    if env['warden'].user.role == 1 || env['warden'].user.role == 4

      @user = User.get params['id']
      @title = "Viewing #{@user.username}"

      @ads = Ad.all(:user_id => @user.id, :order => (:created_at.desc))
      @pub = Publication.all(:paper_id => env['warden'].user.paper_id, :order => :date.desc, :limit => 10, :date.lte => Date.today)
      @data = {}
      this_month_total = 0
      last_month_total = 0
      next_month_total = 0
      @ads.each do |a|
        present = Date.today.mon
        if present == 12
          next_month == 1
        else
          next_month = present + 1
        end

        if present == 1
          last_month = 12
        else
          last_month = present - 1
        end

        @data.update("Last month" => last_month_total)
        if a.publication.date.mon == next_month
          next_month_total += a.price
        end
        if a.publication.date.mon == present
          this_month_total += a.price
        end
        @data.update("This month" => this_month_total)
        if a.publication.date.mon == last_month
          last_month_total += a.price
        end
        @data.update("Next month" => next_month_total)
      end

      price = 0
      count = 0
      @ads.each do |a|
        if a.publication.date.mon == Date.today.mon
          price += a.price
          count += 1
        end
      end
      @price = price
      @count = count

      @per_pub = {}
      @pub.each do |p|
        hash = {}
        c = 0
        pub_price = 0

        p.ads.each do |a|
          if a.user.id == @user.id
            pub_price += a.price
            c += 1
          end
        end
        @per_pub.update(p.date => { price: pub_price, count: c })
      end



      erb :view_user
    else
      flash[:error] = "You do not have permission to view this page"
      redirect back
    end
  end

  get '/create/user' do
    env['warden'].authenticate!
    @title = "Create user"
    @papers = Paper.all

    erb :create_user
  end

  post '/create/user' do
    user = User.new(created_at: Time.now, username: params['user']['username'].downcase, role: params['user']['role'], paper_id: params['user']['publication'], phone: params['user']['phone'], email: params['user']['email'], password: params['user']['password'])
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
    if env['warden'].user.role == 1
      @user = User.first(id: params['id'])
      @title = "Edit User"
      @papers = Paper.all
    else
      flash[:error] = "You do not have permission to view this page"
      redirect back
    end
    erb :edit_user
  end

  post '/edit/user/:id' do
    user = User.first(id: params['id'])
    if user.update(username: params['user']['username'], role: params['user']['role'], paper_id: params['user']['publication'], phone: params['user']['phone'], email: params['user']['email'])
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
      flash[:error] = "Deletion failed #{user.errors.inspect}"
      redirect back
    end
  end

  get '/view/customers' do
    env['warden'].authenticate!
    @customers = Customer.all(:paper_id => env['warden'].user.paper_id, :order => (:business_name.asc))
    @title = "Customers"

    erb :view_customers
  end

  get '/view/customer/:id' do
    env['warden'].authenticate!
    @customer = Customer.get(params['id'])
    @title = "#{@customer.business_name}"
    @ads = Ad.all(:customer_id => params['id'], :order => (:created_at.desc))
    @role = env['warden'].user['role']

    @price = 0
    @count = 0
    @ads.each do |a|
      if a.publication.date.mon == Date.today.mon
        @price += a.price
        @count += 1
      end
    end

    erb :view_customer
  end

  get '/create/customer' do
    env['warden'].authenticate!
    @title = "Create customer"
    erb :create_customer
  end

  get '/edit/customer/:id' do
    env['warden'].authenticate!
    @customer = Customer.get params['id']
    @title = "Edit customer"

    erb :edit_customer
  end

  get '/changepassword/:id' do
    env['warden'].authenticate!
    if env['warden'].user.id == params['id'].to_i || env['warden'].user.role == 1
      @user = User.first(id: params['id'])
      @title = "Change password"
    else
      flash[:error] = "You do not have permission to view this page"
      redirect back
    end
    erb :changepassword
  end

  post '/changepassword/:id' do
    env['warden'].authenticate!
    if env['warden'].user.id == params['id'].to_i || env['warden'].user.role  == 1
      u = User.first(id: params['id'])
      if params['user']['password'] == params['user']['repeat-password']
        if u.update(:password => params['user']['password'])
          flash[:success] = "Password updated"
          redirect '/view/users'
        else
          flash[:error] = "Something went wrong... #{u.errors.inspect}"
          redirect back
        end
      else
        flash[:error] = "Your passwords didn't match... #{u.errors.inspect}"
        redirect back
      end
    else
      flash[:error] = "You do not have permission to view this page"
      redirect back
    end
  end

  post '/edit/customer/:id' do
    customer = Customer.get params['id']
    if params['customer']['banned'] == 'on'
      banned = true
    else
      banned = false
    end
    if customer.update(contact_name: params['customer']['contact_name'], business_name: params['customer']['business_name'], billing_address: params['customer']['billing_address'], phone: params['customer']['phone'], mobile: params['customer']['mobile'], email: params['customer']['email'], custom_rate: params['customer']['custom_rate'], notes: params['customer']['notes'], banned: banned)
      flash[:success] = "Customer updated"
      redirect '/view/customers'
    else
      customer.errors.each do |e|
        flash[:error] = "Update failed - #{e}}"
      end
      redirect back
    end
  end

  post '/delete/customer/:id' do
    env['warden'].authenticate!
    customer = Customer.get params['id']
    customer.ads.each do |a|
      a.destroy
    end
    if customer.destroy!
      flash[:success] = "User deleted"
      redirect '/'
    else
      flash[:error] = "Deletion failed"
      redirect back
    end
  end

  post '/create/customer' do
    if Customer.all(business_name: params['customer']['business_name']).length > 0
      flash[:error] = "There is an existing record with this business name"
      redirect back
    end
    if params['customer']['custom_rate'] == ""
      customer = Customer.new(created_at: Time.now, contact_name: params['customer']['contact_name'], business_name: params['customer']['business_name'], billing_address: params['customer']['billing_address'], phone: params['customer']['phone'], mobile: params['customer']['mobile'], email: params['customer']['email'], custom_rate: '0', paper_id: env['warden'].user.paper_id, alt_contact_name: params['customer']['alt_contact_name'], alt_contact_phone: params['customer']['alt_contact_phone'], notes: params['customer']['notes'], banned: false)
    else
      customer = Customer.new(created_at: Time.now, contact_name: params['customer']['contact_name'], business_name: params['customer']['business_name'], billing_address: params['customer']['billing_address'], phone: params['customer']['phone'], mobile: params['customer']['mobile'], email: params['customer']['email'], custom_rate: params['customer']['custom_rate'], paper_id: env['warden'].user.paper_id, alt_contact_name: params['customer']['alt_contact_name'], alt_contact_phone: params['customer']['alt_contact_phone'], notes: params['customer']['notes'], banned: false)
    end
    if customer.save
      flash[:success] = "Customer created"
      redirect '/view/customers'
    else
      customer.errors.each do |e|
        flash[:error] = "Create customer failed - #{e}"
      end
      redirect back
    end
  end

  get '/cancel/ad' do
    env['warden'].authenticate!
    session[:ad].clear
    redirect '/'
  end

  get '/create/ad' do
    env['warden'].authenticate!
    @customers = Customer.all(:paper_id => env['warden'].user.paper_id)
    @users = User.all(:paper_id => env['warden'].user.paper_id)
    @title = "Create ad"
    today = Date.today
    @features = Feature.all(:paper_id => env['warden'].user.paper_id, :type => 1) + Feature.all(:paper_id => env['warden'].user.paper_id, :type => 3) + Feature.all(:paper_id => env['warden'].user.paper_id, :type => 4)
    if env['warden'].user.role == 1 || env['warden'].user.role == 4
      @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :order => [:date.asc])
    else
      @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :date.gt => today, :order => [:date.asc])
    end
    erb :create_ad
  end

  post '/create/ad' do
    session[:ad] = {height: params['ad']['height'], columns: params['ad']['columns'], notes: params['ad']['note'], customer: params['ad']['customer'], feature: params['ad']['feature'], position: params['ad']['position'], payment: params['ad']['payment'], price: params['ad']['price'], user: params['ad']['user'], receipt: params['ad']['receipt'], publication: params['ad']['single-publication'], print: params['ad']['print']}

    if params['ad']['user']
      ad_user = params['ad']['user']
    else
      ad_user = env['warden'].user[:id]
    end

    if params['ad']['updated_by']
      updated_by = params['ad']['updated_by']
    else
      updated_by = nil
    end
    if params['ad']['paid']
      paid = true
    else
      paid = false
    end

    customer = Customer.get(params['ad']['customer'])
    feature = Feature.get(params['ad']['feature'])
    if feature.type == 2
      columns = 0
    else
      columns = params['ad']['columns']
    end

    if params['ad']['price'] != ""
      user_price = params['ad']['price'].to_f
    end
    if customer.custom_rate > 0
      price = params['ad']['height'].to_f * params['ad']['columns'].to_f * customer.custom_rate
      percent = price / 100 * 20
      if user_price
        if env['warden'].user.role == 1 || env['warden'].user.role == 4
          price = user_price
        elsif user_price && user_price >= (price - percent)
          price = user_price
        else
          flash[:error] = "The minimum price for this ad is $#{format_price(price - percent)} - see an admin for further discounts"
          redirect back
        end
      end
    else
      price = params['ad']['height'].to_f * params['ad']['columns'].to_f * feature.rate
      percent = price / 100 * 20
      if user_price
        if env['warden'].user.role == 1 || env['warden'].user.role == 4
          price = user_price
        elsif user_price >= (price - percent)
          price = user_price
        else
          flash[:error] = "The minimum price for this ad is $#{format_price(price - percent)} - see an admin for further discounts"
          redirect back
        end
      end
    end

    if params['ad']['repeat']
      repeat_publication = Publication.get(params['ad']['publication'].first[0])
      if params['ad']['repeat_date']
        repeat_date = params['ad']['repeat_date']
      else
        repeat_date = repeat_publication.date
      end
      params['ad']['publication'].each do |a|
        ad = Ad.new(created_at: Time.now, repeat_date: repeat_date, publication_id: a[0], height: params['ad']['height'], columns: columns, position: params['ad']['position'], price: price, user_id: ad_user, customer_id: params['ad']['customer'], feature_id: params['ad']['feature'], note: params['ad']['note'], payment: params['ad']['payment'], paid: paid, completed: false, placed: false, receipt: params['ad']['receipt'], print_only: params['ad']['print'])
        if ad.save
          flash[:success] = "<a class='blue-text text-darken-4' href='/view/ad/#{ad.id}'>#{ad.id} - #{ad.height}x#{ad.columns} #{customer.business_name}</a> successfully booked"
          session[:ad].clear
        else
          ad.errors.each do |e|
            flash[:error] = e
          end
        end
      end
      redirect '/'
    else
      feature = Feature.get(params['ad']['feature'])
      if params['ad']['repeat_date']
        repeat_date = params['ad']['repeat_date']
      else
        repeat_date = nil
      end
      ad = Ad.new(created_at: Time.now, publication_id: params['ad']['single-publication'], height: params['ad']['height'], columns: columns, position: params['ad']['position'], price: price, user_id: ad_user, customer_id: params['ad']['customer'], feature_id: params['ad']['feature'], note: params['ad']['note'], repeat_date: repeat_date, updated_by: updated_by, payment: params['ad']['payment'], paid: paid, completed: false, placed: false, receipt: params['ad']['receipt'], print_only: params['ad']['print'])
      if ad.save
        flash[:success] = "<a class='blue-text text-darken-4' href='/view/ad/#{ad.id}'>#{ad.id} - #{ad.height}x#{ad.columns} #{customer.business_name}</a> successfully booked"
        session[:ad].clear
        redirect '/'
      else
        flash[:error] = "Something went wrong #{ad.errors.inspect}"
        redirect back
      end
    end
  end

  get '/edit/ad/:id' do
    env['warden'].authenticate!
    today = Date.today
    @title = "Edit ad"
    @ad = Ad.get params['id']
    @customers = Customer.all
    @features = Feature.all
    if env['warden'].user.role == 1 || env['warden'].user.role == 4
      @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :order => [:date.asc])
    else
      @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :date.gt => today, :order => [:date.asc])
    end
    @users = User.all(:paper_id => env['warden'].user.paper_id)

    erb :edit_ad

  end

  post '/edit/ad/:id' do
    ad = Ad.get params['id']
    updater = env['warden'].user.id
    if params['ad']['user']
      user = params['ad']['user']
    else
      user = ad.user[:id]
    end
    feature = Feature.get params['ad']['feature']
    customer = ad.customer
    if params['ad']['price']
      price = params['ad']['price']
    else
      price = ad.price
    end
    if params['ad']['columns'] == ""
      params['ad']['columns'] = 0
    end
    if params['ad']['paid']
      paid = true
    else
      paid = false
    end
    if ad.update(publication_id: params['ad']['publication'], height: params['ad']['height'], columns: params['ad']['columns'], feature_id: params['ad']['feature'], price: price, customer_id: params['ad']['customer'], note: params['ad']['note'], updated_at: Time.now, updated_by: updater, payment: params['ad']['payment'], user_id: user, position: params['ad']['position'], receipt: params['ad']['receipt'], print_only: params['ad']['print'], paid: paid)
      flash[:success] = "Ad #{ad.id} updated"
      redirect "/view/customer/#{customer.id}"
    else
      flash[:error] = "Something went wrong #{ad.errors.inspect}"
      redirect back
    end

  end

  get '/delete/ad/:id' do
    env['warden'].authenticate!

    if env['warden'].user['role'] == 1 || env['warden'].user['role'] == 4
      ad = Ad.get params['id']
      if ad.destroy
        flash[:success] = "Ad #{ad.id} deleted"
        redirect "/view/customer/#{ad.customer_id}"
      end
    else
      flash[:error] = "Sorry, you don't have permission to do that"
    end
  end

  get '/view/ad/:id' do
    env['warden'].authenticate!
    today = Date.today
    @ad = Ad.get params['id']
    @users = User.all(:paper_id => @ad.publication.paper_id)
    if env['warden'].user.role == 1 || env['warden'].user.role == 4
      @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :order => [:date.asc])
    else
      @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :date.gt => today, :order => [:date.asc])
    end
    @title = "Viewing ad"

    erb :view_ad
  end

  get '/create/runon' do
    env['warden'].authenticate!
    @customers = Customer.all(:paper_id => env['warden'].user.paper_id)
    @title = "Create ad"
    today = Date.today
    @features = Feature.all(:paper_id => env['warden'].user.paper_id, :type => 2)

    @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :date.gt => today, :order => [:date.asc])

    erb :create_runon
  end

  post '/create/runon' do
    feature = Feature.get params['runon']['feature']
    words = params['runon']['words'].to_i
    if params['runon']['paid']
      paid = true
    else
      paid = false
    end

    if words > feature.rate
      price = (words - feature.rate) * 0.5 + 10
    else
      price = 10
    end

    if params['runon']['repeat']
      repeat_publication = Publication.get(params['runon']['publication'].first[0])
      repeat_date = repeat_publication.date

      params['runon']['publication'].each do |p|
        runon = Ad.new(height: words, customer_id: params['runon']['customer'], note: params['runon']['note'], payment: params['runon']['payment'], publication_id: p[0], price: price, user_id: env['warden'].user.id, feature_id: params['runon']['feature'], position: params['runon']['position'], paid: paid, receipt: params['runon']['receipt'])
        if runon.save
          flash[:success] = "Run on created"
        else
          flash[:error] = "Something went wrong #{runon.errors.inspect}"
          redirect back
        end
      end
      redirect '/'
    else
      runon = Ad.new(height: words, customer_id: params['runon']['customer'], note: params['runon']['note'], payment: params['runon']['payment'], publication_id: params['runon']['single-publication'], price: price, user_id: env['warden'].user.id, feature_id: params['runon']['feature'], position: params['runon']['position'], paid: paid, receipt: params['runon']['receipt'])
      if runon.save
        flash[:success] = "Run on created"
        redirect '/'
      else
        flash[:error] = "Something went wrong #{runon.errors.inspect}"
        redirect back
      end
    end
  end

  get '/edit/runon/:id' do
    env['warden'].authenticate!
    @customers = Customer.all(:paper_id => env['warden'].user.paper_id)
    @title = "Edit run on"
    today = Date.today
    @features = Feature.all(:paper_id => env['warden'].user.paper_id, :type => 2)

    @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :date.gt => today, :order => [:date.asc])

    @ad = Ad.get params['id']

    erb :edit_runon
  end

  post '/edit/runon/:id' do
    ad = Ad.get params['id']
    feature = Feature.get params['runon']['feature']
    words = params['runon']['words'].to_i
    updater = env['warden'].user.id
    if params['runon']['paid']
      paid = true
    else
      paid = false
    end

    if params['runon']['price'] != "" && env['warden'].user.role == 1 || env['warden'].user.role == 4
      price = params['runon']['price'].to_f
    else
      price = ad.price
    end

    if params['runon']['repeat']
      repeat_publication = Publication.get(params['runon']['publication'].first[0])
      repeat_date = repeat_publication.date

      params['runon']['publication'].each do |p|
        if ad.update(height: words, customer_id: params['runon']['customer'], note: params['runon']['note'], payment: params['runon']['payment'], publication_id: p[0], price: price, user_id: ad.user.id, feature_id: params['runon']['feature'], position: params['runon']['position'], updated_by: updater, paid: paid, receipt: params['runon']['receipt'])
          flash[:success] = "Run on #{ad.id} updated"
        else
          flash[:error] = "Something went wrong #{ad.errors.inspect}"
          redirect back
        end
      end
      redirect '/'
    else
      if ad.update(height: words, customer_id: params['runon']['customer'], note: params['runon']['note'], payment: params['runon']['payment'], publication_id: params['runon']['single-publication'], price: price, user_id: ad.user.id, feature_id: params['runon']['feature'], position: params['runon']['position'], updated_by: updater, paid: paid, receipt: params['runon']['receipt'])
        flash[:success] = "Run on #{ad.id} updated"
        redirect '/'
      else
        flash[:error] = "Something went wrong #{ad.errors.inspect}"
        redirect back
      end
    end
  end

  get '/ad/completed/:id' do
    ad = Ad.get params['id']
    if ad.completed == true
      ad.completed = false
      if ad.save
        return "incomplete"
      else
        return "#{ad.errors.inspect}"
      end
    elsif ad.completed == false || ad.placed == nil
      ad.completed = true
      if ad.save
        return "completed"
      else
        return "#{ad.errors.inspect}"
      end
    end
  end

  get '/ad/place/:id' do

    ad = Ad.get params['id']
    if ad.placed == true
      ad.placed = false
      if ad.save
        return "not-placed"
      else
        return "#{ad.errors.inspect}"
      end
    elsif ad.placed == false || ad.placed == nil
      ad.placed = true
      if ad.save
        return "placed"
      else
        return "#{ad.errors.inspect}"
      end
    end

  end

  get '/ad/status/:id' do
    ad = Ad.get params['id']
    if ad.placed == true
      return true
    else
      return false
    end
  end

  get '/me' do
    env['warden'].authenticate!
    @user = env['warden'].user
    @title = "#{@user.username.capitalize}'s bookings"
    @tasks = Task.all(:user_id => @user.id, :completed => false)
    @ads = Ad.all(:user_id => @user.id, :order => (:created_at.desc))
    @data = {}
    this_month_total = 0
    last_month_total = 0
    next_month_total = 0
    @ads.each do |a|
      present = Date.today.mon
      if present == 12
        next_month == 1
      else
        next_month = present + 1
      end

      if present == 1
        last_month = 12
      else
        last_month = present - 1
      end

      @data.update("Last month" => last_month_total)
      if a.publication.date.mon == next_month
        next_month_total += a.price
      end
      if a.publication.date.mon == present
        this_month_total += a.price
      end
      @data.update("This month" => this_month_total)
      if a.publication.date.mon == last_month
        last_month_total += a.price
      end
      @data.update("Next month" => next_month_total)
    end

    price = 0
    count = 0
    paid = 0
    @ads.each do |a|
      if a.publication.date.mon == Date.today.mon
        price += a.price
        count += 1
      end
      if a.paid == false
        paid += 1
      end
    end
    @price = price
    @count = count
    @paid = paid
    erb :me
  end

  get '/view/task/:id' do
    env['warden'].authenticate!
    @task = Task.get params['id']
    @title = @task.title

    erb :view_task
  end
  get '/view/tasks/complete' do
    env['warden'].authenticate!
    @tasks = Task.all(:user_id => env['warden'].user.id, :order => [:created_at.desc], :completed => true)
    @title = "Completed tasks"

    erb :view_tasks
  end
  get '/task/completed/:id' do
    t = Task.get params['id']
    t.completed = true
    if t.save
      flash[:success] = "Task completed"
      redirect back
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
      redirect back
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

  get '/create/task/:id' do
    env['warden'].authenticate!
    @title = "Create task"
    @users = User.all
    @task_ad = "/view/ad/#{params['id']}"

    erb :create_task
  end

  get '/task/reply/:user/:title' do
    env['warden'].authenticate!
    @title = "Reply"
    @tasktitle = "Re: " + params[:title].gsub(/-/, ' ')
    @user = params[:user]
    @users = User.all

    erb :create_task
  end

  post '/create/task' do
    uid = env['warden'].user.id
    title = params['task']['title']
    title.gsub!(/\s/, '-')
    t = Task.new(title: params['task']['title'], created_by: uid, created_at: Time.now, deadline: params['task']['deadline'], user_id: params['task']['user_id'], priority: params['task']['priority'], body: params['task']['body'], completed: false)

    if t.save
      flash[:success] = "Task successfully created..."
      redirect back
    else
      flash[:error] = "Something went wrong.. #{t.errors.inspect}"
      redirect back
    end
  end

  get '/view/publications' do
    env['warden'].authenticate!
    if env['warden'].user.role == 1 || env['warden'].user.role == 4
      @title = "Publications"
      user_pub = env['warden'].user.paper_id
      @publications = Publication.all(:paper_id => user_pub, :order => [:date.asc])
      @ads_booked = {}
      @ads_gross = {}

      @publications.each do |p|
        total = 0
        feature_total = 0
        @ads_booked[p.date] = p.ads.count
        p.ads.each do |a|
          total += a.price
        end
        @ads_gross[p.date] = total
      end

      erb :view_publications
    else
      flash[:error] = "You do not have permission to view this page"
      redirect back
    end
  end

  get '/view/publication/:id' do
    env['warden'].authenticate!
    if env['warden'].user.role == 1 || env['warden'].user.role == 4
      if @publication = Publication.get(params['id'])
        @title = "Viewing publication #{@publication.name} - #{display_date(@publication.date)}"
        @ads = @publication.ads
        @account = 0
        @cash = 0
        @eftpos = 0
        @direct_credit = 0
        @paid = 0
        @unpaid = 0
        @unpaid_total = 0
        @publication.ads.each do |a|
          if a.payment == 1
            @account += a.price
          elsif a.payment == 3
            @eftpos += a.price
          elsif a.payment == 2
            @cash += a.price
          elsif a.payment == 4
            @direct_credit += a.price
          end
          if a.paid == true
            @paid += a.price
          else
            @unpaid_total += a.price
          end

          if a.paid == false
            @unpaid += 1
          end
        end

        @pub_data = {}
        past_publications = Publication.all(:date.lte => @publication.date, :order => [:date.desc], :limit => 12, :paper_id => env['warden'].user.paper_id)
        past_publications.each do |p|
          total = 0
          p.ads.each do |a|
            total += a.price
          end
          @pub_data.update(display_date(p.date) => total)
        end
        @pub_data.update(display_date(@publication.date) => (@paid))

        @gst = (@paid + @unpaid_total) * @publication.paper.gst / 100.0

        u = User.all
        @repdata = {}
        u.each do |u|
          total = 0
          u.ads.each do |a|
            if a.publication_id == @publication.id
              total += a.price
            end
          end
          @repdata.update(u.username.capitalize => total)
        end

        @features = @publication.ads.feature
        @feat_data = {}
        @rop_data = {}
        @clas_data = {}
        @other_data = {}
        @feat_total = 0
        @rop_total = 0
        @clas_total = 0
        @other_total = 0
        @features.each do |f|
          total = 0
          rop_price = 0
          clas_price = 0
          other_price = 0

          f.ads.each do |a|
            if a.publication_id == @publication.id
              total += a.price
              if a.feature.type == 1
                @rop_total += a.price
                rop_price += a.price
              elsif a.feature.type == 2 || a.feature.type == 3
                @clas_total += a.price
                clas_price += a.price
              else
                @other_total += a.price
                other_price += a.price
              end
            end
          end
          if f.type == 1
            @rop_data.update(f.name => rop_price)
          elsif f.type == 2 || f.type == 3
            @clas_data.update(f.name => clas_price)
          else
            @other_data.update(f.name => other_price)
          end

          @feat_data.update("ROP" => @rop_total, "Classified" => @clas_total, "Other" => @other_total)
        end

        erb :view_publication
      else
        flash[:error] = "Couldn't find that publication..."
        redirect back
      end
    else
      flash[:error] = "You do not have permission to view this page"
      redirect back
    end
  end

  get '/create/publication' do
    env['warden'].authenticate!
    if env['warden'].user[:role] != 1
      flash[:error] = "Only Admins can go there"
      redirect back
    end

    @title = "Create publication"
    @papers = Paper.all

    erb :create_publication
  end

  post '/create/single_publication' do
    p = Publication.new(name: params['publication']['name'], date: params['publication']['date'], paper_id: params['publication']['publication_id'])
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
        p = Publication.new(name: params['publication']['name'], date: d, paper_id: params['publication']['publication_id'])
        if p.save
          flash[:success] = "Publications created"
        else
          p.errors.each do |e|
            flash[:error] = "Error: #{e}"
          end
        end
      end
    end
    redirect '/view/publications'
  end

  get '/create/feature' do
    env['warden'].authenticate!

    @title = "Create feature"


    erb :create_feature
  end

  post '/create/feature' do
    f = Feature.get params['id']
    if params['feature']['rop'] == "true"
      rop = true
    else
      rop = false
    end
    f = Feature.new(name: params['feature']['name'], rate: params['feature']['rate'], paper_id: env['warden'].user.paper_id, type: params['feature']['type'], rop: rop)
    if f.save
      flash[:success] = "Feature created"
      redirect '/view/publications'
    else
      f.errors.each do |f|
        flash[:error] = "Something went wrong... #{f}"
      end
      redirect back
    end
  end

  get '/view/features' do
    env['warden'].authenticate!

    @title = "Features"
    @features = Feature.all(paper_id: env['warden'].user.paper_id)

    erb :view_features
  end

  get '/edit/feature/:id' do
    env['warden'].authenticate!

    @feature = Feature.get params['id']
    @title = "Editing feature #{@feature.name}"

    erb :edit_feature
  end

  post '/edit/feature/:id' do
    f = Feature.get params['id']
    if params['feature']['rop'] == "true"
      rop = true
    else
      rop = false
    end
    if f.update(name: params['feature']['name'], rate: params['feature']['rate'], type: params['feature']['type'], rop: rop)
      flash[:success] = "Feature updated"
      redirect '/view/features'
    else
      f.errors.each do |f|
        flash[:error] = "Something went wrong... #{f}"
      end
      redirect back
    end
  end

  get '/delete/feature/:id' do
    env['warden'].authenticate!

    if env['warden'].user['role'] != 1
      flash[:error] = "Sorry, you don't have permission to do that"
      redirect '/'
    else
      f = Feature.get params['id']
      if f.destroy!
        flash[:success] = "Feature deleted"
        redirect back
      else
        f.errors.each do |f|
          flash[:error] = "Something went wrong... #{f}"
        end
        redirect back
      end
    end
  end

  post '/create/motd' do
    if params['motd']['enabled']
      enabled = true
    else
      enabled = false
    end
    m = Motd.new(message: params['motd']['message'], paper_id: params['motd']['paper'], enabled: enabled)
    if m.save
      flash[:success] = "Message saved";
      redirect '/'
    else
      flash[:error] = "Something went wrong..."
    end
  end

  get '/settings' do
    @title = "Paper settings"
    if Paper.all.count < 1
      erb :setup
    elsif env['warden'].user.role == 1
      env['warden'].authenticate!
      @paper = Paper.get(env['warden'].user.paper_id)
      @papers = Paper.all
      @motd = Motd.last
      erb :settings
    else
      flash[:error] = "You do not have permission to view this page"
      redirect back
    end
  end

  post '/setup' do
    p = Paper.new(name: params['paper']['name'], gst: params['paper']['gst'])
    if p.save
      u = User.new(username: params['user']['username'], password: params['user']['password'], role: 1, paper_id: p.id)
      if u.save
        flash[:success] = "Paper and user set"
        redirect '/'
      else
        u.errors.each do |u|
          flash[:error] = "Something went wrong... #{u}"
          redirect back
        end
      end
    end
  end

  post '/edit/paper' do
    if p = Paper.update(name: params['paper']['name'], gst: params['paper']['gst'])
      flash[:success] = "Paper updated"
      redirect '/'
    else
      p.errors.each do |p|
        flash[:error] = "Something went wrong... #{p}"
      end
      redirect back
    end
  end

  post '/create/paper' do
    p = Paper.new(name: params['paper']['name'], gst: params['paper']['gst'])
    if p.save
      flash[:success] = "Paper created"
      redirect '/'
    else
      p.errors.each do |p|
        flash[:error] = "Something went wrong... #{p}"
      end
      redirect back
    end
  end

  get '/quote' do
    env['warden'].authenticate!
    @title = "Quote calculator"
    @features = Feature.all(:paper_id => env['warden'].user.paper_id)
    erb :quote
  end
  post '/quote' do
    feature = Feature.get params['quote']['feature']
    quote = params['quote']['height'].to_f * params['quote']['columns'].to_f * feature.rate
    flash[:notice] = "$#{quote}"
    redirect back
  end

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
    @users = User.all(:paper_id => env['warden'].user.paper_id)
    @customers = Customer.all(:paper_id => env['warden'].user.paper_id)
    @paper = env['warden'].user.paper_id
    if params['customer-search']
      if params['customer-search']['query']
        if @customer = Customer.all(:business_name.like => "%#{params['customer-search']['query']}%") + Customer.all(:contact_name.like => "%#{params['customer-search']['query']}%") & Customer.all(:paper_id => @paper)
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


      if @ads.count == 1
        @results = "1 record found"
      else
        @results = "#{@ads.count} records found"
      end
    end

    erb :search
  end

  get '/paper/:id' do
    env['warden'].authenticate!
    if env['warden'].user.role == 1
      @user = User.get env['warden'].user.id
      if @user.update(:paper_id => params['id'])
        flash[:success] = "Changed papers"
        redirect back
      else
        flash[:error] = "Something went wrong"
        redirect back
      end
    else
      flash[:error] = "You do not have permission to view this page"
      redirect back
    end

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

  end

end
