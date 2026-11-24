module NaverPeople
  class TargetDiff
    EVIDENCE = {
      "ename" => [ "여권 사본(영문 이름 면)" ],
      "jobs" => [ "재직증명서 또는 사업자등록증" ],
      "offices" => [ "재직증명서 또는 사업자등록증명원(대표자는 사업자등록증)" ],
      "careers" => [ "경력증명서 또는 재직증명서(기간 표시)" ],
      "schools" => [ "졸업증명서" ],
      "prizes" => [ "상장 사본 또는 수상 기사 주소" ],
      "licenses" => [ "자격증 사본 또는 자격 확인서" ],
      "sites" => [ "본인 운영 확인(프로필 화면 캡처 등)" ]
    }.freeze
    MATCH_BY_FIRST_COLUMN = %w[offices careers schools].freeze

    def initialize(current_values, target_values)
      @current = current_values
      @target = target_values
    end

    def items
      @items ||= NaverPeopleTarget::FIELDS.keys.flat_map do |field|
        next [] unless @target.key?(field)

        before, after = @current[field], @target[field]
        if field == "ename"
          before, after = before.presence, after.presence
          before == after ? [] : [ item(field, before, after) ]
        else
          list_items(field, before, after)
        end
      end
    end

    def checklist
      documents = {}
      items.each do |entry|
        entry[:evidence].each do |document|
          (documents[document] ||= []) << entry[:label]
        end
      end
      documents.map { |document, labels| { document: document, for: labels.uniq } }
    end

    def digest
      Digest::SHA256.hexdigest(items.to_json).first(16)
    end

    private

    def indexed(lines)
      Array(lines).sort.index_by { |line| line.squish.gsub(/\s*\|\s*/, "|").downcase }
    end

    def list_items(field, before, after)
      old = indexed(before)
      new = indexed(after)
      removed = (old.keys - new.keys).sort
      added = (new.keys - old.keys).sort
      changes = removed.map do |key|
        replacement = if MATCH_BY_FIRST_COLUMN.include?(field)
          added.find { |candidate| candidate.split("|", 2).first == key.split("|", 2).first }
        end
        added.delete(replacement) if replacement
        item(field, old[key], new[replacement])
      end
      changes + added.map { |key| item(field, nil, new[key]) }
    end

    def item(field, before, after)
      action = before.nil? ? "add" : after.nil? ? "remove" : "change"
      { field: field, label: NaverPeopleTarget::FIELDS.fetch(field), action: action,
        before: before, after: after, evidence: after.nil? ? [] : EVIDENCE.fetch(field) }
    end
  end
end
