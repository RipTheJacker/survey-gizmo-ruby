$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require "bundler/setup"
Bundler.require(:test)
require 'survey-gizmo-ruby'
require "active_support/json"
require "active_support/ordered_hash"

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f }

RSpec.configure do |config|
  config.include SurveyGizmoSpec::Methods

  config.before(:each) do
    @base = 'https://restapi.surveygizmo.com/v3'
  end
end
