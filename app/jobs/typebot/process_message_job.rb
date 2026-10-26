# frozen_string_literal: true

require 'redis'
require 'securerandom'

module Typebot
  class ProcessMessageJob < ApplicationJob
    queue_as :default

    ASSIGNMENT_BODY = '(?:(?:queue|team|fila|agent|agente)\s*:\s*\d+\s*,?\s*)+'
    ASSIGNMENT_DIRECTIVE = /\[\[\s*(#{ASSIGNMENT_BODY})\s*\]\]|\{\{\s*(#{ASSIGNMENT_BODY})\s*\}\}/i
    ASSIGNMENT_PAIR = /(queue|team|fila|agent|agente)\s*:\s*(\d+)/i

    def perform(message_id)
      message = Message.find_by(id: message_id)
      return unless message&.incoming?
      return if message.content_attributes&.dig('bot_response')
      return if message.content_attributes&.dig('campaign_id')
      return if message.content.blank?
      return unless Typebot::ConversationPolicy.bot_enabled?(message.conversation)

      config = Typebot::AgentBotConfig.for_inbox(message.inbox)
      return unless config.valid?

      lock_key = "typebot:conversation:#{message.conversation_id}"
      return unless with_lock(lock_key) do
        process(message, config)
      end
    rescue StandardError => e
      Rails.logger.error("[Typebot] message #{message_id} failed: #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace&.first(8)&.join("\n"))
    end

    private

    def process(message, config)
      conversation = message.conversation
      record = TypebotConversation.find_or_initialize_by(conversation_id: conversation.id)
      client = Typebot::Client.new
      variables = prefilled_variables(message, config)

      response =
        if record.session_id.present?
          client.continue_chat(record.session_id, message: message.content)
        else
          client.start_chat(config.public_id, message: message.content, prefilled_variables: variables)
        end

      if response['error'] == 'session_not_found'
        record.destroy if record.persisted?
        response = client.start_chat(config.public_id, message: message.content, prefilled_variables: variables)
        record = TypebotConversation.new(conversation_id: conversation.id)
      end

      session_id = response['sessionId'] || record.session_id
      unless session_id.present?
        Rails.logger.warn("[Typebot] no sessionId for conversation #{conversation.id}")
        return
      end

      record.assign_attributes(
        session_id: session_id,
        typebot_id: config.public_id,
        last_activity_at: Time.current
      )
      record.save!

      Array(response['messages']).each do |chat_message|
        content = format_chat_message(chat_message)
        next if content.blank?

        content = apply_assignments(conversation, content)
        next if content.blank?

        conversation.messages.create!(
          account_id: conversation.account_id,
          inbox_id: conversation.inbox_id,
          message_type: :outgoing,
          content: content.truncate(150_000),
          content_attributes: { 'bot_response' => true }
        )
      end

      input_hint = format_input_hint(response['input'])
      if input_hint.present?
        conversation.messages.create!(
          account_id: conversation.account_id,
          inbox_id: conversation.inbox_id,
          message_type: :outgoing,
          content: input_hint.truncate(150_000),
          content_attributes: { 'bot_response' => true }
        )
      end

      record.destroy if response['input'].blank?
    end

    def prefilled_variables(message, config)
      conversation = message.conversation
      contact = conversation.contact
      inbox = conversation.inbox
      channel = inbox&.channel
      account = conversation.account
      workspace = TypebotAccountWorkspace.find_by(account_id: conversation.account_id)

      {
        'contact_name' => contact&.name,
        'contact_first_name' => contact&.name&.split&.first,
        'contact_last_name' => contact&.last_name,
        'contact_phone' => contact&.phone_number,
        'contact_email' => contact&.email,
        'contact_id' => contact&.id,
        'contact_identifier' => contact&.identifier,
        'contact_type' => contact&.contact_type,
        'contact_country_code' => contact&.country_code,
        'contact_city' => contact&.additional_attributes&.dig('city'),
        'contact_country' => contact&.additional_attributes&.dig('country'),
        'contact_description' => contact&.additional_attributes&.dig('description'),
        'contact_company_name' => contact&.additional_attributes&.dig('company_name'),
        'contact_labels' => contact&.labels&.map(&:name)&.join(', '),
        'contact_custom_attributes' => contact&.custom_attributes&.to_json,
        'contact_additional_attributes' => contact&.additional_attributes&.to_json,
        'conversation_id' => conversation.id,
        'conversation_display_id' => conversation.display_id,
        'conversation_status' => conversation.status,
        'conversation_priority' => conversation.priority,
        'conversation_labels' => conversation.labels&.map(&:name)&.join(', '),
        'conversation_custom_attributes' => conversation.custom_attributes&.to_json,
        'conversation_additional_attributes' => conversation.additional_attributes&.to_json,
        'team_id' => conversation.team_id,
        'team_name' => conversation.team&.name,
        'assignee_id' => conversation.assignee_id,
        'assignee_name' => conversation.assignee&.name,
        'inbox_id' => conversation.inbox_id,
        'inbox_name' => inbox&.name,
        'inbox_channel_type' => inbox&.channel_type,
        'inbox_phone_number' => channel&.try(:phone_number),
        'inbox_timezone' => inbox&.timezone,
        'account_id' => conversation.account_id,
        'account_name' => account&.name,
        'account_locale' => account&.locale,
        'account_timezone' => account&.custom_attributes&.dig('timezone'),
        'typebot_id' => config.public_id,
        'typebot_workspace_id' => workspace&.workspace_id,
        'chatbot_id' => config.public_id,
        'chatbot_workspace_id' => workspace&.workspace_id
      }.compact
        .merge(flattened_attributes('contact_custom', contact&.custom_attributes))
        .merge(flattened_attributes('contact_additional', contact&.additional_attributes))
        .merge(flattened_attributes('conversation_custom', conversation.custom_attributes))
        .merge(flattened_attributes('conversation_additional', conversation.additional_attributes))
    end

    def flattened_attributes(prefix, attributes)
      return {} unless attributes.respond_to?(:each)

      attributes.each_with_object({}) do |(key, value), result|
        next if value.nil? || value == ''

        name = "#{prefix}_#{key.to_s.gsub(/[^0-9A-Za-z_]+/, '_').downcase}"
        result[name] = value.is_a?(Hash) || value.is_a?(Array) ? value.to_json : value.to_s
      end
    end

    def apply_assignments(conversation, content)
      directives = content.scan(ASSIGNMENT_DIRECTIVE).flatten.compact
      return content if directives.empty?

      team_id = nil
      agent_id = nil

      directives.each do |directive|
        directive.scan(ASSIGNMENT_PAIR).each do |key, value|
          case key.downcase
          when 'queue', 'team', 'fila'
            team_id = value.to_i
          when 'agent', 'agente'
            agent_id = value.to_i
          end
        end
      end

      assign_conversation(conversation, team_id: team_id, agent_id: agent_id)
      content.gsub(ASSIGNMENT_DIRECTIVE, '').strip
    end

    def assign_conversation(conversation, team_id:, agent_id:)
      account = conversation.account
      team = team_id && account.teams.find_by(id: team_id)
      agent = agent_id && account.users.find_by(id: agent_id)

      if team_id && team.nil?
        Rails.logger.warn("[Typebot] team #{team_id} not found for account #{account.id}")
      end
      if agent_id && agent.nil?
        Rails.logger.warn("[Typebot] agent #{agent_id} not found for account #{account.id}")
      end
      if agent && !assignable_agent?(conversation, agent)
        Rails.logger.warn("[Typebot] agent #{agent.id} is not assignable to inbox #{conversation.inbox_id}")
        agent = nil
      end

      handoff = { assignee_agent_bot_id: nil, ai_assignee_type: nil }
      conversation.update!(handoff.merge(team_id: team.id)) if team
      if agent
        conversation.update!(
          handoff.merge(assignee_id: agent.id, status: :open, waiting_since: conversation.waiting_since || Time.current)
        )
      end
      return unless team || agent

      Typebot::ConversationPolicy.mark_handoff!(conversation, team_id: team&.id, agent_id: agent&.id)
      TypebotConversation.where(conversation_id: conversation.id).delete_all

      Rails.logger.info(
        "[Typebot] conversation #{conversation.id} assigned team=#{team&.id || '-'} agent=#{agent&.id || '-'}"
      )
    rescue StandardError => e
      Rails.logger.error("[Typebot] assignment for conversation #{conversation.id} failed: #{e.class}: #{e.message}")
    end

    def assignable_agent?(conversation, agent)
      conversation.inbox.members.exists?(id: agent.id) || conversation.account.administrators.exists?(id: agent.id)
    end

    def format_chat_message(chat_message)
      case chat_message['type']
      when 'text'
        content = chat_message['content'] || {}
        content['markdown'].presence || rich_text_to_s(content['richText'])
      when 'image', 'video', 'audio'
        url = chat_message.dig('content', 'url')
        url.present? ? "#{chat_message['type']}: #{url}" : nil
      when 'embed'
        chat_message.dig('content', 'url')
      when 'custom-embed'
        chat_message.dig('content', 'url')
      else
        chat_message.dig('content', 'markdown').presence || chat_message.dig('content', 'text')
      end
    end

    def rich_text_to_s(rich_text)
      return if rich_text.blank?

      text = rich_text.is_a?(String) ? rich_text : rich_text.to_json
      text.gsub(/<[^>]+>/, ' ').squish
    end

    def format_input_hint(input)
      return if input.blank?

      items = input['items'] || input['options'] || input['choices']
      return unless items.is_a?(Array) && items.any?

      labels = items.filter_map do |item|
        next unless item.is_a?(Hash)

        item['content'].presence || item['title'].presence || item['label'].presence
      end
      return if labels.empty?

      "Opções: #{labels.each_with_index.map { |label, index| "#{index + 1}) #{label}" }.join(' | ')}"
    end

    def with_lock(key)
      redis = Redis.new(Redis::Config.app)
      token = SecureRandom.hex(8)
      return false unless redis.set(key, token, nx: true, ex: 90)

      begin
        yield
      ensure
        redis.del(key) if redis.get(key) == token
      end
    ensure
      redis&.close
    end
  end
end
