module MemberCardHelper
  def member_profession_details(role)
    details = {
      "insurance_agent" => [ "보험 설계사", "shield-2-check", "#e6f1ec" ],
      "realtor" => [ "공인중개사", "home-2", "#edf0e6" ],
      "educator" => [ "강사", "book-1", "#eef0e8" ],
      "author" => [ "작가", "pencil-1", "#f3eee5" ],
      "shopowner" => [ "자영업자", "cart-1", "#f4eee5" ],
      "freelancer" => [ "프리랜서", "camera-1", "#e8efed" ],
      "custom" => [ "크리에이터", "camera-1", "#e8efed" ]
    }
    details.fetch(role.to_s, [ "크리에이터", "user-4", "#edf0ed" ])
  end
end
