#!/usr/bin/env bash
# Step: timezone — set the system timezone (the live USB boots in UTC)
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$REPO_DIR/lib/common.sh"

# Override with TIMEZONE=Region/City bash install.sh --only timezone
tz="${TIMEZONE:-America/Los_Angeles}"

current="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
if [[ "$current" == "$tz" ]]; then
  skip "timezone already $tz"
else
  run sudo timedatectl set-timezone "$tz"
  ok "timezone set to $tz (was ${current:-unknown})"
fi
