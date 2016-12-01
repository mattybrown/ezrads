module Sinatra
  module EzrAds
    module Routing
      module Users

        def self.registered(app)

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
            pub.each do |p|
              if p.date.mon == today.mon
                @pub << p.date
              end
            end
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

        end

      end
    end
  end
end
