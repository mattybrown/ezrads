module Sinatra
  module EzrAds
    module Routing
      module Papers

        def self.registered(app)

          app.get '/settings' do
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

          app.post '/setup' do
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

          app.post '/create/paper' do
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

          app.post '/edit/paper' do
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

          app.post '/create/motd' do
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

          #change papers
          app.get '/paper/:id' do
            env['warden'].authenticate!
              @user = User.get env['warden'].user.id
              if @user.update(:paper_id => params['id'])
                flash[:success] = "Changed papers"
                redirect '/'
              else
                flash[:error] = "Something went wrong"
                redirect back
              end
          end

          #end of self registered
        end

      end
    end
  end
end
