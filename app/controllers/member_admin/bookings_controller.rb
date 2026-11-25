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
      translate_address_error(booking)
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
      translate_address_error(@booking)
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
    attributes = params.require(:member_booking).permit(:booking_type, :description, :external_url)
    attributes[:external_url] = normalize_web_address(attributes[:external_url]) if attributes.key?(:external_url)
    attributes
  end

  def translate_address_error(booking)
    return if booking.errors[:external_url].empty?

    booking.errors.delete(:external_url)
    message = if booking.external_url.blank?
      "예약 주소를 적어 주세요."
    else
      "예약 주소를 다시 확인해 주세요. 띄어쓰기 없이 주소만 적어 주세요."
    end
    booking.errors.add(:base, message)
  end
end
