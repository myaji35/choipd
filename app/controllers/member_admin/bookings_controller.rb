class MemberAdmin::BookingsController < MemberAdmin::BaseController
  before_action :set_booking, only: [ :update, :destroy ]

  def index
    @bookings = @member.member_bookings.recent
  end

  def create
    booking = @member.member_bookings.new(booking_params)

    if booking.save
      redirect_to slug_admin_bookings_path(slug: @member.slug), notice: "예약 링크를 등록했습니다."
    else
      @bookings = @member.member_bookings.recent
      flash.now[:alert] = booking.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @booking.update(booking_params)
      redirect_to slug_admin_bookings_path(slug: @member.slug), notice: "예약 링크를 수정했습니다."
    else
      @bookings = @member.member_bookings.recent
      flash.now[:alert] = @booking.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @booking.destroy!
    redirect_to slug_admin_bookings_path(slug: @member.slug), notice: "예약 링크를 삭제했습니다."
  end

  private

  def set_booking
    @booking = @member.member_bookings.find(params[:id])
  end

  def booking_params
    params.require(:member_booking).permit(:booking_type, :description, :external_url)
  end
end
