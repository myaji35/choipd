class PrintCardsController < ApplicationController
  def show
    @member = Member.publicly_visible.find_by!(slug: params[:slug])
    render layout: false
  end
end
