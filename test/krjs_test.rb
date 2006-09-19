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

end
SampleController.template_root = File.join(File.dirname(__FILE__), 'views')


class KrjsTest < Test::Unit::TestCase

  def setup
    @controller = SampleController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_this_plugin
    get :index
    assert_not_ajaxified 'form', 'change', 'form submit'
    assert_ajaxified 'form', 'submit', 'form submit'

    assert_not_ajaxified 'account-new-login', 'focus', 'login onblur'
    assert_ajaxified 'account-new-login', 'blur', 'login onblur'

    assert_not_ajaxified 'account-new-password', 'change', 'password onchange'
    assert_ajaxified 'account-new-password', 'observe', 'password onchange'

    assert_not_ajaxified 'remember', 'blur', 'remember onblur'
    assert_ajaxified 'remember', 'change', 'remember onchange'
  end

  def assert_ajaxified(dom_id, event, assert_comments=nil)
    assert @response.body =~ /(\<[^\>]+ id="#{Regexp.escape(dom_id.to_s)}".*?\>(<script |))/m, "Cannot find #{Regexp.escape(dom_id.to_s)} in #{$1}\n\n#{@response.body}"
    tag = $1
    observer = $2
    case event
    when 'observe'
      assert(observer, "#{assert_comments}\n#{tag} #{observer}\n\n#{@response.body}")
    else
      assert((tag =~ / on#{event}\=/), "#{assert_comments}\n#{tag} #{observer}\n\n#{@response.body}")
    end
  end

  def assert_not_ajaxified(dom_id, event, assert_comments=nil)
    assert @response.body =~ /(\<[^\>]+ id="#{Regexp.escape(dom_id.to_s)}".*?\>(<script |))/m, "Cannot find #{Regexp.escape(dom_id.to_s)} in #{$1}\n\n#{@response.body}"
    tag = $1
    observer = $2
    case event
    when 'observe'
      assert_nil(observer, "#{assert_comments}\n#{tag} #{observer}\n\n#{@response.body}")
    else
      assert_nil((tag =~ / on#{event}\=/), "#{assert_comments}\n#{tag} #{observer}\n\n#{@response.body}")
    end
  end

end
