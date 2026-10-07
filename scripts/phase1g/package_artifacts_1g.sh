#!/bin/bash
# SRW3 Phase 1G — artifact bundle (self-excluding MANIFEST; the 1D/1E/1F
# packaging discipline). Bundles the phase1g evidence + the report + the
# provenance; verifies the round trip.
set -u
SRW3=/home/z/my-project/srw3-kevm
OUTDIR=/home/z/my-project/download
NAME=SRW3-Phase1G-Artifact-Bundle
STAGE=/tmp/1g-bundle
rm -rf "$STAGE"; mkdir -p "$STAGE/$NAME"
cd "$SRW3" || exit 1

# copy the 1G tree (sources, proofs, python, transcripts, report, provenance)
mkdir -p "$STAGE/$NAME"/{phase1g,scripts}
cp -r phase1g/semantics phase1g/proofs phase1g/python phase1g/transcripts \
      phase1g/report phase1g/provenance "$STAGE/$NAME/phase1g/" || exit 1
find "$STAGE/$NAME" -name "*.tmp_codes" -delete
rm -rf "$STAGE/$NAME/phase1g/semantics/authz-hs-out" \
       "$STAGE/$NAME/phase1g/semantics/authz-out"
cp -r scripts/phase1g "$STAGE/$NAME/scripts/"
mkdir -p "$STAGE/$NAME/k-kevm"
cp k/kevm/srw3-authz-evm.k k/kevm/srw3-authz-evm-demos.k "$STAGE/$NAME/k-kevm/"
mkdir -p "$STAGE/$NAME/k-kevm/demos"
cp k/kevm/demos/evm_authz_*.srw3evm "$STAGE/$NAME/k-kevm/demos/"
cp worklog.md "$STAGE/$NAME/"

cd "$STAGE/$NAME" || exit 1
find . -type f ! -name MANIFEST.txt -printf './%P\n' | sort | while read -r f; do
  sha256sum "$f"
done > MANIFEST.txt
cd "$STAGE" || exit 1
rm -f "$OUTDIR/$NAME.zip" && zip -qr "$OUTDIR/$NAME.zip" "$NAME"
sha256sum "$OUTDIR/$NAME.zip" | cut -d' ' -f1 > "$OUTDIR/$NAME.zip.sha256"

# round-trip check
RT=/tmp/1g-rt; rm -rf "$RT"; mkdir -p "$RT"
unzip -q "$OUTDIR/$NAME.zip" -d "$RT"
cd "$RT/$NAME" || exit 1
OK=0; BAD=0
while read -r f; do
  if echo "$f" | grep -qE "MANIFEST.txt$"; then continue; fi
  GOT=$(sha256sum "$f" | cut -d' ' -f1)
  WANT=$(grep -F " $f" MANIFEST.txt | cut -d' ' -f1)
  if [ "$GOT" = "$WANT" ]; then OK=$((OK+1)); else BAD=$((BAD+1)); echo "DRIFT: $f"; fi
done < <(find . -type f ! -name MANIFEST.txt -printf './%P\n' | sort)
echo "ROUND-TRIP: OK=$OK BAD=$BAD"
echo "bundle: $OUTDIR/$NAME.zip ($(stat -c%s "$OUTDIR/$NAME.zip") bytes), sha256 $(cat "$OUTDIR/$NAME.zip.sha256")"
