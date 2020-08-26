# frozen_string_literal: true

module Tumblr
  class Text < Base
    def post_body
      @body = @json['body']

      super
    end

    def post_title
      @title = @json['title']

      @title = @json['body'] unless @title.present?

      super
    end
  end
end
