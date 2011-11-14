require 'routing_filter/base'

module RoutingFilter
  class Mode < Base
    cattr_accessor :current_mode
    class << self
      def modes
        @@modes ||= ['embed', 'embed-app', 'embed-func']
      end

      def modes_pattern
        @@modes_pattern ||= self.modes.map { |mode| Regexp.escape(mode.to_s) }.join('|')
      end

      def modes_regexp
        @@modes_regexp ||= %r(^/(#{self.modes_pattern})(?=/|$))
      end
    end

    def around_recognize(path, env, &block)
      mode = extract_mode!(path)
      #mode = ['fn']
      Rails.logger.info "!!!!!!!!!!!!!!!!!!!!!!!!!!!!  #{mode}"
      returning yield do |params|
        @@current_mode = params[:mode] = mode
      end
    end

    def around_generate(*args, &block)
      mode = args.extract_options!.delete(:mode) || current_mode
      mode = nil if mode and mode.to_sym == :platform
      returning yield do |result|
        url = result.is_a?(Array) ? result.first : result
        insert_mode(url, mode)
      end
    end

    protected

    def extract_mode!(path)
      path.sub! self.class.modes_regexp, ''
      $1
    end

    def insert_mode(url, mode)
      mode = mode ? ('/' + mode.to_s) : ''
      url.sub!(%r(^(http.?://[^/]*)?(/\w{2})?(/#{self.class.modes_pattern})?(/.*))) { "#{$1}#{$2}#{mode}#{$4}" }
    end

  end
end
