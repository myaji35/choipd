class MemberAdmin::BookingsController < MemberAdmin::BaseController
  before_action :set_booking, only: [ :update, :destroy ]

  def index
    @bookings = @member.member_bookings.recent
  end

  def create
    booking = @member.member_bookings.new(booking_params)

    if booking.save
      flash[:saved_item] = "booking-#{booking.id}"
      redirect_to slug_admin_bookings_path(slug: @member.slug), notice: "예약 링크를 저장했어요. 내 페이지에 '예약하기' 버튼이 생겨요."
    else
      @bookings = @member.member_bookings.recent
      @new_booking = booking
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @booking.update(booking_params)
      flash[:saved_item] = "booking-#{@booking.id}"
      redirect_to slug_admin_bookings_path(slug: @member.slug), notice: "예약 링크를 고쳤어요."
    else
      @bookings = @member.member_bookings.recent
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @booking.destroy!
    redirect_to slug_admin_bookings_path(slug: @member.slug), notice: "예약 링크를 지웠어요."
  end

  private

  def set_booking
    @booking = @member.member_bookings.find(params[:id])
  end

  def booking_params
    params.require(:member_booking).permit(:booking_type, :description, :external_url)
  end
end
