#!/usr/bin/env bash
# Creates a self-signed cert for local Plaid OAuth (dev only).
set -euo pipefail

cd "$(dirname "$0")/.."
CERT_DIR="backend/certs"

mkdir -p "$CERT_DIR"

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$CERT_DIR/localhost-key.pem" \
  -out "$CERT_DIR/localhost.pem" \
  -days 825 \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

echo "✓ Created $CERT_DIR/localhost.pem"
echo ""
echo "In Plaid Dashboard → Allowed redirect URIs, add:"
echo "  https://localhost:8787/plaid/oauth"
echo "  https://localhost:8787/plaid/complete"
echo ""
echo "Then restart: cd backend && npm start"
