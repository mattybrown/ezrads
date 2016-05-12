
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
  property :business_name, String
  property :billing_address, String
  property :phone, String
  property :mobile, String
  property :email, String

  has n, :ads
end

class Ad
  include DataMapper::Resource

  property :id, Serial, :key => true
  property :created_at, DateTime
  property :updated_at, DateTime
  property :updated_by, Integer
  property :publication_date, Date
  property :publication, Integer
  property :size, String
  property :position, String
  property :price, Float
  property :completed, Boolean
  property :placed, Boolean
  property :note, Text

  belongs_to :user
  belongs_to :customer
  belongs_to :publication
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
  property :date, Date

  has n, :ads
end


DataMapper.finalize
DataMapper.auto_upgrade!
