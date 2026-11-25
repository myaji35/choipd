require "test_helper"

class EducationFilterTest < ActionDispatch::IntegrationTest
  setup do
    @online = Course.create!(title: "Education filter published online", course_type: "online", published: true)
    @offline = Course.create!(title: "Education filter published offline", course_type: "offline", published: true)
    @b2b = Course.create!(title: "Education filter published b2b", course_type: "b2b", published: true)
    @unpublished = Course.create!(title: "Education filter unpublished online", course_type: "online", published: false)
  end

  test "shows all published courses with no filter" do
    get education_path
    assert_courses_and_filter [ @online, @offline, @b2b ], "전체"
  end

  test "shows only published courses of each selected type" do
    { "온라인" => @online, "오프라인" => @offline, "B2B/B2G" => @b2b }.each do |label, course|
      get education_path, params: { type: course.course_type }
      assert_courses_and_filter [ course ], label
    end
  end

  test "shows all published courses with an unknown or empty filter" do
    [ "foo", "" ].each do |type|
      get education_path, params: { type: type }
      assert_courses_and_filter [ @online, @offline, @b2b ], "전체"
    end
  end

  test "shows the empty state with an inquiry link when no courses are published" do
    Course.update_all(published: false)

    get education_path

    assert_response :success
    assert_select ".empty-state", count: 1 do
      assert_select "a[href=?]", new_inquiry_path(type: "b2b"), text: "원하는 강좌 문의하기", count: 1
    end
    assert_select ".course-title", count: 0
  end

  test "hides the empty state and its inquiry link when courses are published" do
    get education_path

    assert_response :success
    assert_select ".empty-state", count: 0
    assert_select ".empty-state-cta", count: 0
  end

  test "empty state text meets WCAG contrast against the page background" do
    Course.update_all(published: false)

    get education_path

    assert_response :success
    assert_select ".empty-state", count: 1
    rule = css_select("style").map(&:text).join("\n")[/(?:^|\})\s*\.empty-state\s*\{([^}]+)\}/, 1]
    flunk "Expected an .empty-state rule in the page styles" unless rule

    color = rule.match(/(?:\A|;)\s*color:\s*rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d*\.?\d+)\s*\)/)
    flunk "Expected an rgba color in the .empty-state rule" unless color

    red, green, blue, alpha = color.captures.map(&:to_f)
    background = [ 0x0a, 0x0e, 0x1a ]
    foreground = [ red, green, blue ].zip(background).map do |text, base|
      text * alpha + base * (1 - alpha)
    end
    ratio = contrast_ratio(foreground, background)

    assert_operator ratio, :>=, 4.5, format("Empty state text on #0a0e1a has a contrast ratio of %.4f:1", ratio)
  end

  private

  def contrast_ratio(first, second)
    darker, lighter = [ relative_luminance(first), relative_luminance(second) ].sort
    (lighter + 0.05) / (darker + 0.05)
  end

  def relative_luminance(rgb)
    red, green, blue = rgb.map do |value|
      channel = value / 255.0
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end

    0.2126 * red + 0.7152 * green + 0.0722 * blue
  end

  def assert_courses_and_filter(courses, label)
    assert_response :success
    assert_equal courses.map(&:title).sort, css_select(".course-title").map(&:text).sort
    assert_select ".course-title", text: @unpublished.title, count: 0
    assert_select ".filter-bar a[aria-current]", count: 1
    assert_select '.filter-bar a.active[aria-current="page"]', text: label, count: 1
  end
end
