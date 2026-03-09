.PHONY: test lint

test:
	bash tests/test-common.sh
	bash tests/test-checkpoint.sh
	bash tests/test-auto-handoff.sh
	bash tests/test-auto-resume.sh

lint:
	bash -n scripts/lib/common.sh
	bash -n scripts/checkpoint.sh
	bash -n scripts/auto-handoff.sh
	bash -n scripts/auto-resume.sh
