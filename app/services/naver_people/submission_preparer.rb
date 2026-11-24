module NaverPeople
  class SubmissionPreparer
    class Error < StandardError; end

    TABS = {
      "jobs" => "기본정보", "ename" => "기본정보", "sites" => "기본정보",
      "offices" => "소속/경력", "careers" => "소속/경력",
      "schools" => "학력/수상/자격증", "prizes" => "학력/수상/자격증", "licenses" => "학력/수상/자격증"
    }.freeze

    def initialize(filler: EgoProfile::NaverSubmissionFiller.new)
      @filler = filler
    end

    def call(account)
      submission, job = account.with_lock do
        target = account.naver_people_target
        raise Error, "승인된 최신 초안이 없습니다." unless target&.status == "approved"

        current = TargetSources.new(account).values_for("naver")
        diff = TargetDiff.new(current, target.values)
        raise Error, "바꿀 항목이 없습니다." if diff.items.empty?
        raise Error, "다시 승인 필요" unless target.approved_current?(diff.digest)

        submissions = account.naver_people_submissions
        existing = submissions.where(status: "filled", target_digest: diff.digest).order(id: :desc).first
        return existing if existing
        raise Error, "이미 네이버 수정 신청 화면에 입력 중입니다." if submissions.exists?(status: "preparing")

        job = Array(current["jobs"]).first.to_s.partition("|").first.strip.presence || account.headline
        record = submissions.create!(tenant_id: account.tenant_id, target_digest: diff.digest, items: diff.items.map(&:stringify_keys))
        [ record, job ]
      end

      # Commit the reservation before waiting for ego so SQLite can accept other writes.
      automatic = submission.items.select { |item| automatic?(item) }
      ename = automatic.find { |item| item["field"] == "ename" }&.fetch("after")
      sites = automatic.select { |item| item["field"] == "sites" }.pluck("after")
      result = @filler.call(account: account, job: job, ename: ename, sites: sites)

      account.with_lock do
        submission.with_lock do
          if submission.status == "preparing"
            if approved_for_submission?(account, submission)
              apply_result(submission, automatic, result)
            else
              space_id = result["space_id"].presence
              message = "입력 중 목표 프로필이 바뀌었습니다."
              message += space_id ? " ego 작업 공간 ##{space_id}를 확인 후 닫고 다시 입력하세요." : " 다시 입력하세요."
              submission.update!(status: "failed", ego_space_id: space_id, result_message: message)
            end
          end
        end
      end
      submission
    rescue StandardError => e
      raise unless submission

      submission.with_lock do
        submission.update!(status: "failed", result_message: e.message) if submission.status == "preparing"
      end
      submission
    end

    private

    def approved_for_submission?(account, submission)
      target = account.naver_people_target
      return false unless target

      current = TargetSources.new(account).values_for("naver")
      digest = TargetDiff.new(current, target.values).digest
      target.approved_current?(digest) && digest == submission.target_digest
    end

    def automatic?(item)
      field, action, value = item.values_at("field", "action", "after")
      (field == "ename" && %w[add change].include?(action)) ||
        (field == "sites" && action == "add" && NaverPeopleTarget.http_url?(value))
    end

    def apply_result(submission, automatic, result)
      unless result["ok"] == true && result["space_id"].present?
        submission.update!(status: "failed", result_message: result["reason"].presence || "ego 작업 공간을 확인할 수 없습니다.")
        return
      end

      filled = automatic.select do |item|
        Array(result["filled"]).any? { |entry| entry.values_at("field", "value") == item.values_at("field", "after") }
      end
      failures = Array(result["failed"]).index_by { |entry| entry["value"] }
      manual = (submission.items - filled).map do |item|
        entry = item.slice("label", "action", "before", "after").merge("tab" => TABS.fetch(item["field"]))
        if automatic.include?(item) && (failure = failures[item["after"]])
          entry["reason"] = failure["reason"]
        end
        entry
      end
      submission.update!(status: "filled", ego_space_id: result["space_id"], prepared_at: Time.current,
        filled_items: filled, manual_items: manual)
    end
  end
end
