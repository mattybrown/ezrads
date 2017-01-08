module Sinatra
  module EzrAds
    module Routing
      module Features

        def self.registered(app)

          app.get '/create/feature' do
            env['warden'].authenticate!
            @title = "Create feature"
            erb :create_feature
          end

          app.post '/create/feature' do
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

          app.get '/view/features' do
            env['warden'].authenticate!

            @title = "Features"
            @features = Feature.all(paper_id: env['warden'].user.paper_id)

            erb :view_features
          end

          app.get '/edit/feature/:id' do
            env['warden'].authenticate!

            @feature = Feature.get params['id']
            @title = "Editing feature #{@feature.name}"

            erb :edit_feature
          end

          app.post '/edit/feature/:id' do
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

          app.get '/delete/feature/:id' do
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

        #end of self.registered
        end

      end
    end
  end
end
