class I18nHelper
  def self.adjective(adjective)
    I18n.t("analytics.adjectives.#{adjective}")
  end

  def self.day_name(idx)
    I18n.t("date.day_names")[idx]
  end
end
