require 'logger'

module SurveyGizmo
  class Logger < ::Logger
    def format_message(severity, timestamp, progname, message)
      message = message.dup
      if (api_token = SurveyGizmo.configuration.api_token)
        message.gsub!(
          /#{Regexp.quote(api_token)}|#{Regexp.quote(CGI.escape(api_token))}/,
          '<SG_API_KEY>'
        )
      end

      if (api_token_secret = SurveyGizmo.configuration.api_token_secret)
        message.gsub!(
          /#{Regexp.quote(api_token_secret)}|#{Regexp.quote(CGI.escape(api_token_secret))}/,
          '<SG_API_SECRET>'
        )
      end

      "[#{timestamp.strftime('%Y-%m-%d %H:%M:%S')} #{severity} (#{Process.pid})] #{message}\n"
    end
  end
end
