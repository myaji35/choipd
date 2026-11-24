module Linkedin
  class NetworkParser
    LABELS = { connections: "1촌", following: "팔로우중", invitations_sent: "초대 보냄" }.freeze

    def initialize(pages, nav_badges)
      @pages = pages.is_a?(Hash) ? pages : {}
      @nav_badges = nav_badges.is_a?(Hash) ? nav_badges : {}
    end

    def to_h
      lines = page_text("network").lines.map(&:strip).reject(&:empty?)
      counts = LABELS.transform_values do |label|
        index = lines.index(label)
        number(lines[index - 1]) if index&.positive?
      end
      counts.merge(
        unread_messages: number(@nav_badges["messages"]),
        unread_notifications: number(@nav_badges["notifications"]),
        invitations: invitations
      )
    end

    private

    def page_text(key)
      page = @pages[key]
      page.is_a?(Hash) && !page.key?("error") ? page["text"].to_s : ""
    end

    def number(value)
      value.to_s[/\A\d+(?:,\d{3})*\z/]&.delete(",")&.to_i
    end

    def invitations
      text = page_text("invitations").split(/^\s*회원님을 위한 추천/, 2).first.to_s
      text.scan(/(.*?)^\h*건너뛰기\s*수락\h*$/m).filter_map do |(block)|
        if (connection = block.match(/^\h*(?<name>[^\r\n]+?)\s*님이 1촌이 되고 싶어 함\h*\r?$(?<details>.*)/m))
          details = connection[:details].lines.map(&:strip).reject(&:empty?)
          mutual = details.find { |line| line.include?("공통 1촌") }
          invitation("connection", connection[:name], (details.first unless details.first == mutual), mutual)
        elsif (series = block[/^\h*[^\r\n]+?\s*님이 (.+?) 시리즈를 구독하라고 초대함\h*\r?$/, 1])
          invitation("newsletter", series, nil, nil)
        end
      end
    end

    def invitation(kind, name, headline, mutual)
      name = name.squish
      return if name.empty?

      { key: "#{kind}:#{name}:#{headline}", kind: kind, name: name, headline: headline, mutual: mutual }
    end
  end
end
