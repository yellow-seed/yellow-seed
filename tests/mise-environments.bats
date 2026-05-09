#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "mise default config stays minimal" {
	[[ -f "$REPO_ROOT/.mise.toml" ]]
	run grep -E '^(bats|dotenvx|gh|pinact|terraform|"github:qltysh/qlty"|"github:max-sixty/worktrunk") = ' "$REPO_ROOT/.mise.toml"
	[ "$status" -eq 1 ]
}

@test "ci workflow installs only bats from ci mise environment" {
	run grep -F "MISE_ENV=ci bash scripts/install-tools.sh bats" "$REPO_ROOT/.github/workflows/ci.yml"
	[ "$status" -eq 0 ]
}

@test "sidecar workflow owns quality checks" {
	[[ -f "$REPO_ROOT/.github/workflows/sidecar-ci.yml" ]]

	run grep -F "name: Sidecar CI" "$REPO_ROOT/.github/workflows/sidecar-ci.yml"
	[ "$status" -eq 0 ]

	run grep -F "scripts/run-checks.sh" "$REPO_ROOT/.github/workflows/sidecar-ci.yml"
	[ "$status" -eq 0 ]

	run grep -F "reviewdog/action-actionlint@" "$REPO_ROOT/.github/workflows/sidecar-ci.yml"
	[ "$status" -eq 0 ]
}

@test "tool sidecar build uses sidecar mise environment" {
	run grep -F "COPY .mise.sidecar.toml /workspace/.mise.sidecar.toml" "$REPO_ROOT/Dockerfile"
	[ "$status" -eq 0 ]

	run grep -F "MISE_ENV=sidecar STRICT_MODE=true bash /workspace/scripts/install-tools.sh" "$REPO_ROOT/Dockerfile"
	[ "$status" -eq 0 ]

	run grep -F "ENV MISE_ENV=sidecar" "$REPO_ROOT/Dockerfile"
	[ "$status" -eq 0 ]
}

@test "tool sidecar runtime uses sidecar mise environment" {
	run grep -F "MISE_ENV=sidecar" "$REPO_ROOT/compose.yml"
	[ "$status" -eq 0 ]
}

@test "qlty excludes openspec artifacts from prettier" {
	run grep -F '"openspec/**",' "$REPO_ROOT/.qlty/qlty.toml"
	[ "$status" -eq 0 ]
}
