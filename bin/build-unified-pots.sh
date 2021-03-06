#!/bin/bash

[ -z "$1" ] || [ -z "$1" ] || [ -z "$2" ] || [ ! -d "$2" ] || [ -z "$3" ] && echo "usage: $0 source-dir-or-repo POT-dir releases"   && exit 1
[ -n "$4" ]                                                               && echo 'provide releases as one, space-separated string' && exit 1

root="$1"
potdir="$2"
rels=`echo "$3" | tr ' ' '\n'`

temp=`mktemp -d`

for rel in $rels; do

  ## This can be useful to debug the build process or to test on a trunk checkout
  ## (if you use this, comment out the 'get fresh codebase' block below)
  # cp -r /path/to/civicrm $temp/v4.1

  mkdir -p $temp/$rel
  mkdir -p $temp/pot/$rel

  pushd .

  # get fresh codebase from either Git or Subversion
  if [[ $root == http* ]]; then
    svn export --force "$root/$rel" "$temp/$rel"
  else
    cd $root
    git archive $rel | tar -xC $temp/$rel
  fi

  mkdir $temp/$rel/xml/default
  echo '<?php define("CIVICRM_CONFDIR", ".");' > $temp/$rel/settings_location.php
  echo '<?php define("CIVICRM_UF", "Drupal");' > $temp/$rel/xml/default/civicrm.settings.php

  cd $temp/$rel/xml
  php GenCode.php schema/Schema.xml

  popd

  bin/create-pot-files.sh $temp/$rel $temp/pot/$rel

done

pots=`for pot in $temp/pot/*/*.pot; do basename $pot .pot; done | sort -u | grep -v ^drupal-civicrm$`

# merge per-release files into unified ones
for pot in $pots; do
  echo " * merging $pot.pot files"
  msgcat --use-first $temp/pot/*/$pot.pot > $potdir/$pot.pot
done

# drop strings in common-base.pot from other files
for pot in $pots; do
  [ $pot == 'common-base' ] && continue
  echo " * dropping common-base strings from $pot.pot"
  common=`tempfile`
  msgcomm $potdir/$pot.pot $potdir/common-base.pot > $common
  msgcomm --unique $potdir/$pot.pot $common | sponge $potdir/$pot.pot
  rm $common
done

# drop strings in common-components.pot from other files
for pot in $pots; do
  [ $pot == 'common-base' ]       && continue
  [ $pot == 'common-components' ] && continue
  echo " * dropping common-components strings from $pot.pot"
  common=`tempfile`
  msgcomm $potdir/$pot.pot $potdir/common-components.pot > $common
  msgcomm --unique $potdir/$pot.pot $common | sponge $potdir/$pot.pot
  rm $common
done

rm -r $temp
