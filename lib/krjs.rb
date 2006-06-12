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
        dom_id.to_s.split(/-/) # based on convention of dashed_dom_id plugin
      end
  
      # given a dom_id, retrieve the defined controller method (if any)
      # e.g. on_student_submit, on_student_name_change, on_student_grade_focus
      def controller_method(ctrler, dom_id, tag = nil)
        return nil if dom_id.nil?
        array = split_dom_id(dom_id)
        method_match = "on_#{array.first}_"
        method_match += "(#{array[2]}|field|submit)_" if not array[2].nil?
        ctrler.methods.find{|x| x =~ /^#{method_match}(.+)$/}
      end
          
      def tag_options(options, viewer = nil, method_name = nil, event_attr = nil)
        # begin patch
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
      
      def tag(name, options = nil, open = false)
        viewer = self.respond_to?(:controller) ? self : self.template_object
        method_name = controller_method(viewer.controller, options['id'])
        event_attr = "on#{$1}" if method_name =~ /_([^_]+(|_\d+))$/
        appended = nil
        if event_attr =~ /^on(\w+)_(\d+)$/
          on_evt = $1
          freq = $2
          observe_options = {
            :url => options.merge({
              :action => method_name, 
              :dom_id => options['id'],
              :dom_index => split_dom_id(options['id'])[1],
            }), 
            :with => "'dom_value=' + Form.serialize($('#{options['id']}'))",
            :frequency => freq.to_i,
          }          
          if on_evt =~ /(form|submit)/
            appended = observe_form(options['id'], observe_options)
          else
            appended = observe_field(options['id'], observe_options.merge({
                :with => "'dom_value=' + $('#{options['id']}').value",
                :on => on_evt,
                })
            )
          end
          method_name = nil; event_attr = nil # let tag_options behave normally
        end
        "<#{name}#{tag_options(options.stringify_keys, viewer, method_name, event_attr) if options}" + (open ? ">" : " />") + appended.to_s
      end
    end
  end 
end

