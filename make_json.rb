require 'json'
require 'natto'

MAX_REVIEWS = 20
MAX_CO_OCCURING = 3
CO_OCCURING_IN_ALL = 3
MAX_CO2_OCCURING = 5
CO2_OCCURING_IN_ALL = 10
MAX_TOPIC_TERM = 50

@proper_noun = %w(LG21 MOW R1 DOREA ドレア スーパーカップ 果汁グミ メルティーキッス ビヒダス 雪見だいふく きのこの山 たけのこの里 ほほえみ ミルチ ヴァーム ハーゲンダッツ ポッキー ガーナ カール ロッテ 小岩井 ブルガリア 森永 メグ グリコ)
@co_occuring_parts = %w(名詞 形容詞 副詞)
@not_co_occuring_terms = %w(ヨーグルト チョコ チョコレート アイス)

@parsed = {}
@parsed_array = []
@reviews = []
@count_co_terms = {}
@count_co2_terms = {}
#@nm = Natto::MeCab.new("-u /path/to/user/dic")
@nm = Natto::MeCab.new("-u /usr/local/lib/mecab/dic/ipadic/mydic/meiji_items.dic")


def self.co_occuring(term)
  term_included_reviews     = {}
  term_not_included_reviews = {}
  count_of_terms_included     = 0
  count_of_terms_not_included = 0

  @parsed_array.each do |ary|
    next unless ary # parsed_array[0] is nil
    if ary.include?(term)
      ary.each do |t|
        term_included_reviews[t] ||= 0
        term_included_reviews[t] += 1
        count_of_terms_included += 1
      end
    else
      ary.each do |t|
        term_not_included_reviews[t] ||= 0
        term_not_included_reviews[t] += 1
        count_of_terms_not_included += 1
      end
    end
  end

  candidates = {}
  term_included_reviews.each do |k, v|

    candidates[k] = (v.to_f / count_of_terms_included) - ((term_not_included_reviews[k].to_f || 0) / count_of_terms_not_included)
  end

  sorted = candidates.sort{|(k1, v1), (k2, v2)| v2.abs <=> v1.abs }
  ret_ary = []
  sorted.each do |k, v|
    next if k == term # IMPORTANT!! can't line two the same term
    next if (k =~ /\p{Hiragana}/ && k.length == 1)
    next if k =~ /\p{Katakana}/ && k.length == 1
    next if k =~ /_ALPHABET_/

    part  = @nm.parse(k).split("\n")[0].split("\t")[1].split(",")[0]

    ret_ary << [k, v] if (@co_occuring_parts.include?(part) \
                          && !@not_co_occuring_terms.include?(k) \
                          && !@proper_noun.include?(k) \
                          && (!@count_co_terms[k] || @count_co_terms[k] < CO_OCCURING_IN_ALL))
    break if ret_ary.size >= MAX_CO_OCCURING
  end
  ret_ary.each do |k, v|
    @count_co_terms[k] ||= 0
    @count_co_terms[k] += 1
  end
  #puts "#{term} : #{ret_ary.inspect}"
  [ret_ary.map{|i| i[0]}, ret_ary.map{|i| i[1]}]
end

def self.co2_occuring(term, co_term, avoid_terms)
  term_included_reviews     = {}
  term_not_included_reviews = {}
  count_of_terms_included     = 0
  count_of_terms_not_included = 0

  @parsed_array.each do |ary|
    next unless ary # parsed_array[0] is nil
    if ary.include?(term) && ary.include?(co_term)
      ary.each do |t|
        term_included_reviews[t] ||= 0
        term_included_reviews[t] += 1
        count_of_terms_included += 1
      end
    else
      ary.each do |t|
        term_not_included_reviews[t] ||= 0
        term_not_included_reviews[t] += 1
        count_of_terms_not_included += 1
      end
    end
  end

  candidates = {}
  term_included_reviews.each do |k, v|

    candidates[k] = (v.to_f / count_of_terms_included) - ((term_not_included_reviews[k].to_f || 0) / count_of_terms_not_included)
  end

  sorted = candidates.sort{|(k1, v1), (k2, v2)| v2.abs <=> v1.abs }
  ret_ary = []
  sorted.each do |k, v|
    next if avoid_terms.include?(k) # !! you don't want the same of co_terms as co2_terms
    next if k == term # IMPORTANT!! can't line two the same term
    next if (k =~ /\p{Hiragana}/ && k.length == 1)
    next if k =~ /\p{Katakana}/ && k.length == 1
    next if k =~ /_ALPHABET_/

    part  = @nm.parse(k).split("\n")[0].split("\t")[1].split(",")[0]

    ret_ary << [k, v] if @co_occuring_parts.include?(part) \
      && !@not_co_occuring_terms.include?(k) \
      && !@proper_noun.include?(k) \
      && (!@count_co2_terms[k] || @count_co2_terms[k] < CO2_OCCURING_IN_ALL)
    break if ret_ary.size >= MAX_CO2_OCCURING
  end
  ret_ary.each do |k, v|
    @count_co2_terms[k] ||= 0
    @count_co2_terms[k] += 1
  end
  #puts "#{term}x#{co_term} : #{ret_ary.inspect}"
  [ret_ary.map{|i| i[0]}, ret_ary.map{|i| i[1].round(3)}]
