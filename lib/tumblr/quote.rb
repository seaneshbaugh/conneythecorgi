# frozen_string_literal: true

module Tumblr
  class Quote < Base
    def post_body
      @body = content_tag('blockquote', class: 'tumblr-quote') do
        concat(content_tag(:p, @json['text'].html_safe, class: 'tumblr-quote-text'))

        concat(content_tag('cite', class: 'tumblr-quote-source') do
          concat(' &mdash; '.html_safe)

          concat(@json['source'].html_safe)
        end)
      end

      super
    end

    def post_title
      @title = @json['text']

      super
    end
  end
end
