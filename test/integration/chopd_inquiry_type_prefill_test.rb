require "test_helper"

class ChopdInquiryTypePrefillTest < ActionDispatch::IntegrationTest
  test "preselects a recognized inquiry type" do
    %w[b2b contact].each do |type|
      get new_inquiry_path(type: type)

      assert_response :success
      assert_select 'select[name="inquiry[inquiry_type]"]', count: 1 do
        assert_select "option[value=?][selected]", type, count: 1
      end
    end
  end

  test "leaves the inquiry type blank for missing or unknown types" do
    [ new_inquiry_path, new_inquiry_path(type: "hack") ].each do |path|
      get path

      assert_response :success
      assert_select 'select[name="inquiry[inquiry_type]"]', count: 1 do
        assert_select 'option[selected]:not([value=""])', count: 0
      end
    end
  end
end
