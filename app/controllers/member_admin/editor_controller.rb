class MemberAdmin::EditorController < MemberAdmin::BaseController
  def show
    @step = (params[:step] || 1).to_i
    @documents = @member.member_documents.order(uploaded_at: :desc)
    @portfolio_count = @member.member_portfolio_items.count
    @services_count = @member.member_services.count
  end
end
