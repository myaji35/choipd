require "test_helper"

require "rake"

class BrandOpsDemoSeedTest < ActiveSupport::TestCase
  test "demo task can be run twice without duplicating rows" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("impd:demo_brand_ops")
    task = Rake::Task["impd:demo_brand_ops"]
    environment = Rails.env
    original = environment.method(:development?)
    environment.define_singleton_method(:development?) { true }
    begin
      task.invoke
      counts = demo_counts
      task.reenable
      task.invoke
      assert_equal counts, demo_counts
    ensure
      environment.define_singleton_method(:development?, original)
    end
  end

  private
    def demo_counts
      [ AnalyticsEvent.where(event_category: "brand_ops_demo").count,
        MemberPost.where("title LIKE ?", "예시 소식 %").count,
        MemberInquiry.where("sender_email LIKE ?", "demo-%@example.invalid").count,
        MemberReview.where("reviewer_email LIKE ?", "demo-%@example.invalid").count,
        SnsPostHistory.count ]
    end
end
