require "test_helper"

class ChopdGreetingReadabilityTest < ActionDispatch::IntegrationTest
  test "publisher greeting uses the dark theme and a Lineicons user icon" do
    get media_greeting_path
    assert_response :ok

    assert_select "main", count: 1 do |main|
      assert_select ".text-navy, .text-gray-500, .text-gray-700, svg", count: 0
      assert_select "i.lni.lni-user-4[aria-hidden='true']", count: 1

      [ "최범희", "안녕하십니까", "드림" ].each do |text|
        assert_includes main.first.text, text
      end
    end
  end

  test "publisher greeting is public and read-only" do
    get media_greeting_path
    assert_response :ok

    assert_select "main", count: 1 do
      [ "form", "input", "textarea", "select", "button[type=submit]", "a[data-turbo-method]", "a[data-method]" ].each do |selector|
        assert_select selector, count: 0
      end
    end
  end

  test "publisher greeting ends with next-step links" do
    get media_greeting_path
    assert_response :ok

    assert_select "main .greeting-actions", count: 1 do
      assert_select "a.greeting-btn-primary[href=?]", education_path, text: /교육 과정 보기/, count: 1 do
        assert_select "i.lni.lni-arrow-right", count: 1
      end

      assert_select "a.greeting-btn-secondary[href=?]", new_inquiry_path, text: /강좌 문의/, count: 1 do
        assert_select "i.lni.lni-chat-bubble-2", count: 1
      end

      assert_select "a", count: 2
      assert_select "svg", count: 0
    end

    assert_select ".greeting-heading .max-w-3xl", count: 1
  end
end
