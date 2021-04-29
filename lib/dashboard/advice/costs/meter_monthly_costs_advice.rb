class MeterMonthlyCostsAdvice
  def initialize(school, meter)
    @school = school
    @meter = meter
    @non_rate_types = %i[days start_date end_date first_day month]
  end

  def two_year_monthly_comparison_table_html
    header, rows, totals = two_year_monthly_comparison_table
    formatted_rows = rows.map{ |row| row_to_£(row) }
    formatted_totals = row_to_£(totals)
    html_table = HtmlTableFormatting.new(header, formatted_rows, formatted_totals)
    html_table.html
  end

  private

  def row_to_£(row)
    row.map{ |value| value.is_a?(Numeric) ? format_£(value) : value }
  end

  def format_£(value)
    FormatEnergyUnit.format(:£, value, :html, false, false, :no_decimals)
  end

  def two_year_monthly_comparison_table
    start_month_index = [monthly_accounts.values.length - 13, 0].max
    up_to_13_most_recent_months = monthly_accounts.values[start_month_index..monthly_accounts.values.length]
    components = up_to_13_most_recent_months.map{ |k,_v| k.keys }.flatten.uniq
    components = reorder_columns(components)
    bill_components = components.select{ |type| !@non_rate_types.include?(type) } # inefficient

    header = ['Month', bill_components.map { |component| component.to_s.humanize }].flatten
    rows = data_rows(up_to_13_most_recent_months, bill_components)
    totals = total_row(up_to_13_most_recent_months, bill_components)
    [header, rows, totals]
  end

  private def reorder_columns(components)
    # move to last 3 columns, in this order
    %i[standing_charge variance_versus_last_year total].each do |column_type|
      if components.include?(column_type)
        components.delete(column_type)
        components.push(column_type)
      end
    end

    if components.include?(:rate) # put rate in the first column
      components.delete(:rate)
      components.insert(0, :rate)
    end

    if components.include?(:flat_rate) # put flat_rate in the first column
      components.delete(:flat_rate)
      components.insert(0, :flat_rate)
    end

    components
  end

  def data_rows(up_to_13_most_recent_months, bill_components)
    up_to_13_most_recent_months.map do |month|
      [
        month[:month],
        bill_components.map { |col_name| month[col_name] }
        # month.select{ |type, value| !@non_rate_types.include?(type) }.values
      ].flatten
    end
  end

  def total_row(up_to_13_most_recent_months, bill_components)
    exceptions = [] # don't add up non-full months
    totals = bill_components.map do |component|
      up_to_13_most_recent_months.map do |month|
        if month[:variance_versus_last_year].nil?
          exceptions.push(month[:month])
          0.0
        else
          month[component]
        end
      end.sum
    end
    except = exceptions.empty? ? "" : " (except #{exceptions.uniq.join(', ')})"
    ['Total' + except, totals].flatten
  end

  def monthly_accounts
    months_billing = Hash.new {|hash, month| hash[month] = Hash.new{|h, bill_component_types| h[bill_component_types] = 0.0 }}

    (@meter.amr_data.start_date..@meter.amr_data.end_date).each do |date|
      day1_month = first_day_of_month(date)
      bc = @meter.amr_data.accounting_tariff.bill_component_costs_for_day(date)
      bc.each do |bill_type, £|
        months_billing[day1_month][bill_type] += £
      end
      months_billing[day1_month][:days]       += 1
      months_billing[day1_month][:start_date] = date unless months_billing[day1_month].key?(:start_date)
      months_billing[day1_month][:end_date]   = date
    end

    # calculate totals etc.
    months_billing.each do |date, months_bill|
      months_bill[:total]      = months_bill.map{ |type, £| @non_rate_types.include?(type) ? 0.0 : £ }.sum
      months_bill[:first_day]  = first_day_of_month(date)
      months_bill[:month]      = months_bill[:first_day].strftime('%b %Y')
    end

    # calculate change with 12 months before, unless not full (last) month
    months_billing.each_with_index do |(_day1_month, month_billing), month_index|
      unless month_index + 12 > months_billing.length - 1
        months_billing_plus_12 = months_billing.values[month_index + 12]
        full_month = last_day_of_month(months_billing_plus_12[:start_date]) == months_billing_plus_12[:end_date]
        months_billing_plus_12[:variance_versus_last_year] = full_month ? months_billing_plus_12[:total] - month_billing[:total] : nil
      end
    end

    # label partial months
    months_billing.each do |_day1_month, month_billing|
      full_month = last_day_of_month(month_billing[:start_date]) == month_billing[:end_date]
      month_billing[:month] += ' (partial)' unless full_month
    end

    months_billing
  end

  def first_day_of_month(date)
    Date.new(date.year, date.month, 1)
  end

  def last_day_of_month(date)
    if date.month == 12
      Date.new(date.year + 1, 1, 1) - 1
    else
      Date.new(date.year, date.month + 1, 1) - 1
    end
  end
end
