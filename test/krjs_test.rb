require 'rubygems'
require_gem "rails"
require 'initializer'
require 'test/unit'
require 'action_controller/test_process'
require File.dirname(__FILE__) + '/../lib/krjs'

ENV["RAILS_ENV"] = "test"
require 'test_help'

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end

class SampleController < ActionController::Base

  def index
  end
  
  def alternate_index
    render :action => 'index'
  end

  def on_form_submit
    render :update do |page|
      page.insert_html :after, params[:dom_id], CGI.escapeHTML(params.inspect)
    end
  end

  def on_account_login_blur
    render :update do |page|
      page.insert_html :after, params[:dom_id], CGI.escapeHTML(params.inspect)
    end
  end

  def on_account_password_change_3
    render :update do |page|
      page.insert_html :after, params[:dom_id], CGI.escapeHTML(params.inspect)
    end
  end
  
  def on_account_comments_change
    render :update do |page|
      page.insert_html :after, params[:dom_id], CGI.escapeHTML(params.inspect)
    end
  end
  
  def on_account_country_change_9
    render :update do |page|
      page.insert_html :after, params[:dom_id], CGI.escapeHTML(params.inspect)
    end
  end

end
SampleController.template_root = File.join(File.dirname(__FILE__), 'views')


class KrjsTest < Test::Unit::TestCase

  def setup
    @controller = SampleController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_basic
    get :index
    assert_not_ajaxified 'form', 'change', 'form submit'
    assert_ajaxified 'form', 'submit', 'form submit'

    assert_not_ajaxified 'account-new-login', 'focus', 'login onblur'
    assert_ajaxified 'account-new-login', 'blur', 'login onblur'

    assert_not_ajaxified 'account-new-password', 'change', 'password onchange'
    assert_ajaxified 'account-new-password', 'observe', 'password onchange'

    # external .rjs file
    assert_not_ajaxified 'remember', 'blur', 'remember onblur'
    assert_ajaxified 'remember', 'change', 'remember onchange'
    
    assert_not_ajaxified 'account_comments', 'blur', 'account_comments onblur'
    assert_ajaxified 'account_comments', 'change', 'account_comments onchange'    

    assert_not_ajaxified 'account_country', 'change', 'account_country onblur'
    assert_ajaxified 'account_country', 'observe', 'account_country observe'    
  end

  def test_optional_action
    
  end

  def test_optional_callback
    
  end




protected
  def assert_ajaxified(dom_id, event, assert_comments=nil)
    tag, observer = rendered_html(dom_id, event)
    case event
    when 'observe'
      assert(!observer.blank?, "#{assert_comments}\n#{tag} #{observer}\n\n#{@response.body}")
    else
      assert((tag =~ / on#{event}\=/), "#{assert_comments}\n#{tag} #{observer}\n\n#{@response.body}")
    end
  end

  def assert_not_ajaxified(dom_id, event, assert_comments=nil)
    tag, observer = rendered_html(dom_id, event)
    case event
    when 'observe'
      assert(observer.blank?, "#{assert_comments}\n#{tag} #{observer}\n\n#{@response.body}")
    else
      assert_nil((tag =~ / on#{event}\=/), "#{assert_comments}\n#{tag} #{observer}\n\n#{@response.body}")
    end
  end
  
  # returns an array, 
  # first element is the tag of the dom_id: e.g. "<form id='thisform'.... >" if dom_id is "thisform"
  # second element (nillable) is the '<script ... </script>' appended to the tag by rjs if its an observed field
  def rendered_html(dom_id, event)
    if @response.body =~ /(\<([^\>]+) id="#{Regexp.escape(dom_id.to_s)}".*?\>(.+\2>\s*<script))/m
        # matches <select>... </select><script
        tag = $2
        return tag, $1 if $3 =~ /\/#{tag}>(.+)/
    end
    assert @response.body =~ /(\<[^\>]+ id="#{Regexp.escape(dom_id.to_s)}".*?\>(<script |))/m, "Cannot find #{Regexp.escape(dom_id.to_s)} in #{$1}\n\n#{@response.body}"
    return $1, $2
  end

end
