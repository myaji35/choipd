class SitemapsController < ApplicationController
  def show
    @members = Member.publicly_visible.order(:slug)
    @base = public_base_url
    @static_paths = [ "/", "/explore", "/education", "/media", "/works", "/community", "/privacy", "/terms" ]

    render layout: false
  end
end
