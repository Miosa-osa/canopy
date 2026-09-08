.PHONY: setup dev test test-watch lint format build clean doctor seed db-reset gen-types

# ─── Setup ────────────────────────────────────────────────────────────────────

setup:
	pnpm install
	cd backend && mix deps.get
	cd backend && mix ecto.create
	cd backend && mix ecto.migrate
	cd backend && mix run priv/repo/seeds.exs
	make gen-types

gen-types:
	cd packages/types && pnpm generate

seed:
	cd backend && mix run priv/repo/seeds.exs

db-reset:
	cd backend && mix ecto.drop
	cd backend && mix ecto.create
	cd backend && mix ecto.migrate
	cd backend && mix run priv/repo/seeds.exs

# ─── Development ──────────────────────────────────────────────────────────────

dev:
	@trap 'kill %1 %2 %3 2>/dev/null; exit' INT; \
	(cd backend && mix phx.server) & \
	(cd desktop && pnpm dev) & \
	(cd desktop && pnpm tauri dev) & \
	wait

# ─── Testing ──────────────────────────────────────────────────────────────────

test:
	cd backend && mix test
	cd desktop && pnpm test
	cargo test --manifest-path src-tauri/Cargo.toml

test-watch:
	@trap 'kill %1 %2 %3 2>/dev/null; exit' INT; \
	(cd backend && mix test.watch) & \
	(cd desktop && pnpm test) & \
	(cargo watch -x "test --manifest-path src-tauri/Cargo.toml") & \
	wait

# ─── Lint & Format ────────────────────────────────────────────────────────────

lint:
	cd desktop && pnpm biome check .
	cd backend && mix format --check-formatted

format:
	cd desktop && pnpm biome format --write .
	cd backend && mix format

# ─── Build ────────────────────────────────────────────────────────────────────

build:
	cd backend && MIX_ENV=prod mix release
	cd desktop && pnpm build
	cd desktop && pnpm tauri build

# ─── Clean ────────────────────────────────────────────────────────────────────

clean:
	rm -rf backend/_build backend/deps
	rm -rf desktop/node_modules desktop/.svelte-kit desktop/build desktop/dist
	rm -rf src-tauri/target
	rm -rf node_modules

# ─── Doctor ───────────────────────────────────────────────────────────────────

doctor:
	@echo "=== Canopy v2 — Tool Version Check ==="
	@echo ""
	@REQUIRED_ELIXIR="1.19.5"; \
	ACTUAL_ELIXIR=$$(elixir --version 2>/dev/null | grep '^Elixir' | awk '{print $$2}' || echo "not found"); \
	if [ "$$ACTUAL_ELIXIR" = "$$REQUIRED_ELIXIR" ]; then \
		echo "[OK]   elixir   $$ACTUAL_ELIXIR"; \
	else \
		echo "[FAIL] elixir   required=$$REQUIRED_ELIXIR actual=$$ACTUAL_ELIXIR"; exit 1; \
	fi
	@REQUIRED_ERLANG="28"; \
	ACTUAL_ERLANG=$$(erl -noshell -eval 'erlang:display(erlang:system_info(otp_release)), halt().' 2>/dev/null | tr -d '"\n\r' || echo "not found"); \
	if [ "$$ACTUAL_ERLANG" = "$$REQUIRED_ERLANG" ]; then \
		echo "[OK]   erlang   $$ACTUAL_ERLANG"; \
	else \
		echo "[FAIL] erlang   required=$$REQUIRED_ERLANG actual=$$ACTUAL_ERLANG"; exit 1; \
	fi
	@REQUIRED_NODE="24.14.1"; \
	ACTUAL_NODE=$$(node --version 2>/dev/null | sed 's/v//' || echo "not found"); \
	if [ "$$ACTUAL_NODE" = "$$REQUIRED_NODE" ]; then \
		echo "[OK]   nodejs   $$ACTUAL_NODE"; \
	else \
		echo "[FAIL] nodejs   required=$$REQUIRED_NODE actual=$$ACTUAL_NODE"; exit 1; \
	fi
	@REQUIRED_RUST="1.94.1"; \
	ACTUAL_RUST=$$(rustc --version 2>/dev/null | awk '{print $$2}' || echo "not found"); \
	if [ "$$ACTUAL_RUST" = "$$REQUIRED_RUST" ]; then \
		echo "[OK]   rust     $$ACTUAL_RUST"; \
	else \
		echo "[FAIL] rust     required=$$REQUIRED_RUST actual=$$ACTUAL_RUST"; exit 1; \
	fi
	@REQUIRED_PNPM="9"; \
	ACTUAL_PNPM=$$(pnpm --version 2>/dev/null | cut -d. -f1 || echo "not found"); \
	if [ "$$ACTUAL_PNPM" -ge "$$REQUIRED_PNPM" ] 2>/dev/null; then \
		echo "[OK]   pnpm     $$(pnpm --version 2>/dev/null)"; \
	else \
		echo "[FAIL] pnpm     required>=$$REQUIRED_PNPM actual=$$ACTUAL_PNPM"; exit 1; \
	fi
	@echo ""
	@command -v rg >/dev/null || { echo "[FAIL] ripgrep (rg) is required for workspace search"; exit 1; }
	@echo "Tip: use asdf to pin versions — see .tool-versions"
