#!/bin/sh

cat js/vars.js js/attachments.js js/build.js js/case.js js/caserun.js js/category.js js/diff-tabs.js js/environment.js js/plan.js js/product.js js/run.js js/search.js js/strings.js js/tags.js js/util.js > testopia-new.all.js
perl ycomp.pl testopia-new.all.js > testopia-new.all.ycomp.js
echo Check testopia-new.all[ycomp].js and copy them over testopia.all[.ycomp].js