end

def self.surround_span(str, term, co_term)
  str.gsub(term, "<span class=\"accent-term\">#{term}</span>") \
    .gsub(co_term, "<span class=\"co-occured-term\">#{co_term}</span>")
end

@term_no = 0
def self.make_docs(term, co_terms)
  @term_no += 1
  ret = String.new
  ret+= "<p class='doc-index'>"
  co_terms.each_with_index do |ct, i|
    ret+= "<a href='#docs-#{@term_no}-#{i}'>'#{term}' x '#{ct}'のレビュー</a></br>"
  end
  ret+= "</p>"
  co_terms.each_with_index do |ct, i|
    ret += "</br><h4 class='doc-anchor'><a name='docs-#{@term_no}-#{i}\'>#{term} x #{ct}</a></h4>"
    i = 0
    @parsed[ct].uniq.each do |id|
      break unless i < MAX_REVIEWS
      if  @parsed_array[id].include?(term)
        i += 1
        ret += "<br>#{surround_span(@reviews[id], term, ct)}</p>"
      end
    end
  end
  ret
end

# entry point
File.foreach("datasets/parsed.csv") do |input|
  input.split(",")[2] =~ /lineid:(\d+)/
  line_id = $1.to_i
  @parsed_array[line_id] = input.split(",")[0].split(" ")

  input.split(",")[0].split(" ").each do |term|
    @parsed[term] = [] unless @parsed[term]
    @parsed[term] << line_id
  end
end

i = 1
File.foreach("input.csv") do |input|
  @reviews[i] = input.split(",")[0]
  i += 1
end

data = {}
topic_term = 0
File.foreach("datasets/factors.txt") do |line|
  line =~ /u'(.*)' : (.*)$/ # for the sake of unicode
  term = $1
  next unless term.length >= 2
  next if @proper_noun.include?(term)

  value = $2.to_f

  topic_term += 1

  part = @nm.parse(term).split("\n")[0].split("\t")[1].split(",")[0]
  (co_terms, co_values) = co_occuring(term)
  if (data[term])
    data[term]["depends"] = co_terms
    data[term]["co_values"] = co_values
    data[term]["value"] = value
    data[term]["docs"] = "<h2><span class=\"accent-term\">'#{term}'</span>に関するレビュー</h2><div>#{make_docs(term, co_terms)}</div>";
  else
    data[term] = {
      "part" => part,
      "type" => "term",
      "name" => term,
      "value" => value,
      "co_values" => co_values,
      "depends" => co_terms,
      "dependedOnBy" => [],
      "docs" => "<h2><span class=\"accent-term\">'#{term}'</span>に関するレビュー</h2><div>#{make_docs(term, co_terms)}</div>",
    }
  end

  co_terms.each do |t|
    (co2_terms, co2_values) = co2_occuring(term, t, co_terms)
    data[term]["co2_terms"] ||= []
    data[term]["co2_terms"] << co2_terms
    data[term]["co2_values"] ||= []
    data[term]["co2_values"] << co2_values

    if (data[t])
      data[t]["dependedOnBy"] << term
    else
      data[t] = {
        "part" => part,
        "type" => "clue",
        "name" => t,
        "depends" => [],
        "dependedOnBy" => [term,],
        "value " => -0.5,
      }
    end
  end

  break if topic_term > MAX_TOPIC_TERM
end

File.open("data.json","w") do |writer|
  writer.puts JSON.pretty_generate({"data" => data , "errors" => []})
end
