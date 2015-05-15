require File.dirname(__FILE__) + '/authorize_net'

module ActiveMerchant
  module Billing
    class AuthorizeNetCardPresentGateway < AuthorizeNetGateway
      # http://www.authorize.net/support/CP_guide.pdf
      API_VERSION = '1.0'
      
      self.test_url = 'https://test.authorize.net/gateway/transact.dll'
      self.live_url = 'https://cardpresent.authorize.net/gateway/transact.dll'
      self.ssl_version = :TLSv1
      # Only one supported market type
      MARKET_TYPE_RETAIL = 2
      
      # Device types
      DEVICE_TYPES = {
        :unknown => 1,
        :unattended_terminal => 2,
        :self_service_terminal => 3,
        :electronic_cash_register => 4,
        :pc_terminal => 5,
        :airpay => 6,
        :wireless_pos => 7,
        :website => 8,
        :dial_terminal => 9,
        :virtual_terminal => 10,
      }.freeze
      
      # These differ from AuthorizeNetGateway
      RESPONSE_CODE, RESPONSE_REASON_CODE, RESPONSE_REASON_TEXT = 1, 2, 3
      AUTHORIZATION_CODE, AVS_RESULT_CODE, CARD_CODE_RESPONSE_CODE, TRANSACTION_ID = 4, 5, 6, 7
      
      # Captures the funds from an authorized transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured.  Either an Integer value in cents or a Money object.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.
      def capture(money, authorization, options = {})
        post = {:ref_trans_id => authorization}
        add_customer_data(post, options)
        if test? && options[:mock_response] == true
          credit_card = CreditCard.new(:year => "15", :month => "01", :number => "4" + ("2" * 12))
          add_creditcard(post, credit_card)
        end
        commit('PRIOR_AUTH_CAPTURE', money, post)
      end

      # Void a previous transaction
      #
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The authorization returned from the previous authorize request.
      def void(authorization, options = {})
        post = {:ref_trans_id => authorization}
        commit('VOID', nil, post)
      end

      # Credit an account.
      #
      # This transaction is also referred to as a Refund and indicates to the gateway that
      # money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be credited to the customer. Either an Integer value in cents or a Money object.
      # * <tt>identification</tt> -- The ID of the original transaction against which the credit is being issued.
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      #
      # * <tt>:card_number</tt> -- The credit card number the credit is being issued to. (REQUIRED)
      def credit(money, identification, options = {})
        requires!(options, :card_number)

        post = { :ref_trans_id => identification,
                 :card_num => options[:card_number]
               }
        add_invoice(post, options)

        commit('CREDIT', money, post)
      end      
      
      private

      def parse(body)
        fields = split(body)

        results = {
          :response_code => fields[RESPONSE_CODE].to_i,
          :response_reason_code => fields[RESPONSE_REASON_CODE], 
          :response_reason_text => fields[RESPONSE_REASON_TEXT],
          :authorization_code => fields[AUTHORIZATION_CODE],
          :avs_result_code => fields[AVS_RESULT_CODE],
          :transaction_id => fields[TRANSACTION_ID],
          :card_code => fields[CARD_CODE_RESPONSE_CODE]
        }
        results
      end

      def post_data(action, parameters = {})
        post = {}

        post[:cpversion]        = API_VERSION
        post[:login]            = @options[:login]
        post[:tran_key]         = @options[:password]
        post[:market_type]      = MARKET_TYPE_RETAIL
        post[:device_type]      = @options[:device_type]
        post[:type]             = action
        post[:response_format]  = 1
        post[:delim_char]       = ","
        post[:encap_char]       = "$"

        request = post.merge(parameters).collect { |key, value| "x_#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
      
      # http://www.gae.ucm.es/~padilla/extrawork/tracks.html
      def add_creditcard(post, creditcard, options = {})
        super(post, creditcard)
        if options[:track_type] == 2
          post[:track2] = creditcard.track_data
        else
          post[:track1] = creditcard.track_data
        end
      end
    end
  end
end
