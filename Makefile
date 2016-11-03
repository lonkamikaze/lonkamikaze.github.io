build:
	@jekyll clean
	@jekyll build --incremental

test: build
	@find _site -name \*.html -print -exec tidy5 -qe {} \;
