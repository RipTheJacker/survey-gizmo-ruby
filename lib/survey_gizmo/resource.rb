require "set"

module SurveyGizmo
  module Resource
    extend ActiveSupport::Concern
    
    included do
      include Virtus
      instance_variable_set('@paths', {})
      instance_variable_set('@collections', {})
      SurveyGizmo::Resource.descendants << self
    end
    
    # @return [Set] Every class that includes SurveyGizmo::Resource
    def self.descendants
      @descendants ||= Set.new
    end
    
    # These are methods that every API resource has to access resources
    # in Survey Gizmo
    module ClassMethods
      
      # Get a list of resources
      # @param [Hash] conditions
      # @return [SurveyGizmo::Collection, Array]
      def all(conditions = {})
        response = Response.new SurveyGizmo.get(handle_route(:create, conditions))
        if response.ok?
          _collection = SurveyGizmo::Collection.new(self, nil, response.data)
          _collection.send(:options=, {:target => self, :parent => self})
          _collection
        else
          []
        end
      end
      
      # Get the first resource
      # @param [Hash] conditions
      # @return [Object, nil]
      def first(conditions)
        response = Response.new SurveyGizmo.get(handle_route(:get, conditions))
        response.ok? ? load(conditions.merge(response.data)) : nil
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
      
      # Deleted the Resource from Survey Gizmo
      # @param [Hash] conditions
      # @return [Boolean]
      def destroy(conditions)
        response = Response.new SurveyGizmo.delete(handle_route(:delete, conditions))
        response.ok?
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
        methods.is_a?(Array) ? methods.each{|m| @paths[m] = path } : (@paths[methods] = path)
        nil
      end
      
      # @api private
      def load(attributes = {})
        resource = new(attributes)
        resource.__send__(:clean!)
        resource
      end
      
      # Defines a new collection. These are child objects of the resource.
      # @macro [new] collection
      #   @param [Symbol] resource_name the name of the collection, pluralized
      #   @param [Class] model and optional class name if the class name does not match the resource_name
      #   @return [Collection] 
      #     the $1 collection
      #   @scope instance
      def collection(resource_name, model = nil)
        @collections[resource_name] = {:parent => self, :target => (model ? model : resource_name)} # workaround for weird bug with passing a class to Collection
        class_eval(<<-EOS)
          def #{resource_name}
            @#{resource_name} ||= []
          end
          
          def #{resource_name}=(array)
            @#{resource_name} = SurveyGizmo::Collection.new(#{self}, :#{resource_name}, array)
          end
        EOS
      end
      
      # @api private
      def collections
        @collections.dup.freeze
      end
      
      # @api private
      def handle_route(key, *interp)
        path = @paths[key]
        raise "No routes defined for `#{key}` in #{self.name}" unless path
        options = interp.last.is_a?(Hash) ? interp.pop : path.scan(/:(\w+)/).inject({}){|hash, k| hash.merge(k.to_sym => interp.shift) }
        path.gsub(/:(\w+)/) do |m| 
          options[$1.to_sym].tap{ |result| raise(SurveyGizmo::URLError, "Missing parameters in request: `#{m}`") unless result }
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
    #
    # @return [Boolean]
    #   true if Resource instance is saved
    def save
      if new?
        _create
      else
        handle_response SurveyGizmo.post(handle_route(:update), :query => self.attributes_without_blanks) do 
          _response.ok? ? saved! : false
        end
      end
    end
    
    # fetch resource from SurveyGizmo and reload the attributes
    # @return [self, false]
    #   Returns the object, if saved. Otherwise returns false.
    def reload
      handle_response SurveyGizmo.get(handle_route(:get)) do
        if _response.ok? 
          self.attributes = _response.data
          clean!
        else
          false
        end
      end  
    end
    
    # Deleted the Resource from Survey Gizmo
    # @return [Boolean]
    def destroy
      return false if new? || destroyed?
      handle_response SurveyGizmo.delete(handle_route(:delete)) do
        _response.ok? ? destroyed! : false
      end
    end
    
    # The state of the current Resource
    # @api private
    def new?
      @_state.nil?
    end
    
    # @todo This seemed like a good way to prevent accidently trying to perform an action
    #   on a record at a point when it would fail. Not sure if it's really necessary though.
    [:clean, # stored and not dirty
      :saved, # stored and not modified
      :destroyed, # duh!
      :zombie  # needs to be stored
    ].each do |state|
      # Change the method state to $1
      define_method("#{state}!") do
        @_state = state
        true
      end
      
      # Inquire about the method state if $1
      define_method("#{state}?") do
        @_state == state
      end
      
      private "#{state}!"
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
      attrs = self.class.attributes.map do |attrib|
        value = attrib.get!(self).inspect

        "#{attrib.instance_variable_name}=#{value}"
      end

      "#<#{self.class.name}:#{self.object_id} #{attrs.join(' ')}>"
    end
    
    # This class normalizes the response returned by Survey Gizmo
    class Response
      def ok?
        @response['result_ok']
      end
      
      # The parsed JSON data of the response
      def data
        @_data ||= (@response['data'] || {})
      end
      
      # The error message if there is one
      def message
        @_message ||= @response['message']
      end
      
      private
      def initialize(response)
        @response = response.parsed_response
      end
    end
    
    protected
    
    def attributes_without_blanks
      self.attributes.reject{|k,v| v.blank? }
    end
    
    private
    attr_reader :_response
    
    def set_response(http)
      @_response = Response.new(http)
    end
    
    def handle_route(key)
      self.class.handle_route(key, to_param_options)
    end
    
    def handle_response(resp, &block)
      set_response(resp)
      (self.errors << _response.message) unless _response.ok?
      self.errors.clear if !self.errors.empty? && _response.ok?
      instance_eval(&block)
    end
    
    def _create(attributes = {})
      http = SurveyGizmo.put(handle_route(:create), :query => self.attributes_without_blanks)
      handle_response http do
        if _response.ok?
          self.attributes = _response.data
          saved!
        else
          false
        end      
      end
    end
    
  end
end