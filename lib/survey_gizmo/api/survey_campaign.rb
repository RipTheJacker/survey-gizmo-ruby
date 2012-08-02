module SurveyGizmo; module API
  # @see SurveyGizmo::Resource::ClassMethods
  class SurveyCampaign
    include SurveyGizmo::Resource

    # @macro [attach] virtus_attribute
    #   @return [$2]
    attribute :id,              Integer
    attribute :name,            String
    attribute :_type,           String
    attribute :_subtype,        String
    attribute :__subtype,       String
    attribute :status,          String
    attribute :uri,             String
    attribute :SSL,             Boolean
    attribute :slug,            String
    attribute :language,        String
    attribute :close_message,   String
    attribute :limit_responses, String
    attribute :tokenvariables,  Array
    attribute :survey_id,       Integer
    attribute :datecreated,     DateTime
    attribute :datemodified,    DateTime

    route '/survey/:survey_id/surveycampaign/:id', :via => [:get, :update, :delete]
    route '/survey/:survey_id/surveycampaign', :via => :create

    # @see SurveyGizmo::Resource#to_param_options
    def to_param_options
      {:id => self.id, :survey_id => self.survey_id}
    end
  end
end; end