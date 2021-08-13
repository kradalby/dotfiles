function gc
    if string length -q -- $GPG_FINGERPRINT
        git commit -S
    else
        git commit
    end
end
