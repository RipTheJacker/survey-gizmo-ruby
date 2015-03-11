# WARNING:

SurveyGizmo doesn't test their REST API when they roll out changes.  They don't publish a list of active defects, and when you call/email for support it is unlikely you will geto a person that knows anything about programming or the REST API.  You can't talk to level 2 support, although they might offer you a discount on their paid consulting rates if the problem persists for more than a few weeks.

-chorn@chorn.com 2013-03-15

# REMINDER:

SurveyGizmo breaks their API a few times a year.  You'd best look elsewhere.

-chorn@chorn.com 2013-12-18

# Survey Gizmo (ruby)

Integrate with the [Survey Gizmo API](http://developer.surveygizmo.com/resources/rest-api-documentation-version-1-01/) using an ActiveModel style interface. We currently support rest API **v3**. If you want to use version 1 of the API, please use gem version ~0.7.0

## Installation

    gem install survey-gizmo-ruby

## Basic Usage

	require 'survey-gizmo-ruby'
	
	# somewhere in your app define your survey gizmo login credentials.
	SurveyGizmo.setup(:user => 'you@somewhere.com', :password => 'mypassword')
	
	survey = SurveyGizmo::API::Survey.first(:id => 12345)
	survey.title # => My Title
	survey.pages # => [page1, page2,...]
	
	question = SurveyGizmo::API::Question.create(:survey_id => survey.id, :title => 'Do you like ruby?', :type => 'checkbox')
	question.title = "Do you LOVE Ruby?"
	question.save # => true
	question.saved? # => true
	
	# Error handling
	question.save # => false
	question.errors # => ['There was an error']
	
## Adding API Objects

Currently, the following API objects are included in the gem: `Survey`, `Question`, `Option`, `Page`, `Response`, `EmailMessage`, `SurveyCampaign`, `Contact`. If you want to use something that isn't included you can easily write a class that handles it. Here's an example of the how to do so:

	class SomeObject
	  # the base where most of the methods for handling the API are stored
	  include SurveyGizmo::Resource
      
      # the attribtues the object should respond to
	  attribute :id,          Integer
	  attribute :title,       String
	  attribute :status,      String
	  attribute :type,        String
	  attribute :created_on,  DateTime
  
      # defing the paths used to retrieve/set info
	  route '/something/:id', :via => [:get, :update, :delete]
	  route '/something',     :via => :create
  		
      # this must be defined with the params that would be included in any route
	  def to_param_options
	    {:id => self.id}
	  end
	end

The [Virtus](https://github.com/solnic/virtus) gem is included to handle the attributes, so please check their documentation as well.

# Contributing to survey-gizmo-ruby
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Take a gander at the github issues beforehand
* Fork the project
* Start a feature/bugfix branch and hack away
* Make sure to add tests for it!!!!
* Submit a pull request
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Missing Features

There are several API objects that are available and not included in this gem. It is also missing OAuth authentication ability. Also, the error notification isn't intuitive. It'd be great if someone could help tackle those!


# Copyright

Copyright (c) 2012 RipTheJacker. See LICENSE.txt for
further details.

