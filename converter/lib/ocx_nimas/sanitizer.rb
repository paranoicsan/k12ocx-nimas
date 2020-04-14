# frozen_string_literal: true

require 'sanitize'

module OcxNimas
  class Sanitizer
    SANITIZE_ATTRIBUTES = Sanitize::Config.merge(
      Sanitize::Config::BASIC[:attributes],
      all: %w(id class type),
      'img' => %w(alt src),
      'ol' => %w(start)
    ).freeze
    private_constant :SANITIZE_ATTRIBUTES

    SANITIZE_CONFIG = Sanitize::Config.merge(
      Sanitize::Config::BASIC,
      elements: Sanitize::Config::RELAXED[:elements] - Sanitize::Config::RESTRICTED[:elements] - %w(span),
      attributes: SANITIZE_ATTRIBUTES
    ).freeze
    private_constant :SANITIZE_CONFIG

    def self.sanitize(text)
      Sanitize.document text, SANITIZE_CONFIG
    end
  end
end
