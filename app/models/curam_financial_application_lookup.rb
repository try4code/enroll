require 'singleton'

class CuramFinancialApplicationLookup
  include Singleton

  attr_accessor :provider

  def initialize
    @provider = AmqpSource
  end

  def search_curam_financial_app(person_demographics)
    provider.search_curam_financial_app person_demographics
  end

  def self.slug!
    self.instance.provider = SlugSource
  end

  class AmqpSource
    def self.search_curam_financial_app(person_demographics)
      request_result = nil
      retry_attempt = 0
      while (retry_attempt < 3) && request_result.nil?
        request_result = Acapi::Requestor.request("curam_financial_application.search", person_demographics, 2)
        retry_attempt = retry_attempt + 1
      end
      request_result.stringify_keys["body"]
    end
  end

  class SlugSource
    def self.search_curam_financial_app(person_demographics)
      "NO_DATA_FOUND"
    end
  end
end

unless Rails.env.production?
  CuramFinancialApplicationLookup.slug!
end