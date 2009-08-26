#!/bin/sh

#NYTPROF=clock=2:savesrc=1:file=/home/www/b3profile.out perl -d:NYTProf ./HTTPServerSimple.pl $*
NYTPROF=savesrc=1:file=/home/www/b3profile.out perl -d:NYTProf ./HTTPServerSimple.pl $*
