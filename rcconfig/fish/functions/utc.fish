function utc
    curl -sI "http://nist.time.gov/timezone.cgi?UTC/s/0" | awk -F': ' '/Date: / {print $2}'
end
