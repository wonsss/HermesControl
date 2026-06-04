#!/bin/zsh
# 공개 배포 전 PII/비밀/불필요파일 스캔. git 레포 루트에서 실행.
set -e
cd "${1:-.}"
echo "════ 배포 전 보안 스캔 ════"

echo "\n[1] 추적되는 파일 (= 공개될 것)"
git ls-files

echo "\n[2] 빌드 산출물이 추적되는가 (없어야 정상)"
git ls-files | grep -iE "\.app|\.zip|\.icns|\.build|DS_Store" && echo "⚠ 산출물 추적됨 — .gitignore 확인" || echo "✓ 산출물 추적 안 됨"

echo "\n[3] 추적 파일 + 전체 히스토리에서 PII/비밀 패턴"
HITS=$(git grep -inE "@(naver|gmail|icloud|outlook|hotmail)\.com|password[=:\" ]|secret[=:\" ]|api[_-]?key|app-specific|sk-[A-Za-z0-9]|ghp_[A-Za-z0-9]|AKIA[0-9A-Z]|-----BEGIN" $(git rev-list --all) 2>/dev/null | grep -viE "example\.com|tokens-per-sec|max_tokens|completion_tokens" || true)
[[ -n "$HITS" ]] && { echo "⚠ 점검 필요:"; echo "$HITS" | head -30; } || echo "✓ 비밀/개인이메일 패턴 없음"

echo "\n[4] 커밋 author/committer 이메일 (개인 이메일 노출?)"
git log --format='%an <%ae> | %cn <%ce>' | sort -u

echo "\n[5] 본인 홈 경로 하드코딩"
git grep -n "/Users/" $(git rev-list --all) 2>/dev/null | head -10 || echo "✓ 없음"

echo "\n════ 스캔 완료 — [3][4][5]에 결과 있으면 정리 후 push ════"
