# TODO(PH, 30Mar2022): reconsider implementation, whether derived from Struct, OpenStruct or Hash
class AggregatorConfig < OpenStruct
  def config_none_or_nil?(config_key)
    !key?(config_key) || self[config_key].nil? || self[config_key] == :none
  end

  private

  # slow? - is there a better way of doing this?
  def key?(k)
    to_h.key?(k)
  end
end
