module Thicket
  module TimeMeasure
    class Measure
      getter :length_in_seconds, :abbreviation, :threshold_in_seconds

      def initialize(@length_in_seconds : UInt32, @abbreviation : String, @threshold_in_seconds : UInt32)
      end
    end

    YEAR = Measure.new(31_104_000, "Y", 155_520_000)
    MONTH = Measure.new(2_592_000, "M", 15_552_000)
    WEEK = Measure.new(604_800, "w", 2_419_200)
    DAY = Measure.new(86_400, "d", 172_800)
    HOUR = Measure.new(3_600, "h", 3_600)
    MINUTE = Measure.new(60, "m", 60)
    SECOND = Measure.new(1, "s", 0)

    def self.measures : Array
      [YEAR, MONTH, WEEK, DAY, HOUR, MINUTE, SECOND]
    end
  end
end
