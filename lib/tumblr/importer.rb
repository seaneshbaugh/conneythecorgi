# frozen_string_literal: true

require 'oauth'
require 'tumblr_client'
require_relative 'base'

module Tumblr
  class Importer
    OAUTH_SETTINGS = {
      site: 'https://www.tumblr.com',
      request_token_path: '/oauth/request_token',
      authorize_path: '/oauth/authorize',
      access_token_path: '/oauth/access_token',
      http_method: :post
    }.freeze

    def import!
      get_posts

      download_photos!

      save_and_update_posts!
    end

    private

    def client
      @client ||= begin
                    Tumblr.configure do |config|
                      config.consumer_key = tumblr_consumer_key
                      config.consumer_secret = tumblr_consumer_secret
                      config.oauth_token = oauth_token
                      config.oauth_token_secret = oauth_token_secret
                    end

                    Tumblr::Client.new(client: :httpclient)
                  end
    end

    def download_photos!
      @tumblr_posts.each(&:download_photos!)
    end

    def get_posts
      @tumblr_posts = []

      offset = 0

      loop do
        tumblr_posts_json = client.posts(tumblr_blog_uri, offset: offset)['posts']

        new_posts = tumblr_posts_json.map { |post_json| Tumblr::Base.new(post_json) }.reject { |post| post.send(:post_tags).include?('cowboycorgi') }

        new_posts.each do |new_post|
          puts "Importing post #{new_post.send(:post_title).inspect}"
        end

        @tumblr_posts += new_posts

        offset += 20

        break unless tumblr_posts_json.present?
      end

      @tumblr_posts
    end

    def oauth_token
      @oauth_token ||= request_token.params[:oauth_token]
    end

    def oauth_token_secret
      @oauth_token_secret ||= request_token.params[:oauth_token_secret]
    end

    def request_token
      @request_token ||= begin
                           consumer = OAuth::Consumer.new(tumblr_consumer_key, tumblr_consumer_secret, OAUTH_SETTINGS)

                           consumer.get_request_token(exclude_callback: true)
                         end
    end

    def save_and_update_posts!
      @tumblr_posts.each do |tumblr_post|
        tumblr_post.save!
      end
    end

    def tumblr_blog_uri
      ENV['TUMBLR_BLOG_URI'] || raise('Environment variable TUMBLR_BLOG_URI not set.')
    end

    def tumblr_consumer_key
      ENV['TUMBLR_CONSUMER_KEY'] || raise('Environment variable TUMBLR_CONSUMER_KEY not set.')
    end

    def tumblr_consumer_secret
      ENV['TUMBLR_CONSUMER_SECRET'] || raise('Environment variable TUMBLR_CONSUMER_SECRET not set.')
    end
  end
end
