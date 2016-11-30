
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/ezrads.sqlite")

class User
  include DataMapper::Resource

  property :created_at, DateTime
  property :id, Serial, :key => true
  property :username, String, :length => 3..50
  property :role, Integer #1 admin, 2 sales, 3 production, 4 accounts
  property :publication, Integer #1 all, 2 Blenheim Sun, 3 Wellington?
  property :phone, String
  property :email, String
  property :password, BCryptHash

  has n, :ads
  belongs_to :paper

  def authenticate(attempted_password)
    if self.password == attempted_password
      true
    else
      false
    end
  end
end

class Customer
  include DataMapper::Resource

  property :id, Serial, :key => true
  property :created_at, DateTime
  property :contact_name, String
  property :alt_contact_name, String, :length => 100
  property :business_name, String, :length => 100
  property :billing_address, String, :length => 100
  property :address_line2, String, :length => 100
  property :address_line3, String, :length => 100
  property :address_text, Text
  property :phone, String
  property :alt_contact_phone, String, :length => 100
  property :mobile, String
  property :email, String
  property :custom_rate, Float, :default => 0
  property :notes, Text
  property :banned, Boolean
  property :booking_order, Boolean

  has n, :ads
  belongs_to :paper
end

class Ad
  include DataMapper::Resource

  property :id, Serial, :key => true
  property :created_at, DateTime
  property :updated_at, DateTime
  property :updated_by, Integer
  property :repeat_date, DateTime
  property :height, Integer
  property :columns, Integer
  property :position, String
  property :price, Float
  property :completed, Boolean
  property :placed, Boolean
  property :note, Text
  property :payment, Integer # 1 = account, 2 = cash, 3 = eftpos, 4 = direct credit
  property :paid, Boolean
  property :receipt, String
  property :print_only, String

  belongs_to :user
  belongs_to :customer
  belongs_to :publication
  belongs_to :feature
end

class Task
  include DataMapper::Resource

  property :id, Serial, :key => true
  property :created_at, DateTime
  property :created_by, Integer
  property :deadline, DateTime
  property :title, String
  property :priority, Integer
  property :completed, Boolean
  property :body, Text

  belongs_to :user
end

class Publication
  include DataMapper::Resource

  property :id, Serial, :key => true
  property :name, String
  property :publication_id, Integer
  property :date, Date

  has n, :ads
  belongs_to :paper
end

class Feature
  include DataMapper::Resource

  property :id, Serial, :key => true
  property :name, String
  property :rate, Float
  property :type, Integer #1: ROP 2: Run on 3:Class 4: Stand alone
  property :rop, Boolean

  belongs_to :paper
  has n, :ads
end

class Paper
  include DataMapper::Resource

  property :id, Serial, :key => true
  property :name, String
  property :gst, Float

  has n, :publications
  has n, :features
  has n, :users
end

class Motd
  include DataMapper::Resource

  property :id, Serial, :key => true
  property :message, Text
  property :enabled, Boolean

  belongs_to :paper
end

DataMapper.finalize
DataMapper.auto_upgrade!
