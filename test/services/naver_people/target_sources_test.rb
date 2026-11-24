require "test_helper"

class NaverPeople::TargetSourcesTest < ActiveSupport::TestCase
  setup do
    @account = ProfileAccount.create!(platform: "naver_people", display_name: "가상 인물", tenant_id: 2)
  end

  test "imports only available Naver fields from the newest snapshot" do
    @account.profile_snapshots.create!(captured_at: 1.day.ago, data: { "people" => { "ename" => "Old" } })
    @account.profile_snapshots.create!(captured_at: Time.current, data: { "people" => {
      "ename" => "New", "peopleJob" => [ { "nameTx" => "기업인" } ],
      "peopleOffice" => [ { "name" => "누리팜", "position" => "대표" } ],
      "peopleCareer" => [
        { "startDate" => "202408", "current" => "Y", "comment" => "누리팜 대표" },
        { "startDate" => "200003", "endDate" => "200702", "comment" => "겸임교수" }
      ],
      "peopleSchool" => [ { "name" => "한국대학", "major" => "전산", "degree" => "학사" } ],
      "peoplePrize" => [ { "name" => "가상상", "date" => 2020 } ],
      "peopleLicense" => [ { "name" => "가상 자격증", "date" => "2020" } ],
      "blog" => "https://blog.example", "peopleSite" => [ { "url" => "https://site.example" } ]
    } })
    assert_equal({
      "ename" => "New", "jobs" => [ "기업인" ], "offices" => [ "누리팜 | 대표" ],
      "careers" => [ "2024.08~현재 | 누리팜 대표", "2000.03~2007.02 | 겸임교수" ],
      "schools" => [ "한국대학 | 전산 | 학사" ], "prizes" => [ "가상상 | 2020" ],
      "licenses" => [ "가상 자격증 | 2020" ], "sites" => %w[https://blog.example https://site.example]
    }, NaverPeople::TargetSources.new(@account).values_for("naver"))
  end

  test "imports LinkedIn from the latest active matching member and tenant" do
    member = create_member("same")
    @account.update!(member: member)
    pages = %w[experience education certifications_filled].to_h do |name|
      [ name.delete_suffix("_filled"), { "text" => file_fixture("linkedin/#{name}.txt").read } ]
    end

    [
      [ 2, member, true, "https://linkedin.example/right", 1.day.ago ],
      [ 2, member, false, "https://linkedin.example/inactive", Time.current ],
      [ 1, member, true, "https://linkedin.example/other-tenant", Time.current ],
      [ 2, nil, true, "https://linkedin.example/other-member", Time.current ]
    ].each do |tenant, owner, active, url, captured_at|
      account = ProfileAccount.create!(platform: "linkedin", display_name: "가상 인물", tenant_id: tenant,
        member: owner, is_active: active, profile_url: url)
      account.profile_snapshots.create!(captured_at: captured_at, data: { "pages" => pages })
    end

    values = NaverPeople::TargetSources.new(@account).values_for("linkedin")
    assert_equal [ "https://linkedin.example/right" ], values["sites"]
    assert_includes values["offices"], "한빛랩 | CTO"
    assert_includes values["careers"], "2026.07~현재 | 한빛랩 CTO"
    assert_includes values["careers"], "2024~현재 | (주)새솔 대표이사"
    assert_includes values["schools"], "한국대학 | Computer Engineering"
    assert_includes values["licenses"], "데이터 분석 전문가 | 2024"
  end

  test "imports career lines with missing, non-string, and partial dates" do
    sources = NaverPeople::TargetSources.new(@account)
    def sources.linkedin_profile
      periods = [ nil, 2024, "2019년 - 2021년", "2019년 3월 - 2021년" ]
      { experiences: periods.map { |period| { company: "한빛랩", title: "CTO", period: period } } }
    end

    assert_equal [ "한빛랩 CTO", "한빛랩 CTO", "2019~2021 | 한빛랩 CTO", "2019.03~2021 | 한빛랩 CTO" ],
      sources.values_for("linkedin")["careers"]
  end

  test "uses an unlinked LinkedIn account only when exactly one active account matches the tenant" do
    linkedin = ProfileAccount.create!(platform: "linkedin", display_name: "LinkedIn 1", tenant_id: 2,
      profile_url: "https://linkedin.example/one")
    linkedin.profile_snapshots.create!(captured_at: Time.current, data: {
      "pages" => { "experience" => { "text" => file_fixture("linkedin/experience.txt").read } }
    })
    ProfileAccount.create!(platform: "linkedin", display_name: "Inactive", tenant_id: 2, is_active: false)
    ProfileAccount.create!(platform: "linkedin", display_name: "Other tenant", tenant_id: 1)
    assert_equal [ "https://linkedin.example/one" ], NaverPeople::TargetSources.new(@account).values_for("linkedin")["sites"]

    ProfileAccount.create!(platform: "linkedin", display_name: "LinkedIn 2", tenant_id: 2)
    assert_empty NaverPeople::TargetSources.new(@account).values_for("linkedin")
    cross_check = NaverPeople::CrossCheck.new(@account)
    assert_nil cross_check.linkedin_mismatches
    assert_empty cross_check.sites
  end

  test "imports imPD from a linked member or unique same-tenant name" do
    other_tenant = create_member("other", tenant: 1)
    assert_equal({}, NaverPeople::TargetSources.new(@account).values_for("impd"))

    member = create_member("same")
    brand = Brand.create!(name: "가상 브랜드", member_id: member.id, tenant_id: 2)
    brand.brand_channels.create!(platform: "naver_blog", profile_url: "https://brand.example")
    member.sns_accounts.create!(platform: "linkedin", account_name: "계정 이름", tenant_id: 2)

    values = NaverPeople::TargetSources.new(@account).values_for("impd")
    assert_equal [ "작가" ], values["jobs"]
    assert_equal %w[https://brand.example https://impd.townin.net/same https://social.example], values["sites"].sort
    refute_includes values["sites"], "https://impd.townin.net/#{other_tenant.slug}"

    create_member("duplicate")
    assert_equal({}, NaverPeople::TargetSources.new(@account).values_for("impd"))
    @account.update!(member: member)
    assert_equal values, NaverPeople::TargetSources.new(@account).values_for("impd")
    assert_equal({}, NaverPeople::TargetSources.new(@account).values_for("unknown"))
  end

  test "uses the latest Naver English name to find one same-tenant imPD member" do
    @account.profile_snapshots.create!(captured_at: 1.day.ago, data: { "people" => { "ename" => "Previous Name" } })
    @account.profile_snapshots.create!(captured_at: Time.current, data: { "people" => { "ename" => "Kang Seung Sig" } })
    create_member("other", tenant: 1, name: "Kang Seung Sig")
    create_member("english", name: "KANG SeungSig")
    assert_includes NaverPeople::TargetSources.new(@account).values_for("impd")["sites"], "https://impd.townin.net/english"

    create_member("duplicate", name: "Kang Seung Sig")
    assert_empty NaverPeople::TargetSources.new(@account).values_for("impd")
  end

  private

  def create_member(slug, tenant: 2, name: @account.display_name)
    Member.create!(tenant_id: tenant, name: name, email: "#{slug}@example.test", slug: slug,
      status: "approved", profession: "author", social_links: { "blog" => "https://social.example", "other" => "ftp://invalid.example" }.to_json)
  end
end
