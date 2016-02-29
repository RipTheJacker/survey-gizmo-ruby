module SurveyGizmo
  class RateLimitExceededError < RuntimeError; end
  class BadResponseError < RuntimeError; end

  class PesterSurveyGizmoMiddleware < Faraday::Middleware
    Faraday::Response.register_middleware(pester_survey_gizmo: self)

    def call(environment)
      @app.call(environment).on_complete do |response|
        fail RateLimitExceededError if response.status == 429
        fail BadResponseError, "Bad response code #{response.status} in #{response.inspect}" unless response.status == 200
        fail BadResponseError, response.body['message'] unless response.body['result_ok'] && response.body['result_ok'].to_s =~ /^true$/i
      end
    end
  end
end
