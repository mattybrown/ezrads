module Sinatra
  module EzrAds
    module Routing
      module Tasks

        def self.registered(app)

          app.get '/view/task/:id' do
            env['warden'].authenticate!
            @task = Task.get params['id']
            @title = @task.title

            erb :view_task
          end

          app.get '/view/tasks/complete' do
            env['warden'].authenticate!
            @tasks = Task.all(:user_id => env['warden'].user.id, :order => [:created_at.desc], :completed => true)
            @title = "Completed tasks"

            erb :view_tasks
          end

          app.get '/view/tasks/sent' do
            env['warden'].authenticate!
            @tasks = Task.all(created_by: env['warden'].user.id, order: [:created_at.desc])
            @title = 'Sent tasks'

            erb :view_tasks
          end

          app.get '/task/completed/:id' do
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

          app.get '/task/incomplete/:id' do
            t = Task.get params['id']
            t.completed = false
            if t.save
              flash[:success] = "Ad marked as incomplete"
              redirect back
            else
              flash[:error] = "Something went wrong"
              redirect back
            end
          end

          app.get '/create/task' do
            env['warden'].authenticate!
            @title = "Create task"
            @users = User.all

            erb :create_task
          end

          app.get '/create/task/:id' do
            env['warden'].authenticate!
            @title = "Create task"
            @users = User.all
            @task_ad = "/view/ad/#{params['id']}"

            erb :create_task
          end

          app.get '/task/reply/:user/:title' do
            env['warden'].authenticate!
            @title = "Reply"
            @tasktitle = "Re: " + params[:title].gsub(/-/, ' ')
            @user = params[:user]
            @users = User.all

            erb :create_task
          end

          app.post '/create/task' do
            uid = env['warden'].user.id
            title = params['task']['title']
            title.gsub!(/\s/, '-')
            t = Task.new(
                title: params['task']['title'],
                created_by: uid,
                created_at: Time.now,
                deadline: params['task']['deadline'],
                user_id: params['task']['user_id'],
                priority: params['task']['priority'],
                body: params['task']['body'],
                completed: false
            )

            if t.save
              flash[:success] = "Task successfully created..."
              redirect back
            else
              flash[:error] = "Something went wrong.. #{t.errors.inspect}"
              redirect back
            end
          end

        #end of self.registered
        end

      end
    end
  end
end
