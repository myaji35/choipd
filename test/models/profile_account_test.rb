require "test_helper"

class ProfileAccountTest < ActiveSupport::TestCase
  test "search queries are normalized and stored as a JSON list" do
    account = ProfileAccount.create!(platform: "naver_people", display_name: "검색 인물")
    assert_empty account.search_query_list
    long_query = "가" * 51
    account.update!(search_query_list: [ "  강승식   가가호호 ", "강승식 가가호호", "\t", nil, long_query, *("1".."10").to_a ])
    assert_equal [ "강승식 가가호호", "가" * 50, *("1".."8").to_a ], account.reload.search_query_list
    assert_equal account.search_query_list, JSON.parse(account.search_queries)

    [ "{깨진 JSON", "{}", "null", "" ].each do |value|
      account.search_queries = value
      assert_empty account.search_query_list
    end
    account.update!(search_query_list: [])
    assert_nil account.reload.search_queries
  end

  test "validations and labels" do
    account = ProfileAccount.new(platform: "naver_people", display_name: "가상 인물")
    assert account.valid?
    assert_equal "네이버 인물정보", account.platform_label
    assert_equal "미점검", account.session_status_label
    account.platform = "invalid"
    account.session_status = "invalid"
    account.display_name = ""
    assert_not account.valid?
    assert_equal [ :display_name, :platform, :session_status ], account.errors.attribute_names.sort
  end

  test "external id is unique per tenant and platform and may be blank" do
    ProfileAccount.create!(platform: "linkedin", display_name: "가상 인물", external_id: "fake-id")
    duplicate = ProfileAccount.new(platform: "linkedin", display_name: "다른 인물", external_id: "fake-id")
    assert_not duplicate.valid?
    duplicate.tenant_id = 2
    assert duplicate.valid?
    duplicate.tenant_id = 1
    duplicate.platform = "naver_people"
    assert duplicate.valid?
    duplicate.platform = "linkedin"
    duplicate.external_id = nil
    assert duplicate.valid?
  end
end
