require "json"
require "net/https"
require "openssl"
require "time"
require "uri"

require "gatling_gun/api_call"
require "gatling_gun/response"

class GatlingGun
  VERSION = "0.0.4"
  
  def initialize(api_user, api_key)
    @api_user = api_user
    @api_key  = api_key
  end
  
  ###################
  ### Newsletters ###
  ###################
  
  def add_newsletter(newsletter, details)
    fail ArgumentError, "details must be a Hash" unless details.is_a? Hash
    %w[identity subject].each do |field|
      unless details[field.to_sym] or details[field]
        fail ArgumentError, "#{field} is a required detail"
      end
    end
    unless details[:text] or details["text"] or
           details[:html] or details["html"]
      fail ArgumentError, "either text or html must be provided as a detail"
    end
    make_newsletter_api_call("add", details.merge(:name => newsletter))
  end

  def edit_newsletter(newsletter, details)
    fail ArgumentError, "details must be a Hash"  unless details.is_a? Hash
    fail ArgumentError, "details cannot be empty" if     details.empty?
    make_newsletter_api_call("edit", details.merge(:name => newsletter))
  end

  def get_newsletter(newsletter)
    make_newsletter_api_call("get", :name => newsletter)
  end

  def list_newsletters(newsletter = nil)
    parameters        = { }
    parameters[:name] = newsletter if newsletter
    make_newsletter_api_call("list", parameters)
  end
  
  def delete_newsletter(newsletter)
    make_newsletter_api_call("delete", :name => newsletter)
  end

  CLONED_FIELDS = ['identity', 'subject', 'text', 'html']
  def clone_newsletter(newsletter, dest_name)
    response = get_newsletter(newsletter)
    return response unless response.success?

    details = {}
    CLONED_FIELDS.each {|f| details[f] = response[f] if response[f].present?}
    add_newsletter(dest_name, details)
  end
  
  ##################
  ### Categories ###
  ##################
  
  def create_category(category)
    fail ArgumentError, "category cannot be empty" if category.empty?
    make_newsletter_api_call("category/create", {:category => category})
  end

  def add_category(newsletter, category)
    fail ArgumentError, "category cannot be empty" if category.empty?
    fail ArgumentError, "newsletter cannot be empty" if newsletter.empty?
    make_newsletter_api_call("category/add", {:category => category, :name => newsletter})
  end
  
  def remove_category(newsletter, category = nil)
    fail ArgumentError, "newsletter cannot be empty" if newsletter.empty?
    make_newsletter_api_call("category/remove", {:category => category, :name => newsletter})
  end
  
  def get_categories(category = nil)
    parameters        = { }
    parameters[:category] = category if category
    make_newsletter_api_call("category/list", parameters)
  end
  alias_method :list_categories, :get_categories
  
  #############
  ### Lists ###
  #############
  
  def add_list(list, details = { })
    fail ArgumentError, "details must be a Hash" unless details.is_a? Hash
    make_newsletter_api_call("lists/add", details.merge(:list => list))
  end
  
  def edit_list(list, details = { })
    fail ArgumentError, "details must be a Hash"  unless details.is_a? Hash
    fail ArgumentError, "details cannot be empty" if     details.empty?
    make_newsletter_api_call("lists/edit", details.merge(:list => list))
  end
  
  def get_list(list = nil)
    parameters        = { }
    parameters[:list] = list if list
    make_newsletter_api_call("lists/get", parameters)
  end
  alias_method :list_lists, :get_list
  
  def delete_list(list)
    make_newsletter_api_call("lists/delete", :list => list)
  end
  
  ##############
  ### Emails ###
  ##############
  
  def add_email(list, data)
    json_data = case data
                when Hash  then data.to_json
                when Array then data.map(&:to_json)
                else            fail ArgumentError,
                                     "details must be a Hash or Array"
                end
    make_newsletter_api_call("lists/email/add", :list => list, :data => json_data)
  end
  alias_method :add_emails, :add_email
  
  def get_email(list, emails = nil)
    parameters         = {:list => list}
    parameters[:email] = emails if emails
    make_newsletter_api_call("lists/email/get", parameters)
  end
  alias_method :get_emails,  :get_email
  alias_method :list_emails, :get_email
  
  def delete_email(list, emails)
    make_newsletter_api_call("lists/email/delete", :list => list, :email => emails)
  end
  alias_method :delete_emails, :delete_email
  
  ################
  ### Identity ###
  ################
  
  def add_identity(identity, details)
    fail ArgumentError, "details must be a Hash" unless details.is_a? Hash
    %w[name email address city state zip country].each do |field|
      unless details[field.to_sym] or details[field]
        fail ArgumentError, "#{field} is a required detail"
      end
    end
    make_newsletter_api_call("identity/add", details.merge(:identity => identity))
  end
  
  def edit_identity(identity, details)
    fail ArgumentError, "details must be a Hash"  unless details.is_a? Hash
    fail ArgumentError, "details cannot be empty" if     details.empty?
    make_newsletter_api_call("identity/edit", details.merge(:identity => identity))
  end
  
  def get_identity(identity)
    make_newsletter_api_call("identity/get", :identity => identity)
  end
  
  def list_identities(identity = nil)
    parameters            = { }
    parameters[:identity] = identity if identity
    make_newsletter_api_call("identity/list", parameters)
  end
  
  def delete_identity(identity)
    make_newsletter_api_call("identity/delete", :identity => identity)
  end
  
  ##################
  ### Recipients ###
  ##################
  
  def add_recipient(newsletter, list)
    make_newsletter_api_call("recipients/add", :name => newsletter, :list => list)
  end
  alias_method :add_recipients, :add_recipient

  def get_recipient(newsletter)
    make_newsletter_api_call("recipients/get", :name => newsletter)
  end
  alias_method :get_recipients,  :get_recipient
  alias_method :list_recipients, :get_recipient
  
  def delete_recipient(newsletter, list)
    make_newsletter_api_call("recipients/delete", :name => newsletter, :list => list)
  end
  alias_method :delete_recipients, :delete_recipient
  
  #################
  ### Schedules ###
  #################
  
  def add_schedule(newsletter, details = { })
    parameters      = {:after => details[:after]}
    parameters[:at] = details[:at].iso8601.sub("T", " ") \
      if details[:at].respond_to? :iso8601
    if not details[:after].nil? and ( not details[:after].is_a?(Integer) or 
                                      details[:after] < 1 )
      fail ArgumentError, "after must be a positive integer"
    end
    make_newsletter_api_call("schedule/add", parameters.merge(:name =>  newsletter))
  end
  
  def get_schedule(newsletter)
    make_newsletter_api_call("schedule/get", :name => newsletter)
  end
  
  def delete_schedule(newsletter)
    make_newsletter_api_call("schedule/delete", :name => newsletter)
  end

  ####################
  ### Unsubscribes ###
  ####################
  
  def add_unsubscribe(email)
    make_api_call("unsubscribese/add", {:email => email})
  end
  
  def delete_unsubscribe(details)
    raise "Use the parameter :all to delete all." unless details == :all || (details.is_a?(Hash) && (details['email'] || details['start_date'] || details['end_date']))
    details = {} if details == :all                                                                         
    make_api_call("unsubscribes/delete", details)
  end
  
  def get_unsubscribe(details = {})
    make_api_call("unsubscribes/get", details)
  end
  
  #######
  private
  #######

  def make_newsletter_api_call(action, parameters = { })
    make_api_call("newsletter/#{action}", parameters)
  end

  def make_api_call(action, parameters = { })
    response = ApiCall.new(action, parameters.merge( :api_user => @api_user,
                                                      :api_key =>  @api_key ) ).response

    Rails.logger.info "SendGrid: Action:#{action}, Parameters: #{parameters}, Response: #{response}"
    response
  end  
end
