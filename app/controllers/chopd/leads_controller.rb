class Chopd::LeadsController < Chopd::BaseController
  def create
    @lead = Lead.new(lead_params)

    respond_to do |format|
      if @lead.save
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "newsletter-form",
            partial: "chopd/leads/success"
          )
        end
        format.html { redirect_to community_path, notice: "뉴스레터에 구독하셨습니다." }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "newsletter-form",
            partial: "chopd/leads/form",
            locals: { lead: @lead }
          )
        end
        format.html { redirect_to community_path, alert: @lead.errors.full_messages.first }
      end
    end
  end

  private

  def lead_params
    params.require(:lead).permit(:email)
  end
end
