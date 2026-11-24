module Linkedin
  class ProfileDiffer
    def initialize(older_data, newer_data)
      @older = older_data
      @newer = newer_data
    end

    def changes
      basic_changes +
        item_changes(:experiences, %i[company title], %i[period description employment_type location]) +
        item_changes(:education, %i[school], %i[major period skills_text]) +
        item_changes(:skills) +
        item_changes(:certifications, %i[name], %i[issuer issued])
    end

    private

    def basic_changes
      return [] if @older[:basics].nil? || @newer[:basics].nil?

      before = @older[:basics].presence || {}
      after = @newer[:basics].presence || {}
      ProfilePresenter::BASIC_LABELS.filter_map do |key, label|
        next if before[key].to_s == after[key].to_s

        { section: "기본정보", kind: "changed", label: label, before: before[key], after: after[key] }
      end
    end

    def item_changes(section, identity = [], tracked_fields = [])
      return [] if @older[section].nil? || @newer[section].nil?

      before_items = index_items(@older[section], identity)
      after_items = index_items(@newer[section], identity)
      (before_items.keys | after_items.keys).filter_map do |key|
        before, after = before_items[key], after_items[key]
        next if before && after && (tracked_fields.empty? || before.values_at(*tracked_fields) == after.values_at(*tracked_fields))

        {
          section: ProfilePresenter::SECTIONS.fetch(section),
          kind: before.nil? ? "added" : after.nil? ? "removed" : "changed",
          label: Array(identity.empty? ? key : key.first).join(" · "),
          before: (ProfilePresenter.render_item(section, before) if before),
          after: (ProfilePresenter.render_item(section, after) if after)
        }
      end
    end

    def index_items(items, identity)
      return items.index_by(&:itself) if identity.empty?

      occurrences = Hash.new(0)
      items.index_by do |item|
        fields = item.values_at(*identity)
        [ fields, occurrences[fields] += 1 ]
      end
    end
  end
end
