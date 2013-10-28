#!/bin/bash

bundle exec jruby \
	--server \
	-J-Djruby.compile.fastest=true \
	-J-Djruby.compile.frameless=true \
	-J-Djruby.compile.positionless=true \
	-J-Djruby.compile.threadless=true \
	-J-Djruby.compile.fastops=true \
	-J-Djruby.compile.fastcase=true \
	-J-Djruby.compile.invokedynamic=true \
	"$@" | pv -l >/dev/null
