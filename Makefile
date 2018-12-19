usage:
	@echo "Available commands are:"
	@echo " serve, build, rsync"

MKFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
MKDIR  := $(dir $(MKFILE))

JEKYLL_VERSION := 3.8.5
SERVER_HOST := jekyll.transpridebrighton.org
SERVER_PORT := 12345
SERVER_USER := root

serve:
	docker run --rm -it -p "4000:4000" -v "$$(pwd):/srv/jekyll" -v "$$(pwd)/vendor:/usr/local/bundle" -w "/srv/jekyll" "jekyll/jekyll:$(JEKYLL_VERSION)" jekyll serve

build:
	docker run --rm -it -v "$$(pwd):/srv/jekyll" -v "$$(pwd)/vendor:/usr/local/bundle" -w "/srv/jekyll" "jekyll/jekyll:$(JEKYLL_VERSION)" jekyll build

# It's likely that rsync will fail unless you have the server key added to the list of known hosts beforehand.
# Run the following and immediately exit: `ssh $(SERVER_USER)@$(SERVER_HOST) -p $(SERVER_PORT)`
rsync: build
	rsync -vzarh -e "ssh -p $(SERVER_PORT)" "$(MKDIR)/_site/" "$(SERVER_USER)@$(SERVER_HOST):/srv/public/"

