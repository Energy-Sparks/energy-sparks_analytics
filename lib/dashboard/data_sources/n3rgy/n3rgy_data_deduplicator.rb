module MeterReadingsFeeds
  class N3rgyDataDeduplicator
    def self.deduplicate_standing_charges(ary)
      deduped = [ary.first]
      ary.each_cons(2) { |a,b| deduped << b if a[1] != b[1] }
      deduped
    end

    def self.deduplicate_prices(hsh)
      deduped = Hash[*hsh.first]
      hsh.each_cons(2) { |(date1,prices1),(date2,prices2)| deduped[date2] = prices2 if prices1 != prices2 }
      deduped.merge(hsh.keys.last => hsh.values.last)
    end
  end
end
