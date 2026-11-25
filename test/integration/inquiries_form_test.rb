require "test_helper"

class InquiriesFormTest < ActionDispatch::IntegrationTest
  test "inquiry form uses the chopd color palette" do
    get new_inquiry_path

    assert_response 200
    assert_includes response.body, "bg-coral"
    assert_includes response.body, "text-white"
    refute_includes response.body, "bg-primary"
    refute_includes response.body, "text-navy"
  end

  test "blank inquiry shows Korean presence errors" do
    post inquiries_path, params: { inquiry: { name: "", email: "", message: "", inquiry_type: "" } }

    assert_response 422
    assert_includes response.body, "이름을 입력해 주세요."
    assert_includes response.body, "이메일을 입력해 주세요."
    assert_includes response.body, "문의 내용을 입력해 주세요."
    assert_includes response.body, "문의 유형을 선택해 주세요."
    refute_includes response.body, "can't be blank"
    refute_includes response.body, "이메일 주소 형식이 올바르지 않습니다."
  end
end
