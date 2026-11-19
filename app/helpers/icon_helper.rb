module IconHelper
  def lni_icon(name, size: nil, label: nil, class: nil, style: nil)
    if !Rails.env.production? && !lineicon_names.include?(name.to_s)
      raise ArgumentError, "Unknown Lineicons icon: #{name}"
    end

    styles = [ style, ("font-size: #{Integer(size)}px" if size) ].compact.join("; ")
    attributes = { class: [ "lni", "lni-#{name}", binding.local_variable_get(:class) ].compact.join(" "), style: styles.presence }
    attributes.merge!(label.present? ? { "aria-hidden": "false", role: "img", "aria-label": label } : { "aria-hidden": "true" })
    tag.i(**attributes)
  end

  private

  def lineicon_names
    IconHelper.lineicon_names
  end

  def self.lineicon_names
    @lineicon_names ||= Rails.root.join("config/lineicons_names.txt").read.lines.map(&:strip).to_set.freeze
  end
end
