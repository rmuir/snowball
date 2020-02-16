#!/usr/bin/env bash
# remove this script when problems are fixed
# it assumes you have a lucene checkout in ../lucene-solr, if you don't, then fix that.
# it also assumes you have a snowball-data checkout in ../snowball-data, fix that too
# it also assumes you have a snowball-website checkout in ../snowball-website, fix that too
SRCDIR=.
DESTDIR=../lucene-solr/lucene/analysis/common/src/java/org/tartarus/snowball
TESTSRCDIR=../snowball-data
TESTDSTDIR=../lucene-solr/lucene/analysis/common/src/test/org/apache/lucene/analysis/snowball
WWWSRCDIR=../snowball-website
WWWDSTDIR=../lucene-solr/lucene/analysis/common/src/resources/org/apache/lucene/analysis/snowball/

trap ': "*** BUILD FAILED ***" $BASH_SOURCE:$LINENO: error: "$BASH_COMMAND" returned $?' ERR
set -eExuo pipefail

# completely reformats file with vim, to kill the crazy space/tabs mix.
# prevents early blindness !
function reformat_java() {
  target=$1
  vimrc=$(mktemp)
  cat > ${vimrc} << EOF
syntax on
filetype plugin indent on
set tabstop=2
set softtabstop=2
set shiftwidth=2
set expandtab
EOF
  vim -u ${vimrc} -c 'normal gg=G' -c ':wq' ${target}
  rm ${vimrc}
}

# generate stuff with existing makefile, just 'make' will try to do crazy stuff with e.g. python
# and likely fail. so only ask for our specific target.
(cd ${SRCDIR} && make dist_libstemmer_java)

for file in "SnowballStemmer.java" "Among.java" "SnowballProgram.java"; do
  # add license header to files since they have none, otherwise rat will flip the fuck out
  echo "/*" > ${DESTDIR}/${file}
  cat ${SRCDIR}/COPYING >> ${DESTDIR}/${file}
  echo "*/" >> ${DESTDIR}/${file}
  cat ${SRCDIR}/java/org/tartarus/snowball/${file} >> ${DESTDIR}/${file}
  reformat_java ${DESTDIR}/${file}
done

rm ${DESTDIR}/ext/*Stemmer.java
for file in ${SRCDIR}/java/org/tartarus/snowball/ext/*.java; do
  # title-case the classes (fooStemmer -> FooStemmer) so they obey normal java conventions
  base=$(basename $file)
  oldclazz="${base%.*}"
  # one-off
  if [ "${oldclazz}" == "kraaij_pohlmannStemmer" ]; then
    newclazz="KpStemmer"
  else
    newclazz=${oldclazz^}
  fi
  cat $file | sed "s/${oldclazz}/${newclazz}/g" > ${DESTDIR}/ext/${newclazz}.java
  reformat_java ${DESTDIR}/ext/${newclazz}.java
done

# regenerate test data
rm -f ${TESTDSTDIR}/test_languages.txt
for file in ${TESTSRCDIR}/*; do
  if [ -f "${file}/voc.txt" ] && [ -f "${file}/output.txt" ]; then
    language=$(basename ${file})
    if [ "${language}" == "kraaij_pohlmann" ]; then
      language="kp"
    fi
    rm -f ${TESTDSTDIR}/${language}.zip
    # make the .zip reproducible if data hasn't changed.
    arbitrary_timestamp="200001010000"
    # some test files are yuge, randomly sample up to this amount
    row_limit="2000"
    # TODO: for now don't deal with any special licenses
    if [ ! -f "${file}/COPYING" ]; then
      tmpdir=$(mktemp -d)
      myrandom="openssl enc -aes-256-ctr -pass pass:${arbitrary_timestamp} -nosalt"
      for data in "voc.txt" "output.txt"; do
        shuf -n ${row_limit} --random-source=<(${myrandom} < /dev/zero 2>/dev/null) ${file}/${data} > ${tmpdir}/${data} \
          && touch -t ${arbitrary_timestamp} ${tmpdir}/${data}
      done
      zip --junk-paths -X -9 ${TESTDSTDIR}/${language}.zip ${tmpdir}/voc.txt ${tmpdir}/output.txt
      echo "${language}" >> ${TESTDSTDIR}/test_languages.txt
      rm -r ${tmpdir}
    fi
  fi
done

# regenerate stopwords data
rm -f ${WWWDSTDIR}/*_stop.txt
for file in ${WWWSRCDIR}/algorithms/*/stop.txt; do
  language=$(basename $(dirname ${file}))
  cat > ${WWWDSTDIR}/${language}_stop.txt << EOF
 | From https://snowballstem.org/algorithms/${language}/stop.txt
 | This file is distributed under the BSD License.
 | See https://snowballstem.org/license.html
 | Also see https://opensource.org/licenses/bsd-license.html
 |  - Encoding was converted to UTF-8.
 |  - This notice was added.
 |
 | NOTE: To use this file with StopFilterFactory, you must specify format="snowball"
EOF
  case "$language" in
    danish)
      # clear up some slight mojibake on the website. TODO: fix this file!
      cat $file | sed 's/Ã¥/å/g' | sed 's/Ã¦/æ/g' >> ${WWWDSTDIR}/${language}_stop.txt
      ;;
    *)
      # try to confirm its really UTF-8
      iconv -f UTF-8 -t UTF-8 $file >> ${WWWDSTDIR}/${language}_stop.txt
      ;;
  esac
done
