PROJECT = sumo_rest

CONFIG ?= test/test.config

DEPS = mixer cowboy jiffy katana trails swagger sumo_db
SHELL_DEPS = sync
TEST_DEPS = elvis xref_runner shotgun

dep_katana = git https://github.com/inaka/erlang-katana.git 0.2.14
dep_cowboy = git https://github.com/extend/cowboy.git 1.0.4
dep_jiffy = git https://github.com/davisp/jiffy.git 0.14.4
dep_mixer = git https://github.com/inaka/mixer.git 0.1.4
dep_sync = git https://github.com/inaka/sync.git 0.1.3
dep_shotgun = git https://github.com/inaka/shotgun.git 0.1.12
dep_sumo_db = git https://github.com/inaka/sumo_db.git 0.3.13
dep_swagger = git https://github.com/inaka/cowboy-swagger e9b1062
dep_trails = git https://github.com/inaka/cowboy-trails.git 0.0.2
dep_xref_runner = git https://github.com/inaka/xref_runner.git 0.2.2

include erlang.mk

LOCAL_DEPS := tools compiler syntax_tools common_test inets test_server dialyzer wx
DIALYZER_DIRS := ebin/ test/
DIALYZER_OPTS := --verbose --statistics -Wunmatched_returns

ERLC_OPTS := +warn_unused_vars +warn_export_all +warn_shadow_vars +warn_unused_import +warn_unused_function
ERLC_OPTS += +warn_bif_clash +warn_unused_record +warn_deprecated_function +warn_obsolete_guard +strict_validation
ERLC_OPTS += +warn_export_vars +warn_exported_vars +warn_missing_spec +warn_untyped_record +debug_info

TEST_ERLC_OPTS += +debug_info
CT_OPTS += -cover test/cover.spec -vvv -erl_args -config ${CONFIG}

SHELL_OPTS += -name ${PROJECT}@`hostname` -config ${CONFIG} -boot start_sasl -s sync

quicktests: app
	@$(MAKE) --no-print-directory app-build test-dir ERLC_OPTS="$(TEST_ERLC_OPTS)"
	$(verbose) mkdir -p $(CURDIR)/logs/
	$(gen_verbose) $(CT_RUN) -suite $(addsuffix _SUITE,$(CT_SUITES)) $(CT_OPTS)

test-build-plt: ERLC_OPTS=$(TEST_ERLC_OPTS)
test-build-plt:
	@$(MAKE) --no-print-directory test-dir ERLC_OPTS="$(TEST_ERLC_OPTS)"
	$(gen_verbose) touch ebin/test

plt-all: PLT_APPS := $(ALL_TEST_DEPS_DIRS)
plt-all: test-deps test-build-plt plt

dialyze-all: app test-build-plt dialyze

erldocs:
	erldocs . -o docs

juan:
	echo ${ERL_LIBS}