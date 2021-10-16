require "rack/utils"
require "nkf"

require "gmo/const"
require "gmo/errors"
require "gmo/http_services"
require "gmo/shop_api"
require "gmo/site_api"
require "gmo/shop_and_site_api"
require "gmo/remittance_api"
require "gmo/version"

# Ruby client library for the GMO Payment Platform.

module GMO

  module Payment

    class API

      def initialize(options = {})
        @host = options[:host]
      end
      attr_reader :host

      def api(path, args = {}, verb = "post", options = {}, &error_checking_block)
        # Setup args for make_request
        path = "/payment/#{path}" unless path =~ /^\//
        options.merge!({ :host => @host })
        # Make request via the provided service
        result = GMO.make_request path, args, verb, options
        # Check for any 500 server errors before parsing the body
        if result.status >= 500
          error_detail = {
            :http_status => result.status.to_i,
            :body        => result.body,
          }
          raise GMO::Payment::ServerError.new(result.body, error_detail)
        end
        # Transform the body to Hash
        # "ACS=1&ACSUrl=url" => { "ACS" => "1", ACSUrl => "url" }
        key_values = result.body.to_s.split('&').map { |str| str.split('=', 2) }.flatten
        response = Hash[*key_values]
        # converting to UTF-8
        body = response = Hash[response.map { |k,v| [k, NKF.nkf('-w',v)] }]
        # Check for errors if provided a error_checking_block
        yield(body) if error_checking_block
        # Return result
        if options[:http_component]
          result.send options[:http_component]
        else
          body
        end
      end

      def api_recurring_result_file(path, args = {}, verb = "post", options = {}, &error_checking_block)
        # Setup args for make_request
        path = "/payment/#{path}" unless path =~ /^\//
        options.merge!({ :host => @host })
        # Make request via the provided service
        result = GMO.make_request path, args, verb, options
        # Check for any 500 server errors before parsing the body
        if result.status >= 500
          error_detail = {
            :http_status => result.status.to_i,
            :body        => result.body,
          }
          raise GMO::Payment::ServerError.new(result.body, error_detail)
        end
        # Transform the body to Hash
        # "ACS=1&ACSUrl=url" => { "ACS" => "1", ACSUrl => "url" }
        # key_values.split(/,|\r\n/)
        key_values = result.body.to_s.split(/,|\r\n/)
        keys = [
          :shop_id,
          :recurring_id,
          :order_id,
          :charge_date,
          :transaction_status,
          :amount,
          :tax,
          :next_charge_date,
          :access_id,
          :access_pass,
          :acquirer_code,
          :authorization_code,
          :error_code,
          :error_info,
          :confirm_date
        ]
        response = {res: []}
        (key_values.count / keys.count).times do
          row = {}
          keys.map{|key| row["#{key}"] = key_values.shift.delete('"')}
          response[:res] << row
        end

        # converting to UTF-8
        body = response
        # Check for errors if provided a error_checking_block
        yield(body) if error_checking_block
        # Return result
        if options[:http_component]
          result.send options[:http_component]
        else
          body
        end
      end

      # gmo.get_request("EntryTran.idPass", {:foo => "bar"})
      # GET /EntryTran.idPass with params foo=bar
      def get_request(name, args = {}, options = {})
        api_call(name, args, "get", options)
      end
      alias :get! :get_request

      # gmo.post_request("EntryTran.idPass", {:foo => "bar"})
      # POST /EntryTran.idPass with params foo=bar
      def post_request(name, args = {}, options = {})
        args = associate_options_to_gmo_params args
        api_call(name, args, "post", options)
      end
      alias :post! :post_request

      def post_request_recurring_result_file(name, args = {}, options = {})
        args = associate_options_to_gmo_params args
        api_call_recurring_result_file(name, args, "post", options)
      end
      alias :post! :post_request_recurring_result_file

      private

        def assert_required_options(required, options)
          missing = required.select { |param| options[param].nil? }
          raise ArgumentError, "Required #{missing.join(', ')} were not provided." unless missing.empty?
        end

        def associate_options_to_gmo_params(options)
          Hash[options.map { |k, v| [GMO::Const::INPUT_PARAMS[k], v] }]
        end

        def api_call(*args)
          raise "Called abstract method: api_call"
        end

      def api_call_recurring_result_file(*args)
        raise "Called abstract method: api_call_recurring_result_file"
      end

    end

    class ShopAPI < API
      include ShopAPIMethods
    end

    class SiteAPI < API
      include SiteAPIMethods
    end

    class ShopAndSiteAPI < API
      include ShopAndSiteAPIMethods
    end

    class RemittanceAPI < API
      include RemittanceAPIMethods
    end

  end

  # Set up the http service GMO methods used to make requests
  def self.http_service=(service)
    self.send :include, service
  end

  GMO.http_service = NetHTTPService
end
