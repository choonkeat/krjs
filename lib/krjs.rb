# KRJS (keat's rails java script)
#
# MIT license
#

require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    class InstanceTag
      # reader method used by TagHelper below..
      def template_object
        @template_object
      end
    end
  
    module TagHelper
      include PrototypeHelper # this isn't so good?

      # there might be a better splitting policy yet?
      def split_dom_id(dom_id)
        dom_id.to_s.split(/-/)
      end
  
      # given a dom_id, retrieve the defined controller method (if any)
      # e.g. on_student_submit, on_student_name_change, on_student_grade_focus
      def controller_method(ctrler, dom_id, tag = nil)
        return nil if dom_id.nil?
        array = split_dom_id(dom_id)
        method_match = "on_#{array.first}_"
        method_match += "(#{array[2]}|field)_" if not array[2].nil?
        method_found = ctrler.methods.find{|x| x =~ /^#{method_match}(.+)$/}
        return nil if method_found.nil?
        method_found
      end
    
      def tag_options(options)
        # begin patch
        viewer     = self.respond_to?(:controller) ? self : self.template_object
        method_name = controller_method(viewer.controller, options['id'])
        event_attr = "on#{$1}" if method_name =~ /_([^_]+)$/
        if method_name && event_attr && options[event_attr].nil? 
          options[event_attr] = viewer.remote_function(
            :url => options.merge({
              :action => method_name, 
              :dom_id => options['id'],
              :dom_index => split_dom_id(options['id'])[1],
            }), 
            :with => (event_attr =~ /submit/ ? 'Form.serialize(this)' : "'dom_value=' + this.value")
          ) + "; return false;" 
          # return false is important to neuter the browser event
        end
        # end patch

        cleaned_options = convert_booleans(options.stringify_keys.reject {|key, value| value.nil?})
          ' ' + cleaned_options.map {|key, value| %(#{key}="#{html_escape(value.to_s)}")}.sort * ' ' unless cleaned_options.empty?
      end
    end
  end 
end

