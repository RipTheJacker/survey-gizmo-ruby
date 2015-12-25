module SurveyGizmo
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?

    retryables = [
      Net::ReadTimeout,
      Faraday::Error::TimeoutError,
      SurveyGizmo::RateLimitExceededError
    ]

    Pester.configure do |c|
      c.environments[:survey_gizmo_ruby] = {
        max_attempts: configuration.retries + 1,
        delay_interval: configuration.retry_interval,
        on_retry: Pester::Behaviors::Sleep::Constant,
        logger: configuration.logger
      }

      if configuration.retry_everything
        c.environments[:survey_gizmo_ruby].delete(:retry_error_classes) rescue nil
      else
        c.environments[:survey_gizmo_ruby][:retry_error_classes] = retryables
      end
    end
  end

  def self.reset!
    self.configuration = Configuration.new
    Connection.reset!
  end

  class Configuration
    DEFAULT_REST_API_URL = 'https://restapi.surveygizmo.com'
    DEFAULT_API_VERSION = 'v4'
    DEFAULT_RESULTS_PER_PAGE = 50

    attr_accessor :user
    attr_accessor :password

    attr_accessor :api_debug
    attr_accessor :api_url
    attr_accessor :api_version
    attr_accessor :logger
    attr_accessor :results_per_page
    attr_accessor :retries
    attr_accessor :retry_interval
    attr_accessor :retry_everything

    def initialize
      @api_url = DEFAULT_REST_API_URL
      @api_version = DEFAULT_API_VERSION
      @results_per_page = DEFAULT_RESULTS_PER_PAGE
      @retries = 1
      @retry_interval = 60
      @retry_everything = false
      @logger = ::Logger.new(STDOUT)
      @api_debug = ENV['GIZMO_DEBUG'].to_s =~ /^(true|t|yes|y|1)$/i
    end
  end
end
