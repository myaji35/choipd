module NaverPeople
  class Applications
    STATUSES = %w[ING END].freeze
    LIST_KEYS = %w[content list items resultList].freeze
    UNLIMITED_END_ON = Date.new(2999, 12, 31)

    def initialize(data, today: Date.current)
      @data = data.is_a?(Hash) ? data : {}
      @applications = @data["applications"].is_a?(Hash) ? @data["applications"] : {}
      @today = today
    end

    def collected?
      @data.key?("applications")
    end

    def in_progress
      entries("ING")
    end

    def completed
      entries("END")
    end

    def errors
      STATUSES.each_with_object({}) do |status, result|
        payload = @applications[status]
        result[status] = payload["error"] if payload.is_a?(Hash) && payload["error"].present?
      end
    end

    def changes_from(older_data)
      older = self.class.new(older_data, today: @today)
      old_progress = older.in_progress.index_by { |entry| identity(entry) }
      old_completed = older.completed.index_by { |entry| identity(entry) }
      progress = in_progress.index_by { |entry| identity(entry) }

      changes = progress.filter_map do |key, entry|
        if old_progress.key?(key)
          status_change(old_progress[key], entry)
        elsif older.comparable?("ING")
          change("new", nil, entry)
        end
      end

      changes + completed.filter_map do |entry|
        key = identity(entry)
        if old_progress.key?(key) && comparable?("ING") && !progress.key?(key)
          change("finished", old_progress[key], entry)
        elsif old_completed.key?(key)
          status_change(old_completed[key], entry)
        end
      end
    end

    def delegation
      auth = @data["auth"]
      end_on = parse_date(auth["delegEndDate"]) if auth.is_a?(Hash)
      end_on = nil if end_on == UNLIMITED_END_ON
      days_left = (end_on - @today).to_i if end_on
      {
        end_on: end_on,
        days_left: days_left,
        unlimited: end_on.nil?,
        expiring: (0..30).cover?(days_left),
        expired: days_left.present? && days_left.negative?
      }
    end

    protected
      def comparable?(status)
        @applications.key?(status) && !errors.key?(status)
      end

    private
      def entries(status)
        payload = @applications[status]
        return [] unless comparable?(status)

        list = payload.is_a?(Hash) ? payload.values_at(*LIST_KEYS).find { |value| value.is_a?(Array) } : payload
        return [] unless list.is_a?(Array)

        list.grep(Hash).map do |raw|
          status_text = first_value(raw, %w[statusName status resultStatus state]).to_s
          {
            id: first_value(raw, %w[id applyId requestId seq]),
            item: first_value(raw, %w[itemName fieldName categoryName applyTypeName title type]),
            applied_on: first_value(raw, %w[applyDate regDate createdAt requestDate]),
            status: status_text,
            rejected: status_text.match?(/REJECT|RETURN|DENY|반려/i),
            reject_reason: first_value(raw, %w[rejectReason rejectMsg reason returnReason comment]),
            raw: raw
          }
        end
      end

      def first_value(raw, keys)
        raw.values_at(*keys).find { |value| (value.is_a?(String) || value.is_a?(Numeric)) && value.present? }
      end

      def identity(entry)
        entry[:id]&.to_s || [ entry[:item], entry[:applied_on] ]
      end

      def change(kind, before, after)
        { kind: kind, item: after[:item] || before&.fetch(:item), before: before&.fetch(:status), after: after[:status] }
      end

      def status_change(before, after)
        change("status_changed", before, after) if before[:status] != after[:status]
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end
  end
end
