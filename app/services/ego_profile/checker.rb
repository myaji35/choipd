module EgoProfile
  class Checker
    Result = Struct.new(:platform, :logged_in, :accounts_count, :changed_count, :error, keyword_init: true) do
      def summary
        label = ProfileAccount::PLATFORMS[platform] || platform
        status = if error.present?
          "오류: #{error}"
        elsif logged_in
          "로그인됨 · 계정 #{accounts_count}개 · 변경 사본 #{changed_count}개"
        else
          "로그인 필요"
        end
        "[#{label}] #{status}"
      end
    end

    def initialize(runner: Runner.new, tenant_id: 1)
      @runner, @tenant_id = runner, tenant_id
    end

    def call(platform)
      raise Error, "알 수 없는 플랫폼: #{platform}" unless ProfileAccount::PLATFORMS.key?(platform)
      accounts = ProfileAccount.where(tenant_id: @tenant_id, platform: platform)
      begin
        response = if platform == "naver_people"
          known_accounts = accounts.where.not(external_id: [ nil, "" ]).to_a
          queries_by_account = known_accounts.each_with_object({}) do |account, queries|
            next unless account.is_active?

            list = account.search_query_list
            queries[account.external_id.to_s] = list if list.any?
          end
          @runner.call(platform, search_queries_by_account: queries_by_account,
                       default_search_accounts: known_accounts.size - queries_by_account.size)
        else
          @runner.call(platform)
        end
      rescue Error => e
        response = { "error" => e.message }
      end
      now = Time.current
      result = Result.new(platform: platform, logged_in: false, accounts_count: 0, changed_count: 0)
      ProfileAccount.transaction do
        if response["error"].present?
          result.error = response["error"].first(500)
          accounts.update_all(session_status: "error", last_error: result.error, last_checked_at: now, updated_at: now)
        elsif !response["logged_in"]
          accounts.update_all(session_status: "logged_out", last_error: nil, last_checked_at: now, updated_at: now)
        else
          result.logged_in = true
          response.fetch("accounts", []).each do |attributes|
            account = accounts.find_or_initialize_by(external_id: attributes["external_id"])
            account.assign_attributes(attributes.slice("login_id", "display_name", "headline", "profile_url", "auth_status"))
            account.assign_attributes(session_status: "logged_in", last_checked_at: now, last_error: nil)
            account.save!
            data = attributes["data"]
            latest_snapshot = account.latest_snapshot
            if latest_snapshot.nil? || data != latest_snapshot.data
              account.profile_snapshots.create!(tenant_id: @tenant_id, captured_at: now, source: "ego", data: data)
              result.changed_count += 1
            end
            result.accounts_count += 1
          end
        end
      end
      result
    end
  end
end
