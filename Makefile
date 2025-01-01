IN_DIR := $(PWD)/bin
SRC_FILE := src/Main.elm
OUT_FILE := $(BIN_DIR)/main.js
ELM := $(BIN_DIR)/elm
BUILD_DIR_MAC := ./dist-newstyle/build/aarch64-osx/ghc-*/elm-*/x/elm/build/elm/elm
BUILD_DIR_UBUNTU := ./dist-newstyle/build/x86_64-linux/ghc-*/elm-*/x/elm/build/elm/elm

OS := $(shell uname)

default: all

build:
ifeq ($(OS), Darwin)
	cabal build --minimize-conflict-set
	@mkdir -p $(BIN_DIR)
	cp $(BUILD_DIR_MAC) $(ELM)
else ifeq ($(OS), Linux)
	cabal build --minimize-conflict-set
	@mkdir -p $(BIN_DIR)
	cp $(BUILD_DIR_UBUNTU) $(ELM)
endif

test:
	cd Example && $(ELM) make $(SRC_FILE) --output=$(OUT_FILE)

all: build test

clean:
	rm -rf $(BIN_DIR)
	cabal clean

install-mac:
	brew install ghc cabal-install llvm

	cabal update
	cabal install
	cabal configure
	cabal --version

install-ubuntu:
	sudo apt-get update
	sudo apt-get install -y ghc cabal-install llvm

	cabal update
	cabal install
	cabal configure
	cabal --version

ghcup:
	ghcup install ghc latest
	ghcup set ghc latest
	ghc --version
