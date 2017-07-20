module Sinatra
  module EzrAds
    module Routing
      module Api

        def self.registered(app)

          app.get '/api/ads' do
            cross_origin
            pub = Publication.all(:date.gt => Date.today) & Publication.all(order: [:date.desc])
            ads = pub.last.ads
            ad_arr = []
            ads.each do |a|
              ad_arr << {
                id: a.id,
                customer_id: a.customer.id,
                rep_id: a.user.id,
                rep: a.user.username,
                customer: a.customer.business_name,
                approved: a.completed,
                placed: a.placed,
                position: a.position,
                feature: a.feature.name,
                height: a.height,
                columns: a.columns
              }
            end
            @ads = ad_arr.to_json
          end

        end
      end
    end
  end
end
