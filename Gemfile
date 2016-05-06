source 'https://rubygems.org'

gem 'sinatra'
gem 'sinatra-flash'
gem 'bcrypt-ruby'
gem 'data_mapper'

group :production do
  gem 'dm-postgres-adapter'
end
group :development, :test do
  gem 'warden'
  gem 'shotgun'
  gem 'tux'

  gem 'dm-sqlite-adapter'
end
