require "test_helper"

class Linkedin::NetworkParserTest < ActiveSupport::TestCase
  test "parses Korean network counts, nav badges and received invitations" do
    network = "인맥 한눈에보기\n\n12\n\n초대 보냄\n\n1,234\n\n1촌\n\n9\n\n팔로우중\n\n받은 1촌 신청(5)"
    invitations = <<~TEXT
      받은 1촌 신청

      정재원 님이 1촌이 되고 싶어 함

      데이터 분석가

      Myeong-Ha Hwang님 외 공통 1촌 5명

      건너뛰기
      수락

      이성관#{' '}
       님이 1촌이 되고 싶어 함

      디자이너

      박설영님은 공통 1촌

      건너뛰기
      수락

      뉴스레터 • 일간

      Suk Hyun K.#{' '}
      님이 QIQO 시리즈를 구독하라고 초대함

      건너뛰기
      수락

      가상   인물 님이 1촌이 되고 싶어 함

      건너뛰기
      수락

      가상 신청자 님이 1촌이 되고 싶어 함

      박설영님은 공통 1촌

      건너뛰기
      수락

      회원님을 위한 추천

      추천 인물 님이 1촌이 되고 싶어 함

      건너뛰기
      수락
    TEXT
    pages = { "network" => { "text" => network }, "invitations" => { "text" => invitations } }
    result = Linkedin::NetworkParser.new(pages, { "messages" => 0, "notifications" => 3 }).to_h

    assert_equal [ 1234, 9, 12, 0, 3 ], result.values_at(:connections, :following, :invitations_sent, :unread_messages, :unread_notifications)
    assert_equal [
      { key: "connection:정재원:데이터 분석가", kind: "connection", name: "정재원", headline: "데이터 분석가", mutual: "Myeong-Ha Hwang님 외 공통 1촌 5명" },
      { key: "connection:이성관:디자이너", kind: "connection", name: "이성관", headline: "디자이너", mutual: "박설영님은 공통 1촌" },
      { key: "newsletter:QIQO:", kind: "newsletter", name: "QIQO", headline: nil, mutual: nil },
      { key: "connection:가상 인물:", kind: "connection", name: "가상 인물", headline: nil, mutual: nil },
      { key: "connection:가상 신청자:", kind: "connection", name: "가상 신청자", headline: nil, mutual: "박설영님은 공통 1촌" }
    ], result[:invitations]
  end

  test "distinguishes invitations with the same name and different headlines" do
    invitations = <<~TEXT
      가상 신청자 님이 1촌이 되고 싶어 함
      개발자
      건너뛰기
      수락

      가상 신청자 님이 1촌이 되고 싶어 함
      디자이너
      건너뛰기
      수락
    TEXT
    result = Linkedin::NetworkParser.new({ "invitations" => { "text" => invitations } }, nil).to_h

    assert_equal [ "connection:가상 신청자:개발자", "connection:가상 신청자:디자이너" ], result[:invitations].pluck(:key)
  end

  test "returns nil for missing counts" do
    result = Linkedin::NetworkParser.new({ "network" => { "text" => "1촌\n불명\n팔로우중" } }, nil).to_h

    assert_equal [ nil, nil, nil, nil, nil ], result.values_at(:connections, :following, :invitations_sent, :unread_messages, :unread_notifications)
    assert_empty result[:invitations]
  end
end
