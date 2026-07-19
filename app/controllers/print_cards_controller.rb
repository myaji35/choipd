class PrintCardsController < ApplicationController
  def show
    @member = Member.active.find_by!(slug: params[:slug])
    render layout: false
  end
end
