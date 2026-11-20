module BrandOps
  module Display
    def self.count_with_unit(number, unit)
      value = count(number)
      value == "3건 미만" ? value : "#{value}#{unit}"
    end

    def self.count(number)
      n = number.to_i
      return "3건 미만" if n.between?(1, 2)
      ActiveSupport::NumberHelper.number_to_delimited(n)
    end
  end
end
