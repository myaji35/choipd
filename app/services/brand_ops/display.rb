module BrandOps
  module Display
    def self.count(number)
      n = number.to_i
      return "3건 미만" if n.between?(1, 2)
      ActiveSupport::NumberHelper.number_to_delimited(n)
    end
  end
end
