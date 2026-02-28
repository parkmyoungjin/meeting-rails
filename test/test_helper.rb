ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors, with: :threads)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module TestStubHelpers
  def stub_class_method(klass, method_name, replacement = nil, &block)
    singleton = klass.singleton_class
    original_defined = singleton.method_defined?(method_name) || singleton.private_method_defined?(method_name)
    original_method = singleton.instance_method(method_name) if original_defined

    singleton.send(:define_method, method_name) do |*args, **kwargs, &blk|
      if replacement.respond_to?(:call)
        replacement.call(*args, **kwargs, &blk)
      else
        replacement
      end
    end

    block.call
  ensure
    if original_defined
      singleton.send(:define_method, method_name, original_method)
    else
      singleton.send(:remove_method, method_name)
    end
  end
end

class ActionDispatch::IntegrationTest
  include TestStubHelpers
end
