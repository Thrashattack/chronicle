DatomicCustomer.find_or_create_by!(email: "ada@example.test") do |customer|
  customer.name = "Ada Lovelace"
end
