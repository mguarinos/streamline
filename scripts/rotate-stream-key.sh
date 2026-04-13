#!/usr/bin/env bash
set -euo pipefail

# rotate-stream-key.sh
#
# Creates a new IVS stream key, stores it in Secrets Manager, and deletes
# the old key. Run this if your stream key is ever exposed or you rotate
# credentials on a schedule.
#
# Prerequisites: aws CLI with permissions for ivs:CreateStreamKey,
#   ivs:DeleteStreamKey, secretsmanager:PutSecretValue, and
#   secretsmanager:GetSecretValue.

info()    { echo "  $*"; }
success() { echo "✓ $*"; }
section() { echo ""; echo "── $* ──"; }

# ── 1. Inputs ─────────────────────────────────────────────────────────────────

section "Configuration"

read -r -p "IVS channel ARN    []: " CHANNEL_ARN
if [[ -z "$CHANNEL_ARN" ]]; then
  echo "Error: IVS channel ARN is required." >&2
  exit 1
fi

read -r -p "Secrets Manager ARN []: " SECRET_ARN
if [[ -z "$SECRET_ARN" ]]; then
  echo "Error: Secrets Manager secret ARN is required." >&2
  exit 1
fi

info "Channel: $CHANNEL_ARN"
info "Secret:  $SECRET_ARN"

# ── 2. Read current stream key ARN from Secrets Manager ───────────────────────
#
# The secret value is the raw stream key string (sk_...), not the key ARN.
# We need to list stream keys on the channel to find the ARN of the current key.

section "Reading current stream keys"

CURRENT_KEYS=$(aws ivs list-stream-keys \
  --channel-arn "$CHANNEL_ARN" \
  --query 'streamKeys[*].arn' \
  --output json)

KEY_COUNT=$(echo "$CURRENT_KEYS" | jq 'length')
info "Found $KEY_COUNT existing stream key(s)"

# ── 3. Create new stream key ───────────────────────────────────────────────────

section "Creating new stream key"

NEW_KEY=$(aws ivs create-stream-key \
  --channel-arn "$CHANNEL_ARN" \
  --output json)

NEW_KEY_ARN=$(echo "$NEW_KEY" | jq -r '.streamKey.arn')
NEW_KEY_VALUE=$(echo "$NEW_KEY" | jq -r '.streamKey.value')

success "New stream key created: $NEW_KEY_ARN"

# ── 4. Update Secrets Manager ─────────────────────────────────────────────────

section "Updating Secrets Manager"

aws secretsmanager put-secret-value \
  --secret-id "$SECRET_ARN" \
  --secret-string "$NEW_KEY_VALUE"

success "Secret updated"

# ── 5. Delete old stream keys ─────────────────────────────────────────────────

section "Removing old stream key(s)"

if [[ "$KEY_COUNT" -eq 0 ]]; then
  info "No old keys to remove"
else
  echo "$CURRENT_KEYS" | jq -r '.[]' | while read -r OLD_ARN; do
    info "Deleting $OLD_ARN..."
    aws ivs delete-stream-key --arn "$OLD_ARN"
    success "Deleted"
  done
fi

# ── 6. Summary ────────────────────────────────────────────────────────────────

echo ""
echo "✓ Stream key rotated successfully"
echo ""
echo "Update your broadcasting software:"
echo "  OBS Studio → Settings → Stream → Stream Key"
echo "  Paste the new key from Secrets Manager:"
echo ""
echo "  aws secretsmanager get-secret-value \\"
echo "    --secret-id '${SECRET_ARN}' \\"
echo "    --query SecretString \\"
echo "    --output text"
echo ""
echo "The old key has been invalidated — any live stream using it will be dropped."
