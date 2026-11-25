require "test_helper"

class ChopdFooterHierarchyTest < ActionDispatch::IntegrationTest
  test "education and works footers prioritize list links and emphasize only the inquiry link" do
    [ education_path, works_path ].each do |path|
      get path

      assert_response :success
      assert_select "footer", count: 1 do
        headings = %w[서비스 연락처].map do |label|
          assert_select("div", text: label, count: 1).first
        end
        copyright = assert_select("p", text: /©/, count: 1).first
        bottom_links = %w[교육 미디어 작품].map do |label|
          assert_select("footer > div > div:last-child a", text: label, count: 1).first
        end
        max_secondary_alpha = (headings + [ copyright ] + bottom_links).map { |element| white_alpha(element) }.max

        list_links = assert_select("ul li a").reject { |link| link.text.include?("문의하기") }
        assert_not_empty list_links
        list_links.each do |link|
          alpha = white_alpha(link)
          assert_operator alpha, :>, max_secondary_alpha,
            "#{path} footer link #{link.text.inspect} has alpha #{alpha}, expected above #{max_secondary_alpha}"
        end

        emphasized_links = assert_select("a").reject { |link| inline_color(link).match?(WHITE_RGBA) }
        assert_equal [ [ "B2B/B2G 문의하기", new_inquiry_path ] ],
          emphasized_links.map { |link| [ link.text.strip, link["href"] ] }, "#{path} footer emphasized links"
      end
    end
  end

  private

  WHITE_RGBA = /\Argba\(\s*255\s*,\s*255\s*,\s*255\s*,\s*(\d*\.?\d+)\s*\)\z/

  def inline_color(element)
    color = element["style"].to_s[/(?:\A|;)\s*color\s*:\s*([^;]+)/, 1]
    assert color, "Expected an inline color for #{element.text.strip.inspect}"
    color.strip
  end

  def white_alpha(element)
    alpha = inline_color(element)[WHITE_RGBA, 1]
    assert alpha, "Expected a white rgba color for #{element.text.strip.inspect}"
    alpha.to_f
  end
end
