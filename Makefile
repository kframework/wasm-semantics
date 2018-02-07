# Settings
# --------

buildr_dir:=$(CURDIR)/.buildr
defn_dir:=$(buildr_dir)/defn
k_submodule:=$(buildr_dir)/k

.PHONY: buildr deps ocaml-deps defn

all: buildr

clean:
	rm -rf $(buildr_dir)

# Build Dependencies (K Submodule)
# --------------------------------

k_bin:=$(k_submodule)/k-distribution/target/release/k/bin
pkg_config_local:=$(buildr_dir)/local/lib/pkgconfig

deps: $(k_submodule)/make.timestamp ocaml-deps

$(k_submodule)/make.timestamp:
	git submodule update --init -- $(k_submodule)
	cd $(k_submodule) \
		&& mvn package -q -DskipTests
	touch $(k_submodule)/make.timestamp

ocaml-deps:
	opam init --quiet --no-setup
	opam repository add k "$(k_submodule)/k-distribution/target/release/k/lib/opam" \
		|| opam repository set-url k "$(k_submodule)/k-distribution/target/release/k/lib/opam"
	opam update
	opam switch 4.03.0+k
	eval $$(opam config env) \
	opam install --yes mlgmp zarith uuidm

# Building Definition
# -------------------

buildr: $(defn_dir)/wasm-kompiled/interpreter

# Tangle definition from *.md files

k_files:=wasm.k wasm-syntax.k
defn_files:=$(patsubst %, $(defn_dir)/%, $(k_files))

defn: $(defn_files)

$(defn_dir)/%.k: %.md
	@echo "==  tangle: $@"
	mkdir -p $(dir $@)
	pandoc --from markdown --to tangle.lua --metadata=code:k $< > $@

# OCAML Backend

$(defn_dir)/wasm-kompiled/interpreter: $(defn_files) deps
	@echo "== kompile: $@"
	eval $$(opam config env) \
	$(k_bin)/kompile --debug --gen-ml-only -O3 --non-strict \
					 --main-module WASM --syntax-module WASM $< --directory $(defn_dir) ; \
	ocamlfind opt -c $(defn_dir)/wasm-kompiled/constants.ml -package gmp -package zarith ; \
	ocamlfind opt -c -I $(defn_dir)/wasm-kompiled ; \
	ocamlfind opt -a -o $(defn_dir)/semantics.cmxa ; \
	ocamlfind remove wasm-semantics-plugin ; \
	ocamlfind install wasm-semantics-plugin META $(defn_dir)/semantics.cmxa $(defn_dir)/semantics.a ; \
	$(k_bin)/kompile --debug --packages wasm-semantics-plugin -O3 --non-strict \
					 --main-module WASM --syntax-module WASM $< --directory $(defn_dir) ; \
	cd $(defn_dir)/wasm-kompiled \
		&& ocamlfind opt -o interpreter \
			-package gmp -package dynlink -package zarith -package str -package uuidm -package unix -package wasm-semantics-plugin \
			-linkpkg -inline 20 -nodynlink -O3 -linkall \
			constants.cmx prelude.cmx plugin.cmx parser.cmx lexer.cmx run.cmx interpreter.ml
