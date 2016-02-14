require 'natto'

nm = Natto::MeCab.new("-u /usr/local/lib/mecab/dic/ipadic/mydic/meiji_items.dic")
#nm = Natto::MeCab.new("-u /path/to/user/dic")
target_parts = %w(名詞 形容詞 動詞 助動詞 助詞)
ignore_terms = %w()

proper_noun = %w(LG21 MOW R1 DOREA ドレア スーパーカップ 果汁グミ メルティーキッス ビヒダス 雪見だいふく きのこの山 たけのこの里 ほほえみ ミルチ ヴァーム ハーゲンダッツ)
#proper_noun = %w(固有の 商品名や ブランド名を 入れる)

MAX_COUNT_OF_A_STAR = 2000 #

def concat(term_array, part_array)
  ret = []
  pass = false
  for s in 0...term_array.length do
    if pass
      pass = false
      next
    end

    if (term_array[s] == "_ALPHABET_")
      ret << term_array[s]
      next
    end

    # 否定
    if (term_array[s+1] =~ /ず|ぬ|ない/) != nil && (part_array[s+1] =~ /助動詞|助詞/) != nil
      ret << "#{term_array[s]}_NOT_"
      pass = true
      next
    else
      ret << term_array[s]
    end
  end

  return ret.join(" ")
end


scores = []
File.open("datasets/parsed.csv","w") do |output|
  line = 1
  File.foreach("input.csv") do |input|
    line += 1
    ary = input.split(",")
    str = ary[0].tr('０-９ａ-ｚＡ-Ｚa-z', '0-9A-ZA-ZA-Z') # review本文

    next unless ary[1]
    score = ary[1].strip.to_i # score
    # score = 1 if score == 0 # 0と1をマージ
    if score <= 3 && score >= 2
      score = 0
    elsif score >= 4
      score = 1
    end

    scores[score] ||= 0
    scores[score] += 1
    next if scores[score] > MAX_COUNT_OF_A_STAR

    out = str.gsub(",","")
    #output.print "#{out},"

    elems = nm.parse(str).split("\n")
    elems.pop # remove trailing'*'
    term_array = []
    part_array = []
    term_count = 0
    elems.each do |n|
      surface = n.split("\t")[0]
      part = n.split("\t")[1].split(",")[0] # part
      term = n.split("\t")[1].split(",")[6] # surface

      if (proper_noun.include?(term))
        term_array << term
        part_array << part
        next
      end

      if (surface =~ /[a-zA-Z0-9]/) != nil
        term_array << "_ALPHABET_"
        part_array << "_ALPHABET_"
        next
      end

      if term =~ /\p{Katakana}/ && term.length == 1
        next
      end
      if term !~ /\A(?:\p{Hiragana}|\p{Katakana}|[ー－]|[一-龠々])+\z/
        next
      end

      if term && target_parts.include?(part) && !ignore_terms.include?(term)
        term_array << term
        part_array << part
      end
    end
    terms_list = concat(term_array, part_array)
    output.print terms_list
    output.puts ",#{score},lineid:#{line}"
  end

end
