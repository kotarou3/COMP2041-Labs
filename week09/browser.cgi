#!/bin/sh
echo "Content-type: text/html"
echo

cat <<_EOF
<!DOCTYPE html>
<html lang="en">
<head>
<title>IBrowser IP, Host and User Agent</title>
</head>
<body>
Your browser is running at IP address: <b>$REMOTE_ADDR</b>
<p>
Your browser is running on hostname: <b>$(dig +short -x "$REMOTE_ADDR" | sed -E 's/\.$//')</b>
<p>
Your browser identifies as: <b>$HTTP_USER_AGENT</b>
</body>
</html>
_EOF
