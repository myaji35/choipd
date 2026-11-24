require "test_helper"

class Linkedin::NewsletterParserTest < ActiveSupport::TestCase
  setup do
    @url = "https://www.linkedin.com/newsletters/ximtier-dev-notes-7513833935739547648"
    @subscriber_url = "https://www.linkedin.com/newsletters/목표를-달성하는-협업의-힘-7018115202437054464"
    @links = JSON.parse(file_fixture("linkedin/newsletter_page_links.json").read)
    @pages = {
      "newsletters" => { "text" => file_fixture("linkedin/newsletters.txt").read, "links" => [ @url, "#{@url}/?trk=list#section", @subscriber_url ] },
      "newsletter_pages" => [ { "url" => "#{@url}/?trk=detail#section", "text" => file_fixture("linkedin/newsletter_page.txt").read, "links" => [ "#{@links.first}/?trk=detail#section", *@links ] } ]
    }
  end

  test "parses the measured newsletter list and details in link order" do
    @pages["newsletters"]["text"] = @pages["newsletters"]["text"].sub("구독자 6", "구독자 5")
    newsletters = Linkedin::NewsletterParser.new(@pages).to_h.fetch(:newsletters)
    assert_equal [ @url, @subscriber_url ], newsletters.pluck(:url)
    author, subscriber = newsletters

    assert_equal [ "XimTier Dev Notes", "author", 6, @url, 1, "매일 발행" ],
      author.values_at(:name, :role, :subscribers, :url, :new_subscribers_7d, :cadence)
    assert_equal [
      { title: "From Defaults to Delivery: Making Analysis Workflows Deterministic and Safe", published_relative: "1개월 전", url: @links.first },
      { title: "확정 지표를 기본값으로: 분석·처방 파이프라인의 신뢰성을 다시 세우다", published_relative: "1개월 전", url: @links.last }
    ], author[:editions]
    assert_equal [ "목표를 달성하는 협업의 힘", "subscriber", nil, @subscriber_url ],
      subscriber.values_at(:name, :role, :subscribers, :url)
  end

  test "leaves edition URLs empty when the feed block count differs from the link count" do
    @pages["newsletter_pages"].first["text"] += "\n피드 게시물\n"
    editions = Linkedin::NewsletterParser.new(@pages).to_h.fetch(:newsletters).first.fetch(:editions)

    assert_equal [ nil, nil ], editions.pluck(:url)
  end

  test "handles missing malformed legacy and failed pages" do
    [ nil, [], {}, { "activity" => {} }, { "newsletters" => { "error" => "timeout" } },
      { "newsletters" => { "text" => [], "links" => [ @url ] } } ].each do |pages|
      assert_equal({ newsletters: [] }, Linkedin::NewsletterParser.new(pages).to_h)
    end

    @pages["newsletter_pages"].first["error"] = "timeout"
    author = Linkedin::NewsletterParser.new(@pages).to_h[:newsletters].first
    assert_equal 6, author[:subscribers]
    assert_nil author[:new_subscribers_7d]
    assert_nil author[:cadence]
    assert_empty author[:editions]
  end
end
