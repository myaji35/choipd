require "test_helper"

class ChopdCtaContrastTest < ActionDispatch::IntegrationTest
  test "education renders the CTA and active filter colors with sufficient contrast" do
    get education_path

    assert_response :success
    styles = css_select("style").map(&:text).join("\n")
    cta_rule = styles[/(?:^|\})\s*\.nav-cta\s*\{([^}]+)\}/, 1]
    active_filter_rule = styles[/(?:^|\})\s*\.filter-pill\.active\s*\{([^}]+)\}/, 1]

    assert cta_rule, "Expected a .nav-cta rule in the page styles"
    assert_match(/(?:\A|;)\s*color:\s*#0a0e1a\s*(?:;|\z)/, cta_rule)
    assert_match(/(?:\A|;)\s*background:\s*#ff4d1c\s*(?:;|\z)/, cta_rule)
    assert active_filter_rule, "Expected a .filter-pill.active rule in the page styles"
    assert_match(/(?:\A|;)\s*color:\s*#0a0e1a\s*(?:;|\z)/, active_filter_rule)

    %w[ff4d1c ff7850].each do |background|
      ratio = contrast_ratio("0a0e1a", background)
      assert_operator ratio, :>=, 4.5, format("#0a0e1a on #%s has a contrast ratio of %.4f:1", background, ratio)
    end
  end

  private

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
