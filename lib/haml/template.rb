require File.dirname(__FILE__) + '/engine'
require 'active_support'
require 'action_view'

module Haml
  class Template

    def initialize(view)
      @view = view
      @@precompiled_templates ||= {}
    end

    def render(template_file_name, local_assigns={})
      assigns = @view.assigns.dup

      # Do content for layout on its own to keep things working in partials
      if content_for_layout = @view.instance_variable_get("@content_for_layout")
        assigns['content_for_layout'] = content_for_layout
      end

      # Get inside the view object's world
      @view.instance_eval do
        # Set all the instance variables
        assigns.each do |key,val|
          instance_variable_set "@#{key}", val
        end
        # Set all the local assigns
        local_assigns.each do |key,val|
          class << self; self; end.send(:define_method, key) &:val
        end
      end

      if @precompiled = get_precompiled(template_file_name)
        engine = Haml::Engine.new("", :precompiled => @precompiled)
      else
        engine = Haml::Engine.new(File.read(template_file_name))
        set_precompiled(template_file_name, engine.precompiled)
      end

      engine.to_html(@view)

    end

    def get_precompiled(filename)
      # Do we have it on file? Is it new enough?
      if (precompiled, precompiled_on = @@precompiled_templates[filename]) &&
             (precompiled_on == File.mtime(filename).to_i)
        precompiled
      end
    end

    def set_precompiled(filename, precompiled)
      @@precompiled_templates[filename] = [precompiled, File.mtime(filename).to_i]
    end
  end
end

class ActionView::Base
  attr :haml_filename, true

  alias_method :haml_old_render_file, :render_file
  def render_file(template_path, use_full_path = true, local_assigns = {})
    @haml_filename = File.basename(template_path)
    haml_old_render_file(template_path, use_full_path, local_assigns)
  end

  alias_method :read_template_file_old, :read_template_file
  def read_template_file(template_path, extension)
    if extension =~ /haml/i
      template_path
    else
      read_template_file_old(template_path, extension)
    end
  end
end
