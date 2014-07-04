#   Copyright (C) 2011-2014  Povilas Kanapickas <povilas@radix.lt>
#
#   This file is part of cppreference-doc
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see http://www.gnu.org/licenses/.

SHELL := /bin/bash

#Common prefixes

prefix = /usr
datarootdir = $(prefix)/share
docdir = $(datarootdir)/cppreference/doc
bookdir = $(datarootdir)/devhelp/books

#Version

VERSION=20140323

#STANDARD RULES

all: doc_devhelp doc_qch doc_doxygen

DISTFILES=	\
		reference/				\
		images/					\
		build_link_map.py		\
		ddg_parse_html.py		\
		devhelp2qch.xsl			\
		fix_devhelp-links.py	\
		httrack-workarounds.py	\
		index2browser.py		\
		index2ddg.py			\
		index2devhelp.py		\
		index2search.py			\
		index2highlight.py		\
		index_transform.py		\
		index-chapters-c.xml	\
		index-chapters-cpp.xml	\
		index-functions.README	\
		index-functions-c.xml	\
		index-functions-cpp.xml	\
		preprocess.py			\
		preprocess.xsl			\
		preprocess-css.css		\
		Makefile				\
		README

CLEANFILES= \
		output

clean:
		rm -rf $(CLEANFILES)

check:

dist: clean
	mkdir -p "cppreference-doc-$(VERSION)"
	cp -r $(DISTFILES) "cppreference-doc-$(VERSION)"
	tar czf "cppreference-doc-$(VERSION).tar.gz" "cppreference-doc-$(VERSION)"
	rm -rf "cppreference-doc-$(VERSION)"

install:
	# install the devhelp documentation
	pushd "output/reference" > /dev/null; \
	find . -type f \
		-exec install -DT -m 644 '{}' "$(DESTDIR)$(docdir)/html/{}" \; ; \
	popd > /dev/null

	install -DT -m 644 "output/cppreference-doc-en-c.devhelp2" \
		"$(DESTDIR)$(bookdir)/cppreference-doc-en-c/cppreference-doc-en-c.devhelp2"
	install -DT -m 644 "output/cppreference-doc-en-cpp.devhelp2" \
		"$(DESTDIR)$(bookdir)/cppreference-doc-en-cpp/cppreference-doc-en-cpp.devhelp2"

	# install the .qch (Qt Help) documentation
	install -DT -m 644 "output/cppreference-doc-en-cpp.qch" \
		"$(DESTDIR)$(docdir)/qch/cppreference-doc-en-cpp.qch"

uninstall:
	rm -rf "$(DESTDIR)$(docdir)"
	rm -rf "$(DESTDIR)$(bookdir)"

release: all
	rm -rf release
	mkdir -p release

	# zip the distributable
	mkdir -p "cppreference-doc-$(VERSION)"
	cp -r $(DISTFILES) "cppreference-doc-$(VERSION)"
	tar czf "release/cppreference-doc-$(VERSION).tar.gz" "cppreference-doc-$(VERSION)"
	zip -r "release/cppreference-doc-$(VERSION).zip" "cppreference-doc-$(VERSION)"
	rm -rf "cppreference-doc-$(VERSION)"

	# zip the html output
	pushd "output"; \
	tar czf "../release/html-book-$(VERSION).tar.gz" "reference"; \
	zip -r "../release/html-book-$(VERSION).zip" "reference"; \
	popd

	# zip qch
	pushd "output"; \
	tar czf "../release/qch-book-$(VERSION).tar.gz" "cppreference-doc-en-cpp.qch"; \
	zip -r "../release/qch-book-$(VERSION).zip" "cppreference-doc-en-cpp.qch"; \
	popd

#WORKER RULES
doc_html: output/reference

doc_devhelp: output/cppreference-doc-en-c.devhelp2 output/cppreference-doc-en-cpp.devhelp2

doc_qch: output/cppreference-doc-en-cpp.qch

doc_doxygen: output/cppreference-doxygen-web.tag.xml output/cppreference-doxygen-local.tag.xml

#builds the title<->location map
output/link-map.xml: output/reference
	./build_link_map.py

