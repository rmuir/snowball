#!/usr/bin/env bash
# remove this script when problems are fixed
# it assumes you have a lucene checkout in ../lucene-solr, if you don't, then fix that.
DESTDIR=../lucene-solr/lucene/analysis/common/src/java/org/tartarus/snowball

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
make dist_libstemmer_java

for file in "SnowballStemmer.java" "Among.java" "SnowballProgram.java"; do
  # add license header to files since they have none, otherwise rat will flip the fuck out
  echo "/*" > ${DESTDIR}/${file}
  cat COPYING >> ${DESTDIR}/${file}
  echo "*/" >> ${DESTDIR}/${file}
  cat java/org/tartarus/snowball/${file} >> ${DESTDIR}/${file}
  reformat_java ${DESTDIR}/${file}
done

rm ${DESTDIR}/ext/*Stemmer.java
for file in java/org/tartarus/snowball/ext/*.java; do
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
