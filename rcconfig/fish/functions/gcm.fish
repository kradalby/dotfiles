function gcm
    if string length -q -- $GPG_FINGERPRINT
        git commit -S -m "$argv"
    else
        git commit -m "$argv"
    end
end
