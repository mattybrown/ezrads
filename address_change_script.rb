c = Customer.all
c.each do |c|
  c.address_text = c.billing_address
  if c.address_line2
    c.address_text += c.address_line2
  end
  if c.address_line3
    c.address_text += c.address_line3
  end
  c.save
end
