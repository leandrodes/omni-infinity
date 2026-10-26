# frozen_string_literal: true

require 'pg'
require 'securerandom'

module Typebot
  class ProvisionWorkspaceService
    def initialize(account:, client: Typebot::Client.new)
      @account = account
      @client = client
    end

    def perform
      mapping = TypebotAccountWorkspace.find_or_initialize_by(account_id: @account.id)

      if mapping.workspace_id.present?
        begin
          @client.get_workspace(mapping.workspace_id)
          sync_admin_memberships(mapping.workspace_id)
          return mapping
        rescue Typebot::Client::Error => e
          raise unless e.status.to_i == 404

          mapping.update!(workspace_id: nil, workspace_name: nil)
        end
      end

      workspace = find_or_create_workspace
      mapping.update!(
        workspace_id: workspace.fetch('id'),
        workspace_name: workspace['name']
      )
      sync_admin_memberships(mapping.workspace_id)
      mapping
    end

    private

    def workspace_name
      "Conta #{@account.id} - #{@account.name}"
    end

    def find_or_create_workspace
      existing = @client.list_workspaces.find { |workspace| workspace['name'] == workspace_name }
      return existing if existing

      @client.create_workspace(workspace_name)
    rescue Typebot::Client::Error => e
      raise unless e.message.include?('same name')

      @client.list_workspaces.find { |workspace| workspace['name'] == workspace_name } || raise
    end

    def sync_admin_memberships(workspace_id)
      admin_emails = @account.administrators.where.not(email: [nil, '']).pluck(:email).map(&:downcase).uniq
      service_email = ENV.fetch('TYPEBOT_SERVICE_EMAIL', 'typebot-service@infinitytelecom.com.br').downcase

      with_connection do |conn|
        admin_user_ids = admin_emails.to_h do |email|
          result = conn.exec_params('SELECT id FROM "User" WHERE lower(email) = $1 LIMIT 1', [email])
          [email, result.ntuples.positive? ? result[0]['id'] : nil]
        end

        admin_emails.each do |email|
          user_id = admin_user_ids[email]

          if user_id
            conn.exec_params(
              <<~SQL,
                INSERT INTO "MemberInWorkspace" ("userId", "workspaceId", role, "createdAt", "updatedAt")
                VALUES ($1, $2, 'ADMIN'::"WorkspaceRole", now(), now())
                ON CONFLICT ("userId", "workspaceId")
                DO UPDATE SET role = 'ADMIN'::"WorkspaceRole", "updatedAt" = now()
              SQL
              [user_id, workspace_id]
            )
          else
            conn.exec_params(
              <<~SQL,
                INSERT INTO "WorkspaceInvitation" (id, email, "workspaceId", type, "createdAt", "updatedAt")
                SELECT $1, $2, $3, 'ADMIN'::"WorkspaceRole", now(), now()
                WHERE NOT EXISTS (
                  SELECT 1 FROM "WorkspaceInvitation"
                  WHERE lower(email) = $2 AND "workspaceId" = $3
                )
              SQL
              [SecureRandom.hex(12), email, workspace_id]
            )
          end
        end

        allowed_user_ids = admin_user_ids.values.compact
        service_result = conn.exec_params('SELECT id FROM "User" WHERE lower(email) = $1 LIMIT 1', [service_email])
        allowed_user_ids << service_result[0]['id'] if service_result.ntuples.positive?
        allowed_user_ids = allowed_user_ids.compact.uniq

        if allowed_user_ids.empty?
          conn.exec_params('DELETE FROM "MemberInWorkspace" WHERE "workspaceId" = $1', [workspace_id])
        else
          placeholders = Array.new(allowed_user_ids.length) { |i| "$#{i + 2}" }.join(', ')
          conn.exec_params(
            "DELETE FROM \"MemberInWorkspace\" WHERE \"workspaceId\" = $1 AND \"userId\" NOT IN (#{placeholders})",
            [workspace_id, *allowed_user_ids]
          )
        end

        conn.exec_params(
          'DELETE FROM "WorkspaceInvitation" WHERE "workspaceId" = $1 AND lower(email) <> ALL($2::text[])',
          [workspace_id, admin_emails]
        )
      end
    end

    def with_connection
      connection = PG.connect(ENV.fetch('TYPEBOT_DATABASE_URL'))
      yield connection
    ensure
      connection&.close
    end
  end
end
