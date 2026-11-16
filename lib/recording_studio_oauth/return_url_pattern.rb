# frozen_string_literal: true

require "ipaddr"

module RecordingStudioOauth
  class ReturnUrlPattern
    STAR_HOST = "can use a star only as the whole host, or as the first label of a host with at least two more labels (*.example.com)"
    STAR_IP = "must not put a star in front of an IP address"
    STAR_PATH = "must not use a star in the path or query"

    def self.parse(raw)
      text = raw.to_s
      problem = text_error(text)
      return [nil, problem] if problem

      uri = ReturnUrlRules.http_uri(text)
      problem = shape_error(uri)
      return [nil, problem] if problem

      build(uri)
    end

    def self.text_error(text)
      return "must not be blank" if text.strip.empty?
      return "must be #{ReturnUrlRules::MAX_LENGTH} characters or fewer" if text.bytesize > ReturnUrlRules::MAX_LENGTH

      nil
    end

    def self.shape_error(uri)
      return "must be an absolute http or https URL" if uri.nil?
      return "must not include a username or password" if uri.userinfo.present?
      return "must not include a fragment" if uri.fragment.present?
      return STAR_PATH if star_outside_host?(uri)

      host_error(uri.host.to_s)
    end

    def self.star_outside_host?(uri)
      uri.path.include?("*") || uri.query.to_s.include?("*")
    end

    def self.host_error(host)
      return "must have a host" if host.blank?
      return "must not use a trailing dot in the host" if host.end_with?(".")
      return "must not encode the host" if host.include?("%")

      nil
    end

    def self.build(uri)
      kind, host, suffix, problem = classify(uri.host.to_s)
      return [nil, problem] if problem

      [new(kind: kind, scheme: uri.scheme, port: uri.port, path: uri.path, query: uri.query, host: host, suffix: suffix), nil]
    end

    def self.classify(host)
      lowered = host.downcase
      return [:any_host, nil, nil, nil] if lowered == "*"
      return label_host(lowered) if lowered.start_with?("*.")
      return [nil, nil, nil, STAR_HOST] if lowered.include?("*")

      [:exact, lowered, nil, nil]
    end

    def self.label_host(lowered)
      labels = lowered.delete_prefix("*.").split(".", -1)
      return [nil, nil, nil, STAR_HOST] unless usable_suffix?(labels)
      return [nil, nil, nil, STAR_IP] if ip_host?(labels.join("."))

      [:label, nil, labels, nil]
    end

    def self.usable_suffix?(labels)
      labels.length >= 2 && labels.none? { |label| label.empty? || label.include?("*") }
    end

    def initialize(kind:, scheme:, port:, path:, query:, host:, suffix:)
      @kind = kind
      @scheme = scheme
      @port = port
      @path = path
      @query = query
      @host = host
      @suffix = suffix
    end

    def match?(candidate)
      return false unless same_place?(candidate)

      host_match?(candidate.host.to_s.downcase)
    end

    def any_host?
      kind == :any_host
    end

    private

    attr_reader :kind, :scheme, :port, :path, :query, :host, :suffix

    def same_place?(candidate)
      scheme == candidate.scheme && port == candidate.port && path == candidate.path && query == candidate.query
    end

    def host_match?(lowered)
      case kind
      when :exact then host == lowered
      when :any_host then ordinary_host?(lowered)
      when :label then one_label?(lowered)
      else false
      end
    end

    def one_label?(lowered)
      return false unless ordinary_host?(lowered)

      labels = lowered.split(".", -1)
      labels.length == suffix.length + 1 && labels.first.present? && labels.drop(1) == suffix
    end

    def ordinary_host?(lowered)
      lowered.present? && !lowered.include?("*") && !lowered.end_with?(".") && !self.class.send(:ip_host?, lowered)
    end

    def self.ip_host?(host)
      return false if host.to_s.empty?

      IPAddr.new(host)
      true
    rescue IPAddr::Error
      false
    end
    private_class_method :text_error, :shape_error, :star_outside_host?, :host_error, :build, :classify,
                         :label_host, :usable_suffix?, :ip_host?
  end
end