#build the .devhelp2 index
output/cppreference-doc-en-c.devhelp2: 		\
		output/reference 		\
		output/link-map.xml
	./index2devhelp.py $(docdir)/html index-chapters-c.xml  \
		"C Standard Library reference" "cppreference-doc-en-c" "c" \
		index-functions-c.xml "output/devhelp-index-c.xml"
	./fix_devhelp-links.py "output/devhelp-index-c.xml"  \
		"output/cppreference-doc-en-c.devhelp2"

output/cppreference-doc-en-cpp.devhelp2:	\
		output/reference 		\
		output/link-map.xml
	./index2devhelp.py $(docdir)/html index-chapters-cpp.xml  \
		"C++ Standard Library reference" "cppreference-doc-en-cpp" "cpp" \
		index-functions-cpp.xml "output/devhelp-index-cpp.xml"
	./fix_devhelp-links.py "output/devhelp-index-cpp.xml" \
		"output/cppreference-doc-en-cpp.devhelp2"

#build the .qch (QT help) file
output/cppreference-doc-en-cpp.qch: output/qch-help-project-cpp.xml
	#qhelpgenerator only works if the project file is in the same directory as the documentation
	cp "output/qch-help-project-cpp.xml" "output/reference/qch.xml"

	pushd "output/reference" > /dev/null; \
	qhelpgenerator "qch.xml" -o "../cppreference-doc-en-cpp.qch"; \
	popd > /dev/null

	rm -f "output/reference/qch.xml"

output/qch-help-project-cpp.xml: output/cppreference-doc-en-cpp.devhelp2
	#build the file list
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><files>" > "output/qch-files.xml"

	pushd "output/reference" > /dev/null; \
	find . -type f -not -iname "*.ttf" \
		-exec echo "<file>"'{}'"</file>" >> "../qch-files.xml" \; ; \
	popd > /dev/null

	echo "</files>" >> "output/qch-files.xml"

	#create the project (copies the file list)
	xsltproc devhelp2qch.xsl "output/cppreference-doc-en-cpp.devhelp2" > \
		"output/qch-help-project-cpp.xml"

# build doxygen tag file
output/cppreference-doxygen-local.tag.xml: 		\
		output/reference 		\
		output/link-map.xml
	./index2doxygen-tag.py "output/link-map.xml" \
		"index-functions-cpp.xml" \
		"output/cppreference-doxygen-local.tag.xml"

output/cppreference-doxygen-web.tag.xml: 		\
		output/reference 		\
		output/link-map.xml
	./index2doxygen-tag.py web \
		"index-functions-cpp.xml" \
		"output/cppreference-doxygen-web.tag.xml"

#create preprocessed archive
output/reference:
	mkdir -p output
	./preprocess.py

# create indexes for the wiki
indexes:
	mkdir -p output/indexes
	./index2highlight.py index-functions-cpp.xml output/indexes/highlight-cpp
	./index2highlight.py index-functions-c.xml output/indexes/highlight-c
	./index2search.py index-functions-cpp.xml output/indexes/search-cpp
	./index2search.py index-functions-c.xml output/indexes/search-c
	cat index-cpp-search-app.txt >> output/indexes/search-cpp
	./index2autolinker.py index-functions-c.xml output/indexes/autolink-c
	./index2autolinker.py index-functions-cpp.xml output/indexes/autolink-cpp

#redownloads the source documentation directly from en.cppreference.com
source:
	rm -rf "reference"
	mkdir "reference"

	pushd "reference" > /dev/null; \
	regex=".*index\\.php.*|.*/Special:.*|.*/Talk:.*" \
	regex+="|.*/Help:.*|.*/File:.*|.*/Cppreference:.*" \
	regex+="|.*/WhatLinksHere:.*|.*/Template:.*|.*/Category:.*" \
	regex+="|.*action=.*|.*printable=.*|.*en.cppreference.com/book.*" ; \
	echo $$regex ; \
	wget --adjust-extension --page-requisites --convert-links \
	  --force-directories --recursive --level=15 \
	  --span-hosts --domains=en.cppreference.com,upload.cppreference.com \
	  --reject-regex $$regex \
	  --timeout=180 --no-verbose \
	  --retry-connrefused --waitretry=1 --read-timeout=20 \
	  http://en.cppreference.com/w/ ; \
	popd > /dev/null

