#!/bin/sh

test_description='git fetch output format'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'fetch with invalid output format configuration' '
	test_when_finished "rm -rf clone" &&
	git clone . clone &&

	test_must_fail git -C clone -c fetch.output= fetch origin >actual 2>&1 &&
	cat >expect <<-EOF &&
	fatal: invalid value for ${SQ}fetch.output${SQ}: ${SQ}${SQ}
	EOF
	test_cmp expect actual &&

	test_must_fail git -C clone -c fetch.output=garbage fetch origin >actual 2>&1 &&
	cat >expect <<-EOF &&
	fatal: invalid value for ${SQ}fetch.output${SQ}: ${SQ}garbage${SQ}
	EOF
	test_cmp expect actual
'

test_expect_success 'fetch with invalid output format via command line' '
	test_must_fail git fetch --output-format >actual 2>&1 &&
	cat >expect <<-EOF &&
	error: option \`output-format${SQ} requires a value
	EOF
	test_cmp expect actual &&

	test_must_fail git fetch --output-format= origin >actual 2>&1 &&
	cat >expect <<-EOF &&
	error: unsupported output format ${SQ}${SQ}
	EOF
	test_cmp expect actual &&

	test_must_fail git fetch --output-format=garbage origin >actual 2>&1 &&
	cat >expect <<-EOF &&
	error: unsupported output format ${SQ}garbage${SQ}
	EOF
	test_cmp expect actual
'

test_expect_success 'fetch aligned output' '
	test_when_finished "rm -rf full-cfg full-cli" &&
	git clone . full-cfg &&
	git clone . full-cli &&
	test_commit looooooooooooong-tag &&

	git -C full-cfg -c fetch.output=full fetch origin >actual-cfg 2>&1 &&
	git -C full-cli fetch --output-format=full origin >actual-cli 2>&1 &&
	test_cmp actual-cfg actual-cli &&

	grep -e "->" actual-cfg | cut -c 22- >actual &&
	cat >expect <<-\EOF &&
	main                 -> origin/main
	looooooooooooong-tag -> looooooooooooong-tag
	EOF
	test_cmp expect actual
'

test_expect_success 'fetch compact output' '
	test_when_finished "rm -rf compact-cfg compact-cli" &&
	git clone . compact-cli &&
	git clone . compact-cfg &&
	test_commit extraaa &&

	git -C compact-cfg -c fetch.output=compact fetch origin >actual-cfg 2>&1 &&
	git -C compact-cli fetch --output-format=compact origin >actual-cli 2>&1 &&
	test_cmp actual-cfg actual-cli &&

	grep -e "->" actual-cfg | cut -c 22- >actual &&
	cat >expect <<-\EOF &&
	main       -> origin/*
	extraaa    -> *
	EOF
	test_cmp expect actual
'

test_expect_success 'fetch compact output with multiple remotes' '
	test_when_finished "rm -rf compact-cfg compact-cli" &&

	git clone . compact-cli &&
	git -C compact-cli remote add second-remote "$PWD" &&
	git clone . compact-cfg &&
	git -C compact-cfg remote add second-remote "$PWD" &&
	test_commit multi-commit &&

	git -C compact-cfg -c fetch.output=compact fetch --all >actual-cfg 2>&1 &&
	git -C compact-cli fetch --output-format=compact --all >actual-cli 2>&1 &&
	test_cmp actual-cfg actual-cli &&

	grep -e "->" actual-cfg | cut -c 22- >actual &&
	cat >expect <<-\EOF &&
	main         -> origin/*
	multi-commit -> *
	main       -> second-remote/*
	EOF
	test_cmp expect actual
'

test_expect_success 'fetch output with HEAD and --dry-run' '
	test_when_finished "rm -rf head" &&
	git clone . head &&

	git -C head fetch --dry-run origin HEAD >actual 2>&1 &&
	cat >expect <<-EOF &&
	From $(test-tool path-utils real_path .)/.
	 * branch            HEAD       -> FETCH_HEAD
	EOF
	test_cmp expect actual &&

	git -C head fetch origin HEAD >actual 2>&1 &&
	test_cmp expect actual &&

	git -C head fetch --dry-run origin HEAD:foo >actual 2>&1 &&
	cat >expect <<-EOF &&
	From $(test-tool path-utils real_path .)/.
	 * [new ref]         HEAD       -> foo
	EOF
	test_cmp expect actual &&

	git -C head fetch origin HEAD:foo >actual 2>&1 &&
	test_cmp expect actual
'

test_expect_success '--no-show-forced-updates' '
	mkdir forced-updates &&
	(
		cd forced-updates &&
		git init &&
		test_commit 1 &&
		test_commit 2
	) &&
	git clone forced-updates forced-update-clone &&
	git clone forced-updates no-forced-update-clone &&
	git -C forced-updates reset --hard HEAD~1 &&
	(
		cd forced-update-clone &&
		git fetch --show-forced-updates origin 2>output &&
		test_i18ngrep "(forced update)" output
	) &&
	(
		cd no-forced-update-clone &&
		git fetch --no-show-forced-updates origin 2>output &&
		test_i18ngrep ! "(forced update)" output
	)
'

test_done
