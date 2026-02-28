class Chopd::WorksController < Chopd::BaseController
  def index
    @gallery_works = Work.gallery.recent
    @press_works = Work.press.recent
  end
end
