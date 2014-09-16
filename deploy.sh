#!/bin/bash


namespaces=(`grep -l 'goog.provide' js/*.js | while read namespace ; do echo -n " ${namespace:3:${#namespace}-6} " ; done`)

namespaceArgs=''
for namespace in "${namespaces[@]}" ; do
	namespaceArgs+="-n napster.${namespace} "
done


git pull
mkdir build
cp -rfa .git build/
cd build
git checkout gh-pages
git pull . gh-pages
git push
rm -rf *
cd ..
cp -rfa `ls -a --ignore . --ignore .. --ignore .git --ignore build` build/
cd build


# HTML5 Application Cache
# ./appcache.sh > napster.appcache


ls *.html | while read file ; do cat "${file}" | tr '\n' ' ' | sed 's/<!-- COMPILE START -->.*<!-- COMPILE END -->/\<script src="js\/napster.js"\>\<\/script\>/' > "${file}.tmp" ; java -jar compilers/htmlcompressor.jar -o "${file}" "${file}.tmp" ; rm "${file}.tmp" ; done


cd css
ls *.css | while read file ; do java -jar ../compilers/yuicompressor.jar --type css -o "${file}.tmp" "${file}" ; mv "${file}.tmp" "${file}" ; done
cd ..


initText="`cat js/init.js`"
echo -e "goog.provide('napster.init');\n\ngoog.require('napster.exports');\n\n${initText}" > js/init.js

find . -name *.js | grep -v require.js | grep -v closure | grep -v externs | while read file ; do text="`cat "${file}"`" ; cat js/require.js > "${file}" ; echo >> "${file}" ; echo "${text}" >> "${file}" ; done

./export.sh "${namespaces[@]}"

js/closure-library/closure/bin/build/closurebuilder.py --root=js $namespaceArgs -n napster.exports -n napster.init --output_mode=compiled --compiler_jar=compilers/compiler.jar --compiler_flags="--compilation_level=SIMPLE_OPTIMIZATIONS" --compiler_flags="--externs=js/externs.js" --output_file=js/napster.js

# java -jar compilers/yuicompressor.jar --nomunge --type js -o js/napster.js.tmp js/napster.js
# mv js/napster.js.tmp js/napster.js


# Generates HTML snapshots and sitemaps for Google crawling; see: https://developers.google.com/webmasters/ajax-crawling/docs/getting-started
./crawl.py


# Generates translations
mv js/napster.js js/napster.js.tmp
echo -e "window.languageCodes = `cat languages.json`;\n\n" > js/napster.js
cat js/napster.js.tmp >> js/napster.js
rm js/napster.js.tmp
cp index.html en.html
./translate.py
ls *.html | xargs -I% echo % | perl -pe 's/(.*)\.html$/\1/' | xargs -I% ln -s %.html %


git add .
chmod 777 -R .
git commit -a -m 'deployment'
git push


cd ..
rm -rf build
