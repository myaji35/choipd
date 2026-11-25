module ScanOrganizer
  class Processor
    INSUFFICIENT_FIELDS = "선택한 분류로 읽을 정보가 부족합니다. 원본을 직접 정리해 주세요."

    def initialize(member:, ai:, cloud:, threshold: 0.75)
      @member = member
      @ai = ai
      @cloud = cloud
      @threshold = threshold
    end

    def inspect
      "#<#{self.class} member_id=#{@member.id.inspect}>"
    end

    def process(file)
      item = find_or_create_item(file)
      return item unless claim(item, %w[pending failed])

      with_failure_recording(item, "failed") do
        api_key = setting&.ai_api_key
        raise Http::Error, "스캔 설정과 AI 키를 먼저 등록해 주세요." if api_key.blank?

        bytes = @cloud.download(item.source_file_id)
        result = @ai.classify(api_key: api_key, image_bytes: bytes, mime_type: item.mime_type).symbolize_keys
        category = result.fetch(:category).to_s
        confidence = Float(result.fetch(:confidence))
        known_category = ScanItem::CATEGORIES.include?(category)

        item.assign_attributes(extracted: result, category: known_category ? category : nil, confidence: confidence)
        if confidence < @threshold || !known_category
          item.update!(status: "needs_review", failure_reason: nil)
        else
          store_result!(item, category)
        end
      end
      item
    end

    def resolve!(item, category)
      raise ArgumentError, "다른 회원의 스캔 항목입니다." unless item.member_id == @member.id
      raise ArgumentError, "지원하지 않는 분류입니다." unless ScanItem::CATEGORIES.include?(category)
      return item unless claim(item, "needs_review")

      with_failure_recording(item, "needs_review") do
        raise Http::Error, "스캔 설정을 먼저 저장해 주세요." unless setting

        store_result!(item, category)
      end
      item
    end

    private

    def find_or_create_item(file)
      source_file_id = file.fetch(:id)
      @member.scan_items.find_or_create_by!(source_file_id: source_file_id) do |record|
        record.source_name = file[:name]
        record.mime_type = file[:mime_type]
      end
    rescue ActiveRecord::RecordNotUnique
      @member.scan_items.find_by!(source_file_id: source_file_id)
    end

    def claim(item, statuses)
      claimed = ScanItem.where(id: item.id, status: statuses).update_all(status: "processing", updated_at: Time.current) == 1
      item.reload
      claimed
    end

    def setting
      @member.scan_organizer_setting
    end

    def store_result!(item, category)
      extracted = item.extracted.stringify_keys
      matches_category = extracted["category"] == category
      if !matches_category && category != "document"
        return item.update!(status: "needs_review", failure_reason: INSUFFICIENT_FIELDS)
      end

      fields = matches_category ? extracted["fields"] || {} : {}
      location = case category
      when "business_card"
        contact = Mappers.contact(fields)
        if contact.values_at(:names, :phoneNumbers, :emailAddresses).all?(&:blank?)
          return item.update!(status: "needs_review", failure_reason: INSUFFICIENT_FIELDS)
        end

        @cloud.create_contact(contact)
      when "receipt"
        row = Mappers.receipt_row(fields, item.source_name)
        if row.first(3).all?(&:blank?)
          return item.update!(status: "needs_review", failure_reason: INSUFFICIENT_FIELDS)
        end

        @cloud.append_receipt_row(row)
      when "document"
        @cloud.move_and_rename(file_id: item.source_file_id, **Mappers.document_target(fields, item.source_name))
      end

      item.update!(category: category, status: "processed", result_location: location, processed_at: Time.current, failure_reason: nil)
    end

    def with_failure_recording(item, failure_status)
      yield
    rescue StandardError => error
      reason = if error.is_a?(Http::Error)
        redact_secrets(error.message)
      else
        Rails.logger.warn("ScanOrganizer::Processor #{error.class}")
        "처리 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."
      end
      item.reload.update!(status: failure_status, failure_reason: reason[0, 200])
    end

    def redact_secrets(message)
      reason = message.dup
      [ setting&.ai_api_key, setting&.cloud_refresh_token ].compact_blank.sort_by { |secret| -secret.length }.each do |secret|
        reason.gsub!(secret, "[FILTERED]")
      end
      reason
    end
  end
end
