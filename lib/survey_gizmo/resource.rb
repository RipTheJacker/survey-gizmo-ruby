require 'set'
require 'addressable/uri'

module SurveyGizmo
  module Resource
    extend ActiveSupport::Concern

    included do
      include Virtus.model
      instance_variable_set('@paths', {})
      SurveyGizmo::Resource.descendants << self
    end

    # @return [Set] Every class that includes SurveyGizmo::Resource
    def self.descendants
      @descendants ||= Set.new
    end

    # These are methods that every API resource has to access resources
    # in Survey Gizmo
    module ClassMethods

      # Convert a [Hash] of filters into a query string
      # @param [Hash] filters - simple pagination or other options at the top level, and surveygizmo "filters" at the :filters key
      # @return [String]
      #
      # example input: {page: 2, filters: [{:field=>"istestdata", :operator=>"<>", :value=>1}]}
      # The top level keys (e.g. page, resultsperpage) get simply encoded in the url, while the contents of the array of hashes
      # passed at filters[:filters] gets turned into the format surveygizmo expects for its internal filtering, for example:
      #
      # filter[field][0]=istestdata&filter[operator][0]=<>&filter[value][0]=1
      def convert_filters_into_query_string(filters = nil)
        if filters && filters.size > 0
          output_filters = filters[:filters] || []
          filter_hash = {}
          output_filters.each_with_index do |filter,i|
            filter_hash.merge!({
              "filter[field][#{i}]".to_sym => "#{filter[:field]}",
              "filter[operator][#{i}]".to_sym => "#{filter[:operator]}",
              "filter[value][#{i}]".to_sym => "#{filter[:value]}",
            })
          end
          simple_filters = filters.reject {|k,v| k == :filters}
          filter_hash.merge!(simple_filters)

          uri = Addressable::URI.new
          uri.query_values = filter_hash
          "?#{uri.query}"
        else
          ''
        end
      end

      # Get a list of resources
      # @param [Hash] conditions
      # @param [Hash] filters
      # @return [Array] of objects of this class
      def all(conditions = {}, filters = nil)
        response = RestResponse.new(SurveyGizmo.get(handle_route(:create, conditions) + convert_filters_into_query_string(filters)))
        if response.ok?
          _collection = response.data.map {|datum| datum.is_a?(Hash) ? self.new(datum) : datum}

          # Add in the properties from the conditions hash because many of the important ones (like survey_id) are
          # not often part of the SurveyGizmo's returned data
          conditions.keys.each do |k|
            if conditions[k] && instance_methods.include?(k)
              _collection.each { |c| c[k] ||= conditions[k] }
            end
          end

          # Sub questions are not pulled by default so we have to retrieve them and mark their parent question
          if self == SurveyGizmo::API::Question
            _collection += _collection.map {|question| question.sub_questions}.flatten
          end
          _collection
        else
          []
        end
      end

      # Get the first resource
      # @param [Hash] conditions
      # @param [Hash] filters
      # @return [Object, nil]
      def first(conditions = {}, filters = nil)
        response = RestResponse.new(SurveyGizmo.get(handle_route(:get, conditions) + convert_filters_into_query_string(filters)))
        # Add in the properties from the conditions hash because many of the important ones (like survey_id) are
        # not often part of the SurveyGizmo's returned data
        response.ok? ? new(conditions.merge(response.data)) : nil
      end

      # Create a new resource
      # @param [Hash] attributes
      # @return [Resource]
      #   The newly created Resource instance
      def create(attributes = {})
        resource = new(attributes)
        resource.__send__(:_create)
        resource
      end

      # Copy a resource
      # @param [Integer] id
      # @param [Hash] attributes
      # @return [Resource]
      #   The newly created resource instance
      def copy(attributes = {})
        attributes[:copy] = true
        resource = new(attributes)
        resource.__send__(:_copy)
        resource
      end

      # Deleted the Resource from Survey Gizmo
      # @param [Hash] conditions
      # @return [Boolean]
      def destroy(conditions)
        RestResponse.new(SurveyGizmo.delete(handle_route(:delete, conditions))).ok?
      end

      # Define the path where a resource is located
      # @param [String] path
      #   the path in Survey Gizmo for the resource
      # @param [Hash] options
      # @option options [Array] :via
      #     which is `:get`, `:create`, `:update`, `:delete`, or `:any`
      # @scope class
      def route(path, options)
        methods = options[:via]
        methods = [:get, :create, :update, :delete] if methods == :any
        methods.is_a?(Array) ? methods.each { |m| @paths[m] = path } : (@paths[methods] = path)
        nil
      end

      # This method replaces the :page_id, :survey_id, etc strings defined in each model's URI routes with the
      # values being passed in interpolation hash with the same keys.
      # @api private
      def handle_route(key, interpolation_hash)
        path = @paths[key]
        raise "No routes defined for `#{key}` in #{self.name}" unless path
        raise "User/password hash not setup!" if SurveyGizmo.default_params.empty?

        path.gsub(/:(\w+)/) do |m|
          raise(SurveyGizmo::URLError, "Missing RESTful parameters in request: `#{m}`") unless interpolation_hash[$1.to_sym]
          interpolation_hash[$1.to_sym]
        end
      end
    end

    # Updates attributes and saves this Resource instance
    #
    # @param [Hash] attributes
    #   attributes to be updated
    #
    # @return [Boolean]
    #   true if resource is saved
    def update(attributes = {})
      self.attributes = attributes
      self.save
    end

    # Save the instance to Survey Gizmo
    def save
      if id #Then it's an update
        handle_response(SurveyGizmo.post(handle_route(:update), query: self.attributes_without_blanks))
        @latest_response.ok?
      else
        _create
      end
    end

    # fetch resource from SurveyGizmo and reload the attributes
    # @return [self, false]
    #   Returns the object, if saved. Otherwise returns false.
    def reload
      handle_response(SurveyGizmo.get(handle_route(:get)))
      if @latest_response.ok?
        self.attributes = @latest_response['data']
        self
      else
        false
      end
    end

    # Deleted the Resource from Survey Gizmo
    # @return [Boolean]
    def destroy
      if id
        handle_response(SurveyGizmo.delete(handle_route(:delete)))
        @latest_response.ok?
      else
        false
      end
    end

    # Sets the hash that will be used to interpolate values in routes. It needs to be defined per model.
    # @return [Hash] a hash of the values needed in routing
    def to_param_options
      raise "Define #to_param_options in #{self.class.name}"
    end

    # Any errors returned by Survey Gizmo
    # @return [Array]
    def errors
      @errors ||= []
    end

    # @visibility private
    def inspect
      if ENV['GIZMO_DEBUG']
        ap "CLASS: #{self.class}"
      end

      attribute_strings = self.class.attribute_set.map do |attrib|
        if ENV['GIZMO_DEBUG']
          ap attrib
          ap attrib.name
          ap self.send(attrib.name)
          ap self.send(attrib.name).class
        end

        if self.send(attrib.name).class == Hash
          value = self.send(attrib.name).inspect
        else
          value = self.send(attrib.name).to_s
        end

        "  \"#{attrib.name}\" => \"#{value}\"\n" unless value.strip.blank?
      end.compact

      "#<#{self.class.name}:#{self.object_id}>\n#{attribute_strings.join()}"
    end


    protected

    def attributes_without_blanks
      self.attributes.reject { |k,v| v.blank? }
    end

    private
    def handle_route(key)
      self.class.handle_route(key, to_param_options)
    end

    def handle_response(rest_response, &block)
      @latest_response = rest_response
      if @latest_response.ok?
        self.errors.clear
        true
      else
        errors << @latest_response.message
        false
      end
    end

    # Returns itself if successfully saved, but with attributes added by SurveyGizmo
    def _create(attributes = {})
      http = RestResponse.new(SurveyGizmo.put(handle_route(:create), query: self.attributes_without_blanks))
      handle_response(http)
      if http.ok?
        self.attributes = http.data
        self
      else
        false
      end
    end

    def _copy(attributes = {})
      http = RestResponse.new(SurveyGizmo.post(handle_route(:update), query: self.attributes_without_blanks))
      handle_response(http) do
        if http.ok?
          self.attributes = http.data
        else
          false
        end
      end
    end
  end
end
