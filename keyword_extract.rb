# coding: utf-8

require 'MeCab'
require './gs'
require 'nkf'


class KeywordExtract

  @@nouns_regexp = /^[[:word:]ー\-]+$/u

  def initialize
    @tagger = MeCab::Tagger.new '-Ochasen2'
    @gs = GoogleSuggest.new
  end

  def get_keywords(sentences)
    @words = {}
    @units = []

    sentences = regulate sentences

    sentences.split(/\n+/).each do |sentence|
      nodes = @tagger.parse sentence

      if nodes
        nodes
        .split("\n")
        .each { |node| possible_keywords(node) }
      end
    end

    importance

    final_candidates
  end

  def regulate(s)
    s = NKF::nkf '-WwXm0Z0', s
    s.gsub!(/[～－—─ー]+/, 'ー')
    s.downcase
  end

private

  GOOGLE_TOTAL_INDEXED_PAGES = 50_000_000_000 # updated at Sept, 2012

  def possible_keywords(node)
    f = get_features node

    if f[:pos2] == '助数詞'
      @units << f[:surface]
    end

    if noun? f
      if @prev
        @prev << f[:raw] # 連続した名詞(複合名詞)をまとめる
      else
        @prev = f[:raw]
      end
    else
      count_word @prev if @prev && not_numbers?(@prev)
      @prev = nil
    end
  end

  def get_features(node)
    # 表層刑\t読み\t原型\t品詞(-品詞細分類1)(-品詞細分類2)(-品詞細分類3)(\t活用形\t活用型)

    f = node.split "\t"
    pos = f[3].to_s.split '-'

    {
      raw: f[0],
      surface: f[0].strip,
      pos: pos[0],
      pos1: pos[1],
      pos2: pos[2]
    }
  end

  def not_numbers?(str)
    (str = str.strip) &&
    !str.match(/^[a-z\- ]{1,2}$/) &&
    !str.match(/^[\d一二三四五六七八九十壱弐参拾百千万萬億兆〇 \-]+$/u) &&
    !@units.any? { |unit| str.include?(unit) }
  end

  def noun?(f)
    f[:surface] == '・' ||
    f[:pos] == '名詞' &&
    !%w[代名詞 非自立 副詞可能 特殊].include?(f[:pos1]) &&
    f[:surface].match(@@nouns_regexp) &&
    !%w[自分 男 女 男性 女性 お互い 妻 夫 母].include?(f[:surface])
  end

  def count_word(word)
    word = word.strip
    @words[word] = 0 unless @words[word]
    @words[word] += 1
    word
  end

  def importance
    @total_words = @words.values.reduce(&:+)
    @imp = {}

    @words.each do |word, freq|
      @imp[word] = calc_importance word, freq
    end
  end

  def calc_importance(word, freq)
    # the number of google indexed pages
    gscount = @gs.count_for word

    # tf / idf
    tf = freq.to_f / @total_words
    idf = gscount == 0 ? 1 : Math.log(gscount.to_f / GOOGLE_TOTAL_INDEXED_PAGES)

    tf * idf
  end

  def final_candidates
    words = @words.keys
    _words = words.dup

    # 他の部分文字を含むものまたは含まれているものは imp 値が高い方をとる
    # ただし imp 値が同じ場合は文字数が短い方をとる
    _words.each do |w1|
      _words.each do |w2|
        if w1 != w2 && (w2.include?(w1) && @imp[w1] >= @imp[w2] || w1.include?(w2) && @imp[w1] > @imp[w2])
          words.delete w2
        end
      end
    end

    words.sort { |a, b| @imp[a] <=> @imp[b] }
  end

end
