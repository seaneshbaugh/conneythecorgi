# frozen_string_literal: true

require 'action_view'
require 'digest'
require 'html2haml'
require 'htmlentities'
require 'httparty'
require 'mini_magick'
require 'sanitize'
require 'time'

module Tumblr
  class Base
    include ActionView::Context
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::UrlHelper

    VALID_POST_TYPES = %w(answer audio chat link photo quote text video).freeze

    INVALID_CHARACTER_MAP = {
      /\u2018|\u2019|&#8216;|&#8217;|&#x2018;|&#x2019;|&lsquo;|&rsquo;|&apos;/ => "'",
      /\u201C|\u201D|&#8220;|&#8221;|&#x201c;|&#x201d;|&ldquo;|&rdquo;/ => '"',
      /\u00A0|&#160;|&#xA0;/ => ' '
    }.freeze

    SANITIZE_OPTIONS = {
      whitespace_elements: {
        'br' => {
          before: '',
          after: ' '
        },
        'p' => {
          before: '',
          after: ' '
        }
      }
    }.freeze

    TUMBLR_AUTHOR_NAME = 'Casie'

    HAML_OUTPUT_PATH = File.expand_path(File.join(__dir__, '..', '..', 'source', 'posts')).freeze

    PICTURE_RELATIVE_PATH = File.join('uploads', 'pictures').freeze

    IMAGE_OUTPUT_PATH = File.expand_path(File.join(__dir__, '..', '..', 'source', PICTURE_RELATIVE_PATH)).freeze

    class << self
      alias __new__ new

      def inherited(subclass)
        class << subclass
          alias new __new__
        end
      end
    end

    def self.new(json)
      post_type = json['type']

      raise ArgumentError, "Unknown post type #{post_type.inspect}." unless VALID_POST_TYPES.include?(post_type)

      post_class = Kernel.const_get("Tumblr::#{post_type.capitalize}")

      post_class.new(json)
    end

    def self.remove_invalid_characters(text)
      INVALID_CHARACTER_MAP.inject(text) { |result, (regex, replacement)| result.gsub(regex, replacement) }
    end

    def self.tumblr_user
      'Casie'
    end

    def initialize(json)
      @json = json

      @tumblr_id = @json['id'].to_s

      begin
        @date = Time.parse(@json['date'])
      rescue ArgumentError, TypeError
        @date = Time.now
      end

      @tags = @json['tags']

      @tags << 'tumblr'

      if @json['trail'] && @json['trail'].length > 1 && @json.dig('reblog', 'tree_html').present?
        @reblogged = true
        @tags << 'reblogged'
      else
        @reblogged = false
      end

      @photos = []

      @photo_map = {}
    end

    def download_photos!
      return if @json['photos'].nil?

      @photo_map = {}

      @photos = @json['photos'].map do |photo|
        next if photo['original_size'].nil?

        url = photo['original_size']['url']

        next if url.nil?

        puts "Downloading photo #{url}"

        response = HTTParty.get(url)

        raise "Error downloading \"#{url}\": #{response.code} - #{response.message}" unless response.code == 200

        data = response.body

        fingerprint = Digest::MD5.hexdigest(data)

        original_image_file_name = URI.parse(url).path.split('/').last

        original_image_file_path = File.join(IMAGE_OUTPUT_PATH, original_image_file_name)

        File.open(original_image_file_path, 'w') do |file|
          file.binmode

          file.write(data)
        end

        medium_image_file_name = "medium_#{original_image_file_name}"

        medium_image_file_path = File.join(IMAGE_OUTPUT_PATH, medium_image_file_name)

        medium_image = MiniMagick::Image.open(original_image_file_path)

        medium_image.resize('500x500')

        medium_image.write(medium_image_file_path)

        thumb_image_file_name = "thumb_#{original_image_file_name}"

        thumb_image_file_path = File.join(IMAGE_OUTPUT_PATH, thumb_image_file_name)

        thumb_image = MiniMagick::Image.open(original_image_file_path)

        thumb_image.resize('100x100')

        thumb_image.write(thumb_image_file_path)

        caption = photo['caption']

        caption = @json['caption'] || '' if caption.blank?

        caption = Base.remove_invalid_characters(caption)

        title = Sanitize.clean(caption, SANITIZE_OPTIONS)

        title = Base.remove_invalid_characters(title).strip.gsub(/\s/, ' ').squeeze(' ')

        title = truncate(title.html_safe, escape: false, length: 128, omission: '', separator: ' ')

        title = HTMLEntities.new(:html4).encode(title, :named, :hexadecimal).gsub(/&#x27;|&#39;/, "'")

        title = truncate(title, escape: false, length: 255, omission: '', separator: /\s|&.+;/)

        photo = {
          original_image_path: File.join('/', PICTURE_RELATIVE_PATH, original_image_file_name),
          medium_image_path: File.join('/', PICTURE_RELATIVE_PATH, medium_image_file_name),
          thumb_image_path: File.join('/', PICTURE_RELATIVE_PATH, thumb_image_file_path),
          fingerprint: fingerprint,
          caption: caption,
          title: title
        }

        @photo_map[url] = photo

        photo
      end.compact
    end

    def save!
      title = deduplicate(:title, post_title)

      slug = CGI.unescapeHTML(Sanitize.clean(title)).gsub(/'|"/, '').gsub(' & ', ' and ').delete('&').squeeze(' ').parameterize

      title = if title.include?(':') || title.include?('#')
              "\"#{title}\""
            else
              title
            end

      body = Html2haml::HTML.new(post_body).render
        .gsub(/:(\w+) =>/) { "#{$1}:" }
        .gsub(/\{(.+)\}/) { "{ #{$1} }" }
        .gsub(/: "([^"]+)"(, | })/) { $1.include?("'") ? ": \"#{$1}\"#{$2}" : ": '#{$1}'#{$2}" }
        .gsub(/src: 'http:\/\/conneythecorgi.com\/uploads\/pictures\//, "src: '/uploads/pictures/")
        .gsub(/(\d)\.jpg\?(\d)+'/) { "#{$1}.jpg'" }
        .gsub(/href: 'http:\/\/conneythecorgi.com\/uploads\/pictures\//, "href: '/uploads/pictures/")

      tags = if post_tags.include?('#')
               "\"#{post_tags}\""
             else
               post_tags
             end

      File.open(File.expand_path(File.join(__dir__, '..', '..', 'source', 'posts', "#{slug}.html.haml")), 'w') do |file|
        file.puts '---'
        file.puts "title: #{title}"
        file.puts "date: #{@date.strftime("%Y/%m/%d %H:%M:%S")}"
        file.puts "author: #{TUMBLR_AUTHOR_NAME}"
        file.puts "tumblr_id: #{@tumblr_id}"
        file.puts "tags: #{tags}"
        file.puts '---'
        file.puts
        file.puts body
      end
    end

    private

    def deduplicate(attribute_name, attribute_value)
      return attribute_value if attribute_name == :id || attribute_name == :tumblr_id || !attribute_value.is_a?(String)

      n = 1

      existing_posts = Dir[File.join(HAML_OUTPUT_PATH, '*.html.haml')].map do |post_path|
        lines = File.readlines(post_path)

        attributes_index = lines.drop(1).index("---\n")

        attributes = lines[1..attributes_index].each_with_object({}) do |v, h|
          name, *value = v.split(": ")
          h[name] = value.join(': ').chomp.gsub(/\A\"|\"\z/, '')
        end

        attributes['slug'] = File.basename(post_path, '.html.haml')

        attributes
      end

      original_attribute_value = attribute_value

      loop do
        duplicate = existing_posts.find { |existing_post| existing_post[attribute_name.to_s] == attribute_value }

        break if duplicate.nil? || duplicate['tumblr_id'] == @tumblr_id

        attribute_value = "#{original_attribute_value} #{n}"

        n += 1
      end

      attribute_value
    end

    def post_body
      @body = '' if @body.nil?

      @body = Base.remove_invalid_characters(@body).gsub(/\s/, ' ').gsub(/&#x27;|&#39;/, "'").squeeze(' ').strip
    end

    def post_tags
      @tags.map { |tag| HTMLEntities.new(:html4).encode(tag, :named, :hexadecimal) }.join(', ')
    end

    def post_title
      @title = "Tumblr post from #{@date.strftime('%-m/%-d/%Y')} at #{@date.strftime('%l:%M:%S %p').strip}" if @title.blank?

      @title = Base.remove_invalid_characters(@title).gsub(/\s/, ' ').squeeze(' ').strip

      @title = Sanitize.fragment(@title, SANITIZE_OPTIONS)

      @title = truncate(@title.html_safe, escape: false, length: 64, omission: '', separator: ' ')

      @title = HTMLEntities.new(:html4).encode(@title, :named, :hexadecimal).gsub(/&#x27;|&#39;/, "'").gsub('&amp;amp;', '&amp;')

      @title = truncate(@title, escape: false, length: 128, omission: '', separator: /\s|&.+;/)

      @title = @title.gsub(/\Aconneythecorgi: /, '')

      @title
    end
  end
end

require_relative 'answer'
require_relative 'audio'
require_relative 'chat'
require_relative 'link'
require_relative 'photo'
require_relative 'quote'
require_relative 'text'
require_relative 'video'
