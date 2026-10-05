# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
begin
  require "minitest/mock"
rescue LoadError
  # Minitest 6 removed minitest/mock. Keep Object#stub for gem tests.
  class Object
    def stub(name, val_or_callable, *_block_args)
      singleton = singleton_class
      original = method(name)
      singleton.define_method(name) do |*args, **kwargs, &block|
        if val_or_callable.respond_to?(:call)
          val_or_callable.call(*args, **kwargs, &block)
        else
          val_or_callable
        end
      end
      yield
    ensure
      singleton.define_method(name, original)
    end
  end
end
require "rails"
require "active_support/time"
Time.zone ||= "UTC"
require "recording_studio_oauth"
