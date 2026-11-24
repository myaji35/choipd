require "test_helper"

class NaverPeopleTargetTest < ActiveSupport::TestCase
  setup do
    @account = ProfileAccount.create!(platform: "naver_people", display_name: "가상 인물")
    @target = @account.build_naver_people_target
  end

  test "cleans allowed fields and tolerates broken or non-object JSON" do
    @target.values = {
      "ename" => "  #{'A' * 110} ",
      "jobs" => " 대표   이사 \r\n\n대표 이사\n 기업인 ",
      "schools" => [ "가" * 205, *Array.new(31) { |index| "학교 #{index}" } ],
      "unknown" => "무시"
    }
    @target.save!
    assert_equal "A" * 100, @target.reload.values["ename"]
    assert_equal [ "대표 이사", "기업인" ], @target.values["jobs"]
    assert_equal 30, @target.values["schools"].size
    assert_equal "가" * 200, @target.values["schools"].first
    assert_not @target.values.key?("unknown")

    [ "{", "[]" ].each do |data|
      @target.data = data
      assert_equal({}, @target.values)
    end
  end

  test "accepts HTTP addresses and rejects other schemes and missing hosts" do
    @target.values = { "sites" => "http://example.com\nhttps://example.org" }
    assert @target.valid?

    %w[ftp://example.com example.com https:/x https:// javascript:alert(1)].each do |url|
      @target.values = { "sites" => url }
      assert_not @target.valid?
      assert_includes @target.errors.full_messages.join, "사이트 주소"
    end
  end

  test "keeps approval for equivalent saved values and clears it after a change" do
    @target.update!(values: { "jobs" => "기업인" })
    @target.update!(status: "approved", approved_at: Time.current, approved_draft_digest: "digest")
    @target.update!(values: { "jobs" => " 기업인 \n기업인" })
    assert @target.reload.approved_current?("digest")

    @target.update!(values: { "jobs" => "대표" })
    assert_equal [ "draft", nil, nil ], @target.reload.attributes.values_at("status", "approved_at", "approved_draft_digest")
  end
end
