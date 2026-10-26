# frozen_string_literal: true

require 'net/http'
require 'uri'

module Typebot
  class Client
    class Error < StandardError
      attr_reader :status

      def initialize(message, status: nil)
        @status = status
        super(message)
      end
    end

    def initialize(api_url: nil, viewer_url: nil, token: nil)
      @api_url = api_url || ENV.fetch('TYPEBOT_API_URL', 'http://typebot-builder:3000/api/v1')
      @viewer_url = viewer_url || ENV.fetch('TYPEBOT_VIEWER_INTERNAL_URL', 'http://typebot-viewer:3000/api/v1')
      @token = token || ENV.fetch('TYPEBOT_API_TOKEN', '')
    end

    def list_workspaces
      request(:get, @api_url, 'workspaces').fetch('workspaces', [])
    end

    def get_workspace(workspace_id)
      request(:get, @api_url, "workspaces/#{escape(workspace_id)}").fetch('workspace')
    end

    def create_workspace(name)
      request(:post, @api_url, 'workspaces', body: { name: name }).fetch('workspace')
    end

    def list_typebots(workspace_id)
      query = URI.encode_www_form(workspaceId: workspace_id)
      request(:get, @api_url, "typebots?#{query}").fetch('typebots', [])
    end

    def get_typebot(typebot_id)
      request(:get, @api_url, "typebots/#{escape(typebot_id)}").fetch('typebot')
    end

    def get_published_typebot(typebot_id)
      request(:get, @api_url, "typebots/#{escape(typebot_id)}/publishedTypebot").fetch('publishedTypebot')
    rescue Error => e
      raise unless e.status.to_i == 404

      nil
    end

    def update_typebot(typebot_id, attributes)
      request(
        :patch,
        @api_url,
        "typebots/#{escape(typebot_id)}",
        body: { typebot: attributes }
      ).fetch('typebot')
    end

    def ensure_public_id(typebot)
      return typebot if typebot['publicId'].present?

      update_typebot(typebot['id'], publicId: default_public_id(typebot))
    end

    def start_chat(public_id, message:, prefilled_variables: {})
      request(
        :post,
        @viewer_url,
        "typebots/#{escape(public_id)}/startChat",
        body: {
          message: { type: 'text', text: message.to_s },
          prefilledVariables: prefilled_variables,
          textBubbleContentFormat: 'markdown'
        },
        auth: false
      )
    end

    def continue_chat(session_id, message:)
      request(
        :post,
        @viewer_url,
        "sessions/#{escape(session_id)}/continueChat",
        body: {
          message: { type: 'text', text: message.to_s },
          sessionId: session_id,
          textBubbleContentFormat: 'markdown'
        },
        auth: false
      )
    rescue Error => e
      return { 'error' => 'session_not_found' } if e.status.to_i == 404

      raise
    end

    private

    def default_public_id(typebot)
      suffix = typebot['id'].to_s[-7..].to_s
      prefix = typebot['name'].to_s.parameterize
      [prefix.presence, suffix].compact.join('-')
    end

    def escape(value)
      URI.encode_www_form_component(value.to_s)
    end

    def request(method, base_url, path, body: nil, auth: true)
      uri = URI.join(base_url.end_with?('/') ? base_url : "#{base_url}/", path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 5
      http.read_timeout = 30

      request = case method
                when :get then Net::HTTP::Get.new(uri)
                when :post then Net::HTTP::Post.new(uri)
                when :patch then Net::HTTP::Patch.new(uri)
                else raise ArgumentError, "Unsupported HTTP method: #{method}"
                end

      request['Accept'] = 'application/json'
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@token}" if auth && @token.present?
      request.body = JSON.generate(body) if body

      response = http.request(request)
      parsed = response.body.present? ? JSON.parse(response.body) : {}

      return parsed if response.is_a?(Net::HTTPSuccess)

      message = parsed.is_a?(Hash) ? (parsed['message'] || parsed['error'] || response.body) : response.body
      raise Error.new("#{method.upcase} #{uri.path} failed (#{response.code}): #{message}", status: response.code.to_i)
    rescue JSON::ParserError => e
      raise Error.new("Invalid JSON from Typebot: #{e.message}", status: response&.code&.to_i)
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => e
      raise Error.new("Typebot request failed: #{e.message}")
    end
  end
end
