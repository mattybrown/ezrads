module Sinatra
  module EzrAds
    module Routing
      module Ads

        def self.registered(app)

          app.helpers do
            def save_success_helper(ad)
              flash[:success] = "<a class='blue-text text-darken-4' href='/view/ad/#{ad.id}'>#{ad.id} - #{ad.height}x#{ad.columns} #{ad.customer.business_name}</a> successfully booked"
              session[:ad].clear
              redirect '/'
            end

            def repeat_save_success_helper(ad)
              flash[:success] = "<a class='blue-text text-darken-4' href='/view/ad/#{ad.id}'>#{ad.id} - #{ad.height}x#{ad.columns} #{ad.customer.business_name}</a> successfully booked"
              session[:ad].clear
            end

            def error_helper(custom_error_text)
              custom_error_text ? flash[:error] = "#{ad.errors.inspect} - #{custom_error_text}" : flash[:error] = "#{ad.errors.inspect}"
              redirect back
            end
          end

          #clears session data for create ad
          app.get '/cancel/ad' do
            env['warden'].authenticate!
            session[:ad].clear
            redirect '/'
          end

          app.get '/create/ad' do
            env['warden'].authenticate!
            @customers = Customer.all
            @users = User.all
            @title = "Create ad"
            today = Date.today
            @features = Feature.all(:paper_id => env['warden'].user.paper_id, :type => 1) + Feature.all(:paper_id => env['warden'].user.paper_id, :type => 3) + Feature.all(:paper_id => env['warden'].user.paper_id, :type => 4)
            if env['warden'].user.role == 1 || env['warden'].user.role == 4
              @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :order => [:date.asc])
            else
              @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :date.gt => today, :order => [:date.asc])
            end
            @all_publications = Publication.all(:paper_id => env['warden'].user.paper.id, :order => [:date.asc])
            erb :create_ad
          end

          app.post '/create/ad' do
            session[:ad] = {height: params['ad']['height'], columns: params['ad']['columns'], notes: params['ad']['note'], customer: params['ad']['customer'], feature: params['ad']['feature'], position: params['ad']['position'], payment: params['ad']['payment'], price: params['ad']['price'], user: params['ad']['user'], receipt: params['ad']['receipt'], publication: params['ad']['single-publication'], print: params['ad']['print']}

            params['ad']['user'] ? ad_user = params['ad']['user'] : ad_user = env['warden'].user[:id]
            params['ad']['updated_by'] ? updated_by = params['ad']['updated_by'] : updated_by = nil
            params['ad']['paid'] ? paid = true : paid = false


            customer = Customer.get(params['ad']['customer'])
            if customer.booking_order == true
              if params['ad']['print'] == "" || params['ad']['print'] == nil
                flash[:error] = "This ad requires an order number to be created"
                redirect back
              end
            end

            feature = Feature.get(params['ad']['feature'])
            feature.type == 2 ? columns = 0 : columns = params['ad']['columns']

            user_price = params['ad']['price'].to_f if params['ad']['price'] != ""

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
              if params['ad']['show_repeat']
                repeat_date = nil
              elsif params['ad']['custom_repeat'] && params['ad']['custom_repeat'] != ""
                repeat_pub = Publication.get(params['ad']['custom_repeat'])
                repeat_date = repeat_pub.date
              else
                repeat_date = repeat_publication.date
              end
              params['ad']['publication'].each do |a|
                ad = Ad.new(created_at: Time.now, repeat_date: repeat_date, publication_id: a[0], height: params['ad']['height'], columns: columns, position: params['ad']['position'], price: price, user_id: ad_user, customer_id: params['ad']['customer'], feature_id: params['ad']['feature'], note: params['ad']['note'], payment: params['ad']['payment'], paid: paid, completed: false, placed: false, receipt: params['ad']['receipt'], print_only: params['ad']['print'])
                if ad.save
                  repeat_save_success_helper(ad)
                else
                  error_helper
                end
              end
              redirect '/'
            else
              feature = Feature.get(params['ad']['feature'])
              params['ad']['repeat_date'] ? repeat_date = params['ad']['repeat_date'] :repeat_date = nil

              ad = Ad.new(created_at: Time.now, publication_id: params['ad']['single-publication'], height: params['ad']['height'], columns: columns, position: params['ad']['position'], price: price, user_id: ad_user, customer_id: params['ad']['customer'], feature_id: params['ad']['feature'], note: params['ad']['note'], repeat_date: repeat_date, updated_by: updated_by, payment: params['ad']['payment'], paid: paid, completed: false, placed: false, receipt: params['ad']['receipt'], print_only: params['ad']['print'])
              if ad.save
                save_success_helper(ad)
              else
                error_helper
              end
            end
          end

          app.get '/edit/ad/:id' do
            env['warden'].authenticate!
            today = Date.today
            @title = "Edit ad"
            @ad = Ad.get params['id']
            @customers = Customer.all
            @features = Feature.all(:paper_id => env['warden'].user.paper.id)
            if env['warden'].user.role == 1 || env['warden'].user.role == 4
              @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :order => [:date.asc])
            else
              @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :date.gt => today, :order => [:date.asc])
            end
            @users = User.all

            erb :edit_ad
          end

          app.post '/edit/ad/:id' do
            ad = Ad.get params['id']
            updater = env['warden'].user.id
            if params['ad']['user']
              user = params['ad']['user']
            else
              user = ad.user[:id]
            end
            feature = Feature.get params['ad']['feature']
            customer = ad.customer
            if params['ad']['price'] != "" && env['warden'].user.role == 1 || env['warden'].user.role == 4
              price = params['ad']['price'].to_f
            elsif customer.custom_rate > 0
              price = params['ad']['height'].to_f * params['ad']['columns'].to_f * customer.custom_rate
              percent = price / 100 * 20
            else
              price = params['ad']['height'].to_f * params['ad']['columns'].to_f * feature.rate
              percent = price / 100 * 20
            end
            if params['ad']['columns'] == ""
              params['ad']['columns'] = 0
            end
            if params['ad']['paid']
              paid = true
            else
              paid = false
            end
            if params['ad']['repeat_date'] == ""
              params['ad']['repeat_date'] = nil
            elsif params['ad']['repeat_date'] == "none"
              params['ad']['repeat_date'] = nil
            end
            if ad.update(publication_id: params['ad']['publication'], height: params['ad']['height'], columns: params['ad']['columns'], feature_id: params['ad']['feature'], price: price, customer_id: params['ad']['customer'], note: params['ad']['note'], updated_at: Time.now, updated_by: updater, payment: params['ad']['payment'], user_id: user, position: params['ad']['position'], receipt: params['ad']['receipt'], print_only: params['ad']['print'], paid: paid, repeat_date: params['ad']['repeat_date'])
              save_success_helper(ad)
            else
              error_helper
            end
          end

          app.get '/delete/ad/:id' do
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

          app.get '/view/ad/:id' do
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

          #ajax request routes in view_ads.erb
          app.get '/ad/completed/:id' do
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

          app.get '/ad/place/:id' do
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

          #I don't know if this route is called from anywhere...
          app.get '/ad/status/:id' do
            ad = Ad.get params['id']
            if ad.placed == true
              return true
            else
              return false
            end
          end

          #get calculated price for an ad
          app.get '/quote' do
            env['warden'].authenticate!
            @title = "Quote calculator"
            @features = Feature.all(:paper_id => env['warden'].user.paper_id)
            erb :quote
          end

          app.post '/quote' do
            feature = Feature.get params['quote']['feature']
            quote = params['quote']['height'].to_f * params['quote']['columns'].to_f * feature.rate
            flash[:notice] = "$#{quote}"
            redirect back
          end

        #end of self.registered
        end

      end
    end
  end
end
