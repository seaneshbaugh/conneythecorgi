# frozen_string_literal: true

module Tumblr
  class Link < Base
    def post_body
      @body = @json['description']

      super
    end

    def post_title
      @title = @json['title']

      @title = @json['description'] unless @title.present?

      super
    end
  end
end
