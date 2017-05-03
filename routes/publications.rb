module Sinatra
  module EzrAds
    module Routing
      # Publications route
      module Publications
        def self.registered(app)
          app.get '/' do
            env['warden'].authenticate!
            today = Date.today
            user_publication = env['warden'].user.paper[:id]
            @role = env['warden'].user[:role]
            @title = 'Home'

            paper = Paper.all(id: user_publication)

            pub = paper.publications(:date.gt => today) & paper.publications(order: [:date.desc])
            if pub.count > 1
              if @publications = paper.publications.count >= 1
                @publications = paper.publications(order: [:date.asc])
                @ads = pub.last.ads
                @pub = pub.last
              else
                @pub = "No publications found
                        <a href='/create/publication'>
                          Click here to create one
                        </a>"
              end

              @features = @ads.features

              @gross = 0
              @count = 0
              if @ads.class != String
                @ads.each do |a|
                  @gross += a.price
                  @count += 1
                end
              end
              erb :view_ads
            else
              @title = 'Create publication'
              @papers = Paper.all
              erb :create_publication
            end
          end

         app.get '/view/publication/:pub/:feat' do
            env['warden'].authenticate!
            user_publication = env['warden'].user.paper[:id]
            @role = env['warden'].user[:role]
            @title = 'Home'
            # THIS NEEDS TO BE FIXED TO SHOW THE CORRECT ADS DEPENDING ON TYPE
            paper = Paper.all(id: user_publication)
            pub = paper.publications.get params['pub']
            if params['feat'] == 'rop'
              @feature = 'ROP'
              feature = paper.features(type: 1)
            elsif params['feat'] == 'classie'
              @feature = 'Classified'
              feature = paper.features(type: 2) + paper.features(type: 3)
            elsif params['feat'] == 'ads'
              @feature = 'All Ads'
              feature = paper.features
            end

            if paper.publications.count >= 1
              @publications = paper.publications(order: [:date.asc])
              @pub = pub
              @ads = feature.ads(publication_id: pub.id)
            else
              @pub = "No publications found -
                      <a href='/create/publication'>
                      Click here to create one
                      </a>"
            end

            @gross = 0
            @count = 0
            @paid = 0
            if @ads.class != String
              @ads.each do |a|
                @gross += a.price
                @count += 1
                a.paid == true && a.payment != 1 ? @paid += a.price : ''
              end
            end

            erb :view_publication_feature
          end

          app.get '/view/publication/:pub/feature/:id' do
            env['warden'].authenticate!
            user_publication = env['warden'].user.paper[:id]
            @role = env['warden'].user[:role]
            feature = Feature.get(params['id'])

            @feature = feature.name
            @title = 'Home'
            paper = Paper.all(id: user_publication)
            pub = paper.publications.get params[:pub]

            if @publications = paper.publications.count >= 1
              @publications = paper.publications(order: [:date.asc])
              @pub = pub
              @ads = Ad.all(publication_id: @pub.id, feature_id: params['id'])
            else
              @pub = "No publications found - <a href='/create/publication'>Click here to create one</a>"
            end

            @gross = 0
            @count = 0
            @paid = 0
            if @ads.class != String
              @ads.each do |a|
                @gross += a.price
                @count += 1
                a.paid ? @paid += a.price : ''
              end
            end

            erb :view_publication_feature
          end

          app.get '/ads/publication/' do
            env['warden'].authenticate!
            user = env['warden'].user
            user_paper = user.paper_id
            @role = user.role
            @title = 'Ezrads'

            paper = Paper.all(id: user_paper)
            pub = paper.publications(id: params['view']['publication'])

            @publications = paper.publications(order: [:date.asc])
            @ads = pub.ads
            @features = @ads.features
            @gross = 0
            @count = 0
            @ads.each do |a|
              @gross += a.price
              @count += 1
            end

            @pub = pub.last
            erb :view_ads
          end

          app.get '/view/publications' do
            env['warden'].authenticate!
            if env['warden'].user.role == 1 || env['warden'].user.role == 4
              @title = 'Publications'
              user_pub = env['warden'].user.paper_id
              @publications = Publication.all(paper_id: user_pub, order: [:date.asc])
              @ads_booked = {}
              @ads_gross = {}

              @publications.each do |p|
                total = 0
                @ads_booked[p.date] = p.ads.count
                p.ads.each do |a|
                  total += a.price
                end
                @ads_gross[p.date] = total
              end

              erb :view_publications
            else
              flash[:error] = 'You do not have permission to view this page'
              redirect back
            end
          end

          app.get '/view/publication/:id' do
            env['warden'].authenticate!
            if env['warden'].user.role == 1 || env['warden'].user.role == 4
              if Publication.get(params['id'])
                @publication = Publication.get(params['id'])
                @title = "Viewing publication #{@publication.name} - #{display_date(@publication.date)}"
                @ads = @publication.ads
                @account = 0
                @cash = 0
                @eftpos = 0
                @direct_credit = 0
                @cheque = 0
                @paid = 0
                @unpaid = 0
                @unpaid_total = 0
                # Ad payment totals
                @publication.ads.map { |i| i.payment == 1 ? @account += i.price : nil }
                @publication.ads.map { |i| i.payment == 2 ? @cash += i.price : nil }
                @publication.ads.map { |i| i.payment == 3 ? @eftpos += i.price : nil }
                @publication.ads.map { |i| i.payment == 4 ? @direct_credit += i.price : nil }
                @publication.ads.map { |i| i.payment == 5 ? @cheque += i.price : nil }
                @publication.ads.map { |i| i.payment ? @paid += i.price : @unpaid_total += a.price && @unpaid += 1 }

                @pub_data = {}
                past_publications = Publication.all(
                  :date.lt => @publication.date,
                  :order => [:date.desc],
                  :limit => 4,
                  :paper_id => env['warden'].user.paper_id
                )
                past_publications += Publication.all(
                  :date.gte => @publication.date,
                  :order => [:date.asc],
                  :limit => 9,
                  :paper_id => env['warden'].user.paper_id
                )
                past_publications.each do |p|
                  total = 0
                  p.ads.map { |i| total += i.price }
                  @pub_data.update(display_date(p.date) => total)
                end

                @gst = (@paid + @unpaid_total) * @publication.paper.gst / 100.0

                u = User.all
                @repdata = {}
                u.each do |u|
                  total = 0
                  @publication.ads.map { |i| i.user_id == u.id ? total += i.price : nil }
                  @repdata.update(u.username.capitalize => total)
                end

                @features = @publication.ads.feature
                @feat_data = {}
                @feat_total = 0
                @rop_total = 0
                @clas_total = 0
                @other_total = 0

                @publication.ads.map { |i| i.feature.type == 1 ? @rop_total += i.price : 0 }
                @publication.ads.map { |i| i.feature.type == 2 || i.feature.type == 3 ? @clas_total += i.price : 0 }
                @publication.ads.map { |i| i.feature.type == 4 ? @other_total += i.price : 0 }

                @rop_data = []
                @clas_data = []
                @other_data = []
                @publication.ads.features.each do |f|
                  z = [f.name] << @publication.ads.map { |x| x.feature_id == f.id && x.feature.type == 1 ? x.price : 0 }.inject(:+)
                  @rop_data << z
                end
                @publication.ads.features.each do |f|
                  z = [f.name] << @publication.ads.map { |x| x.feature_id == f.id && (x.feature.type == 2 || x.feature.type == 3) ? x.price : 0 }.inject(:+)
                  @clas_data << z
                end
                @publication.ads.features.each do |f|
                  z = [f.name] << @publication.ads.map { |x| x.feature_id == f.id && x.feature.type == 4 ? x.price : 0 }.inject(:+)
                  @other_data << z
                end

                @feat_data.update(
                  'ROP' => @rop_total,
                  'Classified' => @clas_total,
                  'Other' => @other_total
                )

                erb :view_publication
              else
                flash[:error] = "Couldn't find that publication..."
                redirect back
              end
            else
              flash[:error] = 'You do not have permission to view this page'
              redirect back
            end
          end

          app.get '/create/publication' do
            env['warden'].authenticate!
            if env['warden'].user[:role] != 1
              flash[:error] = 'Only Admins can go there'
              redirect back
            end

            @title = 'Create publication'
            @papers = Paper.all

            erb :create_publication
          end

          app.post '/create/single_publication' do
            p = Publication.new(
              name: params['publication']['name'],
              date: params['publication']['date'],
              paper_id: params['publication']['publication_id']
            )
            if p.save
              flash[:success] = 'Successfully created publication'
              redirect '/view/publications'
            else
              flash[:error] = 'Something went wrong'
              redirect back
            end
          end

          app.post '/create/multiple_publications' do
            sd = Date.parse(params['publication']['start_date'])
            ed = Date.parse(params['publication']['end_date'])

            (sd..ed).each do |d|
              if d.wday == sd.wday
                p = Publication.new(
                  name: params['publication']['name'],
                  date: d, paper_id: params['publication']['publication_id']
                )
                if p.save
                  flash[:success] = 'Publications created'
                else
                  p.errors.each do |e|
                    flash[:error] = "Error: #{e}"
                  end
                end
              end
            end
            redirect '/view/publications'
          end

          # end of self.registered
        end
      end
    end
  end
end
