build:
	rm -rf _site
	jekyll build

test: build
	@find _site -name \*.html -print -exec tidy5 -qe {} \;
