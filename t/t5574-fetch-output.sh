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

test_expect_success 'fetch porcelain output' '
	test_when_finished "rm -rf porcelain-cfg porcelain-cli" &&

	# Set up a bunch of references that we can use to demonstrate different
	# kinds of flag symbols in the output format.
	MAIN_OLD=$(git rev-parse HEAD) &&
	git branch "fast-forward" &&
	git branch "deleted-branch" &&
	git checkout -b force-updated &&
	test_commit --no-tag force-update-old &&
	FORCE_UPDATED_OLD=$(git rev-parse HEAD) &&
	git checkout main &&

	# Clone and pre-seed the repositories. We fetch references into two
	# namespaces so that we can test that rejected and force-updated
	# references are reported properly.
	refspecs="refs/heads/*:refs/unforced/* +refs/heads/*:refs/forced/*" &&
	git clone . porcelain-cli &&
	git clone . porcelain-cfg &&
	git -C porcelain-cfg fetch origin $refspecs &&
	git -C porcelain-cli fetch origin $refspecs &&

	# Now that we have set up the client repositories we can change our
	# local references.
	git branch new-branch &&
	git branch -d deleted-branch &&
	git checkout fast-forward &&
	test_commit --no-tag fast-forward-new &&
	FAST_FORWARD_NEW=$(git rev-parse HEAD) &&
	git checkout force-updated &&
	git reset --hard HEAD~ &&
	test_commit --no-tag force-update-new &&
	FORCE_UPDATED_NEW=$(git rev-parse HEAD) &&

	cat >expect <<-EOF &&
	- $MAIN_OLD $ZERO_OID refs/forced/deleted-branch
	- $MAIN_OLD $ZERO_OID refs/unforced/deleted-branch
	  $MAIN_OLD $FAST_FORWARD_NEW refs/unforced/fast-forward
	! $FORCE_UPDATED_OLD $FORCE_UPDATED_NEW refs/unforced/force-updated
	* $ZERO_OID $MAIN_OLD refs/unforced/new-branch
	  $MAIN_OLD $FAST_FORWARD_NEW refs/forced/fast-forward
	+ $FORCE_UPDATED_OLD $FORCE_UPDATED_NEW refs/forced/force-updated
	* $ZERO_OID $MAIN_OLD refs/forced/new-branch
	  $MAIN_OLD $FAST_FORWARD_NEW refs/remotes/origin/fast-forward
	+ $FORCE_UPDATED_OLD $FORCE_UPDATED_NEW refs/remotes/origin/force-updated
	* $ZERO_OID $MAIN_OLD refs/remotes/origin/new-branch
	EOF

	# Execute a dry-run fetch first. We do this to assert that the dry-run
	# and non-dry-run fetches produces the same output. Execution of the
	# fetch is expected to fail as we have a rejected reference update.
	test_must_fail git -C porcelain-cfg -c fetch.output=porcelain fetch --dry-run --prune origin $refspecs >actual-dry-run-cfg &&
	test_must_fail git -C porcelain-cli fetch --output-format=porcelain --dry-run --prune origin $refspecs >actual-dry-run-cli &&
	test_cmp actual-dry-run-cfg actual-dry-run-cli &&
	test_cmp expect actual-dry-run-cfg &&

	# And now we perform a non-dry-run fetch.
	test_must_fail git -C porcelain-cfg -c fetch.output=porcelain fetch --prune origin $refspecs >actual-cfg &&
	test_must_fail git -C porcelain-cli fetch --output-format=porcelain --prune origin $refspecs >actual-cli &&
	test_cmp actual-cfg actual-cli &&
	test_cmp expect actual-cfg &&

	# Ensure that the dry-run and non-dry-run output matches.
	test_cmp actual-dry-run-cfg actual-cfg
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

test_expect_success 'fetch porcelain output with HEAD and --dry-run' '
	test_when_finished "rm -rf head" &&
	git clone . head &&
	COMMIT_ID=$(git rev-parse HEAD) &&

	git -C head fetch --output-format=porcelain --dry-run origin HEAD >actual &&
	cat >expect <<-EOF &&
	* $ZERO_OID $COMMIT_ID FETCH_HEAD
	EOF
	test_cmp expect actual &&

	git -C head fetch --output-format=porcelain --dry-run origin HEAD:foo >actual &&
	cat >expect <<-EOF &&
	* $ZERO_OID $COMMIT_ID refs/heads/foo
	EOF
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
