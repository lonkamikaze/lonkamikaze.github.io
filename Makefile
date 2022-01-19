test: build
	@find _site -name \*.html -print -exec tidy5 -qe {} \;

build:
	@jekyll clean
	@jekyll build --future --incremental
