source 'https://rubygems.org'

gem 'sinatra'
gem 'sinatra-flash'
gem 'bcrypt-ruby'
gem 'data_mapper'
gem 'warden'
gem 'chartkick'

group :production do
  gem 'pg'
  gem 'dm-postgres-adapter'
end
group :development, :test do

  gem 'shotgun'
  gem 'tux'

  gem 'dm-sqlite-adapter'
end
