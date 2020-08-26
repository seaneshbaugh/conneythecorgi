# frozen_string_literal: true
require 'pp'
module Tumblr
  class Photo < Base
    private

    def post_body
      @body = @json['photos'].map do |photo|
        next if photo['original_size'].nil?

        url = photo['original_size']['url']

        next if url.nil? || @photo_map[url].nil?

        picture = @photo_map[url]

        content_tag :p, class: 'center' do
          content_tag :a, href: picture[:original_image_path] do
            tag :img, { alt: picture[:title], src: picture[:medium_image_path], title: picture[:title] }, true
          end
        end
      end.compact.join("\n")

      @body += @json['caption']

      super
    end

    def post_title
      @title = @json['summary']

      super
    end
  end
end
