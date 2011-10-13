require 'rubygems'
$TESTING=true
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'adsense'

DEVELOPER_EMAIL    = "adsensedeveloper1@google.com"
DEVELOPER_PASSWORD = "Q6R3l6a483"

def rand_email
  rand_num = sprintf("%05d", (rand*100000).to_i)  
  "random_email_#{rand_num}@random.com"
end

def rand_zip
  sprintf("%05d", (rand*100000).to_i)
end

def rand_phone
  rand_num = sprintf("%04d", rand*10000.to_i)
  "415555#{rand_num}"
end
