Paper.new(id: 1, name: 'TestPaper', gst: 15).save
Publication.new(id: 1, name: 'TestPublication', date: Date.today + 1, paper_id: 1).save
Publication.new(id: 2, name: 'TestPublication', date: Date.today + 8, paper_id: 1).save
Feature.new(id: 1, name: 'TestFeature', rate: 7.5, type: 1, rop: true, paper_id: 1 ).save
Customer.new(
  id: 1,
  contact_name: 'Test Customer',
  business_name: 'Test Customer',
  paper_id: 1,
  banned: false
).save
Ad.new(
  height: 10,
  columns: 2,
  payment: 1,
  price: 100.2,
  user_id: 1,
  customer_id: 1,
  publication_id: 1,
  feature_id: 1,
  completed: false,
  placed: false
).save
User.new(
  username: 'test',
  password: 'test',
  role: 1,
  paper_id: 1
).save
