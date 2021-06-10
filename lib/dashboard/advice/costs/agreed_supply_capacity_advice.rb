class AgreedSupplyCapacityAdvice
  def initialize(meter)
    @meter = meter
  end

  def advice
    asc = agreed_supply_capacity
      
    return [] if asc.nil?

    text = %(
      <% if asc[:percent] > 0.85 %>
        Your capacity usage of <%= asc[:kw] %> kW
        is quite close to your agreed limit of <%= asc[:agreed_limit_kw] %> kW
        for meter <%= @meter.mpxn %>.

        There is a risk of incurring signifcantly monthly penalty charges if
        you go over the limit. We suggest you contact your energy manager or energy
        supplier to discuss.
      <% else %>
        <b>Potential easy saving:</b>
        Your current maximum annual capacity usage of <%= asc[:kw] %> kW is signifcantly
        lower than your agreed limit of <%= asc[:agreed_limit_kw] %> kW
        for meter <%= @meter.mpxn %>.
        
        <% if asc.key?(:annual_saving_£) %>
          By reducing your limit you could save up to
          <%= FormatEnergyUnit.format_pounds(asc[:annual_saving_£], :html, :approx_accountant) %> per year.
        <% end %>
        
        We suggest you contact your energy manager or energy supplier to discuss reducing the
        limit to save your costs. The main risk of doing this is if your annual usage goes up
        if you are planning on signficantly increasing the size of the school or electricity
        consumption in the near future?
      <% end %>
    )
    html = ERB.new(text).result(binding)

    { type: :html, content: html }
  end

  private

  def agreed_supply_capacity
    tariff = @meter.meter_tariffs.accounting_tariff_for_date(@meter.amr_data.end_date)
    return nil if tariff.nil? || tariff.tariff[:asc_limit_kw].nil?

    kw = agreed_supply_capacity_requirement_kw

    asc = {
      kw:              kw,
      percent:         kw / tariff.tariff[:asc_limit_kw],
      agreed_limit_kw: tariff.tariff[:asc_limit_kw],
    }

    unless tariff.tariff[:rates][:agreed_availability_charge].nil?
      cost_£ = 12.0 * tariff.tariff[:asc_limit_kw] * tariff.tariff[:rates][:agreed_availability_charge][:rate]
      saving_£ = (1.0 - asc[:percent]) * cost_£

      asc.merge!({ annual_cost_£: cost_£, annual_saving_£: saving_£ } )
    end
    
    asc
  end

  def agreed_supply_capacity_requirement_kw
    end_date = @meter.amr_data.end_date
    start_date = [end_date - 365, @meter.amr_data.start_date].max
    @meter.amr_data.peak_kw_date_range_with_dates(start_date, end_date).values[0]
  end
end