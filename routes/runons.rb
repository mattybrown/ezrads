#save_success_helper and error_helper are found in ads.rb
module Sinatra
  module EzrAds
    module Routing
      module Runons

        def self.registered(app)

          app.get '/create/runon' do
            env['warden'].authenticate!
            @customers = Customer.all(:paper_id => env['warden'].user.paper_id)
            @title = "Create ad"
            @users = User.all
            today = Date.today
            @features = Feature.all(:paper_id => env['warden'].user.paper_id, :type => 2)

            @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :date.gt => today, :order => [:date.asc])

            erb :create_runon
          end

          app.post '/create/runon' do
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

            if !params['runon']['user']
              params['runon']['user'] = env['warden'].user.id
            end

            if params['runon']['repeat']
              repeat_publication = Publication.get(params['runon']['publication'].first[0])
              repeat_date = repeat_publication.date

              params['runon']['publication'].each do |p|
                runon = Ad.new(height: words, customer_id: params['runon']['customer'], note: params['runon']['note'], payment: params['runon']['payment'], publication_id: p[0], price: price, user_id: params['runon']['user'], feature_id: params['runon']['feature'], position: params['runon']['position'], paid: paid, receipt: params['runon']['receipt'])
                if runon.save
                  repeat_save_success_helper(runon)
                else
                  error_helper
                end
              end
              redirect '/'
            else
              runon = Ad.new(height: words, customer_id: params['runon']['customer'], note: params['runon']['note'], payment: params['runon']['payment'], publication_id: params['runon']['single-publication'], price: price, user_id: params['runon']['user'], feature_id: params['runon']['feature'], position: params['runon']['position'], paid: paid, receipt: params['runon']['receipt'])
              if runon.save
                save_success_helper(runon)
              else
                error_helper
              end
            end
          end

          app.get '/edit/runon/:id' do
            env['warden'].authenticate!
            @customers = Customer.all(:paper_id => env['warden'].user.paper_id)
            @title = "Edit run on"
            @users = User.all
            today = Date.today
            @features = Feature.all(:paper_id => env['warden'].user.paper_id, :type => 2)

            @publications = Publication.all(:paper_id => env['warden'].user.paper.id, :date.gt => today, :order => [:date.asc])

            @ad = Ad.get params['id']

            erb :edit_runon
          end

          app.post '/edit/runon/:id' do
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

            if !params['runon']['user']
              params['runon']['user'] = env['warden'].user.id
            end

            if params['runon']['repeat']
              repeat_publication = Publication.get(params['runon']['publication'].first[0])
              repeat_date = repeat_publication.date

              params['runon']['publication'].each do |p|
                if ad.update(height: words, customer_id: params['runon']['customer'], note: params['runon']['note'], payment: params['runon']['payment'], publication_id: p[0], price: price, user_id: params['runon']['user'], feature_id: params['runon']['feature'], position: params['runon']['position'], updated_by: updater, paid: paid, receipt: params['runon']['receipt'])
                  flash[:success] = "Run on #{ad.id} updated"
                else
                  flash[:error] = "Something went wrong #{ad.errors.inspect}"
                  redirect back
                end
              end
              redirect '/'
            else
              if ad.update(height: words, customer_id: params['runon']['customer'], note: params['runon']['note'], payment: params['runon']['payment'], publication_id: params['runon']['single-publication'], price: price, user_id: params['runon']['user'], feature_id: params['runon']['feature'], position: params['runon']['position'], updated_by: updater, paid: paid, receipt: params['runon']['receipt'])
                flash[:success] = "Run on #{ad.id} updated"
                redirect '/'
              else
                flash[:error] = "Something went wrong #{ad.errors.inspect}"
                redirect back
              end
            end
          end

        #end of self.registered
        end

      end
    end
  end
end
