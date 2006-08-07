# KRJS (keat's rails java script)
#
# MIT license

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
        dom_id = dom_id.tr('[]','')
        dom_id.to_s.split(/-/) # based on convention of dashed_dom_id plugin
      end
  
      # given a dom_id, retrieve the defined controller method (if any)
      # e.g. on_student_submit, on_student_name_change, on_student_grade_focus
      # if the controller has no methods of such naming conventions, we'll look
      # to see if there are view templates of such filenames
      def controller_method(ctrler, dom_id, tag = nil)
        return nil if dom_id.nil?
        array = split_dom_id(dom_id)
        method_match = "on_#{Regexp.escape(array.first)}_"
        method_match += "(#{Regexp.escape(array[2])}|field|submit)_" if not array[2].nil?
        regexp = Regexp.new("^#{method_match}(.+)$")
        ret = ctrler.methods.find{|x| x =~ regexp }
        # ctrler.logger.debug "match '#{method_match}' finds '#{ret}'"
        if ret.nil? && self.respond_to?(:base_path)
          view_path = File.join(self.base_path, ctrler.controller_name)
          # ctrler.logger.debug "looking to match within #{view_path}"
          Dir.open(view_path) do |dir|
            ret = dir.find{|x| x =~ regexp }.to_s.gsub(/\.[^\.]+$/, '')
          end unless not File.exist? view_path
        end
        ret
      end

      # convenience method to obtain all 3 information
      def viewer_method_eventattr(options)
        viewer = self.respond_to?(:controller) ? self : self.template_object
        method_name ||= controller_method(viewer.controller, options['id'])
        event_attr ||= "on#{$1}" if method_name =~ /_([^_]+(|_\d+))$/
        [viewer, method_name, event_attr]
      end
          
      def tag_options(options, viewer = nil, method_name = nil, event_attr = nil)
        # other tag helpers may call tag_options directly without tag, hence viewer
        # would be nil - we're then be required to populate those values ourselves
        viewer, method_name, event_attr = viewer_method_eventattr(options) if viewer.nil?
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
        viewer, method_name, event_attr = viewer_method_eventattr(options)
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

