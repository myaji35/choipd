require "test_helper"

class InquirySubmitContrastTest < ActionDispatch::IntegrationTest
  test "inquiry submit colors meet WCAG contrast in default and hover states" do
    get new_inquiry_path

    assert_response 200
    assert_select "input[type=submit][value='문의 접수하기']", count: 1 do |inputs|
      classes = inputs.first["class"].to_s.split
      assert_includes classes, "bg-coral"
      assert_includes classes, "hover:bg-coral-light"
      assert_includes classes, "text-dark"
      refute_includes classes, "text-white"
    end

    layout = Rails.root.join("app/views/layouts/chopd.html.erb").read
    colors = layout[/tailwind\.config\s*=\s*\{[^<]*?\bcolors\s*:\s*\{([^}]+)\}/, 1]
    assert colors, "Expected a colors block in tailwind.config"

    dark = color_hex(colors, "dark")
    %w[coral coral-light].each do |background|
      ratio = contrast_ratio(dark, color_hex(colors, background))
      assert_operator ratio, :>=, 4.5, format("dark on %s has a contrast ratio of %.4f:1", background, ratio)
    end
  end

  private

  def color_hex(colors, name)
    key = Regexp.escape(name)
    hex = colors[/^\s*(?:#{key}|'#{key}'|"#{key}")\s*:\s*['"]#([0-9a-fA-F]{6})['"]/, 1]
    assert hex, "Expected a hex color for #{name} in tailwind.config"
    hex
  end

  def contrast_ratio(first, second)
    darker, lighter = [ relative_luminance(first), relative_luminance(second) ].sort
    (lighter + 0.05) / (darker + 0.05)
  end

  def relative_luminance(hex)
    red, green, blue = hex.scan(/../).map do |pair|
      channel = pair.to_i(16) / 255.0
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end

    0.2126 * red + 0.7152 * green + 0.0722 * blue
  end
end
