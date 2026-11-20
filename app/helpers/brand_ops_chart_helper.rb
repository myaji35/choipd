module BrandOpsChartHelper
  def ops_line_chart(series, keys:, labels:, height: 220, protected_counts: false, area: nil, bars: false)
    colors = area ? %w[#46534e #006241 #788780 #687a73 #788780] : %w[#00754A #687a73 #788780 #46534e #788780]
    values = series.map { |row| keys.map { |key| row[key].to_i } }
    plotted = values.map { |row| row.map { |n| protected_counts && n.between?(1, 2) ? 3 : n } }
    maximum = ops_nice_max(plotted.flatten.max.to_i)
    stacked_maximum = bars ? ops_nice_max(plotted.map(&:sum).max.to_i) : maximum
    pieces = []
    keys.each_with_index do |key, k|
      points = plotted.each_with_index.map { |row, i| [ 100.0 * i / [ series.size - 1, 1 ].max, 100.0 - 100.0 * row[k] / maximum ] }
      if bars
        width = 70.0 / [ series.size, 1 ].max / keys.size
        points.each { |x, y| pieces << tag.rect(x: x - width * keys.size / 2 + width * k, y: y, width: width, height: 100 - y, fill: colors[k % colors.size], class: "ops-bar-grouped") }
        plotted.each_with_index do |row, i|
          bar_width = 90.0 / [ series.size, 1 ].max
          x = (i + 0.5) * 100.0 / [ series.size, 1 ].max - bar_width / 2
          bar_height = 100.0 * row[k] / stacked_maximum
          y = 100.0 - 100.0 * row.first(k + 1).sum / stacked_maximum
          pieces << tag.rect(x: x, y: y, width: bar_width, height: bar_height, fill: colors[k % colors.size], class: "ops-bar-stacked")
        end
      else
        coords = points.map { |x, y| "#{x},#{y}" }.join(" ")
        pieces << tag.polygon(points: "0,100 #{coords} 100,100", fill: "#00754A", "fill-opacity": "0.18", class: "ops-area") if key == area
        pieces << tag.polyline(points: coords, fill: "none", stroke: colors[k % colors.size], "stroke-width": 3, "vector-effect": "non-scaling-stroke")
      end
    end
    legend = content_tag(:div, safe_join(labels.each_with_index.map { |label, i| content_tag(:span, content_tag(:span, "●", style: "color:#{colors[i % colors.size]}", aria: { hidden: true }) + " #{label}") }), class: "ops-legend")
    ticks = content_tag(:div, safe_join([ maximum, maximum / 2, 0 ].map { |n| content_tag(:span, number_with_delimiter(n)) }), class: "ops-y-ticks#{bars ? ' ops-ticks-grouped' : ''}")
    ticks += content_tag(:div, safe_join([ stacked_maximum, stacked_maximum / 2, 0 ].map { |n| content_tag(:span, number_with_delimiter(n)) }), class: "ops-y-ticks ops-ticks-stacked") if bars
    grid = safe_join([ 0, 50, 100 ].map { |y| content_tag(:span, "", class: "ops-gridline", style: "top:#{y}%") })
    svg = content_tag(:svg, safe_join(pieces), viewBox: "0 0 100 100", preserveAspectRatio: "none", role: "img", "aria-label": "주간 추이: #{labels.join(', ')}")
    ends = bars ? "" : safe_join(keys.each_index.map do |k|
      value = values.last&.[](k).to_i
      content_tag(:span, protected_counts ? BrandOps::Display.count(value) : number_with_delimiter(value), class: "ops-end-value", style: "top:#{100 - 100.0 * plotted.last&.[](k).to_i / maximum}%")
    end)
    weeks = content_tag(:div, safe_join(series.each_with_index.map { |row, i| content_tag(:span, row[:week_start].strftime("%-m/%-d"), class: (i.even? || i == series.size - 1 ? "" : "ops-week-odd")) }), class: "ops-weeks")
    rows = series.each_with_index.map { |row, i| content_tag(:tr, content_tag(:th, row[:week_start].to_s) + safe_join(values[i].map { |v| content_tag(:td, protected_counts ? BrandOps::Display.count(v) : v) })) }
    table = content_tag(:table, content_tag(:caption, "주간 추이 표") + content_tag(:thead, content_tag(:tr, content_tag(:th, "주 시작일") + safe_join(labels.map { |l| content_tag(:th, l) }))) + content_tag(:tbody, safe_join(rows)), class: "ops-fallback-table")
    chart = content_tag(:div, ticks + content_tag(:div, grid + svg + ends, class: "ops-plot") + weeks, class: "ops-chart", style: ("min-width:#{(series.size * 8 / 0.9).ceil + 105}px" if bars))
    content_tag(:div, legend + content_tag(:div, chart, class: "ops-chart-scroll") + content_tag(:div, table, class: "ops-sr-only"), class: "ops-chart-wrapper")
  end

  def ops_nice_max(value)
    return [ 2, 4, 6, 10 ].find { |tick| tick >= value } if value <= 10
    scale = 1
    loop do
      ticks = scale == 1 ? [ 20, 30, 40, 60, 80 ] : [ 10, 12, 16, 20, 30, 40, 60, 80 ]
      ticks.each do |tick|
        return tick * scale if tick * scale >= value
      end
      scale *= 10
    end
  end

  def ops_delta(delta, unit = "명")
    return "지난주와 같아요" if delta.zero?
    "지난주보다 #{number_with_delimiter(delta.abs)}#{unit} #{delta.positive? ? '늘었어요' : '줄었어요'}"
  end
end
