module Sinatra
  module EzrAds
    module Routing
      module Customers

        def self.registered(app)

          app.get '/view/customers' do
            env['warden'].authenticate!
            @customers = Customer.paginate(:page => params[:page], :per_page => 30, :order => (:business_name.asc))
            @title = "Customers"

            erb :view_customers
          end

          app.get '/view/customer/:id' do
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

          app.get '/create/customer' do
            env['warden'].authenticate!
            @title = "Create customer"
            erb :create_customer
          end

          app.post '/create/customer' do
            if Customer.all(business_name: params['customer']['business_name']).length > 0
              flash[:error] = "There is an existing record with this business name"
              redirect back
            end
            if params['customer']['booking_order'] == 'on'
              booking_order = true
            else
              booking_order = false
            end

            if params['customer']['custom_rate'] == ""
              customer = Customer.new(created_at: Time.now, contact_name: params['customer']['contact_name'], business_name: params['customer']['business_name'], address_text: params['customer']['address_text'], address_text2: params['customer']['address_text2'], phone: params['customer']['phone'], mobile: params['customer']['mobile'], email: params['customer']['email'], custom_rate: '0', paper_id: env['warden'].user.paper_id, alt_contact_name: params['customer']['alt_contact_name'], alt_contact_phone: params['customer']['alt_contact_phone'], notes: params['customer']['notes'], banned: false, booking_order: booking_order)
            else
              customer = Customer.new(created_at: Time.now, contact_name: params['customer']['contact_name'], business_name: params['customer']['business_name'], address_text: params['customer']['address_text'], address_text2: params['customer']['address_text2'], phone: params['customer']['phone'], mobile: params['customer']['mobile'], email: params['customer']['email'], custom_rate: params['customer']['custom_rate'], paper_id: env['warden'].user.paper_id, alt_contact_name: params['customer']['alt_contact_name'], alt_contact_phone: params['customer']['alt_contact_phone'], notes: params['customer']['notes'], banned: false, booking_order: booking_order)
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

          app.get '/edit/customer/:id' do
            env['warden'].authenticate!
            @customer = Customer.get params['id']
            @title = "Edit customer"

            erb :edit_customer
          end

          app.post '/edit/customer/:id' do
            customer = Customer.get params['id']
            if params['customer']['banned'] == 'on'
              banned = true
            else
              banned = false
            end
            if params['customer']['booking_order'] == 'on'
              booking_order = true
            else
              booking_order = false
            end
            if customer.update(contact_name: params['customer']['contact_name'], business_name: params['customer']['business_name'], address_text: params['customer']['address_text'], address_text2: params['customer']['address_text2'], phone: params['customer']['phone'], mobile: params['customer']['mobile'], email: params['customer']['email'], custom_rate: params['customer']['custom_rate'], notes: params['customer']['notes'], banned: banned, booking_order: booking_order)
              flash[:success] = "Customer <a href='/view/customer/#{customer.id}'>#{customer.id}</a> updated"
              redirect '/view/customers'
            else
              customer.errors.each do |e|
                flash[:error] = "Update failed - #{e}}"
              end
              redirect back
            end
          end

          app.post '/delete/customer/:id' do
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

        #end of self.registered
        end

      end
    end
  end
end
