require 'rubygems'
require 'nokogiri'
require 'htmlentities'
require 'net/https'

class Adsense

  SANDBOX_HOST = "sandbox.google.com"
  PRODUCTION_HOST = "www.google.com"
  HOST_PORT = 443

  ENDPOINTS = {
    :create_account => {:path => "/api/adsense/v3/AccountService", :g_name => "createAccount"},
    :associate_account => {:path => "/api/adsense/v3/AccountService", :g_name => "associateAccount"},
    :get_approval_status => {:path => "/api/adsense/v3/AccountService", :g_name => "getApprovalStatus"},
    :get_association_status => {:path => "/api/adsense/v3/AccountService", :g_name => "getAssociationStatus"},
    :generate_ad_code => {:path => "/api/adsense/v3/AdSenseForContentService", :g_name => "generateAdCode"} 
  }
  
  AD_TYPE_UNITS = %w(TextOnly ImageOnly TextAndImage FourLinkUnit FiveLinkUnit)
  AD_LAYOUTS = %w(28x90 468x60 300x250 160x600 120x600 336x280 250x250 234x60 180x150 200x200 125x125 120x240 728x15 468x15 200x90 180x90 160x90 120x90)
  CORNER_STYLES = %w(DEFAULT SQUARE_CORNERS SLIGHTLY_ROUNDED_CORNERS VERY_ROUNDED_CORNERS)
  
  attr_accessor :client_id
  
  InvalidLayoutType = Class.new(StandardError)
  MissingClientId   = Class.new(StandardError)
  
  def initialize(options = {})
    @developer_url = options[:developer_url]
    @soap_headers  = options[:soap_headers]
    @client_id     = options[:client_id]
    
    @host = options[:sandbox] ? SANDBOX_HOST : PRODUCTION_HOST 
    @port = HOST_PORT    
  end
  
  def create_account(login_email, entity_type, options = {})
    options = {
      :login_email => login_email,
      :entity_type => entity_type,
      :website_url => "posterous.com",
      :website_locale => "en",
      :users_preferred_locale => "en_US",
      :email_promotions_preference => "true",
      :syn_service_types => "ContentAds",
      :developer_url => @developer_url
    }.merge( options )

    resp = call(:create_account, options)
  end

  def associate_account( login_email, postal_code = nil, phone = nil, options = {} )
    options = {
      :login_email => login_email, 
      :postal_code => postal_code,
      :phone => phone,
      :developer_url => @developer_url
    }.merge( options )
    
    resp = call(:associate_account, options)
  end

  def get_approval_status( options = {} )
    resp = call(:get_approval_status, options)
  end
  
  def get_association_status( options = {} )
    resp = call(:get_association_status, options)
  end
  
  def generate_ad_code(layout, options = {})
    # ad_style = {}, alternate = nil, is_framed_page = false, channel_name = nil, corner_styles = nil, host_channel_names = [], 

    options = {
      :syn_service_id => @client_id,
      :ad_style => default_ad_style,
      :ad_unit_type => "TextAndImage",
      :layout => layout,
      :alternate => nil,
      :is_framed_page => false,
      :channel_name => nil,
      :corner_styles => "DEFAULT",
      :host_channel_names => []
    }.merge(options)
    
    raise InvalidLayoutType.new("#{options[:layout]} is an invalid layout type") unless AD_LAYOUTS.include?(options[:layout])
    
    resp = call(:generate_ad_code, options)
  end
  
  # Change account association
  # generate ad code
  
  def soap_headers
    @soap_headers ||= {}
    @soap_headers.merge!(:client_id => @client_id) if @client_id
    @soap_headers
  end
  
  def soap_headers=(soap_hdrs)
    @soap_headers = soap_hdrs
    @soap_headers 
  end
  
  private
  
  def default_ad_style
    {
      :backgroundColor => "#FFFFFF",
      :borderColor => "#000000",
      :name => nil,
      :textColor => "#00FF00",
      :titleColor => "#0000CC",
      :urlColor => "#FF3300"
    }
  end
  
  def call( action , options )

    path    = ENDPOINTS[action][:path]
    g_name  = ENDPOINTS[action][:g_name]
    xml     = self.send("#{action}_xml", options)
    http_headers = {"SOAPAction"=>"urn:#{g_name}", "Content-Type" => "text/xml;charset=UTF-8"}

    resp = http.start do |h|
      req = Net::HTTP::Post.new(path, http_headers)
      req.body = xml
      
      h.request req
    end
    
    xml = Nokogiri::XML( resp.body )
    retval = (resp.code != "200") ? parse_error_response(xml) : self.send("parse_#{action}_response", xml)
    
    retval    
  end
  
  def parse_error_response(xml)
    {:faultcode => xml.css('faultcode').inner_html, :faultstring => xml.css('faultstring').inner_html}
  end
  
  def http
    unless @http
      @http = Net::HTTP.new(@host, @port)
      @http.use_ssl = true
    end
    
    @http
  end  
    
  def create_envelope_xml(&block)
    envelope_attribs = {
      "SOAP-ENV:encodingStyle" => "http://schemas.xmlsoap.org/soap/encoding/",
      "xmlns:SOAP-ENC" => "http://schemas.xmlsoap.org/soap/encoding/",
      "xmlns:xsi" => "http://www.w3.org/1999/XMLSchema-instance",
      "xmlns:SOAP-ENV" => "http://schemas.xmlsoap.org/soap/envelope/",
      "xmlns:xsd" => "http://www.w3.org/1999/XMLSchema"
    }
    string_attribs = { "xsi:type" => "xsd:string", "SOAP-ENC:root" => "1"}
    
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.send("SOAP-ENV:Envelope", envelope_attribs) {
        xml.send("SOAP-ENV:Header") {          
          soap_headers.each_pair {|k,v| xml.send(k, v, string_attribs)}
        }
        
        xml.send("SOAP-ENV:Body") {
          yield(xml) if block_given?
        }    
      }
    end
    
    return builder.to_xml.gsub(%Q[<?xml version="1.0"?>], %Q[<?xml version="1.0" encoding="UTF-8"?>])
  end
  
  def create_account_xml( options )
    xml = create_envelope_xml { |xml|      
      xml.send("ns1:createAccount", body_attribs) {
        xml.loginEmail(options[:login_email])
        xml.entityType { xml.value(options[:entity_type], string_type) }
        xml.websiteUrl(options[:website_url])
        xml.websiteLocale(options[:website_locale])
        xml.usersPreferredLocale(options[:users_preferred_locale])
        xml.emailPromotionsPreference(options[:email_promotions_preference])
        xml.synServiceTypes { xml.value(options[:syn_service_types], string_type)}
        xml.developerUrl(options[:developer_url])
      }
    }
    
    xml
  end
  
  def associate_account_xml( options )
    xml = create_envelope_xml { |xml|
      xml.send("ns1:associateAccount", body_attribs) {
        xml.loginEmail(options[:login_email])
        xml.postalCode(options[:postal_code])
        xml.phone(options[:phone], nil_type)
        xml.developerUrl(options[:developer_url])
      }      
    }
    
    xml
  end
  
  def get_approval_status_xml( options )
    xml = create_envelope_xml { |xml|
      xml.send("ns1:getApprovalStatus", body_attribs) {
        xml.dummy(1)
      }
    }
    
    xml
  end
  
  def get_association_status_xml( options )
    xml = create_envelope_xml { |xml|
      xml.send("ns1:getAssociationStatus", body_attribs) {
        xml.dummy(1)
      }
    }
    
    xml
  end
    
  def generate_ad_code_xml( options )
    xml = create_envelope_xml { |xml|
      xml.send("ns1:generateAdCode", body_attribs) {
        xml.synServiceId(@client_id)
        xml.adStyle { 
          xml.name(options[:ad_style].delete(:name), nil_type)
          options[:ad_style].each_pair {|k,v| xml.send(k, v)}
        }
        xml.adUnitType {
          xml.value(options[:ad_unit_type])
        }
        xml.layout { 
          xml.value(options[:layout])
        }
        xml.alternate(options[:alternate], nil_type)
        xml.isFramedPage(options[:is_framed_page].to_s.capitalize)
        xml.channelName(options[:channel_name])
        xml.cornerStyles { 
          xml.value(options[:corner_styles])
        }
      }
    }
    
    xml
  end
    
  def parse_create_account_response(xml)
    {:type => xml.css('return type value').inner_html, :id => xml.css('return id').inner_html}
  end
  
  def parse_associate_account_response( xml )
    {:type => xml.css('return type value').inner_html, :id => xml.css('return id').inner_html}
  end
  
  def parse_get_approval_status_response( xml )
    {:approval_status => xml.css('return value').inner_html}
  end
  
  def parse_get_association_status_response( xml )
    {:association_status => xml.css('return value').inner_html}
  end
  
  def parse_generate_ad_code_response( xml )
    html = xml.css('return').inner_html
    {:html => HTMLEntities.new.decode(html)}
  end
  
  def body_attribs
    { "xmlns:ns1" => "http://www.google.com/api/adsense/v3", "SOAP-ENC:root" => "1"}
  end
  
  def string_type
    { "xsi:type" => "xsd:string" }
  end
  
  def nil_type
    {"xsi:nil" => "1"}
  end
end