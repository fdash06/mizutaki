# -*- coding: utf-8 -*-
import sys
import codecs
import gensim
from collections import defaultdict
import math
from sklearn.svm import LinearSVC

MIN_FREQUENCY = 3
MAX_FREQUENCY = sys.maxint
NUM_TOPICS    = 10
TEST          = 400
TEST_COUNT    = 5
NUM_STAR      = 2
NUM_FACTORS   = 500

sys.stdout = codecs.getwriter('utf_8')(sys.stdout)

# override pprint => pp
import re, pprint
def pp(obj):
  pp = pprint.PrettyPrinter(indent=4, width=160)
  str = pp.pformat(obj)
  return re.sub(r"\\u([0-9a-f]{4})", lambda x: unichr(int("0x"+x.group(1), 16)), str)

def fit_and_predict(estimator, data_train, label_train, data_test, label_test, line_number, dictionary):
  # fitting
  estimator.fit(data_train, label_train)

  # prediction
  label_predict = estimator.predict(data_test)

  ary = [[0 for i in range(2)] for j in range(2)]
  correct = 0
  for i in range(0,len(data_test)):
    ary[int(label_test[i])-1][int(label_predict[i])-1] += 1
    diff = int(label_test[i])  - int(label_predict[i])
    if diff == 0:
      correct += 1

  print "###################"
  print "  predict  low high"
  print "real:low  ",
  for prediction in range(2):
    print "{0:03d}".format(ary[0][prediction]),
  print ""
  print "real:high ",
  for prediction in range(2):
    print "{0:03d}".format(ary[1][prediction]),
  print ""

  print >> sys.stderr, "accuracy: " + str(correct) + " / " + str(len(data_test))

  coef = estimator.coef_
  items = sorted(dictionary.items())
  term_coef = {}
  for i in range(len(dictionary)):
    term_coef[items[i]] = coef[0,i]
  term_coef = sorted(term_coef.items(), key=lambda x:(- math.fabs(x[1]))) #desc

  # outputs factors
  factors = []
  for i in range(NUM_FACTORS):
    factors.append((str(term_coef[i][0][0]) + " : " + pp(term_coef[i][0][1]) + " : " + str(term_coef[i][1]) + "\n").encode('utf-8'))
  return [(float(correct) / len(data_test)), factors]


def make_data(dictionary, tfidf_corpus, labels, line_ids, offset=0):
  data_train  = []
  data_test   = []
  label_train = []
  label_test  = []
  line_number = []
  i = 0

  num_document = len(tfidf_corpus)
  num_test = 0
  stars = [0] * 6
  is_filling = False
  while True:
    for doc in tfidf_corpus:
      dense = list(gensim.matutils.corpus2dense([doc], num_terms=len(dictionary)).T[0])
      if ((i + offset) % (num_document / TEST )) == 0 and num_test < TEST and stars[int(labels[i])] < (TEST / NUM_STAR):
        data_test.append(dense)
        label_test.append(labels[i])
        stars[int(labels[i])] += 1
        line_number.append(line_ids[i])
        num_test += 1
      elif not is_filling:
        data_train.append(dense)
        label_train.append(labels[i])
      i = i + 1
    if num_test == TEST:
      break
    else:
      offset = (offset + 1) % TEST_COUNT
      i = 0
      is_filling = True
  return [data_train, label_train, data_test, label_test, line_number]

def main():
  documents = []
  labels    = []
  line_ids  = []
  i = 0
  for line in open("datasets/parsed.csv", 'r'):
    ary = line.split(",")
    documents.append(ary[0])
    labels.append(ary[1].strip())
    line_ids.append(ary[2].strip())
    i += 1

  texts = [[word for word in document.split(" ")] for document in documents]

  frequency = {}
  for text in texts:
    for token in text:
      if token and frequency.has_key(token): # omit null string
        frequency[token] += 1
      else:
        frequency[token] = 1
  texts = [[token for token in text if MIN_FREQUENCY <= frequency[token] <= MAX_FREQUENCY ]
            for text in texts]


  dictionary = gensim.corpora.Dictionary(texts)

  corpus = [dictionary.doc2bow(text) for text in texts]
  tfidf_instance=gensim.models.TfidfModel(corpus)
  tfidf_corpus = tfidf_instance[corpus]

  result = []
  max_accuracy = 0.0
  max_factors = []
## MAIN LOOP
  for i in range(0, TEST_COUNT):
    [data_train, label_train, data_test, label_test, line_target] = make_data(dictionary, tfidf_corpus, labels, line_ids, offset = i)

    estimator = LinearSVC(C=0.25);

    accuracy, factors = fit_and_predict(estimator, data_train, label_train, data_test, label_test, line_target, dictionary)
    if accuracy > max_accuracy:
      max_factors = factors
    result.append(accuracy)


  print "### result ###"
  average = sum(result)/len(result)
  print "average : " + str(average)
  f = open('datasets/factors.txt', 'w')
  for i in range(NUM_FACTORS):
    f.write(max_factors[i])
  print >> sys.stderr, "all done!!"
  f.close()

if __name__ == '__main__':
  main()

