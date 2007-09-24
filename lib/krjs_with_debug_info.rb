# KRJS (keat's rails java script)
#
# MIT license

$indent = 0
def log message
  puts ' ' * $indent << message
end

def inc
  $indent = $indent + 1
end

def dec
  $indent = $indent - 1
end

#module ActionView
#  module Helpers
#class InstanceTag
#  include JavascriptHelper
#
#  # reader method used by TagHelper below..
#  def template_object
#    @template_object
#  end
##
#  # required by JavascriptHelper
#  def url_for(options)
#    template_object.url_for(options)
#  end
#end

#[TagHelper].each do |klass|
#  klass.class_eval do
#    include PrototypeHelper # this isn't so good?

module Krjs
  def self.included(base)
    base.class_eval do
      def tag_options(options)
        cleaned_options = options.reject { |key, value| value.nil? }
        unless cleaned_options.empty?
          " " + cleaned_options.symbolize_keys.map { |key, value|
            %(#{key}="#{html_escape(value.to_s)}")
          }.sort.join(" ")
        end
      end

      # adds observer to the original tag method
      def tag_with_observer(*attrs) #name, options = nil, open = false
        #debugger
        puts
        log '#tag_with_observer ' << attrs.inspect
        inc
        appended = observer(attrs[1])
        res = tag_without_observer(*attrs) <<  appended.to_s
        dec
        log '#end_tag_with_observer'
        return res
      end

      # adds observer to the original content_tag method
      def content_tag_with_observer(name, content, options = {})
        log '#content_tag_with_observer'
        inc
        appended = observer(options)
        res = content_tag_without_observer(name, content, options) + appended.to_s
        dec
        log '#end_content_tag_with_observer'
        return res
      end

      # adds a remote function to the options if needed
      def tag_options_with_remote_function(options)
        #debugger
        log '#tag_options_with_remotefunction' << options.inspect
        inc
        viewer, method_name, event_attr = viewer_method_eventattr(options) #unless options.include?
        if method_name && event_attr && options[event_attr].nil?
          # viewer.controller.logger.debug "options before: #{options.inspect}"
          options[event_attr] = remote_function(
          :url => HashWithIndifferentAccess.new(options).merge({
          :action => method_name,
          :dom_id => options['id'],
          :dom_index => split_dom_id(options['id'])[1],
          }),
          :with => (event_attr =~ /submit/ || method_name =~ /form/ ?
          'Form.serialize(this)' : "'dom_value=' + encodeURIComponent(this.value)")
          ) + "; return false;"
          # viewer.controller.logger.debug "options after: #{options.inspect}"
          # return false is important to neuter the browser event
        end
        result = tag_options_without_remote_function(options)
        dec
        log '#end_tag_options_with_remotefunction'

        return result
      end

      # just a copy  
      def tag_options(options)
         cleaned_options = convert_booleans(options.stringify_keys.reject {|key, value| value.nil?})
         ' ' + cleaned_options.map {|key, value| %(#{key}="#{escape_once(value)}")}.sort * ' ' unless cleaned_options.empty?
      end

      # chain the new methods with the old ones

      # tag => tag_with_observer
      # original tag => tag_without_observer
      alias_method_chain :tag, :observer

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
        log '#observer'
        inc
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
        dec
        log '#end_observer'
        appended
      end

      # there might be a better splitting policy yet?
      def split_dom_id(dom_id)
        dom_id = dom_id.tr('[]', '')
        dom_id.to_s.split(/-/) # based on convention of dashed_dom_id plugin
      end

      # given a dom_id, retrieve the defined controller method (if any)
      # e.g. on_student_submit, on_student_name_change, on_student_grade_focus
      # if the controller has no methods of such naming conventions, we'll look
      # to see if there are view templates of such filenames
      def controller_method(ctrler, dom_id)
        log '#controller_method'
        inc
        if dom_id.nil?
          dec
          log '#end_controoller_method'
          return nil
        end
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
        dec
        log '#end_controoller_method'
        ret
      end

      # convenience method to obtain all 3 information
      def viewer_method_eventattr(options)
        log '#viewer_method_eventattr'
        inc
        #viewer = nil
        viewer = self.respond_to?(:controller) ? self : self.template_object

        #controller = eval("controller")
        #controller ||= eval("template_object.controller")
        method_name ||= controller_method(viewer.controller, options['id'])
        # viewer.controller.logger.debug "using method_name #{method_name.inspect}" if method_name
        event_attr ||= "on#{$1}" if method_name =~ /_([^_]+(|_\d+))$/
        # viewer.controller.logger.debug "using event_attr #{event_attr.inspect}" if event_attr
        #puts '#end viewer_method_eventattr'
        dec
        log "#end_viewer_method_eventattr #{method_name} #{event_attr}"
        [viewer, method_name, event_attr]
      end

    end
  end
end
#    end
#  end
#end
#
#
module ActionView
  module Helpers
    module TagHelper
      public :tag_options
      include Krjs
    end
    class InstanceTag
      def template_object; @template_object; end
      def url_for(options); template_object.url_for(options); end
      include JavascriptHelper
      include PrototypeHelper
      public :tag_options      
      include Krjs
    end
  end
end

#module ActionView
#  class Base
#    include Krjs
#  end
#end