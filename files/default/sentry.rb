require 'chef'
require 'chef/handler'
require 'raven'

SANITIZE_WORD_LIST = [
  "key",
  "password",
  "secret"
]
SANITIZED_EXCEPTION_MESSAGE = "Sanitized exception. Check /var/log/chef.log for stacktrace"

module Raven
  module Chef
    class SentryHandler < ::Chef::Handler
      def initialize(node)
        Raven.configure(true) do |config|
          config.ssl_verification = node['sentry']['verify_ssl']
          config.dsn = node['sentry']['dsn']
          config.logger = ::Chef::Log
          config.current_environment = node.chef_environment
          config.environments = [node.chef_environment]
          config.send_modules = Gem::Specification.respond_to?(:map)
        end
        Raven.logger.debug "Raven ready to report errors"
      end

      def report
        return if success?
        Raven.logger.info "Logging run failure to Sentry server"
        if exception
          # Why can't I make this a method? It makes 'exception' nil upon passing it in
          # def sanitize_exception(exception)
          #   exception
          # end
          if SANITIZE_WORD_LIST.any? { |word| exception.to_s.include?(word) }
            evt = Raven::Event.capture_exception(Exception.new(SANITIZED_EXCEPTION_MESSAGE))
          else
            evt = Raven::Event.capture_exception(exception)
          end
        else
          evt = Raven::Event.new do |evt|
            evt.message = "Unknown error during Chef run"
            evt.level = :error
          end
        end
        # Use the node name, not the FQDN
        evt.server_name = node.name
        Raven.send(evt)
      end
    end
  end
end
