module Sinatra
  module EzrAds
    module Helpers
      def self.registered(app)
        app.helpers do
          def format_price(i)
            format '%.2f', i
          end

          def display_role(i)
            role_arr = ['None', 'Admin', 'Sales', 'Production', 'Accounts']
            role_arr[i]
          end

          def display_publication(i)
            pub_arr = ['Other', 'All', 'Blenheim Sun', 'Wellington', 'Publication not found']
            pub_arr[i]
          end

          def display_payment(i)
            payment_arr = ['Other', 'Account', 'Cash', 'Eftpos', 'Direct Credit', 'Cheque']
            payment_arr[i]
          end

          def display_user(i)
            return false if i.blank?
            u = User.get i
            u.username.capitalize
          end

          def display_time(i)
            return false if i.blank?
            i.strftime('%y%m%d %H:%M')
          end

          def display_date(i)
            return false if i.blank?
            i.strftime('%y%m%d')
          end

          def display_task_number
            return false if env['warden'].user.blank?
            uid = env['warden'].user[:id]
            Task.count(:user_id => uid, :completed => false)
          end

          def display_price(h, w, r)
            h * w * r
          end

          def display_papers
            @papers = Paper.all
          end

          def get_feature_id(f)
            k = Feature.all(name: f, paper_id: env['warden'].user.paper_id)[0]
            k.id
          end

          def motd
            if env['warden'].user
              k = Motd.last(paper_id: env['warden'].user.paper_id)
              k.enabled == true ? k.message : false
            else
              false
            end
          end

          def next_issue
            paper = Paper.all(id: env['warden'].user.paper_id)
            pub = paper.publications(:date.gt => Date.today) & paper.publications(order: [:date.desc])
            pub.last
          end

          def save_success_helper(ad)
            flash[:success] = "<a class='blue-text text-darken-4' href='/view/ad/#{ad.id}'>#{ad.id} - #{ad.height}x#{ad.columns} #{ad.customer.business_name}</a> successfully booked"
            session[:ad].clear
            redirect '/'
          end

          def repeat_save_success_helper(ad)
            flash[:success] = "<a class='blue-text text-darken-4' href='/view/ad/#{ad.id}'>#{ad.id} - #{ad.height}x#{ad.columns} #{ad.customer.business_name}</a> successfully booked"
            session[:ad].clear
          end

          def error_helper(ad, custom_error_text)
            custom_error_text ? flash[:error] = "#{ad.errors.inspect} - #{custom_error_text}" : flash[:error] = "#{ad.errors.inspect}"
            redirect back
          end

          def paginate(resources)
            if !resources.next_page.nil? and !resources.previous_page.nil?
              html = "<a href='#{request.path_info}?page=#{resources.previous_page}'> Prev</a> "
              (1..resources.total_pages).each do |p|
                if params[:page].to_i == p
                  html += "<a href='#{request.path_info}?page=#{p}' class='pagination-active'>#{p}</a> "
                else
                  html += "<a href='#{request.path_info}?page=#{p}'>#{p}</a> "
                end
              end
              html += "<a href='#{request.path_info}?page=#{resources.next_page}'>Next </a> "
            elsif !resources.next_page.nil? and resources.previous_page.nil?
              html = "Prev "
              (1..resources.total_pages).each do |p|
                if params[:page].to_i == p
                  html += "<a href='#{request.path_info}?page=#{p}' class='pagination-active'>#{p}</a> "
                else
                  html += "<a href='#{request.path_info}?page=#{p}'>#{p}</a> "
                end
              end
              html += "<a href='#{request.path_info}?page=#{resources.next_page}'>Next </a> "
            elsif resources.next_page.nil? and !resources.previous_page.nil?
              html = "<a href='#{request.path_info}?page=#{resources.previous_page}'> Prev</a> "
              (1..resources.total_pages).each do |p|
                if params[:page].to_i == p
                  html += "<a href='#{request.path_info}?page=#{p}' class='pagination-active'>#{p}</a> "
                else
                  html += "<a href='#{request.path_info}?page=#{p}'>#{p}</a> "
                end
              end
              html += "Next "
            end
            return html
          end

        end
      end
    end
  end
end
