module NaverPeople
  class Differ
    def initialize(old_data, new_data)
      @old = Presenter.new(old_data)
      @new = Presenter.new(new_data)
    end

    def changes
      changes = []
      old_scalars = @old.scalar_values.merge(Presenter::SITES.keys.index_with { |key| scalar(@old.people[key]) })
      new_scalars = @new.scalar_values.merge(Presenter::SITES.keys.index_with { |key| scalar(@new.people[key]) })
      old_scalars.each do |key, before|
        after = new_scalars[key]
        next if before == after
        changes << { section: Presenter::SITES.key?(key) ? "사이트" : "기본정보", kind: "changed", label: Presenter::SCALARS[key] || Presenter::SITES[key], before: before, after: after }
      end
      Presenter::ARRAYS.each do |key, section|
        old_items = indexed(@old, key)
        new_items = indexed(@new, key)
        (old_items.keys | new_items.keys).each do |identity|
          before, after = old_items[identity], new_items[identity]
          next if before == after
          changes << { section: section, kind: before.nil? ? "added" : after.nil? ? "removed" : "changed", label: section, before: before, after: after }
        end
      end
      changes
    end

    private
      def scalar(value) = value.is_a?(String) || value.is_a?(Numeric) ? value.to_s.strip : ""
      def indexed(presenter, key)
        presenter.entries(key).each_with_object({}) do |item, result|
          rendered = presenter.render_item(key, item.reject { |k, _| (k.to_s.include?("Img") && k.to_s != "profileImgFull") || %w[contentsWeight contentsRank dupChk].include?(k) })
          id = scalar(item["id"])
          result[id.present? ? "id:#{id}" : "value:#{rendered}"] = rendered
        end
      end
  end
end
