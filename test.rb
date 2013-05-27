# coding: utf-8

require './keyword_extract'


sentence = File.read ARGV[0] || './sample_1.txt'

start = Time.now

keywords = KeywordExtract.new.get_keywords sentence

keywords.each { |w| print w, ', ' }

printf "\n\ntook %.3fsec. extracted %d keywords\n", Time.now - start, keywords.length

