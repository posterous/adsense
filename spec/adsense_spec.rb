require File.dirname(__FILE__) + '/spec_helper'

## These specs corresond to the "Technical Requirements spelled out here"
## http://code.google.com/apis/adsense/review_tech.html
describe Adsense do 
  before(:each) do
    @email = rand_email
    @zip_code = rand_zip
    @phone = rand_phone
    
    @soap_headers = {
      :developer_email => DEVELOPER_EMAIL,
      :developer_password => DEVELOPER_PASSWORD,
      :debug_zip => @zip_code,
      :debug_phone => @phone      
    }
    
    @adsense = Adsense.new(
      :soap_headers => @soap_headers, 
      :developer_url => "code.google.com", 
      :sandbox => true
    )
  end

  describe "Account Creation" do
    it "Your implementation must be able to create new Google AdSense accounts" do
      retval = @adsense.create_account(@email, "Business")

      retval[:type].should == "ContentAds"
      retval[:id].should match /ca-pub-\d+/
    end
    
    it "Your implementation must also be able to handle the case where a user tries to create an existing Google AdSense account" do
      @adsense.create_account(@email, "Business")
      retval = @adsense.create_account(@email, "Business")
      
      retval[:faultcode].should == "soapenv:Server.userException"
      retval[:faultstring].should == "The specified email address is already in use."
    end    
  end
  
  describe "Polling for Association / Approval Status" do
    before(:each) do
      @adsense.soap_headers.merge!(:debug_association_type => "Active")
      @create_response = @adsense.create_account(@email, "Business")
      @adsense.client_id = @create_response[:id]
    end
    
    it "should allow you to poll association status" do
      @adsense.get_association_status.should ==  {:association_status=>"Active"}
    end

    it "should allow you to poll approval status" do
      @adsense.get_approval_status.should ==  {:approval_status=>"Pending_Email_Verification"}
    end
  end
  
  describe "Account Association" do
    before(:each) do
      @create_response = @adsense.create_account(@email, "Business")
    end    
    
    it "Your implementation must be able to associate with existing Google AdSense accounts - with phone" do
      @adsense.associate_account(@email, nil, @phone[-5..-1]).should == @create_response
    end
    
    it "Your implementation must be able to associate with existing Google AdSense accounts - with zipcode" do
      @adsense.associate_account(@email, @zip_code, nil).should == @create_response
    end    

    it "Your implementation must be able to associate with existing Google AdSense accounts - with phone/zipcode" do
      @adsense.associate_account(@email, @zip_code, @phone[-5..-1]).should == @create_response
    end    
    
    it "Your software must be able to handle the case where the user tries to associate an account that does not exist" do
      @adsense.associate_account("bad_email@bad.com", "02138", nil).should == {:faultcode=>"soapenv:Server.userException", :faultstring=>"The specified email address does not correspond to an AdSense account."}
    end
    
    it "Your application must be able to handle the case where the user tries to associate an account but provides the wrong phone and postal code verifications" do
      @adsense.associate_account(@email, "55555", nil).should == {:faultcode=>"soapenv:Server.userException", :faultstring=>"The account corresponding to the specified client email address does not match with the provided zipcode or telephone number."}
    end
  end
  
  describe "Implementation of Ad Code" do
    
    before(:each) do
      @create_response = @adsense.create_account(@email, "Business")
      @association_resposne = @adsense.associate_account(@email, @zip_code, nil)
      @adsense.client_id = @create_response[:id]
    end
    
    it "should not allow you to create an ad layout that doesn't exist" do
      lambda {
        @adsense.generate_ad_code("bad_widthxbad_height")
      }.should raise_error(Adsense::InvalidLayoutType)      
    end
    
    it "Each unique snippet of ad code must be obtained from a call to an ad code generation method" do
      @adsense.generate_ad_code("300x250")[:html].should match /pagead2\.googlesyndication\.com\/pagead\/show_ads\.js/
    end    
  end
end
