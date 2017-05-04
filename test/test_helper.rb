ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/pride'
require 'rack/test'
require_relative '../app'

include Rack::Test::Methods
include Warden::Test::Helpers

def app
  EzrAds
end

after { Warden.test_reset! }
