module Sinatra
  module EzrAds
    module Routing
      module Users

        def self.registered(app)

          app.get '/me' do
            env['warden'].authenticate!
            today = Date.today
            @user = env['warden'].user
            @title = "#{@user.username.capitalize}'s bookings"
            @tasks = Task.all(:user_id => @user.id, :completed => false)
            @ads = Ad.paginate(Ad.publication.date.gt => today, :order => Ad.publication.date.asc, :page => params[:page], :per_page => 30, :user_id => @user.id)
            erb :me
          end

          app.get '/view/users' do
            env['warden'].authenticate!
            @title = "Users"
            @users = User.all
            @role = env['warden'].user[:role]
            @roleArr = ['nil', 'Admin', 'Sales', 'Production', 'Accounts']

            @pub = []
            @pub_users = []
            today = Date.today
            pub = Publication.all(:date.lt => today, :limit => 8, :paper_id => env['warden'].user.paper_id, :order => :date.desc)
            pub += Publication.all(:date.gt => today, :limit => 8, :paper_id => env['warden'].user.paper_id, :order => :date.asc)
            pub.map { |p| p.date.mon == today.mon ? @pub << p.date : nil }
            @users.each do |u|
              if u.role != 3
                p_user = []
                p_user << u.username
                @user_total = 0
                pub.each do |p|
                  if p.date.mon == today.mon
                    total = 0
                      p.ads.each do |a|
                        if a.user_id == u.id
                          total += a.price
                        end
                      end
                    p_user << total
                    @user_total += total
                  end
                end
                if @user_total > 0
                  @pub_users << p_user
                end
              end
            end

            @this_month = {}
            @last_month = {}

            @users.each do |u|
              this_month_total = 0
              last_month_total = 0
              u.ads.each do |a|
                if a.publication != nil
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
            end

            erb :view_users
          end

          app.get '/view/user/:id' do
            env['warden'].authenticate!
            if env['warden'].user.role == 1 || env['warden'].user.role == 4

              @user = User.get params['id']
              @title = "Viewing #{@user.username}"

              @ads = Ad.paginate(:page => params[:page], :per_page => 30, :user_id => @user.id, :order => (:created_at.desc))
              #@ads = Ad.all(:user_id => @user.id, :order => (:created_at.desc))
              @pub = Publication.all(:order => :date.desc, :limit => 10, :date.lte => Date.today)
              this_month_total = 0
              last_month_total = 0
              next_month_total = 0
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

          app.get '/create/user' do
            env['warden'].authenticate!
            @title = "Create user"
            @papers = Paper.all

            erb :create_user
          end

          app.post '/create/user' do
            user = User.new(created_at: Time.now, username: params['user']['username'].downcase, role: params['user']['role'], paper_id: params['user']['publication'], phone: params['user']['phone'], email: params['user']['email'], password: params['user']['password'])
            if user.save
              flash[:success] = "User created"
              redirect '/view/users'
            else
              flash[:error] = "User creation failed"
              redirect '/create/user'
            end
          end

          app.get '/edit/user/:id' do
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

          app.post '/edit/user/:id' do
            user = User.first(id: params['id'])
            if user.update(username: params['user']['username'], role: params['user']['role'], paper_id: params['user']['publication'], phone: params['user']['phone'], email: params['user']['email'])
              flash[:success] = "User updated"
              redirect '/view/users'
            else
              flash[:error] = "Update failed"
              redirect back
            end
          end

          app.get '/delete/user/:id' do
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

          app.get '/changepassword/:id' do
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

          app.post '/changepassword/:id' do
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

        #end of self.registered
        end

      end
    end
  end
end
