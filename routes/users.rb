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
            sd = Date.today - Date.today.mday + 1
            ed = Date.new(sd.year, sd.month, -1)
            if sd.month != 1
              lsd = Date.new(sd.year, sd.month - 1, sd.day)
              led = Date.new(sd.year, sd.month - 1, -1)
            else
              lsd = Date.new(sd.year - 1, 12)
              led = Date.new(sd.year - 1, 12, -1)
            end
            pub = Publication.all(
              date: (sd..ed),
              paper_id: env['warden'].user.paper_id,
              order: :date.asc
            )
            last_month_pubs = Publication.all(
              date: (lsd..led),
              paper_id: env['warden'].user.paper_id,
              order: :date.desc
            )
            pub.each do |p|
              total = 0
              p.ads.map { |a| total += a.price }
              @pub << [p.date, total]
            end

            @this_month = Hash.new
            @last_month = Hash.new
            @users.each do |u|
              if u.role != 3
                p_user = []
                p_user << u.username
                @user_total = 0
                pub.each do |p|
                  total = 0
                  p.ads.map { |a| a.user_id == u.id ? total += a.price : nil }
                  p_user << total
                  @user_total += total
                end
                @last_month_user_total = 0
                last_month_pubs.each do |p|
                  total = 0
                  p.ads.map { |a| a.user_id == u.id ? total += a.price : nil }
                  @last_month_user_total += total
                end
                if @user_total > 0
                  @pub_users << p_user
                  @this_month[u.username.capitalize] = @user_total
                end
                @last_month_user_total > 0 ? @last_month[u.username.capitalize] = @last_month_user_total : nil
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
