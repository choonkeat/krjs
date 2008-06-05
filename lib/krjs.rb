# KRJS (keat's rails java script)
#
# MIT license

module Krjs
  # brought over from tag_helper (exist after 2.0.1)
  BOOLEAN_ATTRIBUTES = Set.new(%w(disabled readonly multiple))

  def self.included(base)
    base.class_eval do
      
      # just a public copy of the original tag options
      # we need to overwrite this because InstanceTag and TagHelper
      # are already bound to its private version.
      # without this the alias_method_chain seems not to work well
      def tag_options(options, escape = true)
        unless options.blank?
          attrs = []
          if escape
            options.each do |key, value|
              next unless value
              key = key.to_s
              value = ::Krjs::BOOLEAN_ATTRIBUTES.include?(key) ? key : escape_once(value)
              attrs << %(#{key}="#{value}")
            end
          else
            attrs = options.map { |key, value| %(#{key}="#{value}") }
          end
          " #{attrs.sort * ' '}" unless attrs.empty?
        end
      end

      # adds an observer to the original tag method if needed
      def tag_with_observer(*attrs) #name, options = nil, open = false
        appended = observer(attrs[1])
        return tag_without_observer(*attrs) <<  appended.to_s
      end

      # adds an observer to the original content_tag method if needed
      def content_tag_with_observer(name, content, options = {})
        appended = observer(options)
        return content_tag_without_observer(name, content, options) + appended.to_s
      end

      # adds a remote function to the options if needed
      def tag_options_with_remote_function(options, escape = true)
        viewer, method_name, event_attr = viewer_method_eventattr(options) #unless options.include?
        if method_name && event_attr && options[event_attr].nil? 
          options[event_attr] = remote_function(
            :url => HashWithIndifferentAccess.new(options).merge({
              :action => method_name, 
              :dom_id => options['id'],
              :dom_index => split_dom_id(options['id'])[1],
            }), 
            :with => (event_attr =~ /submit/ || method_name =~ /form/ ? 
                      '(window.Form ? Form.serialize(this) : jQuery(this).serialize())' : "'dom_value=' + encodeURIComponent(this.value)")
          ) + "; return false;" 
        end
        return tag_options_without_remote_function(options, escape = true)
      end
      
      # chain the new methods with the old ones

      # tag => tag_with_observer
      # original tag => tag_without_observer
      # alias_method_chain :tag, :observer

      # content_tag => content_tag_with_observer
      # original content_tag => content_tag_without_observer
      alias_method_chain :content_tag, :observer

      # tag_options => tag_options_with_remote_function
      # original tag_options => tag_option_without_remote_function
      alias_method_chain :tag_options, :remote_function

      protected

      # creates the javascript needed to observe a form/field
      # if necessary, otherwise returns nil
      def observer(options)
        viewer, method_name, event_attr = viewer_method_eventattr(options)
        appended = nil
        if event_attr =~ /^on(\w+)_(\d+)$/
          on_evt = $1
          freq = $2
          observe_options = HashWithIndifferentAccess.new({
            :url => HashWithIndifferentAccess.new(options).merge({
              :action => method_name, 
              :dom_id => options['id'],
              :dom_index => split_dom_id(options['id'])[1],
            }), 
            :with => "'dom_value=' + Form.serialize($('#{options['id']}'))",
            :frequency => freq.to_i,
          })
          if on_evt =~ /(form|submit)/
            appended = observe_form(options['id'], observe_options)
          else
            appended = observe_field(options['id'], observe_options.merge({
                :with => "'dom_value=' + encodeURIComponent($('#{options['id']}').value)",
                :on => on_evt,
                })
            )
          end
        end
        appended
      end
            
      # there might be a better splitting policy yet?
      def split_dom_id(dom_id)
        dom_id = dom_id.to_s.tr('[]', '')
        dom_id.split(/-/) # based on convention of dashed_dom_id plugin
      end
    
      # given a dom_id, retrieve the defined controller method (if any)
      # e.g. on_student_submit, on_student_name_change, on_student_grade_focus
      # if the controller has no methods of such naming conventions, we'll look
      # to see if there are view templates of such filenames
      def controller_method(ctrler, dom_id)
        return nil if dom_id.nil?
        array = split_dom_id(dom_id)
        method_match = "on_#{Regexp.escape(array.first)}_"
        method_match += "(#{Regexp.escape(array[2])}|field|submit)_" if not array[2].nil?
        regexp = Regexp.new("^#{method_match}(.+)$")
        ret = ctrler.methods.find{|x| x =~ regexp }

        if ret.nil? && self.respond_to?(:base_path)
          view_path = File.join(self.base_path, ctrler.controller_name) unless [self.base_path, ctrler.controller_name].include?(nil)
          Dir.open(view_path) do |dir|
            ret = dir.find{|x| x =~ regexp }.to_s.gsub(/\.[^\.]+$/, '')
          end unless view_path.blank? || !(File.exist? view_path)
        end
        ret
      end

      # convenience method to obtain all 3 information
      def viewer_method_eventattr(options)
        viewer = self.respond_to?(:controller) ? self : @template_object
        return [] unless viewer
        method_name ||= controller_method(viewer.controller, options['id'])
        event_attr ||= "on#{$1}" if method_name =~ /_([^_]+(|_\d+))$/
        [viewer, method_name, event_attr]
      end
    end
  end
end

module ActionView
  module Helpers
    module TagHelper
      include Krjs
    end
    class InstanceTag
      def method_missing(method, *args)
        if @template_object && @template_object.respond_to?(method)
          @template_object.send method, *args
        else
          super
        end
      end
      include JavascriptHelper
      include PrototypeHelper
      include Krjs
    end
  end
end
