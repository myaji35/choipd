class SitemapsController < ApplicationController
  def show
    @members = Member.active.where(status: "approved").order(:slug)
    @base = public_base_url
    @static_paths = [ "/", "/education", "/media", "/works", "/community", "/privacy", "/terms" ]

    render layout: false
  end
end
